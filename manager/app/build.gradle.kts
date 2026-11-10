@file:Suppress("UnstableApiUsage")

import com.google.protobuf.gradle.id
import com.android.build.api.variant.HostTestBuilder
import java.io.File
import java.net.URI

plugins {
    alias(libs.plugins.agp.app)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.lsplugin.apksign)
    alias(libs.plugins.protobuf)
    id("kotlin-parcelize")
}

val androidCompileSdkVersion = rootProject.extra["androidCompileSdkVersion"] as Int
val androidCompileSdkVersionMinor = rootProject.extra["androidCompileSdkVersionMinor"] as Int
val androidCompileNdkVersion = rootProject.extra["androidCompileNdkVersion"] as String
val androidBuildToolsVersion = rootProject.extra["androidBuildToolsVersion"] as String
val androidMinSdkVersion = rootProject.extra["androidMinSdkVersion"] as Int
val androidTargetSdkVersion = rootProject.extra["androidTargetSdkVersion"] as Int
val androidSourceCompatibility = rootProject.extra["androidSourceCompatibility"] as JavaVersion
val androidTargetCompatibility = rootProject.extra["androidTargetCompatibility"] as JavaVersion
val managerVersionCode = rootProject.extra["managerVersionCode"] as Int
val managerVersionName = rootProject.extra["managerVersionName"] as String
val bundledKernelVersionCode = rootProject.extra["bundledKernelVersionCode"] as Int

val isPrBuild = project.findProperty("IS_PR_BUILD")?.toString()?.toBoolean() ?: false
val defaultManagerPackageName = if (isPrBuild) "io.tomiesu.manager.pr" else "io.tomiesu.manager"
val defaultManagerName = if (isPrBuild) "TomieSU PR" else "TomieSU"
val managerPackageName = project.findProperty("KSU_PACKAGE_NAME")?.toString() ?: defaultManagerPackageName
require(!Regex("^(me\\.weishu\\.kernelsu|com\\.rifsxd\\.ksunext)(\\..*)?$").matches(managerPackageName)) {
    "TomieSU must use its own application ID; upstream Manager identities are reserved."
}
val managerName = project.findProperty("KSU_NAME")?.toString() ?: defaultManagerName
val tomieSuUpdateUrl = providers.gradleProperty("TOMIESU_UPDATE_URL")
    .orElse(providers.environmentVariable("TOMIESU_UPDATE_URL"))
    .orElse("https://api.github.com/repos/Xiaogugtfgdfhgrh/MikSU/releases/latest").get().trim()
val coreUpdateEnabled = !isPrBuild && tomieSuUpdateUrl.isNotEmpty()
require(!coreUpdateEnabled || runCatching {
    val uri = URI(tomieSuUpdateUrl)
    uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null
}.getOrDefault(false)) { "TOMIESU_UPDATE_URL must be an HTTPS URL" }

apksign {
    storeFileProperty = "KEYSTORE_FILE"
    storePasswordProperty = "KEYSTORE_PASSWORD"
    keyAliasProperty = "KEY_ALIAS"
    keyPasswordProperty = "KEY_PASSWORD"
}

fun managerAbis(): List<String> {
    val known = listOf("arm64-v8a", "x86_64")
    val jniLibs = layout.projectDirectory.dir("src/main/jniLibs").asFile
    val staged = known.filter { File(jniLibs, "$it/libtsud.so").isFile }
    val configured = providers.gradleProperty("TOMIESU_ABIS")
        .orElse(providers.environmentVariable("TOMIESU_ABIS"))
        .orNull
    val allowMissingDaemon = providers.gradleProperty("TOMIESU_ALLOW_MISSING_DAEMON")
        .orElse(providers.environmentVariable("TOMIESU_ALLOW_MISSING_DAEMON"))
        .orNull?.let { it == "1" || it.equals("true", ignoreCase = true) } ?: false
    val requested = configured?.split(Regex("[,\\s]+"))?.filter(String::isNotBlank)?.distinct()
        ?: staged.ifEmpty { if (allowMissingDaemon) emptyList() else known }
    require(requested.all { it in known }) {
        "TOMIESU_ABIS must contain supported daemon ABIs: ${known.joinToString()}"
    }
    if (!allowMissingDaemon) {
        require(requested.isNotEmpty()) {
            "TOMIESU_ABIS must not be empty"
        }
        require(requested.all { it in staged }) {
            "Build and stage libtsud.so for each requested ABI before Manager: ${requested.filterNot { it in staged }}"
        }
    } else if (requested.any { it !in staged }) {
        logger.lifecycle(
            "TOMIESU_ALLOW_MISSING_DAEMON=1: building Manager without staged libtsud.so for " +
                requested.filterNot { it in staged }
        )
    }
    return requested
}

protobuf {
    protoc {
        artifact = libs.protobuf.protoc.get().toString()
    }
    generateProtoTasks {
        ofNonTest().forEach { task ->
            task.builtins {
                id("java") {
                    option("lite")
                }
                id("kotlin") {
                    option("lite")
                }
            }
        }
    }
}

val baseCFlags = listOf(
    "-Wall", "-Qunused-arguments", "-fvisibility=hidden", "-fvisibility-inlines-hidden",
    "-fno-exceptions", "-fno-stack-protector", "-fomit-frame-pointer",
    "-Wno-builtin-macro-redefined", "-Wno-unused-value", "-D__FILE__=__FILE_NAME__"
)
val baseCppFlags = baseCFlags + "-fno-rtti"

