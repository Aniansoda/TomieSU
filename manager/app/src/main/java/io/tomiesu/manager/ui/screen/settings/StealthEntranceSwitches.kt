package io.tomiesu.manager.ui.screen.settings

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.tomiesu.manager.R
import io.tomiesu.manager.privilege.StealthEntrance
import io.tomiesu.manager.ui.component.material.SegmentedSwitchItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 隐身入口开关的共同状态：读 [StealthEntrance.isIconHidden]，写走 tsud
 * `stealth start|stop`（武装成功才藏图标，关闭先恢复图标）。
 */
private class StealthSwitchState(
    private val context: android.content.Context,
    private val scope: kotlinx.coroutines.CoroutineScope,
) {
    var hidden by mutableStateOf(StealthEntrance.isIconHidden(context))
    var busy by mutableStateOf(false)

    fun toggle(want: Boolean) {
        if (busy || want == hidden) return
        busy = true
        scope.launch {
            val ok = withContext(Dispatchers.IO) {
                if (want) StealthEntrance.enable(context) else StealthEntrance.disable(context)
            }
            busy = false
            if (ok) {
                hidden = want
            } else {
                // 失败时回读真实状态，避免 UI 与设备不一致。
                hidden = StealthEntrance.isIconHidden(context)
            }
        }
    }

    val summaryRes: Int
        get() = if (hidden) {
            R.string.settings_stealth_entrance_summary_on
        } else {
            R.string.settings_stealth_entrance_summary_off
        }
}

@Composable
private fun rememberStealthSwitchState(): StealthSwitchState {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    return remember(context) { StealthSwitchState(context, scope) }
}

/** Miuix 主题下的隐身入口开关。 */
@Composable
fun StealthEntranceSwitchMiuix(modifier: Modifier = Modifier) {
    val state = rememberStealthSwitchState()
    SwitchPreference(
        title = stringResource(id = R.string.settings_stealth_entrance),
        summary = stringResource(id = state.summaryRes),
        startAction = {
            Icon(
                if (state.hidden) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                modifier = Modifier.padding(end = 6.dp),
                contentDescription = stringResource(id = R.string.settings_stealth_entrance),
            )
        },
        checked = state.hidden,
        enabled = !state.busy,
        onCheckedChange = state::toggle,
    )
}

/** Material 主题下的隐身入口开关。 */
@Composable
fun StealthEntranceSwitchMaterial() {
    val state = rememberStealthSwitchState()
    SegmentedSwitchItem(
        icon = if (state.hidden) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
        title = stringResource(id = R.string.settings_stealth_entrance),
        summary = stringResource(id = state.summaryRes),
        checked = state.hidden,
        enabled = !state.busy,
        onCheckedChange = state::toggle,
    )
}
