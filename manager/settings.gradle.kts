@file:Suppress("UnstableApiUsage")

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
    }
}

rootProject.name = "TomieSU"
include(":ai-api")
val aiEnabled = providers.gradleProperty("ai").orNull?.toBoolean() ?: true
if (aiEnabled && file("ai/build.gradle.kts").isFile) {
    include(":ai")
}
include(":app")
