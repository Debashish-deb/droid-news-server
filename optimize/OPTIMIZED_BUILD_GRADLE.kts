import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // kotlin("kapt") // Add if using annotation processors
}

// ============================================================================
// PROPERTIES & SIGNING CONFIGURATION
// ============================================================================

val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProps = keystorePropertiesFile.exists()

if (hasKeystoreProps) {
    keystorePropertiesFile.inputStream().buffered().use { keystoreProperties.load(it) }
}

fun requireKeystoreProp(name: String): String {
    return keystoreProperties.getProperty(name)
        ?: throw GradleException(
            "Missing `$name` in android/app/key.properties (required for release signing).\n" +
            "Create the file or set CI environment variables."
        )
}

// ============================================================================
// ANDROID CONFIGURATION
// ============================================================================

android {
    namespace = "com.bd.bdnewsreader"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    // ========================================================================
    // SIGNING CONFIGURATION
    // ========================================================================
    signingConfigs {
        if (hasKeystoreProps) {
            create("release") {
                keyAlias = requireKeystoreProp("keyAlias")
                keyPassword = requireKeystoreProp("keyPassword")
                storeFile = file(requireKeystoreProp("storeFile"))
                storePassword = requireKeystoreProp("storePassword")
                
                // ✅ SECURITY: Use v1 + v2 signing (recommend v2 for modern apps)
                enableV1Signing = true
                enableV2Signing = true
            }
        }

        // Debug signing config (optional, explicit)
        getByName("debug") {
            // Uses default Android debug key
        }
    }

    // ========================================================================
    // DEFAULT BUILD CONFIGURATION
    // ========================================================================
    defaultConfig {
        applicationId = "com.bd.bdnewsreader"
        minSdk = flutter.minSdkVersion  // ~24 for Flutter
        targetSdk = 35
        versionCode = 30
        versionName = flutter.versionName
        
        // ✅ OPTIMIZATION: Enable multidex for large apps
        multiDexEnabled = true
        
        // ✅ OPTIMIZATION: Configure vector drawable caching
        vectorDrawables.useSupportLibrary = true
        
        // ✅ APP: Configure resource configurations
        resourceConfigurations.addAll(
            setOf(
                "en",    // English
                "bn",    // Bengali - for your app
                "hdpi",  // High-density screens
                "xhdpi",
                "xxhdpi",
                "xxxhdpi"
            )
        )
        
        // ✅ OPTIMIZATION: Disable unused language resources
        // Prevents including ~200 languages Flutter doesn't use
        
        // ✅ OPTIMIZATION: Configure build features (disable unused)
        buildFeatures {
            viewBinding = false  // Set true only if you use it
            dataBinding = false  // Set true only if you use it
            aidl = false
            renderScript = false
            resValues = false
            shaders = false
        }

        // ✅ LINT: Configure linting
        lintOptions {
            checkReleaseBuilds = true
            abortOnError = false  // Don't fail build on lint warnings
            disable += setOf(
                "MissingDimensDefs",
                "MissingTranslation",
                "ExtraTranslation",
                "MissingDefaultResource"
            )
            // Fail on these critical issues
            fatal += setOf(
                "NewApi",
                "InlinedApi"
            )
        }
    }

    // ========================================================================
    // JAVA & KOTLIN COMPILER OPTIONS
    // ========================================================================
    compileOptions {
        // ✅ OPTIMIZATION: Use Java 17 for better performance
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        
        // ✅ OPTIMIZATION: Core library desugaring for modern APIs on older devices
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
        // ✅ OPTIMIZATION: Enable incremental compilation
        incremental = true
        
        // ✅ OPTIMIZATION: Allow jvm default methods
        freeCompilerArgs = listOf(
            "-Xjvm-default=all",
            "-opt-in=kotlin.RequiresOptIn"
        )
    }

    // ========================================================================
    // BUILD TYPES (Debug & Release)
    // ========================================================================
    buildTypes {
        
        // RELEASE BUILD - Optimized for production
        release {
            name = "release"
            
            // ✅ SECURITY: Fail fast if signing config missing
            if (!hasKeystoreProps) {
                throw GradleException(
                    "❌ Release build requires android/app/key.properties for signing.\n" +
                    "   Create it with: keytool -genkey -v -keystore ...\n" +
                    "   Or use CI environment variables + create at build time"
                )
            }

            // ✅ SECURITY: Apply signing configuration
            signingConfig = signingConfigs.getByName("release")

            // ✅ OPTIMIZATION: Enable code shrinking (ProGuard/R8)
            isMinifyEnabled = true
            isShrinkResources = true
            
            // ✅ OPTIMIZATION: Use R8 (built-in, modern replacement for ProGuard)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // ✅ OPTIMIZATION: Disable debug symbols in release
            isDebuggable = false
            
            // ✅ OPTIMIZATION: Enable debuggable for crash reporting (if needed)
            // isDebuggable = true  // Only if using Firebase Crashlytics

            // ✅ OPTIMIZATION: Set appropriate JNI debugging
            ndk {
                debugSymbolLevel = "full"  // Include debug symbols
            }
        }

        // DEBUG BUILD - Fast iteration, minimal optimization
        debug {
            name = "debug"
            
            // ✅ DEVELOPMENT: Keep debug symbols for crash stacks
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            
            // ✅ DEVELOPMENT: Fast build by disabling optimization
            ndk {
                debugSymbolLevel = "none"  // Skip symbols for faster builds
            }
        }

        // OPTIONAL: Staging build for testing
        // create("staging") {
        //     initWith(buildTypes.getByName("release"))
        //     isMinifyEnabled = false  // Keep readable for debugging
        //     isShrinkResources = false
        // }
    }

    // ========================================================================
    // BUILD VARIANTS & FLAVORS (Optional, uncomment if needed)
    // ========================================================================
    // flavorDimensions.add("app")
    // productFlavors {
    //     create("free") {
    //         dimension = "app"
    //         applicationIdSuffix = ".free"
    //     }
    //     create("premium") {
    //         dimension = "app"
    //         applicationIdSuffix = ".pro"
    //     }
    // }

    // ========================================================================
    // PACKAGING CONFIGURATION
    // ========================================================================
    packaging {
        // ✅ OPTIMIZATION: Exclude redundant files
        resources {
            excludes += setOf(
                // ✅ Exclude license files (already included elsewhere)
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/LICENSE.md",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/NOTICE.md",
                
                // ✅ Exclude Kotlin metadata (not needed at runtime)
                "META-INF/kotlinc.xml",
                
                // ✅ Exclude proguard mappings (keep in release but not in APK)
                "proguard-mapping.txt"
                
                // ⚠️ DON'T exclude:
                // - META-INF/services/* (service loaders)
                // - META-INF/MANIFEST.MF (required)
                // - META-INF/*_RELEASE or *_DEBUG (Firebase uses these)
            )
        }
        
        // ✅ OPTIMIZATION: Exclude native debug symbols from debug builds
        nativeLibraries {
            // excludes += setOf("armeabi")  // Only if not targeting ARM
        }
    }

    // ========================================================================
    // DEX CONFIGURATION
    // ========================================================================
    dexOptions {
        // ✅ OPTIMIZATION: Enable incremental dexing
        incremental = true
        
        // ✅ OPTIMIZATION: Parallel dex processing
        preDexLibraries = true
    }

    // ========================================================================
    // BUILD FEATURES (Disable unused, faster builds)
    // ========================================================================
    buildFeatures {
        // ✅ Set to true ONLY if you use these
        viewBinding = false
        dataBinding = false
        buildConfig = true  // Keep for BuildConfig.DEBUG, VERSION_NAME, etc
        
        // Disable unused features
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
    }
}

