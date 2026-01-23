#!/bin/bash

# Firebase Security Rules Deployment Script
# This script deploys Firestore and Storage security rules to production

echo "🔒 Deploying Firebase Security Rules..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Login check
echo "🔐 Checking Firebase authentication..."
firebase login:list

if [ $? -ne 0 ]; then
    echo "🔑 Please login to Firebase:"
    firebase login
fi

# Deploy Firestore rules
echo ""
echo "📦 Deploying Firestore rules..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully"
else
    echo "❌ Firestore rules deployment failed"
    exit 1
fi

# Deploy Storage rules
echo ""
echo "📦 Deploying Storage rules..."
firebase deploy --only storage:rules

if [ $? -eq 0 ]; then
    echo "✅ Storage rules deployed successfully"
else
    echo "❌ Storage rules deployment failed"
    exit 1
fi

echo ""
echo "🎉 All security rules deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Test rules in Firebase Console"
echo "2. Verify user data access is restricted"
echo "3. Monitor usage in Firebase Console"
