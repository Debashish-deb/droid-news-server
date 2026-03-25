# ============================================================================
# OPTIMIZED PROGUARD/R8 RULES FOR ANDROID APP
# ============================================================================
# File: android/app/proguard-rules.pro
#
# These rules tell R8 which code to keep and how to optimize it.
# More aggressive = smaller APK but must test thoroughly
# ============================================================================

# ============================================================================
# SECTION 1: KEEP CLASSES REQUIRED FOR APP TO FUNCTION
# ============================================================================

# Keep all classes with @Keep annotation (from AndroidX)
-keep @androidx.annotation.Keep class * {*;}
-keep @com.google.android.gms.common.annotation.KeepName class * {*;}

# Keep your app's main classes and entry points
-keep class com.bd.bdnewsreader.** {*;}
-keep class com.bd.bdnewsreader.MainActivity {*;}

# Keep Android framework classes (already stripped by AGP, but explicit is safer)
-keep public class android.** {*;}
-keep public class androidx.** {*;}
-keep public class com.google.** {*;}

# ============================================================================
# SECTION 2: NATIVE METHODS (Must keep for JNI calls)
# ============================================================================

# Keep native methods (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================================
# SECTION 3: ANDROID LIFECYCLE & FRAMEWORK
# ============================================================================

# Activities, Services, Receivers, Providers - these are referenced by manifest
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.Fragment
-keep public class * extends androidx.fragment.app.Fragment
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Keep constructors for Fragment classes (instantiated via reflection)
-keep public class * extends androidx.fragment.app.Fragment {
    public <init>();
}

# Keep callbacks for AsyncTask
-keep class * extends android.os.AsyncTask {*;}

# Application class
-keep public class * extends android.app.Application

# ============================================================================
# SECTION 4: SERIALIZATION (Parcelable, Serializable)
# ============================================================================

# Parcelable - used for intent passing
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable - implements Serializable interface
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================================================================
# SECTION 5: REFLECTION & DYNAMIC LOADING
# ============================================================================

# Keep resource references (R classes) - accessed via reflection
-keep class **.R$* {
    <fields>;
}

# Keep enum values/methods - often accessed via reflection
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================================================================
# SECTION 6: ANDROIDX & GOOGLE LIBRARIES
# ============================================================================

# Firebase - required for crash reporting and analytics
-keep class com.firebase.** {*;}
-keep class com.google.firebase.** {*;}
-keep class com.google.firebase.analytics.** {*;}
-keep class com.google.firebase.crashlytics.** {*;}

# Keep annotation classes
-keep class androidx.annotation.** {*;}
-keep class com.google.android.material.** {*;}

# Keep Room database classes (if using SQLite)
-keep class androidx.room.** {*;}
-keepclassmembers class * {
    @androidx.room.* <fields>;
}

# Keep Jetpack Compose classes (if used)
-keep class androidx.compose.** {*;}

# Keep Kotlin metadata (helps with reflection)
-keep class kotlin.Metadata { *; }

# ============================================================================
# SECTION 7: GSON/JSON SERIALIZATION
# ============================================================================

# Gson classes and methods
-keep class com.google.gson.** {*;}
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Your data classes used by Gson (JSON serialization)
# Example:
-keep class com.bd.bdnewsreader.data.models.** {*;}
-keep class com.bd.bdnewsreader.domain.models.** {*;}

# Keep field names in data classes
-keepclassmembers class com.bd.bdnewsreader.data.models.** {
    !transient <fields>;
}

# ============================================================================
# SECTION 8: RETROFIT & HTTP CLIENTS
# ============================================================================

# Retrofit interfaces and methods must be kept
-keep interface com.bd.bdnewsreader.data.api.** {*;}
-keep class * implements com.bd.bdnewsreader.data.api.** {*;}

# OkHttp
-keep class okhttp3.** {*;}
-keep class com.squareup.okhttp3.** {*;}

# ============================================================================
# SECTION 9: COROUTINES & REACTIVE LIBRARIES
# ============================================================================

# Kotlin Coroutines
-keep class kotlinx.coroutines.** {*;}
-keep interface kotlinx.coroutines.** {*;}

# Keep debugging info for coroutines
-keepattributes SourceFile,LineNumberTable

# RxJava (if used)
-keep class io.reactivex.** {*;}
-keep interface io.reactivex.** {*;}

