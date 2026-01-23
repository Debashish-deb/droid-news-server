// File: android/build.gradle.kts

import com.android.build.gradle.LibraryExtension
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.api.JavaVersion

// ✅ Declare plugin versions here (do not apply at root)
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

// ─── Global repositories ───────────────────────────────────────────────────────
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject
    .layout
    .buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.set(newBuildDir)

// ─── Per‐module build dirs, JVM overrides, and namespace fallback ───────────────
subprojects {
    // 1) Move each module's build into <newBuildDir>/<moduleName>
    project.layout.buildDirectory.set(newBuildDir.dir(project.name))

    // 2) Force Kotlin to compile with JVM target 11 - use configureEach for better compatibility
    tasks.configureEach {
        if (this is KotlinCompile) {
            kotlinOptions.jvmTarget = "11"
        }
    }

    // 3) Force Java to compile with target/sourceCompatibility = Java 11
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
    }

    // 4) After evaluation, give any Android library a fallback namespace
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<LibraryExtension>("android") {
                // only set if not already declared
                if (namespace.isNullOrEmpty()) {
                    namespace = "com.example.${project.name.replace("-", "_")}"
                }
                // also enforce Java 11 at the Android‐extension level
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
    }

    // ensure your app module is configured first
    evaluationDependsOn(":app")
}

// ─── Standard clean task ───────────────────────────────────────────────────────
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
