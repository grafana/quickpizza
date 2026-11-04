buildscript {
    // Lock the plugin/buildscript classpath for this module too.
    configurations.classpath {
        resolutionStrategy.activateDependencyLocking()
    }
}

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
    alias(libs.plugins.bytebuddy)
    // Auto-uploads R8 mapping.txt + native-debug-symbols.zip after assembleRelease/bundleRelease/installRelease.
    // NOTE: this module locks the buildscript classpath; after adding this plugin run
    // `./gradlew --write-locks` (or `dependencies --write-locks`) to refresh the lockfiles.
    id("com.grafana.faro.android-symbols") version "0.1.1"
}

// Remove config.json.example from res/raw before the resource merger runs.
// Android resource file names must only contain [a-z0-9_], so dots are invalid.
// The example template lives at the project root instead (config.json.example).
tasks.register<Delete>("deleteExampleConfig") {
    delete(layout.projectDirectory.file("src/main/res/raw/config.json.example"))
}
tasks.matching { it.name.contains("mergeDebugResources") || it.name.contains("mergeReleaseResources") || it.name.contains("packageDebugResources") || it.name.contains("packageReleaseResources") }
    .configureEach { dependsOn("deleteExampleConfig") }

// Select an alternate build input without touching the developer's resource file.
val alternateConfig = providers.environmentVariable("QUICKPIZZA_ANDROID_CONFIG_FILE").orElse(
    providers.provider {
        rootProject.file("../telemetry/.runtime/active/android.json")
            .takeIf { it.isFile }?.absolutePath
    }
)
val prepareConfiguredResources = tasks.register<Sync>("prepareConfiguredResources") {
    onlyIf { alternateConfig.isPresent }
    from("src/main/res") { exclude("raw/config.json", "raw/config.json.example") }
    if (alternateConfig.isPresent) {
        from(alternateConfig) { into("raw"); rename { "config.json" } }
    }
    into(layout.buildDirectory.dir("configuredResources"))
}
if (alternateConfig.isPresent) {
    tasks.named("preBuild") { dependsOn(prepareConfiguredResources) }
}

val quickPizzaDemoVersionName = providers.gradleProperty("quickpizzaDemoVersionName").orElse("1.0.0")

android {
    if (alternateConfig.isPresent) {
        sourceSets.getByName("main").res.setSrcDirs(listOf(layout.buildDirectory.dir("configuredResources")))
    }
    namespace = "com.grafana.quickpizza"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.grafana.quickpizza.android"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = quickPizzaDemoVersionName.get()

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // Demo / local release installs (installRelease requires a signing config).
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            ndk {
                debugSymbolLevel = "FULL"
            }
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

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

// Grafana Faro symbol upload. Secrets come from the environment / CI — never hardcode the key.
faro {
    endpoint.set(System.getenv("FARO_SOURCEMAP_ENDPOINT"))
    appId.set(System.getenv("FARO_SOURCEMAP_APP_ID"))
    stackId.set(System.getenv("FARO_SOURCEMAP_STACK_ID"))
    apiKey.set(System.getenv("FARO_SOURCEMAP_API_KEY"))
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

    // Persistence
    implementation(libs.datastore.preferences)

    // OpenTelemetry Android
    implementation(platform(libs.opentelemetry.android.bom))
    implementation(project(":grafana-opentelemetry-android"))
    implementation(libs.opentelemetry.sdk)
    implementation(libs.opentelemetry.extension.kotlin)
    implementation(libs.opentelemetry.android.compose.navigation)
    implementation(libs.opentelemetry.android.okhttp3.library)
    implementation(libs.opentelemetry.okhttp3)
    byteBuddy(libs.opentelemetry.android.okhttp3.agent)

    // TODO(opentelemetry-android#764): remove with com.grafana.quickpizza.nativecrash package.
    // Protobuf tombstone decode for ApplicationExitInfo.traceInputStream (API 31+).
    implementation("com.google.protobuf:protobuf-javalite:3.25.9")

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.proguard.retrace)
    androidTestImplementation(libs.test.runner)
    androidTestImplementation(libs.test.espresso.core)
    androidTestImplementation(libs.test.junit.ext)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    debugImplementation(libs.compose.ui.test.manifest)
}
