pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localProperties = file("local.properties")
            if (localProperties.exists()) {
                localProperties.inputStream().use { properties.load(it) }
            }
            properties.getProperty("flutter.sdk")
                ?: System.getenv("FLUTTER_ROOT")
                ?: error("flutter.sdk not set in local.properties, 请先执行 `flutter pub get` 或 `flutter build apk`")
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 版本对齐本机 Flutter SDK 的 flutter_tools/lib/src/android/gradle_utils.dart
    // （Flutter 3.47.6：Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0）
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
