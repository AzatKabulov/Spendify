import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material lives in android/key.properties (gitignored). When it
// is absent — a fresh clone, CI without secrets — the release build falls back
// to debug signing so `flutter build` still works, just not shippably signed.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.azatkabulov.spendly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.azatkabulov.spendly"
        // minSdk pinned explicitly (Phase 0 decision).
        // The build plan asks for "21+". The effective floor is 24 (Android 7.0):
        //   - flutter_secure_storage, the mandated encrypted-key store (CLAUDE.md §2),
        //     requires minSdk 23+;
        //   - Flutter 3.44's own Gradle migration rewrites any `minSdk` of 16..23 back
        //     to `flutter.minSdkVersion` (24) on every build, so 21 will not hold.
        // Android < 24 is a negligible device share; 24 is the honest, stable choice.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so an unsigned-secrets build still completes.
                signingConfigs.getByName("debug")
            }
            // R8: shrink + obfuscate. Flutter ships default keep rules; the extra
            // rules in proguard-rules.pro cover this app's reflective corners
            // (Hive adapters are codegen'd, but Firebase / Gemini model classes
            // and the Play Core split-install stubs need explicit keeps).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
