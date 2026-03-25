import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { google } from 'googleapis';
import { defineString } from 'firebase-functions/params';

admin.initializeApp();

// Define parameters
const appleSharedSecret = defineString('APPLE_SHARED_SECRET');

// ============================================================================
// Rate Limiting Helper
// ============================================================================
const rateLimit = async (userId: string): Promise<boolean> => {
    const now = Date.now();
    const windowMs = 60 * 1000; // 1 minute
    const maxRequests = 5; // Max 5 requests per minute

    const rateLimitRef = admin.firestore().collection('rate_limits').doc(userId);

    try {
        const doc = await rateLimitRef.get();
        const data = doc.data();

        if (!data) {
            await rateLimitRef.set({ count: 1, resetTime: now + windowMs });
            return true;
        }

        if (now > data.resetTime) {
            await rateLimitRef.set({ count: 1, resetTime: now + windowMs });
            return true;
        }

        if (data.count >= maxRequests) {
            return false;
        }

        await rateLimitRef.update({ count: admin.firestore.FieldValue.increment(1) });
        return true;
    } catch (error) {
        console.error('Rate limit error:', error);
        return false;
    }
};

// ============================================================================
// iOS App Store Receipt Validation
// ============================================================================
const validateAppleReceipt = async (receiptData: string): Promise<any> => {
    const url = 'https://sandbox.itunes.apple.com/verifyReceipt';

    const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            'receipt-data': receiptData,
            'password': appleSharedSecret.value() || '',
            'exclude-old-transactions': true,
        }),
    });

    return response.json();
};

// ============================================================================
// Android Play Store Receipt Validation
// ============================================================================
const validateGoogleReceipt = async (
    packageName: string,
    productId: string,
    purchaseToken: string
): Promise<any> => {
    const androidpublisher = google.androidpublisher('v3');

    const auth = new google.auth.GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const authClient = await auth.getClient();

    const result = await androidpublisher.purchases.products.get({
        auth: authClient as any,
        packageName: packageName,
        productId: productId,
        token: purchaseToken,
    });

    return result.data;
};

// ============================================================================
// Main Cloud Function - Receipt Validation (v2)
// ============================================================================
export const validateReceipt = onCall(async (request) => {
    const { auth, data } = request;

    // 1. Authenticate user
    if (!auth) {
        throw new HttpsError(
            'unauthenticated',
            'User must be authenticated to validate receipts'
        );
    }

    const userId = auth.uid;
    console.log(`Receipt validation request from user: ${userId}`);

    // 2. Rate limiting
    const allowed = await rateLimit(userId);
    if (!allowed) {
        console.warn(`Rate limit exceeded for user: ${userId}`);
        throw new HttpsError(
            'resource-exhausted',
            'Too many validation requests. Please try again in a minute.'
        );
    }

    // 3. Validate input
    const { platform, receiptData, packageName, productId, purchaseToken } = data;

    if (!platform || !['ios', 'android'].includes(platform)) {
        throw new HttpsError(
            'invalid-argument',
            'Platform must be either "ios" or "android"'
        );
    }

    try {
        let validationResult: any;
        let tier = 'free';

        // 4. Platform-specific validation
        if (platform === 'ios') {
            if (!receiptData) {
                throw new HttpsError('invalid-argument', 'Receipt data is required for iOS validation');
            }

            console.log('Validating iOS receipt...');
            validationResult = await validateAppleReceipt(receiptData);

            if (validationResult.status !== 0) {
                console.error(`iOS receipt validation failed with status: ${validationResult.status}`);
                throw new HttpsError(
                    'failed-precondition',
                    `Receipt validation failed with status: ${validationResult.status}`
                );
            }

            const latestReceipt = validationResult.latest_receipt_info?.[0];
            if (latestReceipt) {
                tier = latestReceipt.product_id.includes('pro_plus') ? 'proPlus' : 'pro';
            }
        } else {
            // Android validation
            if (!packageName || !productId || !purchaseToken) {
                throw new HttpsError(
                    'invalid-argument',
                    'Package name, product ID, and purchase token are required for Android validation'
                );
            }

            console.log(`Validating Android receipt for product: ${productId}`);
            validationResult = await validateGoogleReceipt(packageName, productId, purchaseToken);

            if (validationResult.purchaseState !== 0) {
                console.error(`Android purchase not in valid state: ${validationResult.purchaseState}`);
                throw new HttpsError('failed-precondition', 'Purchase is not in a valid state');
            }

            tier = productId.includes('pro_plus') ? 'proPlus' : 'pro';
        }

        // 5. Update user subscription in Firestore
        await admin
            .firestore()
            .collection('users')
            .doc(userId)
            .set(
                {
                    subscription: {
                        tier: tier,
                        status: 'active',
                        validatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        platform: platform,
                        productId: productId || 'unknown',
                    },
                    isPremium: true,
                },
                { merge: true }
            );

        console.log(`✅ Successfully validated ${platform} purchase for user: ${userId}, tier: ${tier}`);

        // 6. Log successful validation
        await admin.firestore().collection('purchase_logs').add({
            userId: userId,
            platform: platform,
            productId: productId || 'unknown',
            tier: tier,
            validatedAt: admin.firestore.FieldValue.serverTimestamp(),
            success: true,
        });

        return {
            success: true,
            tier: tier,
            message: 'Receipt validated successfully',
        };
    } catch (error: any) {
        console.error(`❌ Receipt validation failed for user: ${userId}`, error);

        // Log failed validation
        await admin.firestore().collection('purchase_logs').add({
            userId: userId,
            platform: platform,
            productId: productId || 'unknown',
            validatedAt: admin.firestore.FieldValue.serverTimestamp(),
            success: false,
            error: error.message || 'Unknown error',
        });

        // Re-throw if it's already an HttpsError
        if (error instanceof HttpsError) {
            throw error;
        }

        // Wrap other errors
        throw new HttpsError('internal', `Receipt validation failed: ${error.message}`);
    }
});
