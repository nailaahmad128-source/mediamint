plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mediamint.app"
    compileSdk = 36
    ndkVersion = "26.3.11579264"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by several plugins (incl. FFmpegKit) that ship desugared
        // Java 8+ APIs for use on older Android versions.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mediamint.app"
        // ffmpeg_kit_flutter_new's Android platform support starts at API 24.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Debug builds sign with the default debug key. For a real release,
        // replace this with your own upload keystore referenced from
        // android/key.properties (never commit a real keystore/password).
        getByName("debug") {}
    }

    buildTypes {
        release {
            // TODO before shipping: point this at your own release signing
            // config. Left as debug signing so `flutter build apk --release`
            // succeeds out of the box for local testing.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    packaging {
        // Several ffmpeg-kit native libraries ship the same license/notice
        // files across architectures; avoids a duplicate-file build failure.
        resources.excludes.add("META-INF/LICENSE*")
        resources.excludes.add("META-INF/NOTICE*")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
