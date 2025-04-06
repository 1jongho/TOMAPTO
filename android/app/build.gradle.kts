plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val naverApiKey: String = run {
    val envFile = project.file("../../.env")
    if (envFile.exists()) {
        envFile.readLines().forEach { line ->
            val parts = line.split("=", limit = 2)
            if (parts.size == 2 && parts[0].trim() == "NAVER_API_KEY") {
                return@run parts[1].trim()
            }
        }
    }
    // 기본값으로 빈 문자열을 반환하고 개발자에게 경고
    logger.warn("WARNING: NAVER_API_KEY not found in .env file!")
    logger.warn("Please create a .env file in the project root with NAVER_API_KEY=your_api_key")
    ""  // 빈 문자열 반환
}

android {
    namespace = "com.example.tomapto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tomapto"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 네이버 맵 API 키가 비어있으면 빌드시 경고 출력
        if (naverApiKey.isEmpty()) {
            logger.warn("Building with empty NAVER_API_KEY - map functionality may not work")
        }
        // 매니페스트 플레이스홀더 설정
        manifestPlaceholders["NAVER_API_KEY"] = naverApiKey
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
