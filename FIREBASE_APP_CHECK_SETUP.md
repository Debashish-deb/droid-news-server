# Firebase App Check Setup Guide

**Status**: Implementation Complete  
**Time Required**: 15-30 minutes  
**Difficulty**: Easy

---

## What is Firebase App Check?

Firebase App Check protects your backend resources from abuse by ensuring requests come from legitimate instances of your app, not:

- Modified/hacked APKs
- Emulators
- Bots/scripts
- Unauthorized clients

---

## ✅ Code Integration (DONE)

### 1. Added Dependency

```yaml
# pubspec.yaml
firebase_app_check: ^0.3.1+3
```

### 2. Activated in main.dart

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.deviceCheck,
);
```

---

## 🔧 Required Setup Steps

### Step 1: Enable App Check in Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Build** → **App Check**
4. Click **Get Started**

---

### Step 2: Register Android App (Play Integrity)

1. In App Check console, find your Android app
2. Click **Register** under Play Integrity
3. No additional configuration needed (automatic with Google Play)

**Note**: Play Integrity is Google's recommended provider for production apps.

---

### Step 3: Register iOS App (DeviceCheck)

1. In App Check console, find your iOS app
2. Click **Register** under DeviceCheck
3. Download your **private key** from Apple Developer Console
4. Upload the key to Firebase

**Apple Developer Steps**:

1. Go to [Apple Developer](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Keys**
4. Create new key with **DeviceCheck** capability
5. Download the `.p8` file
6. Upload to Firebase App Check settings

---

### Step 4: Set Enforcement (Optional but Recommended)

In Firebase Console App Check settings:

**For Testing** (Leave unenforced initially):

- ✅ Firestore: Unenforced
- ✅ Cloud Functions: Unenforced
- ✅ Storage: Unenforced

**For Production** (After testing):

- ✅ Firestore: **Enforced**
- ✅ Cloud Functions: **Enforced**
- ✅ Storage: **Enforced**

---

## 🧪 Testing Setup

### Debug Tokens (For Development)

During development, you'll need debug tokens to test without Play Integrity.

#### Generate Debug Token

```bash
# Run app in debug mode
flutter run

# Check logs for:
# "App Check debug token: XXXXX-XXXX-XXXX-XXXX"
```

#### Add to Firebase Console

1. Go to App Check → Apps → Your App
2. Click **Manage debug tokens**
3. Add the token from logs
4. Set expiration (up to 1 year)

---

## 📱 Platform-Specific Notes

### Android (Play Integrity)

**Requirements**:

- App must be published on Google Play (even internal testing track)
- Or use debug tokens for development

**Automatic**:

- No code changes needed
- Works automatically when app is signed and published

### iOS (DeviceCheck)

**Requirements**:

- iOS 11+ (App Attest for iOS 14+)
- App must be installed from App Store
- Or use debug tokens for development

**Automatic**:

- Works after key upload to Firebase
- No additional code needed

---

## 🔒 Security Benefits

### What App Check Blocks

✅ **Modified APKs**: Users can't decompile and modify your app  
✅ **Emulators**: Bot farms can't test/abuse your app  
✅ **Bots**: Automated scripts can't access your backend  
✅ **Unauthorized Clients**: Only your genuine app can connect

### What Gets Through

✅ **Legitimate Users**: Real users on real devices  
✅ **Official App**: Only your signed app from stores  
✅ **Debug Mode**: With debug tokens for testing

---

## ⚙️ How It Works

### Without App Check (Before)

```
User → Firestore ✅ (Anyone can access)
Bot  → Firestore ✅ (No verification)
Hack → Firestore ✅ (Modified app works)
```

### With App Check (After)

```
User → App Check → Firestore ✅ (Verified)
Bot  → App Check → ❌ Blocked (No valid token)
Hack → App Check → ❌ Blocked (Invalid signature)
```

---

## 🚀 Deployment Checklist

### Pre-Production

- [ ] Install `firebase_app_check` package ✅
- [ ] Add activation code to `main.dart` ✅
- [ ] Enable App Check in Firebase Console
- [ ] Register Android app (Play Integrity)
- [ ] Register iOS app (DeviceCheck + upload key)
- [ ] Add debug tokens for development
- [ ] Test app on real device
- [ ] Verify no blocking in debug mode

### Production Launch

- [ ] Remove debug tokens (or set short expiration)
- [ ] Test on production build
- [ ] Monitor App Check dashboard
- [ ] **Enable enforcement** for:
  - [ ] Firestore
  - [ ] Cloud Functions
  - [ ] Storage
- [ ] Monitor for legitimate users being blocked
- [ ] Keep debug tokens for support team

---

## 📊 Monitoring

### Firebase App Check Dashboard

View in Console:

1. App Check → Overview
2. See metrics:
   - Valid requests
   - Invalid requests (blocked)
   - Top sources of invalid requests

### Expected Metrics

- **Valid Requests**: 95-99% (normal usage)
- **Invalid Requests**: 1-5% (bots, modified apps)

**Alert if**:

- Valid requests drop significantly (misconfiguration)
- Invalid requests spike (coordinated attack)

---

## 🐛 Troubleshooting

### "App Check token is invalid" in logs

**Development**:

- Add debug token from logs to Firebase Console
- Or temporarily disable enforcement

**Production**:

- Ensure app is signed with release keystore
- Verify Play Integrity registration
- Check iOS DeviceCheck key is uploaded

### App doesn't work on emulator

**Expected**: Emulators are blocked by design

**Solution**:

- Add debug token for that emulator
- Or test on real device

### iOS app fails after App Store deployment

**Issue**: DeviceCheck key not uploaded

**Solution**:

1. Download .p8 key from Apple Developer
2. Upload to Firebase Console
3. Redeploy app

---

## 💰 Cost

Firebase App Check is **FREE** on the Spark (free) plan:

- 10,000 verifications/month free
- $0.01 per 1,000 verifications after that

**For most apps**: Completely free

---

## 🔄 Rollback Plan

If App Check causes issues:

1. **Quick Fix**: Disable enforcement in Firebase Console
2. **Complete Rollback**: Comment out activation code:

```dart
// await FirebaseAppCheck.instance.activate(...);
```

3. Redeploy app

---

## 📚 Additional Resources

- [Firebase App Check Docs](https://firebase.google.com/docs/app-check)
- [Play Integrity Guide](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [DeviceCheck Guide](https://firebase.google.com/docs/app-check/ios/devicecheck-provider)

---

## Summary

**Code**: ✅ Integrated  
**Setup Required**: Firebase Console (15-30 min)  
**Benefits**: Blocks modified apps, bots, emulators  
**Cost**: Free for most apps  
**Difficulty**: Easy

**Next**: Complete Firebase Console setup following steps above!
