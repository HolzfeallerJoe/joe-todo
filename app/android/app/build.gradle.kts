plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.joe.joe_todo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications braucht java.time auch auf aelteren
        // Android-Versionen; ohne das bricht schon der Build ab.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.joe.joe_todo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Wo der Debug-Keystore liegt, sucht AGP sich sonst selbst zusammen:
    // ANDROID_USER_HOME, ANDROID_PREFS_ROOT, ANDROID_SDK_HOME und erst zuletzt
    // user.home. Auf dem CI-Runner greift eine der vorderen Variablen, der
    // eingespielte Keystore unter $HOME/.android blieb dadurch unbenutzt und
    // AGP legte sich still einen neuen an -- jede APK also mit eigener
    // Signatur, kein Update ohne Deinstallation. JOE_DEBUG_KEYSTORE macht die
    // Wahl eindeutig; ohne die Variable bleibt es beim bisherigen Verhalten.
    signingConfigs {
        getByName("debug") {
            val fromEnv = System.getenv("JOE_DEBUG_KEYSTORE")
            if (!fromEnv.isNullOrBlank()) {
                val ks = File(fromEnv)
                require(ks.isFile) { "JOE_DEBUG_KEYSTORE zeigt auf keine Datei: $fromEnv" }
                storeFile = ks
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
