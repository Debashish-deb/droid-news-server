# ============================================================================
# PROGUARD / R8 RULES — BD NEWS READER
# ============================================================================

# ─── SECTION 1: APP CLASSES ──────────────────────────────────────────────────

# Annotation-driven keep (always prefer this over blanket rules)
-keep @androidx.annotation.Keep class * { *; }
-keep @com.google.android.gms.common.annotation.KeepName class * { *; }

# App package — MainActivity is redundant here since it's covered by the wildcard
-keep class com.bd.bdnewsreader.** { *; }


# ─── SECTION 2: JNI / NATIVE ─────────────────────────────────────────────────

-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
# includedescriptorclasses: also keeps param/return types reachable from JNI


# ─── SECTION 3: ANDROID FRAMEWORK ────────────────────────────────────────────

# Activities, Services, etc. are referenced by name in the manifest —
# R8 handles these automatically when minifyEnabled=true, but explicit
# rules are harmless and act as documentation.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends androidx.fragment.app.Fragment

# Custom Views inflated from XML need their constructor signatures preserved
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}



# ─── SECTION 4: SERIALIZATION ────────────────────────────────────────────────

-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}


# ─── SECTION 5: GOOGLE ADS ───────────────────────────────────────────────────

# The Play Services Ads SDK ships its own consumer proguard rules via AAR.
# These explicit rules are only needed if you use reflection/custom mediation.
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# AD_ID API (required for PPID / privacy sandbox on API 33+)
-keep class com.google.android.gms.ads.identifier.** { *; }


# ─── SECTION 6: FIREBASE ─────────────────────────────────────────────────────

# Firebase & Flutter Plugins:
# We explicitly keep io.flutter.plugins.** to ensure Pigeon-generated utility 
# classes (like GeneratedAndroidFirebaseAnalyticsPigeonUtils) are not stripped.
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn io.flutter.plugins.**



# ─── SECTION 7: SQLCIPHER / SQLITE ───────────────────────────────────────────

-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn net.sqlcipher.**


# ─── SECTION 8: FLUTTER PLUGINS ──────────────────────────────────────────────

# flutter_secure_storage
-keep class com.it_solutions.flutter_secure_storage.** { *; }

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# just_audio (commonly paired with audio_service)
-keep class com.ryanheise.just_audio.** { *; }


# ─── SECTION 9: REFLECTION & ENUMS ───────────────────────────────────────────

-keep class **.R$* { <fields>; }

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Generics & annotations needed for Gson, Retrofit, and similar reflection libs
-keepattributes Signature, Exceptions, *Annotation*, EnclosingMethod, InnerClasses

# Suppress noisy warnings from annotation processors not in the runtime classpath
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**


# ─── SECTION 10: DEBUG & STACK TRACES ────────────────────────────────────────

# Preserve line numbers for Crashlytics stack traces
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile


# ─── SECTION 11: R8 FULL MODE OPTIMIZATIONS ──────────────────────────────────

# R8 full mode (enabled by default in AGP 8+) supersedes ProGuard's -optimizations
# directive. These flags are ignored by R8 and only affect legacy ProGuard runs.
# Keeping them is harmless but they do nothing in a modern AGP 8+ / R8 build.
#
# -optimizations code/simplification/arithmetic,...
# -optimizationpasses 5
#
# Instead, control R8 behaviour via gradle.properties:
#   android.enableR8.fullMode=true   ← default in AGP 8+

-allowaccessmodification
