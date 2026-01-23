const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}

/**
 * App Verification Function - Alternative to Firebase App Check
 * Validates app authenticity and blocks suspicious requests
 */
exports.validateAppRequest = functions.https.onCall(async (data, context) => {
    // Ensure user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'User must be authenticated'
        );
    }

    const { appVersion, platform, operation } = data;
    const userId = context.auth.uid;

    // 1. Version Check - Block outdated app versions
    const MIN_APP_VERSION = '1.0.0';
    if (!appVersion || appVersion < MIN_APP_VERSION) {
        console.log(`[AppVerification] Outdated version: ${appVersion} from user: ${userId}`);

        throw new functions.https.HttpsError(
            'failed-precondition',
            'App update required. Please update to the latest version.',
            { minVersion: MIN_APP_VERSION }
        );
    }

    // 2. Platform Check - Ensure valid platform
    const ALLOWED_PLATFORMS = ['android', 'ios'];
    if (!platform || !ALLOWED_PLATFORMS.includes(platform.toLowerCase())) {
        console.log(`[AppVerification] Invalid platform: ${platform} from user: ${userId}`);

        throw new functions.https.HttpsError(
            'invalid-argument',
            'Invalid platform specified'
        );
    }

    // 3. User Agent Check - Basic bot detection
    const userAgent = context.rawRequest.headers['user-agent'] || '';

    // Check if user agent contains expected app identifier
    const isValidUserAgent = userAgent.includes('Droid') ||
        userAgent.includes('okhttp') ||
        userAgent.includes('Dart');

    if (!isValidUserAgent) {
        console.log(`[AppVerification] Suspicious user-agent: ${userAgent} from user: ${userId}`);

        // Log but don't block (some legitimate requests might have different UA)
        await admin.firestore().collection('security_audit_log').add({
            userId,
            eventType: 'suspicious_user_agent',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            data: {
                userAgent,
                platform,
                operation,
            },
        });
    }

    // 4. Rate Limiting Check (basic server-side)
    const now = Date.now();
    const RATE_LIMIT_WINDOW = 60 * 60 * 1000; // 1 hour
    const MAX_VERIFICATIONS_PER_HOUR = 100;

    const recentVerifications = await admin.firestore()
        .collection('app_verifications')
        .where('userId', '==', userId)
        .where('timestamp', '>', now - RATE_LIMIT_WINDOW)
        .get();

    if (recentVerifications.size >= MAX_VERIFICATIONS_PER_HOUR) {
        console.log(`[AppVerification] Rate limit exceeded for user: ${userId}`);

        throw new functions.https.HttpsError(
            'resource-exhausted',
            'Too many verification requests. Please try again later.'
        );
    }

    // 5. Log successful verification
    await admin.firestore().collection('app_verifications').add({
        userId,
        appVersion,
        platform,
        operation: operation || 'general',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        userAgent: userAgent.substring(0, 100), // Limit length
    });

    // Return success
    return {
        verified: true,
        message: 'App verification successful',
        timestamp: now,
    };
});

/**
 * Device Registration Validation
 * Additional validation specifically for device registration
 */
exports.validateDeviceRegistration = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const { deviceId, platform } = data;
    const userId = context.auth.uid;

    // First, run general app validation
    try {
        await exports.validateAppRequest.run({
            ...data,
            operation: 'device_registration',
        }, context);
    } catch (error) {
        throw error; // Re-throw validation errors
    }

    // Additional device-specific validation
    if (!deviceId || typeof deviceId !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid device ID');
    }

    // Check device turnover rate (detect account sharing)
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const recentDevices = await admin.firestore()
        .collection('user_sessions')
        .doc(userId)
        .collection('devices')
        .where('firstSeen', '>', admin.firestore.Timestamp.fromMillis(thirtyDaysAgo))
        .get();

    // Flag suspicious behavior (>5 new devices in 30 days)
    if (recentDevices.size > 5) {
        await admin.firestore().collection('security_audit_log').add({
            userId,
            eventType: 'suspicious_device_turnover',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            data: {
                deviceCount: recentDevices.size,
                period: '30days',
            },
        });
    }

    return {
        validated: true,
        deviceId,
    };
});

/**
 * Cleanup old app verification logs (run daily)
 */
exports.cleanupAppVerifications = functions.pubsub
    .schedule('0 2 * * *') // Run at 2 AM daily
    .timeZone('UTC')
    .onRun(async (context) => {
        const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;

        const oldLogs = await admin.firestore()
            .collection('app_verifications')
            .where('timestamp', '<', admin.firestore.Timestamp.fromMillis(thirtyDaysAgo))
            .limit(500)
            .get();

        const batch = admin.firestore().batch();
        oldLogs.docs.forEach(doc => batch.delete(doc.ref));

        await batch.commit();

        console.log(`[Cleanup] Deleted ${oldLogs.size} old verification logs`);
        return null;
    });

/**
 * Save FCM notification token to Firestore
 * Enables server-side notification targeting
 */
exports.saveNotificationToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const { token, platform } = data;
    const userId = context.auth.uid;

    if (!token || typeof token !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid token');
    }

    const validPlatforms = ['android', 'ios', 'web'];
    if (!platform || !validPlatforms.includes(platform.toLowerCase())) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid platform');
    }

    // Save or update token
    await admin.firestore()
        .collection('notification_tokens')
        .doc(userId)
        .set({
            token,
            platform: platform.toLowerCase(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            userId,
        }, { merge: true });

    console.log(`[NotificationToken] Saved token for user: ${userId}, platform: ${platform}`);

    return {
        success: true,
        message: 'Token saved successfully',
    };
});

/**
 * Remove notification token (on logout)
 */
exports.removeNotificationToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const userId = context.auth.uid;

    await admin.firestore()
        .collection('notification_tokens')
        .doc(userId)
        .delete();

    console.log(`[NotificationToken] Removed token for user: ${userId}`);

    return {
        success: true,
        message: 'Token removed successfully',
    };
});
