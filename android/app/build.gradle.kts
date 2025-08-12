plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.noam.jwlife"

    // Laisse Flutter piloter les versions, mais force des valeurs sûres si besoin.
    compileSdk = maxOf(flutter.compileSdkVersion, 34) // 34 pour Android 14 (exact alarms)
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Recommandé avec AGP 8+ et Kotlin récents
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.noam.jwlife"
        minSdk = maxOf(flutter.minSdkVersion, 21) // requis par la plupart des libs notif
        targetSdk = maxOf(flutter.targetSdkVersion, 34) // Android 14 (SCHEDULE/USE_EXACT_ALARM)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Nécessaire si tu utilises des vecteurs comme icônes de notif
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        debug {
            // Confort dev
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // Active l'optimisation tout en gardant les ressources notif
            isMinifyEnabled = true
            isShrinkResources = true

            // Utilise tes propres clés si dispo (sinon debug pour tester rapidement)
            signingConfig = signingConfigs.getByName("debug")

            // ProGuard/R8
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Évite que le shrinker supprime des ressources utiles (sons/icônes de notif)
    packaging {
        resources {
            // Exemples d'exclusions courantes (facultatif)
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/*.kotlin_module"
            )
        }
    }

    // Si tu utilises des productFlavors, garde ce block simple
    // flavorDimensions += listOf("env")

    // (Optionnel) pour corriger les warnings lint bloquants en CI
    lint {
        abortOnError = false
    }
}

dependencies {
    // Core library desugaring dependency - required when isCoreLibraryDesugaringEnabled = true
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}