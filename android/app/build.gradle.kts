import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application") version "8.11.1"
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Configuración según documentación oficial de Flutter actualizada
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.shamirdhc.alerta_desaparecidos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // Configuración de lint - DESHABILITAR TEMPORALMENTE
    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable.addAll(listOf("InvalidPackage", "MissingTranslation", "ExtraTranslation"))
        quiet = true
        ignoreWarnings = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_23
        targetCompatibility = JavaVersion.VERSION_23
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "23"
    }

    // Configuración de firma según documentación oficial Flutter 2024
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.shamirdhc.alerta_desaparecidos"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Optimizaciones adicionales
        vectorDrawables.useSupportLibrary = true
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // Configuraciones de optimización
            isMinifyEnabled = true
            isShrinkResources = false
            isDebuggable = false
            
            // Usar ProGuard optimizado
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Configuraciones adicionales de optimización - REMOVIDAS LAS DEPRECADAS
            isJniDebuggable = false
            isPseudoLocalesEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(23)
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    
    val appcompatVersion = "1.7.0"
    implementation("androidx.appcompat:appcompat:$appcompatVersion")
    implementation("androidx.appcompat:appcompat-resources:$appcompatVersion")
    
    implementation("com.google.firebase:firebase-appcheck-debug")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}