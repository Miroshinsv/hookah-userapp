import java.util.Properties
import java.util.Base64
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("app/key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

// Локальные секреты для разработки (не коммитится).
val localEnv = Properties()
val localEnvFile = rootProject.file("local.env.properties")
if (localEnvFile.exists()) {
    localEnv.load(FileInputStream(localEnvFile))
}

// Flutter передаёт --dart-define значения через Gradle project property 'dart-defines'.
fun dartDefines(): Map<String, String> {
    val raw = (project.findProperty("dart-defines") as? String)
        ?: localProperties.getProperty("dart.defines")
        ?: return emptyMap()
    return raw.split(",").associate { entry ->
        val decoded = String(Base64.getDecoder().decode(entry))
        val idx = decoded.indexOf('=')
        if (idx >= 0) decoded.substring(0, idx) to decoded.substring(idx + 1)
        else decoded to ""
    }
}

val dartDefines = dartDefines()

// Возвращает значение: сначала из --dart-define, потом из local.env.properties.
fun envKey(name: String): String =
    dartDefines[name]?.takeIf { it.isNotBlank() }
        ?: localEnv.getProperty(name, "")

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

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "ru.hookahorder.user_app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["yandexApiKey"] = envKey("YANDEX_MAPS_API_KEY")
        buildConfigField(
            "String",
            "YANDEX_MAPS_API_KEY",
            "\"${envKey("YANDEX_MAPS_API_KEY")}\""
        )
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProperties["keyAlias"]     as String? ?: ""
            keyPassword  = keyProperties["keyPassword"]  as String? ?: ""
            storeFile    = file(keyProperties["storeFile"] as String? ?: "release.keystore")
            storePassword = keyProperties["storePassword"] as String? ?: ""
        }
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
    implementation("com.yandex.android:maps.mobile:4.19.0-lite")
}
