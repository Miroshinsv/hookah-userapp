import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("app/key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}
val yandexMapsApiKey: String = run {
    val fromFile = localProperties.getProperty("yandex.maps.api.key", "")
    if (fromFile.isNotBlank() && fromFile != "YOUR_KEY_HERE") fromFile
    else System.getenv("YANDEX_MAPS_API_KEY") ?: ""
}

android {
    namespace = "ru.hookahorder.user_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProperties["keyAlias"]     as String? ?: ""
            keyPassword  = keyProperties["keyPassword"]  as String? ?: ""
            storeFile    = file(keyProperties["storeFile"] as String? ?: "release.keystore")
            storePassword = keyProperties["storePassword"] as String? ?: ""
        }
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "ru.hookahorder.user_app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "YANDEX_MAPS_API_KEY", "\"$yandexMapsApiKey\"")
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.yandex.android:maps.mobile:4.22.0-lite")
}