# ============================================================================
# SECTION 10: CRASH REPORTING & ANALYTICS
# ============================================================================

# Firebase Crashlytics
-keep class com.google.firebase.crashlytics.** {*;}
-keep class com.google.firebase.crashlytics.internal.** {*;}

# Keep stack traces readable (don't rename methods in critical classes)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ============================================================================
# SECTION 11: OPTIMIZATION RULES
# ============================================================================

# General optimizations
-optimizations code/simplification/arithmetic,code/simplification/cast,field/*,class/merging/*
-optimizationpasses 5

# Aggressive optimizations (may break some apps - test thoroughly!)
-allowaccessmodification
-repackageclasses

# ============================================================================
# SECTION 12: WARNINGS & VERBOSE OUTPUT
# ============================================================================

# Ignore warnings from libraries (they're often fine)
-dontwarn android.**
-dontwarn androidx.**
-dontwarn com.google.**
-dontwarn com.firebase.**

# Ignore Kotlin warnings
-dontwarn kotlin.**
-dontwarn kotlin.reflect.**

# Ignore warnings from common libraries
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn com.squareup.**
-dontwarn com.google.gson.**

# Enable verbose logging to see what's being kept/removed (debug)
# -verbose

# ============================================================================
# SECTION 13: KOTLIN-SPECIFIC RULES
# ============================================================================

# Kotlin data classes often use reflection
-keep class kotlin.reflect.** {*;}

# Keep lambda classes
-keepclasseswithmembernames class * {
    private <fields>;
}

# Kotlin object singleton pattern
-keep class * {
    *** INSTANCE;
}

# ============================================================================
# SECTION 14: YOUR APP-SPECIFIC RULES
# ============================================================================

# ⚠️ Add these for YOUR specific classes that use reflection:

# Example: If you have a news model that's JSON-serialized
# -keep class com.bd.bdnewsreader.domain.models.NewsArticle {*;}
# -keep class com.bd.bdnewsreader.domain.models.NewsCategory {*;}

# Example: If you have custom views or components
# -keep class com.bd.bdnewsreader.ui.widgets.** {*;}

# Example: If you have a database with Room
# -keep @androidx.room.Entity class * {*;}
# -keep @androidx.room.Dao class * {*;}

# ============================================================================
# SECTION 15: OBFUSCATION CONTROL
# ============================================================================

# Some classes should NOT be obfuscated (often for debugging or external calls)
# -keep class com.bd.bdnewsreader.analytics.** {*;}

# Keep constants readable
-keepclasseswithmembers class * {
    public static final <fields>;
}

# ============================================================================
# SECTION 16: USEFUL COMMENTS FOR DEBUGGING
# ============================================================================

# To analyze what got removed:
# 1. Check mapping.txt in build outputs
# 2. Look for "nothing to do" warnings
# 3. Use R8 mapping viewer if concerned

# To verify a specific class is kept:
# Run: ./gradlew assembleRelease
# Then search mapping.txt for your class name

# Testing obfuscation:
# 1. Build release APK
# 2. Use apktool to decompile
# 3. Verify critical code is protected
# 4. Check no crashes from reflection breaking

# ============================================================================
# COMMON ISSUES & FIXES
# ============================================================================

# Issue: App crashes with NoSuchMethodException or NoSuchFieldException
# Fix: Add -keep rule for the class that caused it

# Issue: JSON deserialization fails (Gson/Retrofit)
# Fix: Add -keep for your model/data classes

# Issue: Firebase events not tracked
# Fix: Ensure -keep class com.google.firebase.** {*;}

# Issue: Custom Views don't inflate
# Fix: Keep class with constructors: -keep public class MyView { public <init>(...); }

# Issue: Animation/Interpolator classes fail
# Fix: Keep the specific classes or entire package

# ============================================================================
# PERFORMANCE NOTES
# ============================================================================

# APK Size Impact:
# - Minimal ProGuard: APK ~5% smaller
# - Aggressive: APK ~15-25% smaller
# - Trade-off: Need thorough testing

# Build Time Impact:
# - Added ~30-60 seconds to release builds
# - Only affects release builds (debug is untouched)
# - Subsequent builds are cached

# Runtime Impact:
# - Negligible (maybe 5-10ms slower app startup)
# - Small improvement in memory usage
# - Better for older Android versions

# ============================================================================
