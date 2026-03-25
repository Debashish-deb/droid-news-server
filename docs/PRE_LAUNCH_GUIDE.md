# 🚀 Pre-Launch Deployment Guide

## ✅ Step 1: Deploy Firebase Rules (5 min)

### Command

```bash
cd /Users/debashishdeb/Documents/JS/MobileApp/droid
chmod +x deploy_firebase_rules.sh
./deploy_firebase_rules.sh
```

### What it does

- Deploys `firestore.rules` to Firestore
- Deploys `storage.rules` to Firebase Storage
- Secures your Firebase backend

### Verification

- Check Firebase Console → Firestore → Rules
- Check Firebase Console → Storage → Rules
- Both should show updated timestamps

---

## 📝 Step 2: Host Privacy Policy (10 min)

### Option A: GitHub Pages (Recommended)

1. **Create a new GitHub repo** (e.g., `bdnews-legal`)

2. **Create two files:**

   ```
   privacy.html
   terms.html
   ```

3. **Copy content:**
   - From `docs/PRIVACY_POLICY.md` → `privacy.html` (convert to HTML)
   - From `docs/TERMS_OF_SERVICE.md` → `terms.html` (convert to HTML)

4. **Enable GitHub Pages:**
   - Settings → Pages
   - Source: main branch
   - Save

5. **Get URLs:**

   ```
   https://yourusername.github.io/bdnews-legal/privacy.html
   https://yourusername.github.io/bdnews-legal/terms.html
   ```

6. **Update app:**
   Edit `lib/features/settings/privacy_data_screen.dart`:

   ```dart
   Line 110: const url = 'https://yourusername.github.io/bdnews-legal/privacy.html';
   Line 118: const url = 'https://yourusername.github.io/bdnews-legal/terms.html';
   ```

### Option B: Firebase Hosting (Alternative)

1. **Install Firebase CLI:**

   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize hosting:**

   ```bash
   cd /Users/debashishdeb/Documents/JS/MobileApp/droid
   firebase login
   firebase init hosting
   ```

3. **Create `public` folder:**

   ```bash
   mkdir -p public
   cp docs/PRIVACY_POLICY.md public/privacy.html
   cp docs/TERMS_OF_SERVICE.md public/terms.html
   ```

4. **Deploy:**

   ```bash
   firebase deploy --only hosting
   ```

5. **Update URLs** in app (same as GitHub Pages)

---

## 🧪 Step 3: Test Features (30 min)

### Social Sharing Test

1. ✅ Open any news article
2. ✅ Tap share icon
3. ✅ Verify share sheet appears
4. ✅ Test WhatsApp share
5. ✅ Test copy link
6. ✅ Verify analytics logs event

### Offline Reading Test

1. ✅ Open any news article
2. ✅ Tap download icon
3. ✅ Verify article downloads
4. ✅ Check offline articles screen
5. ✅ Turn off WiFi
6. ✅ Verify article opens offline
7. ✅ Test delete article

### Privacy & Data Test

1. ✅ Go to Settings
2. ✅ Tap "Privacy & Data"
3. ✅ Verify screen opens
4. ✅ Test privacy policy link (after hosting)
5. ✅ Test terms link (after hosting)
6. ✅ Test data export
7. ✅ Test account deletion (BE CAREFUL!)

### General Testing

1. ✅ Test light/dark theme switching
2. ✅ Test language switching (EN/BN)
3. ✅ Test push notifications
4. ✅ Test favorites
5. ✅ Test search
6. ✅ Check for crashes in Crashlytics

---

## 🎉 Step 4: Final Checks Before Launch

### Code

- [ ] All features working
- [ ] No console errors
- [ ] Build succeeds
- [ ] Tests passing (flutter test)

### Firebase

- [ ] Rules deployed ✅
- [ ] Analytics working
- [ ] Crashlytics configured
- [ ] Push notifications tested

### Legal

- [ ] Privacy policy hosted
- [ ] Terms of service hosted
- [ ] URLs updated in app
- [ ] Data export working
- [ ] Account deletion working

### App Store

- [ ] Create app icon (1024x1024)
- [ ] Take screenshots (6-8 images)
- [ ] Write app description (EN + BN)
- [ ] Prepare store listing

---

## 📋 Quick Checklist

```
✅ Firebase rules deployed
✅ Privacy policy hosted
✅ URLs updated in app
✅ Social sharing tested
✅ Offline reading tested
✅ Privacy & Data tested
✅ Build successful
✅ No crashes
```

**When all checked:** YOU'RE READY TO LAUNCH! 🚀

---

## 🆘 Troubleshooting

### Firebase Rules Deployment Failed

```bash
# Check Firebase CLI
firebase --version

# Login again
firebase login

# Check project
firebase projects:list
```

### Privacy Policy Links Not Working

- Verify URLs are accessible in browser
- Check for HTTPS (not HTTP)
- Ensure no typos in URLs
- Test on mobile device

### Features Not Working

```bash
# Clean build
flutter clean
flutter pub get
flutter build apk --debug
```

---

## ⏱️ Time Estimate

- Firebase rules: 5 min
- Privacy hosting: 10 min
- Testing: 30 min
- Final checks: 15 min

**Total: 1 hour to launch-ready!**

---

You're almost there! 🎊
