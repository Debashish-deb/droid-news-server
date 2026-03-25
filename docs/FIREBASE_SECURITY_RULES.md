# Firebase Security Rules

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // User profiles - users can only read/write their own
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // User preferences - same as profiles
    match /preferences/{userId} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Favorites - users can only access their own
    match /favorites/{userId}/{document=**} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Reading history - users can only access their own
    match /history/{userId}/{document=**} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Public read-only data (if any)
    match /public/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Firebase Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // User profile images
    match /users/{userId}/profile/{filename} {
      allow read: if true; // Anyone can read profile images
      allow write: if request.auth != null 
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // Max 5MB
                   && request.resource.contentType.matches('image/.*');
    }
    
    // User uploaded content (if any)
    match /users/{userId}/uploads/{filename} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null 
                   && request.auth.uid == userId
                   && request.resource.size < 10 * 1024 * 1024; // Max 10MB
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Realtime Database Security Rules (if used)

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "favorites": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    ".read": false,
    ".write": false
  }
}
```

## How to Deploy

### Via Firebase Console

1. Go to Firebase Console
2. Select your project
3. Navigate to Firestore/Storage/Realtime Database
4. Click "Rules" tab
5. Paste the rules above
6. Click "Publish"

### Via Firebase CLI

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (if not done)
firebase init

# Deploy rules
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
firebase deploy --only database:rules
```

## Testing Security Rules

```dart
// Test authenticated access
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // This should work
  await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();
  
  // This should fail
  await FirebaseFirestore.instance
    .collection('users')
    .doc('other-user-id')
    .get(); // Permission denied
}
```

## Important Notes

- Rules are **not** filters - they deny requests that don't match
- Test rules thoroughly before deploying to production
- Use Firebase Emulator for local testing
- Monitor usage in Firebase Console
- Set up billing alerts to avoid unexpected costs

## Common Patterns

### Allow read but restrict write

```javascript
allow read: if true;
allow write: if isOwner(userId);
```

### Validate data

```javascript
allow write: if isOwner(userId) 
             && request.resource.data.keys().hasAll(['name', 'email'])
             && request.resource.data.name is string;
```

### Time-based rules

```javascript
allow read: if request.time < timestamp.date(2027, 1, 1);
```
