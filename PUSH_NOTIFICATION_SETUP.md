# Push Notification Platform Configuration Guide

## Overview

This guide walks you through the platform-specific configuration required for push notifications on Android and iOS.

## Android Configuration

### 1. AndroidManifest.xml

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Add these permissions before the <application> tag -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/> <!-- Android 13+ -->
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### 2. Notification Icon (Optional but Recommended)

For better branding, add a custom notification icon:

1. Create notification icon image (white on transparent, 24x24dp)
2. Use Android Asset Studio or place manually in:
   - `android/app/src/main/res/drawable/ic_notification.png`
   - Or use multiple densities:
     - `res/drawable-hdpi/ic_notification.png` (72x72px)
     - `res/drawable-mdpi/ic_notification.png` (48x48px)  
     - `res/drawable-xhdpi/ic_notification.png` (96x96px)
     - `res/drawable-xxhdpi/ic_notification.png` (144x144px)
     - `res/drawable-xxxhdpi/ic_notification.png` (192x192px)

3. Update the notification service if using custom icon:

   ```dart
   icon: '@drawable/ic_notification', // in push_notification_service.dart
   ```

### 3. Firebase Configuration

Ensure `google-services.json` is in `android/app/` directory.

---

## iOS Configuration

### 1. Capabilities

Open `ios/Runner.xcworkspace` in Xcode and:

1. Select the **Runner** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Push Notifications**
5. Add **Background Modes** and enable:
   - ✅ Remote notifications
   - ✅ Background fetch (optional)

### 2. Info.plist

No changes needed - permissions are requested at runtime.

### 3. APNs Configuration (Critical for Production)

#### Get APNs Auth Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Keys** → Create new key
4. Enable **Apple Push Notifications service (APNs)**
5. Download the `.p8` file (you can only download once!)
6. Note the **Key ID** and **Team ID**

#### Upload to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Project Settings** → **Cloud Messaging**
4. Under **Apple app configuration**, click **Upload**
5. Upload your `.p8` file
6. Enter **Key ID** and **Team ID**
7. Click **Upload**

### 4. Firebase Configuration

Ensure `GoogleService-Info.plist` is in `ios/Runner/` directory.

### 5. Testing Requirements

**IMPORTANT**: iOS push notifications only work on physical devices, not the simulator!

---

## Testing Your Setup

### 1. Check Token Generation

Run the app and check the console/logs for:

```
🔑 FCM Token: <long-token-string>
```

If you see this, Firebase Messaging is working!

### 2. Send Test Notification from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Navigate to **Engage** → **Cloud Messaging**
3. Click **Send your first message**
4. Fill in:
   - **Notification title**: "Test Notification"
   - **Notification text**: "This is a test message"
5. Click **Next**
6. Select your app
7. Click **Next**
8. Click **Review** → **Publish**

### 3. Expected Behavior

**App in Foreground:**

- Local notification banner appears
- Tapping opens the app to appropriate screen

**App in Background:**

- System notification appears
- Tapping opens the app

**App Terminated:**

- System notification appears
- Tapping launches the app

---

## Notification Payload Format

When sending notifications from your backend, use this format:

```json
{
  "notification": {
    "title": "Breaking News",
    "body": "New article published"
  },
  "data": {
    "screen": "/news-detail",
    "url": "https://example.com/article/123",
    "title": "Article Title",
    "channel": "general_news"
  },
  "topic": "breaking_news"
}
```

**Data Fields:**

- `screen`: Route to navigate to (e.g., `/webview`, `/home`)
- `url`: URL to open in webview
- `title`: Title for webview screen
- `channel`: Notification channel (`general_news`, `personalized`, `promotional`)

---

## Topic Subscriptions

Users are automatically subscribed to topics based on their preferences:

- **breaking_news**: Breaking news updates (enabled by default)
- **personalized**: Personalized content (enabled by default)
- **promotional**: Promotional content (enabled by default, premium users can disable)

### Sending to Topics

From your backend:

```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "topic": "breaking_news",
      "notification": {
        "title": "Breaking News",
        "body": "Important update"
      },
      "data": {
        "screen": "/home",
        "channel": "general_news"
      }
    }
  }'
```

---

## Troubleshooting

### Android

**Notifications not appearing:**

- Check if `POST_NOTIFICATIONS` permission is granted (Android 13+)
- Verify `google-services.json` is present
- Check notification channels are created
- Enable logging and check console

**App crashes on notification:**

- Ensure background handler is registered before `runApp()`
- Check notification payload format

### iOS

**Notifications not appearing:**

- Verify APNs certificate is uploaded to Firebase
- Check device is not in "Do Not Disturb" mode
- Ensure notification permissions are granted
- Test on physical device (not simulator!)

**Permission dialog not showing:**

- Permission is only requested once
- Reset: Settings → General → Reset → Reset Location & Privacy

### Common Issues

**Token not generating:**

- Check Firebase initialization in main.dart
- Verify Firebase config files are present
- Check internet connectivity

**Notifications work in foreground but not background:**

- Ensure background handler is registered
- Check iOS capabilities (Background Modes)

---

## Next Steps

### Backend Integration

Create an endpoint to store FCM tokens:

```dart
// Example: Send token to backend
Future<void> _sendTokenToBackend(String token) async {
  final response = await http.post(
    Uri.parse('https://your-api.com/fcm/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fcm_token': token,
      'user_id': userId,
      'platform': Platform.isAndroid ? 'android' : 'ios',
    }),
  );
}
```

Uncomment the `// TODO` sections in `push_notification_service.dart` once your backend is ready.

### Analytics

Track notification events:

```dart
// In notification service
FirebaseAnalytics.instance.logEvent(
  name: 'notification_received',
  parameters: {'type': data['channel']},
);
```

---

## Production Checklist

Before going live:

- [ ] APNs certificate uploaded to Firebase (iOS)
- [ ] Custom notification icons added (Android)
- [ ] Tested on physical iOS device
- [ ] Tested all app states (foreground/background/terminated)
- [ ] Backend token storage implemented
- [ ] Notification categories configured
- [ ] Analytics tracking added
- [ ] Rate limiting configured on backend
- [ ] User preferences tested
- [ ] Topic subscriptions working

---

## Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [FlutterFire Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [APNs Documentation](https://developer.apple.com/documentation/usernotifications)
