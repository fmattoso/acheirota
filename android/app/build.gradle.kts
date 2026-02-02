plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Carregar propriedades do local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

// Obter a chave do Google Maps
val mapsApiKey = localProperties.getProperty("mapsApiKey") 

android {
    namespace = "com.brdata.acheirota"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.brdata.acheirota"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Passar a chave para o AndroidManifest
        manifestPlaceholders["mapsApiKey"] = mapsApiKey

        // Também disponível como build config
        buildConfigField("String", "\"$mapsApiKey\"")
   }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Para release, você pode querer uma chave diferente
            // manifestPlaceholders["mapsApiKey"] = "SUA_CHAVE_RELEASE"
        }
        debug {
            manifestPlaceholders["mapsApiKey"] = mapsApiKey
        }
    }
}

flutter {
    source = "../.."
}
