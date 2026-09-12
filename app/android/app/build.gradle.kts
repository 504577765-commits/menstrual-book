plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yuejingben.yuejingben"
    // compileSdk 36：AGP 9.1.0 的稳定支持目标（官方 platforms/android-36）。
    // 说明：SDK 中心对 API 37 仅发放新式 platforms;android-37.0 包（ApiLevel 带 .0），
    // 而本 AGP 版本的编译目标按老式 hash 识别（android-37 仓库中不存在），
    // compileSdk=37 无法解析目标平台，故使用 36。
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 等插件要求 core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 应用唯一标识（安装到设备上的包名）。
        applicationId = "com.yuejingben.app"
        // minSdk 26 (Android 8.0)：覆盖约 97% 设备，通知渠道与生物识别 API 均可直接使用。
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// core library desugaring 支持库（配合上方 isCoreLibraryDesugaringEnabled）
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
