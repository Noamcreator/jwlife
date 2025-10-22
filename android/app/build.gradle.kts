plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.noam.jwlife"

    // Versions SDK minimales
    compileSdk = maxOf(flutter.compileSdkVersion, 34)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.noam.jwlife"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = maxOf(flutter.targetSdkVersion, 34)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 🔑 Bloc de configuration de signature conservé
    signingConfigs {
        create("sharedKey") {
            storeFile = file("../keystore/jwlife-keystore.jks")
            storePassword = "MonMotDePasse123!"
            keyAlias = "jwlife_alias"
            keyPassword = "MonMotDePasse123!"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("sharedKey")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("sharedKey")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Desugaring pour les fonctionnalités de la librairie Java 8+ sur les anciennes versions d'Android pour flutter notification
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}