import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey = localProperties.getProperty("MAPS_API_KEY") ?: ""
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}
val requiredSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = requiredSigningKeys.filter { keyProperties.getProperty(it).isNullOrBlank() }
val releaseTasksRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseTasksRequested && (missingSigningKeys.isNotEmpty() || !keyPropertiesFile.exists())) {
    throw GradleException(
        "Android release signing requires android/key.properties with ${requiredSigningKeys.joinToString(", ")}. " +
            "See README.md for setup. Missing: ${missingSigningKeys.joinToString(", ")}"
    )
}
val releaseStoreFile = keyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
if (releaseTasksRequested && releaseStoreFile?.isFile != true) {
    throw GradleException("Android release keystore not found at ${releaseStoreFile ?: "<unset>"}; check storeFile in android/key.properties.")
}

android {
    namespace = "com.depar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.depar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            if (missingSigningKeys.isEmpty()) {
                storeFile = releaseStoreFile
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
