import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // Kein `kotlin-android` mehr: seit AGP 9 wendet das Flutter-Plugin das
    // Kotlin-Plugin selbst an. Angewandt man es hier zusaetzlich, streiten
    // sich beide um die Erweiterung – so haelt es auch die Projektvorlage
    // von Flutter 3.47.
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

// Seit AGP 9 / Kotlin 2.3 ist `kotlinOptions { jvmTarget = ... }` innerhalb
// von `android { }` abgekuendigt; die Einstellung gehoert dem
// Kotlin-Plugin. Gleicher Wert wie compileOptions oben – Java und Kotlin
// muessen auf dieselbe Bytecode-Fassung uebersetzen, sonst beschwert sich
// der Compiler zu Recht.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
