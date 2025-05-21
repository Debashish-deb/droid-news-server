plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter plugin must come after Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version("4.4.2") apply false
}

android {
    namespace = "com.bd.bdnewsreader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.bd.bdnewsreader"
        minSdk = 23                      // ↑ raised to 23 for firebase_auth
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // ↑ enable desugaring
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isDebuggable = true
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/*")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Back-port Java 8+ APIs for any AARs (e.g. firebase_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
