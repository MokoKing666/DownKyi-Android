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
            // ---------------- 精简包（评审第 27 项） ----------------
            //
            // APK 体积几乎全被 FFmpeg 吃掉（arm64-v8a 下约 42 MB / 总体 64 MB）。
            // 但相当一部分用户只想要「下载 + 直接播放」，转码、GIF、H.265 都用不上。
            //
            // 做成**显式开关**而不是 productFlavors，是有意为之：
            // 一旦声明了 flavor，`flutter build apk` 就必须带 --flavor，
            // 本仓库现有的 CI、tools/build_apk.ps1、tools/publish_release.ps1
            // 以及所有用户的构建命令都会立刻失效。这个代价不该由一个 P3 优化来付。
            //
            // 用法：tools/build_lite.ps1（或手工加 -Pdownkyi.lite=true）
            // 不传该属性时，下面这个分支不会执行，构建行为与以前完全一致。
            if ((project.findProperty("downkyi.lite") as String?)?.toBoolean() == true) {
                excludes += setOf(
                    "lib/arm64-v8a/libavcodec.so",
                    "lib/arm64-v8a/libavdevice.so",
                    "lib/arm64-v8a/libavfilter.so",
                    "lib/arm64-v8a/libavformat.so",
                    "lib/arm64-v8a/libavutil.so",
                    "lib/arm64-v8a/libpostproc.so",
                    "lib/arm64-v8a/libswresample.so",
                    "lib/arm64-v8a/libswscale.so",
                    "lib/arm64-v8a/libffmpegkit.so",
                    "lib/arm64-v8a/libffmpegkit_abidetect.so",
                )
            }
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
