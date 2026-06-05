pluginManagement {
    repositories {
        // Resolve a locally published `com.grafana.faro` build first (gradle publishToMavenLocal).
        // Once the plugin is on the Gradle Plugin Portal, gradlePluginPortal() below is enough.
        mavenLocal()
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
buildscript {
    // Lock the settings classpath (anything resolved by settings.gradle.kts).
    configurations.classpath {
        resolutionStrategy.activateDependencyLocking()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "QuickPizza"
include(":app")
