import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing credentials, kept OUT of version control.
//
// Create android/key.properties from android/key.properties.example and point
// it at a keystore you generated yourself - see docs/RELEASE_SIGNING.md. When
// the file is absent the release build falls back to the debug key, so a
// checkout with no keystore still builds and installs; it just cannot be
// published to the Play Store.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.example.flutter_id_card"
    // Pinned above Flutter's default (36) because one of the AndroidX libraries
    // pulled in by the Firebase / ML Kit plugin set is compiled against 37 and
    // Gradle refuses to link an app built against an older platform.
    // Raising compileSdk only widens the APIs available at compile time; it does
    // not change runtime behaviour - that is targetSdk, left at Flutter's default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // NOTE: Before publishing, change this to the organisation's real ID and
        // register that exact package in the Firebase console so google-services.json matches.
        applicationId = "com.example.flutter_id_card"
        // minSdk 24 is the floor imposed by our dependency set:
        //   - firebase_auth / cloud_firestore require 23+
        //   - google_mlkit_selfie_segmentation requires 21+
        //   - camera + image_cropper require 21+
        // 24 gives headroom and covers >97% of active Android devices.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no keystore is configured, so a
            // fresh checkout still produces an installable APK for the client.
            // A debug-signed APK cannot go to the Play Store, and cannot be
            // upgraded over by a properly signed one - the signatures differ.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
