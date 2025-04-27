// File: android/build.gradle.kts (root project)

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

// Configure repositories for buildscript dependencies (if any)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Example: Android Gradle plugin and Google Services
        classpath("com.android.tools.build:gradle:7.4.1")
        classpath("com.google.gms:google-services:4.3.15")
    }
}

// Root-level repositories for all modules
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect the build output to a sibling "build" folder
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // Redirect each subproject's build output
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // Ensure :app project is evaluated first (optional)
    evaluationDependsOn(":app")
}

// Clean task to delete the relocated build directory
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