// ============================================================================
// FLUTTER CONFIGURATION
// ============================================================================
flutter {
    source = "../.."
}

// ============================================================================
// GRADLE BUILD OPTIMIZATION
// ============================================================================
// Add to project's build.gradle.kts for better performance:
//
// org.gradle.parallel=true                    // Parallel task execution
// org.gradle.workers.max=8                    // Max worker threads
// org.gradle.caching=true                     // Cache build outputs
// org.gradle.configureondemand=true           // Only configure needed tasks
// org.gradle.jvmargs=-Xmx4096m               // Increase Gradle heap
// kotlin.incremental=true                    // Incremental Kotlin compilation
// kotlin.incremental.js=true                 // Incremental JS compilation

// ============================================================================
// DEPENDENCIES
// ============================================================================
dependencies {
    // ✅ OPTIMIZATION: Core library desugaring for modern APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    
    // ✅ REQUIRED: MultiDex support for large apps
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ✅ OPTIONAL: Add other common dependencies here
    // implementation("com.google.firebase:firebase-bom:33.1.0")  // Firebase
    // implementation("com.google.firebase:firebase-analytics-ktx")
    // implementation("com.google.firebase:firebase-crashlytics-ktx")
    
    // ✅ OPTIMIZATION: Use BoM (Bill of Materials) for Firebase/Google dependencies
    // This ensures version consistency without specifying versions
}

// ============================================================================
// KOTLIN COMPILER SETTINGS (Module-level)
// ============================================================================
// These can also go in build.gradle.kts at project level for all modules
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        // ✅ OPTIMIZATION: Incremental compilation
        incremental = true
        
        // ✅ OPTIMIZATION: Use all-open compiler plugin if using Spring/Hibernate
        // Add at top: plugins { kotlin("plugin.allopen") }
        
        // ✅ OPTIMIZATION: Suppress warnings from generated code
        suppressWarnings = false
        
        // ✅ OPTIMIZATION: Inline functions aggressively
        freeCompilerArgs = freeCompilerArgs + listOf(
            "-Xjvm-default=all",
            "-opt-in=kotlin.RequiresOptIn",
            "-Xinline-classes"  // Inline value classes
        )
    }
}

// ============================================================================
// BUILD TIME OPTIMIZATION
// ============================================================================
// Tasks to measure build performance:
//
// Analyze build performance:
// $ ./gradlew assembleDebug --profile
// $ ./gradlew assembleRelease --profile
//
// This creates build/reports/profile-TIMESTAMP.html
//
// Tips:
// 1. Use parallel builds: org.gradle.parallel=true
// 2. Enable caching: org.gradle.caching=true
// 3. Update Gradle wrapper to latest version
// 4. Use Gradle configuration cache (Gradle 6.5+)
// 5. Limit included projects if using monorepo
// 6. Use pre-compiled script plugins for shared build logic

