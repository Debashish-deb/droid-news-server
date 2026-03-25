import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
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
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true  // Key rotation support (Android 9+)
                enableV4Signing = true  // Streaming install support
            }
        }
    }

    defaultConfig {
        applicationId = "com.bd.bdnewsreader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        resourceConfigurations.addAll(
            setOf(
                "en",   
                "bn"    
            )
        )
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    buildTypes {
        release {
            if (!hasKeystoreProps) {
                throw GradleException(
                    "Release build requires android/app/key.properties for signing. " +
                    "Create it (or use CI secrets) before building release."
                )
            }

            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            isDebuggable = false
        }

        getByName("profile") {
            initWith(getByName("release"))
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
        }

        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

 
    packaging {
        resources {
            excludes += setOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/LICENSE.md",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/NOTICE.md",
                "META-INF/kotlinc.xml",
                "proguard-mapping.txt"
            )
        }
    }

    // ✅ OPTIMIZATION: Disable unused build features
    buildFeatures {
        viewBinding = false
        dataBinding = false
        aidl = false
        renderScript = false
        resValues = false
        shaders = false
        buildConfig = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
}
