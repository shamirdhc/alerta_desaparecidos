plugins {
    // Reload plugins to ensure changes take effect
    id("com.android.application") version "8.11.1" // Aquí especificas la nueva versión
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shamirdhc.alerta_desaparecidos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_23
        targetCompatibility = JavaVersion.VERSION_23
        // Habilitar core library desugaring manteniendo Java 23
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "23"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shamirdhc.alerta_desaparecidos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
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

flutter {
    source = "../.."
}

// Configuration del Java Toolchain
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(23)) // Manteniendo Java 23
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))  // BOM al inicio
    val appcompat_version = "1.7.0"
    implementation("androidx.appcompat:appcompat:$appcompat_version")
    implementation("androidx.appcompat:appcompat-resources:$appcompat_version")
    implementation("com.google.firebase:firebase-appcheck-debug")  // Sin versión, BOM lo maneja (nota: este es para debug, no siempre gestionado por BOM, pero déjalo así)
    implementation("com.google.firebase:firebase-storage-ktx")  // Sin versión
    implementation("com.google.firebase:firebase-appcheck-playintegrity")  // Sin versión
    
    // Core library desugaring - Actualizado a versión 2.1.4 como requiere flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}