plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
