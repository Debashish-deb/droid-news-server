import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase / Google Services
    id("com.google.gms.google-services")
}

// ─────────────────────────────────────────────────────────────
// Keystore (perfect setup):
// ✅ Debug builds work even if key.properties is missing
// ✅ Release builds REQUIRE key.properties (fail fast)
// ─────────────────────────────────────────────────────────────
val keystorePropertiesFile = file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProps = keystorePropertiesFile.exists()

if (hasKeystoreProps) {
    keystorePropertiesFile.inputStream().buffered().use { keystoreProperties.load(it) }
}

fun requireKeystoreProp(name: String): String {
    return keystoreProperties.getProperty(name)
        ?: throw GradleException("Missing `$name` in android/app/key.properties (required for release signing).")
}

android {
    namespace = "com.bd.bdnewsreader"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    signingConfigs {
        
        if (hasKeystoreProps) {
            create("release") {
                keyAlias = requireKeystoreProp("keyAlias")
                keyPassword = requireKeystoreProp("keyPassword")
                storeFile = file(requireKeystoreProp("storeFile"))
                storePassword = requireKeystoreProp("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.bd.bdnewsreader"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 30
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            // ✅ Fail fast ONLY when building release and key.properties missing
            if (!hasKeystoreProps) {
                throw GradleException(
                    "Release build requires android/app/key.properties for signing. " +
                    "Create it (or use CI secrets) before building release."
                )
            }

            // Only safe because we throw above if missing
            signingConfig = signingConfigs.getByName("release")

            // 🔐 SECURITY: Enable code obfuscation & optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // uses default debug signing
        }
    }

    // Keep excludes narrow (don’t exclude signature-related META-INF files)
    packaging {
        resources {
            excludes += setOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
}
