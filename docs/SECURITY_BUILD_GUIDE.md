# Security Build Configuration Guide

## Code Obfuscation for Flutter

### Building Release with Obfuscation

```bash
# Android Release APK (Obfuscated)
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Android App Bundle (Obfuscated)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols

# iOS Release (Obfuscated)
flutter build ios --release --obfuscate --split-debug-info=build/ios/outputs/symbols
```

### What Obfuscation Does

- Renames classes, methods, and variables to meaningless names
- Makes reverse engineering extremely difficult
- Reduces app size slightly
- **Does NOT affect performance**

### Debug Symbols

The `--split-debug-info` flag creates symbol files that map obfuscated names back to original names.

**Important:** Save these symbols! They're needed to:

- Read crash reports from Crashlytics
- Debug production issues
- Decode stack traces

**Where symbols are saved:**

- Android: `build/app/outputs/symbols/`
- iOS: `build/ios/outputs/symbols/`

### Upload Symbols to Firebase

```bash
# Android
firebase crashlytics:symbols:upload \
  --app=YOUR_ANDROID_APP_ID \
  build/app/outputs/symbols

# iOS
# Automatically uploaded by Xcode if configured
```

## ProGuard Configuration (Android)

If you have custom Android code or plugins, you may need ProGuard rules.

### Create `android/app/proguard-rules.pro`

```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Preserve generic signatures (for plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serialization
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
```

### Enable ProGuard in `android/app/build.gradle`

```gradle
android {
    buildTypes {
        release {
            // Enable ProGuard
            minifyEnabled true
            shrinkResources true
            
            // ProGuard files
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            
            // Signing config
            signingConfig signingConfigs.release
        }
    }
}
```

## Testing Obfuscated Build

### 1. Build obfuscated APK

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

### 2. Install on device

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 3. Test thoroughly

- All features work
- No crashes
- Crashlytics reports correctly
- Performance is good

### 4. Verify obfuscation

```bash
# Extract APK
unzip build/app/outputs/flutter-apk/app-release.apk -d extracted/

# Check lib/arm64-v8a/libapp.so - should see gibberish class names
strings extracted/lib/arm64-v8a/libapp.so | less
```

## Data Security

### Sensitive Data Storage

Use `flutter_secure_storage` for sensitive data:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Write
await storage.write(key: 'auth_token', value: token);

// Read
String? token = await storage.read(key: 'auth_token');

// Delete
await storage.delete(key: 'auth_token');
```

### What to Store Securely

- Authentication tokens
- API keys
- User passwords (if any)
- Refresh tokens
- Private keys

### What NOT to Store

- Never hardcode API keys in code
- Never store passwords in SharedPreferences
- Never log sensitive data

## Network Security

### Enforce HTTPS

In `AndroidManifest.xml`:

```xml
<application
    android:usesCleartextTraffic="false">
</application>
```

### Certificate Pinning (Optional)

For high-security needs:

```dart
import 'package:http/io_client.dart';
import 'dart:io';

SecurityContext context = SecurityContext.defaultContext;
context.setTrustedCertificates('path/to/cert.pem');

HttpClient httpClient = HttpClient(context: context);
IOClient ioClient = IOClient(httpClient);
```

## Permission Security

### Review AndroidManifest.xml

```xml
<!-- Only include permissions you actually use -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Remove any unused permissions -->
```

### iOS Info.plist

```xml
<!-- Add permission descriptions -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan QR codes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo access to share images</string>
```

## Security Checklist

- [ ] Code obfuscation enabled
- [ ] Debug symbols saved
- [ ] ProGuard rules configured
- [ ] Sensitive data encrypted
- [ ] HTTPS enforced
- [ ] Permissions minimized
- [ ] API keys secured
- [ ] Firebase rules deployed
- [ ] Privacy policy linked
- [ ] Crashlytics configured for obfuscated builds

## Common Issues

### Crashlytics shows obfuscated stack traces

**Solution:** Upload debug symbols to Firebase

### App crashes after obfuscation

**Solution:** Add ProGuard rules for affected classes

### Larger APK size

**Solution:** Enable `shrinkResources` and `minifyEnabled`

### Build fails

**Solution:** Check ProGuard rules, may need to keep certain classes

## Production Build Command

**Final command for production:**

```bash
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --target-platform android-arm,android-arm64 \
  --build-number=1 \
  --build-name=1.0.0
```

Save symbols folder: `build/symbols/` (backup these files!)
