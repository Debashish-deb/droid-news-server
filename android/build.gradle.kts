// File: android/build.gradle.kts

import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.Delete
import org.gradle.kotlin.dsl.configure
import org.gradle.api.tasks.compile.JavaCompile

// ─── Plugin catalogue (declared here, applied in subprojects) ──────────────────
plugins {
    id("com.google.gms.google-services")      version "4.4.2"  apply false
    id("com.google.firebase.crashlytics")     version "3.0.3"  apply false
    // ❌ MISSING: Crashlytics plugin must be declared at root to keep versions
    //    consistent across modules; omitting it forces each module to re-declare
    //    its own version, which can drift.
}

// ─── Global repositories ───────────────────────────────────────────────────────
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ─── Redirect all build outputs next to the Flutter project root ───────────────
//     Flutter tooling expects build artefacts at <project>/build, not inside
//     android/. The two-level "../.." walk-up achieves that from android/.
val sharedBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(sharedBuildDir)

// ─── Per-module configuration ─────────────────────────────────────────────────
subprojects {

    // Mirror each module's build output under the shared build dir
    layout.buildDirectory.set(sharedBuildDir.dir(name))

    // ✅ Use jvmToolchain — single source of truth for both the Kotlin compiler
    //    and the Java source/target compatibility. Replaces the separate
    //    KotlinCompile + JavaCompile overrides and works with AGP 8.3+
    //    where kotlinOptions is deprecated.
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            jvmToolchain(21)
        }
    }

    // Fallback for any subproject that applies the JVM (non-Android) Kotlin plugin
    plugins.withId("org.jetbrains.kotlin.jvm") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension> {
            jvmToolchain(21)
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        // Third-party Flutter plugins frequently emit deprecation/unchecked notes.
        // Keep build logs actionable by suppressing Java warning output for these tasks.
        options.isWarnings = false

        // Keep plugin defaults, but silence noisy third-party warnings.
        options.compilerArgs.addAll(
            listOf(
                "-Xlint:-deprecation",
                "-Xlint:-unchecked",
                "-Xlint:-options",
            )
        )
    }

    // Give Android library modules without an explicit namespace a safe default.
    // Using plugins.withId is evaluated eagerly-but-correctly and avoids the
    // afterEvaluate ordering pitfalls in multi-module builds.
    plugins.withId("com.android.library") {
        configure<LibraryExtension> {
            if (namespace.isNullOrEmpty()) {
                namespace = "com.example.${name.replace("-", "_")}"
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_21
                targetCompatibility = JavaVersion.VERSION_21
            }
        }
    }
}

// ❌ CRITICAL BUG REMOVED: evaluationDependsOn(":app") was inside subprojects {},
//    meaning every subproject (including :app itself) declared a dependency on
//    :app. This creates a circular evaluation chain that can cause non-
//    deterministic configuration-phase failures and breaks configuration cache.
//    If you genuinely need :app evaluated before a specific sibling module,
//    declare it in that module's own build.gradle.kts, not here.

// ─── Clean ────────────────────────────────────────────────────────────────────
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
