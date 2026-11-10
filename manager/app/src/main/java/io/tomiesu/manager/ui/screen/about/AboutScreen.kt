package io.tomiesu.manager.ui.screen.about

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.dropUnlessResumed
import androidx.lifecycle.viewmodel.compose.viewModel
import io.tomiesu.manager.BuildConfig
import io.tomiesu.manager.R
import io.tomiesu.manager.ui.LocalUiMode
import io.tomiesu.manager.ui.UiMode
import io.tomiesu.manager.ui.navigation3.LocalNavigator
import io.tomiesu.manager.ui.theme.Shapes
import io.tomiesu.manager.ui.theme.ThemeController
import io.tomiesu.manager.ui.theme.Typography
import io.tomiesu.manager.ui.theme.animateAsState
import io.tomiesu.manager.ui.theme.rememberKernelSUColorScheme
import io.tomiesu.manager.ui.util.BuiltinAppIcons
import io.tomiesu.manager.ui.util.customText
import io.tomiesu.manager.ui.util.CustomTextKey
import io.tomiesu.manager.ui.viewmodel.SettingsViewModel

// Miuix's own default accent, used when the Miuix skin runs without Monet or a custom key color.
private val MiuixDefaultSeed = Color(0xFF3482FF)

@Composable
fun AboutScreen() {
    val navigator = LocalNavigator.current
    val uriHandler = LocalUriHandler.current
    val viewModel = viewModel<SettingsViewModel>()
    val settingsState by viewModel.uiState.collectAsStateWithLifecycle()
    val htmlString = stringResource(
        id = R.string.about_source_code,
        "<b><a href=\"https://github.com/ShirkNeko/SukiSU-Ultra\">GitHub</a></b>",
        "<b><a href=\"https://t.me/SukiKSU\">Telegram</a></b>",
    )
    val state = AboutUiState(
        title = customText(CustomTextKey.PAGE_ABOUT),
        appName = stringResource(R.string.app_name),
        versionName = BuildConfig.VERSION_NAME,
        icon = BuiltinAppIcons.find(settingsState.appIconId),
        links = extractLinks(htmlString),
        checkUpdate = settingsState.checkUpdate,
        checkCiUpdate = settingsState.checkCiUpdate,
        checkModuleUpdate = settingsState.checkModuleUpdate,
    )
    val actions = AboutScreenActions(
        onBack = dropUnlessResumed { navigator.pop() },
        onOpenLink = uriHandler::openUri,
        onSetCheckUpdate = viewModel::setCheckUpdate,
        onSetCheckCiUpdate = viewModel::setCheckCiUpdate,
        onSetCheckModuleUpdate = viewModel::setCheckModuleUpdate,
    )

    // The Material 3 Expressive page is shared by both skins; the Miuix skin has no Material theme above it.
    when (LocalUiMode.current) {
        UiMode.Material -> AboutScreenMaterial(state, actions)
        UiMode.Miuix -> MiuixSkinMaterialTheme { AboutScreenMaterial(state, actions) }
    }
}

@Composable
private fun MiuixSkinMaterialTheme(content: @Composable () -> Unit) {
    val appSettings = remember { ThemeController.getAppSettings() }
    val colorMode = appSettings.colorMode
    val darkTheme = colorMode.isDark || (colorMode.isSystem && isSystemInDarkTheme())
    val seedColor = when {
        appSettings.keyColor != 0 -> Color(appSettings.keyColor)
        colorMode.isMonet -> Color.Unspecified
        else -> MiuixDefaultSeed
    }
    val colorScheme = rememberKernelSUColorScheme(
        seedColor = seedColor,
        isDark = darkTheme,
        isAmoled = colorMode.isAmoled,
        paletteStyle = appSettings.paletteStyle,
        colorSpec = appSettings.colorSpec,
    )

    MaterialExpressiveTheme(
        colorScheme = colorScheme.animateAsState(),
        motionScheme = MotionScheme.expressive(),
        shapes = Shapes,
        typography = Typography,
        content = content,
    )
}
