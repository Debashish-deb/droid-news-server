// path: android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // ✅ Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // ✅ Flutter
}

android {
    namespace = "com.example.droid"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.droid"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true // ✅ Prevent dex overflow
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ Important for Java 8+ and notifications
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("/Users/debashishdeb/my-release-key.jks") // ✅ Your key path
            storePassword = "your-keystore-password"  // ❗ Replace securely
            keyAlias = "my-key-alias"                  // ❗ Replace securely
            keyPassword = "your-key-password"          // ❗ Replace securely
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") 
    implementation("androidx.multidex:multidex:2.0.1") // ✅ Safe
}

flutter {
    source = "../.."
}
