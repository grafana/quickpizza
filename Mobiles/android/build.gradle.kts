buildscript {
    // Lock the plugin/buildscript classpath so plugin versions are pinned too.
    configurations.classpath {
        resolutionStrategy.activateDependencyLocking()
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.bytebuddy) apply false
}

// Enable dependency locking for every project configuration (root + :app).
allprojects {
    dependencyLocking {
        lockAllConfigurations()
    }
}
