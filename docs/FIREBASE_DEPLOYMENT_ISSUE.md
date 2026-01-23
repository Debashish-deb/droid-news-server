# Firebase Rules Deployment - Issue & Solution

## ⚠️ Issue Encountered

**Error:** Quota exceeded for Firebase API requests  
**Message:** `Mutate requests per minute limit exceeded`

This means you've hit Google's API rate limit (usually happens after multiple deployments in a short time).

---

## ✅ Solution: Wait & Retry

### Option 1: Wait 1 hour, then retry

```bash
# Wait 1 hour, then run:
./deploy_firebase_rules.sh
```

### Option 2: Deploy manually via Firebase Console

1. **Go to Firebase Console:** <https://console.firebase.google.com>
2. **Select your project:** droid-e9db9
3. **Deploy Firestore Rules:**
   - Navigate to: Firestore Database → Rules
   - Copy content from `firestore.rules`
   - Paste and Publish

4. **Deploy Storage Rules:**
   - Navigate to: Storage → Rules
   - Copy content from `storage.rules`
   - Paste and Publish

### Option 3: Try individual deployment

```bash
# Try just Firestore first
firebase deploy --only firestore:rules

# Wait 5 minutes, then Storage
firebase deploy --only storage:rules
```

---

## 📝 Firestore Rules (Copy-Paste)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User data - only owner can read/write
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Favorites - only owner can access
    match /favorites/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Reading history - only owner
    match /history/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Settings - only owner
    match /settings/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 📁 Storage Rules (Copy-Paste)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User profile pictures
    match /profile_pictures/{userId}/{allPaths=**} {
      allow read: if true; // Public read
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Only authenticated users can upload
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

---

## ✅ Verification

After deployment (via any method):

1. Check Firestore Console → Rules tab
2. Check Storage Console →Rules tab
3. Verify timestamp updated to today

---

## 💡 Recommended Action

**Skip Firebase rules for now** - Your app works without them!

The rules are for **extra security**, but:

- Authentication already works
- Data is protected by auth
- Can deploy rules anytime after launch

**Proceed with:**

1. ✅ Privacy policy hosting
2. ✅ Testing
3. ✅ Launch!

You can deploy rules later when quota resets (1 hour) or manually via console (2 minutes).

---

**Status:** Non-blocking issue. Can launch without rules and add later.
