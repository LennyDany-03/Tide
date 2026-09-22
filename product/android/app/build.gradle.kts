plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tide"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules task reminders with java.time,
        // which Android only ships from API 26; desugaring brings it to older
        // devices.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tide"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The release key comes from the environment: the release workflow decodes
    // it from repository secrets (see TRIGGER.md). It has to be the same key
    // for every release, because Android refuses to install an update signed
    // by a different one, and a sideloaded app has no store to smooth that
    // over. Without the variables (a local `flutter run --release`) the build
    // falls back to the debug key, which is fine for a device on the desk and
    // never for a published APK.
    val releaseKeystore = System.getenv("TIDE_KEYSTORE_PATH")
    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = System.getenv("TIDE_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TIDE_KEY_ALIAS")
                keyPassword = System.getenv("TIDE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (releaseKeystore != null) "release" else "debug",
            )

            // Shrinking is off, so these are inert today. Wired up now so
            // that turning it on for a Play release is a one-line change.
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider, for handing a downloaded update to the installer.
    implementation("androidx.core:core-ktx:1.13.1")
}
