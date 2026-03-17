plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.bytebuddy)
}

// Remove config.json.example from res/raw before the resource merger runs.
// Android resource file names must only contain [a-z0-9_], so dots are invalid.
// The example template lives at the project root instead (config.json.example).
tasks.register<Delete>("deleteExampleConfig") {
    delete(layout.projectDirectory.file("src/main/res/raw/config.json.example"))
}
tasks.matching { it.name.contains("mergeDebugResources") || it.name.contains("mergeReleaseResources") || it.name.contains("packageDebugResources") || it.name.contains("packageReleaseResources") }
    .configureEach { dependsOn("deleteExampleConfig") }

android {
    namespace = "com.grafana.quickpizza"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.grafana.quickpizza"
        minSdk = 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
    compileOptions {
        // Required for opentelemetry-android when minSdk < 26
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    coreLibraryDesugaring(libs.desugar.jdk.libs)

    // AndroidX
    implementation(libs.core.ktx)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.ktx)
    implementation(libs.navigation.compose)

    // Compose
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons)
    debugImplementation(libs.compose.ui.tooling)

    // Hilt DI
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    // Networking
    implementation(libs.okhttp)
    implementation(libs.gson)

    // OpenTelemetry Android
    implementation(platform(libs.opentelemetry.android.bom))
    implementation(libs.opentelemetry.android.agent)
    implementation(libs.opentelemetry.sdk)
    implementation(libs.opentelemetry.extension.kotlin)
    implementation(libs.opentelemetry.android.okhttp3.library)
    byteBuddy(libs.opentelemetry.android.okhttp3.agent)

    // Testing
    androidTestImplementation(libs.test.runner)
    androidTestImplementation(libs.test.espresso.core)
    androidTestImplementation(libs.test.junit.ext)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    debugImplementation(libs.compose.ui.test.manifest)
}
