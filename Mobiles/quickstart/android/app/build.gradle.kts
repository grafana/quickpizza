plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.example.otelandroidsample"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.example.otelandroidsample"
        minSdk = 24   // 24 for androidx.navigation; the agent itself supports 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        // REQUIRED when minSdk is below 31. The agent calls java.time methods that Android only has
        // natively from Android 12 (API 31). Without desugaring, the app crashes on Android 11 and
        // older when it goes to the background (opentelemetry-android#2183).
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // OpenTelemetry Android. The BOM pins every OpenTelemetry artifact below to matching versions.
    implementation(platform("io.opentelemetry.android:opentelemetry-android-bom:1.8.0-alpha"))
    implementation("io.opentelemetry.android:android-agent")
    // HTTP spans for OkHttp. Version comes from the BOM above.
    implementation("io.opentelemetry.instrumentation:opentelemetry-okhttp-3.0")
    implementation("com.squareup.okhttp3:okhttp:5.5.1")
    // Screen views for Jetpack Compose navigation. Version comes from the BOM above.
    implementation("io.opentelemetry.android.instrumentation:compose-navigation")

    // UI for the sample screen only.
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.navigation:navigation-compose:2.10.2")
}
