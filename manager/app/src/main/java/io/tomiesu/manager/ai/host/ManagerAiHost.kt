package io.tomiesu.manager.ai.host

import android.content.Context
import android.content.SharedPreferences
import io.tomiesu.manager.KernelSUApplication
import io.tomiesu.manager.ai.api.AiAvatarDrawables
import io.tomiesu.manager.ai.api.AiExtensionsService
import io.tomiesu.manager.ai.api.AiFeatureService
import io.tomiesu.manager.ai.api.AiHost
import io.tomiesu.manager.ai.api.AiModuleService
import io.tomiesu.manager.ai.api.AiShellOutput
import io.tomiesu.manager.ai.api.AiSuperuserService
import io.tomiesu.manager.ai.api.AiThemeImageService
import io.tomiesu.manager.ai.api.AiThemeService
import io.tomiesu.manager.data.repository.SettingsRepositoryImpl
import io.tomiesu.manager.ui.util.BuiltinAppIcons
import io.tomiesu.manager.ui.util.ImageStorage
import io.tomiesu.manager.ui.util.withNewRootShell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.time.Duration.Companion.milliseconds

/**
 * TomieSU manager implementation of the assistant host SPI.
 *
 * Everything manager-specific lives in this module's host package; the `:ai`
 * library only sees the interfaces in [AiHost].
 */
class ManagerAiHost(
    private val app: KernelSUApplication,
) : AiHost {

    override val context: Context get() = app

    override fun isBackgroundImageActive(): Boolean {
        val settings = SettingsRepositoryImpl()
        val systemWallpaper = settings.useSystemWallpaper &&
            ImageStorage.systemWallpaperFile(app).isFile
        return systemWallpaper || settings.customBackgroundUri.isNotBlank()
    }

    override fun cardBackgroundAlpha(): Float =
        SettingsRepositoryImpl().cardBackgroundAlphaPercent / 100f

    override fun avatarDrawables(): AiAvatarDrawables? = runCatching {
        val icon = BuiltinAppIcons.find(SettingsRepositoryImpl().appIconId)
        AiAvatarDrawables(icon.iconRes, icon.foregroundRes)
    }.getOrNull()

    override fun showAiHomeCard(): Boolean = SettingsRepositoryImpl().showAiHomeCard

    override fun registerShowAiHomeCardListener(listener: () -> Unit): AutoCloseable {
        val prefs = app.getSharedPreferences("settings", Context.MODE_PRIVATE)
        val registration = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == null || key == "show_ai_home_card") listener()
        }
        prefs.registerOnSharedPreferenceChangeListener(registration)
        return AutoCloseable { prefs.unregisterOnSharedPreferenceChangeListener(registration) }
    }

    override suspend fun executeRootShell(command: String): AiShellOutput =
        withContext(Dispatchers.IO) {
            val output = withTimeoutOrNull(ROOT_TIMEOUT_MS.milliseconds) {
                runInterruptible(Dispatchers.IO) {
                    runCatching {
                        withNewRootShell {
                            val stdout = mutableListOf<String>()
                            val stderr = mutableListOf<String>()
                            val result = newJob().add(command).to(stdout, stderr).exec()
                            AiShellOutput(
                                output = buildString {
                                    if (stdout.isNotEmpty()) append(stdout.joinToString("\n"))
                                    if (stderr.isNotEmpty()) {
                                        if (isNotEmpty()) append('\n')
                                        append(stderr.joinToString("\n"))
                                    }
                                },
                                exitCode = result.code,
                            )
                        }
                    }.getOrElse { error ->
                        AiShellOutput(
                            output = error.message ?: error.javaClass.simpleName,
                            exitCode = -1,
                        )
                    }
                }
            }
            output?.let { capped(it) } ?: AiShellOutput(output = "", exitCode = -1, timedOut = true)
        }

    private fun capped(result: AiShellOutput): AiShellOutput =
        if (result.output.length <= MAX_OUTPUT) {
            result
        } else {
            result.copy(output = result.output.take(MAX_OUTPUT))
        }

    override val environment = AiEnvironment
    override val theme: AiThemeService = AiThemeController
    override val extensions: AiExtensionsService = AiExtensionsController
    override val superuser: AiSuperuserService = AiSuperuserController
    override val modules: AiModuleService = AiModuleServiceHost
    override val features: AiFeatureService = AiFeatureCatalog
    override val themeImages: AiThemeImageService = AiThemeImageStore

    private companion object {
        const val ROOT_TIMEOUT_MS = 60_000L
        const val MAX_OUTPUT = 20_000
    }
}
