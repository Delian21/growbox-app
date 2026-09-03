import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key: read from android/local.properties (git-ignored) or the
// MAPS_API_KEY environment variable (CI). Never commit a real key.
fun loadLocalProperties(): Properties {
    val props = Properties()
    val candidates = listOf(
        file("local.properties"),
        rootProject.file("local.properties"),
    )
    for (candidate in candidates) {
        if (candidate.exists()) {
            candidate.inputStream().use { props.load(it) }
        }
    }
    return props
}

val mapsApiKey: String = (
    loadLocalProperties().getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: "YOUR_API_KEY"
    ).trim()

android {
    namespace = "com.example.growbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Injected into AndroidManifest.xml's com.google.android.geo.API_KEY
        // meta-data (value="${MAPS_API_KEY}").
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey

        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.growbox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