android {
    namespace = "io.tomiesu.manager"

    buildTypes {
        debug {
            externalNativeBuild {
                cmake {
                    arguments += listOf("-DCMAKE_CXX_FLAGS_DEBUG=-Og", "-DCMAKE_C_FLAGS_DEBUG=-Og")
                }
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            vcsInfo.include = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            externalNativeBuild {
                cmake {
                    arguments += "-DDEBUG_SYMBOLS_PATH=${layout.buildDirectory.get().asFile.absolutePath}/symbols"
                    arguments += "-DCMAKE_BUILD_TYPE=Release"

                    val releaseFlags = listOf(
                        "-flto", "-ffunction-sections", "-fdata-sections", "-Wl,--gc-sections",
                        "-fno-unwind-tables", "-fno-asynchronous-unwind-tables", "-Wl,--exclude-libs,ALL"
                    )
                    val configFlags = listOf("-Oz", "-DNDEBUG").joinToString(" ")

                    cppFlags += releaseFlags
                    cFlags += releaseFlags

                    arguments += listOf(
                        "-DCMAKE_CXX_FLAGS_RELEASE=$configFlags",
                        "-DCMAKE_C_FLAGS_RELEASE=$configFlags",
                        "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--gc-sections -Wl,--exclude-libs,ALL -Wl,--icf=all -s -Wl,--hash-style=sysv -Wl,-z,norelro"
                    )
                }
            }
        }
    }

    buildFeatures {
        aidl = true
        buildConfig = true
        resValues = true
        compose = true
        prefab = true
    }

    packaging {
        dex {
            useLegacyPackaging = true
        }
        jniLibs {
            useLegacyPackaging = true
            excludes += "lib/*/libandroidx.graphics.path.so"
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    androidResources {
        generateLocaleConfig = false
    }
    compileSdk {
        version =
            release(androidCompileSdkVersion) {
                minorApiLevel = androidCompileSdkVersionMinor
            }
    }
    buildToolsVersion = androidBuildToolsVersion
    ndkVersion = androidCompileNdkVersion

    defaultConfig {
        minSdk = androidMinSdkVersion
        targetSdk = androidTargetSdkVersion
        versionCode = managerVersionCode
        versionName = managerVersionName
        applicationId = managerPackageName

        buildConfigField("boolean", "IS_PR_BUILD", isPrBuild.toString())
        buildConfigField("long", "BUNDLED_KERNEL_VERSION_CODE", "${bundledKernelVersionCode}L")
        buildConfigField("boolean", "CORE_UPDATE_ENABLED", coreUpdateEnabled.toString())
        buildConfigField("String", "TOMIESU_UPDATE_URL", "\"${tomieSuUpdateUrl.replace("\\", "\\\\").replace("\"", "\\\"")}\"")
        resValue("string", "app_name", managerName)

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=none"
                cFlags += baseCFlags + "-std=c2x"
                cppFlags += baseCppFlags + "-std=c++2b"
            }
        }

        ndk {
            abiFilters += managerAbis()
        }
    }

    lint {
        lintConfig = file("lint.xml")
        abortOnError = true
        checkReleaseBuilds = false
    }

    compileOptions {
        sourceCompatibility = androidSourceCompatibility
        targetCompatibility = androidTargetCompatibility
    }
}

androidComponents {
    beforeVariants(selector().all()) { variant ->
        requireNotNull(variant.hostTests[HostTestBuilder.UNIT_TEST_TYPE]) {
            "Missing default JVM test component for ${variant.name}"
        }.enable = true
    }
    onVariants(selector().withBuildType("release")) {
        it.packaging.resources.excludes.addAll(listOf("META-INF/**", "kotlin/**", "**.bin"))
    }
}

base {
    archivesName.set(
        "${managerName.replace(" ", "_")}_${managerVersionName}_${managerVersionCode}"
    )
}

dependencies {
    implementation("com.android.tools.build:apksig:9.4.1")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.83")
    // GhostLock 隐藏环境配置引擎（HOCON 解析）
    implementation("com.typesafe:config:1.4.3")
    implementation(libs.androidx.exifinterface)
    implementation(libs.reorderable)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.splashscreen)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.coil.compose)
    implementation(project(":ai-api"))
    val aiAar = file("libs/ai.aar")
    val aiProject = findProject(":ai")
    if (aiAar.isFile) {
        implementation(files(aiAar))
    } else if (aiProject != null) {
        implementation(project(":ai"))
    }
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)

    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigationevent.compose)

    implementation(libs.com.github.topjohnwu.libsu.core)
    implementation(libs.com.github.topjohnwu.libsu.service)
    implementation(libs.com.github.topjohnwu.libsu.io)

    implementation(libs.dev.rikka.rikkax.parcelablelist)

    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.commonmark)
    implementation(libs.commonmark.ext.gfm.tables)
    implementation(libs.commonmark.ext.gfm.strikethrough)
    implementation(libs.commonmark.ext.autolink)
    implementation(libs.commonmark.ext.task.list.items)

    implementation(libs.androidx.webkit)

    implementation(libs.lsposed.cxx)

    implementation(libs.hiddenapibypass)

    implementation(libs.miuix.ui)
    implementation(libs.miuix.icons)
    implementation(libs.miuix.nav)
    implementation(libs.miuix.preference)
    implementation(libs.miuix.blur)

    implementation(platform(libs.okhttp.bom))
    implementation(libs.okhttp)

    implementation(libs.material.kolor)

    implementation(libs.appiconloader)

    implementation(libs.commons.compress)
    implementation(libs.xz)
    implementation(libs.protobuf.kotlin.lite)

    testImplementation(libs.junit)
}

kotlin {
    compilerOptions {
        freeCompilerArgs.addAll(
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi",
        )
    }
}
