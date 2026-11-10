package io.tomiesu.manager.ui.screen.hidepack

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.rounded.SettingsSuggest
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import io.tomiesu.manager.R
import io.tomiesu.manager.ui.component.material.SegmentedListItem
import io.tomiesu.manager.ui.navigation3.LocalNavigator
import io.tomiesu.manager.ui.navigation3.Route
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.preference.ArrowPreference

/** 设置页 → 隐藏环境列表（Miuix 主题）。 */
@Composable
fun HideEnvEntryMiuix() {
    val navigator = LocalNavigator.current
    ArrowPreference(
        title = stringResource(id = R.string.hide_env_title),
        summary = stringResource(id = R.string.hide_env_violet_desc),
        startAction = {
            Icon(
                Icons.Rounded.SettingsSuggest,
                contentDescription = stringResource(id = R.string.hide_env_title),
            )
        },
        onClick = { navigator.push(Route.HideEnvList) },
    )
}

/** 设置页 → 隐藏环境列表（Material 主题）。 */
@Composable
fun HideEnvEntryMaterial() {
    val navigator = LocalNavigator.current
    SegmentedListItem(
        onClick = { navigator.push(Route.HideEnvList) },
        headlineContent = { Text(stringResource(id = R.string.hide_env_title)) },
        supportingContent = { Text(stringResource(id = R.string.hide_env_violet_desc)) },
        leadingContent = {
            Icon(
                Icons.Rounded.SettingsSuggest,
                stringResource(id = R.string.hide_env_title),
            )
        },
        trailingContent = {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null)
        },
    )
}
