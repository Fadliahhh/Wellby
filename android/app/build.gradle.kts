plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.wellby_baru" // Pastikan ini sesuai package name Anda
    compileSdk = flutter.compileSdkVersion // Biarkan Flutter yang atur
    
    // NDK Version dari log error sebelumnya
    ndkVersion = "27.0.12077973" 

    compileOptions {
        // Aktifkan Desugaring di sini (ini tempat standar baru)
        isCoreLibraryDesugaringEnabled = true 
        // Biarkan source/target compatibility default (biasanya 1.8)
         sourceCompatibility = JavaVersion.VERSION_1_8 
         targetCompatibility = JavaVersion.VERSION_1_8 
    }

    kotlinOptions {
        jvmTarget = "1.8" // Sesuaikan dengan sourceCompatibility
    }

    defaultConfig {
        applicationId = "com.example.wellby_baru" // Pastikan ini sesuai package name Anda
        minSdk = 23 // WAJIB
        targetSdk = flutter.targetSdkVersion // Biarkan Flutter yang atur
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true // WAJIB
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Tetap pakai debug untuk skripsi
            // Proguard/R8 diatur otomatis oleh Flutter di mode release
        }
    }
}

flutter {
    source = "../.."
}

// --- TAMBAHKAN BLOK DEPENDENSI INI SECARA MANUAL ---
dependencies {
    // Tambahkan library Desugaring yang WAJIB
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") 
    // Dependensi lain (Firebase BOM, Kotlin stdlib) akan diurus otomatis
}
// --- BATAS BLOK TAMBAHAN ---