plugins {
    id("com.android.application")
    // Flutter Gradle Plugin 必须在 Android / Kotlin 插件之后应用
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.moko.downkyi"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 要求开启 core library desugaring
        // （它在 Java 8+ API 上用了 java.time 等新库，低版本设备需要脱糖补齐）
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.moko.downkyi"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 只打包 arm64-v8a
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // 使用 debug 签名，保证 `flutter build apk --release` 可直接运行
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/*.kotlin_module")
        }
        // ndk.abiFilters 不会清理依赖 AAR 里自带的预编译库（如 datastore 的
        // libdatastore_shared_counter.so 各 ABI 都带），这里再显式排除掉非 arm64 的目录
        jniLibs {
            excludes += setOf(
                "lib/armeabi/**",
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/mips/**",
                "lib/mips64/**",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // FileProvider（打开/分享已下载文件）
    implementation("androidx.core:core-ktx:1.13.1")

    // 配合 isCoreLibraryDesugaringEnabled（flutter_local_notifications 的要求）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
