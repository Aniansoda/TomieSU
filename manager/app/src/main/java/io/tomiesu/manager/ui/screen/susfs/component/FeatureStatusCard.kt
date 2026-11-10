package io.tomiesu.manager.ui.screen.susfs.component

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.tomiesu.manager.ui.LocalUiMode
import io.tomiesu.manager.ui.UiMode
import io.tomiesu.manager.ui.screen.susfs.component.miuix.FeatureStatusCardMiuix
import io.tomiesu.manager.ui.screen.susfs.component.material.FeatureStatusCardMaterial
import io.tomiesu.manager.ui.screen.susfs.util.EnabledFeature

@Composable
fun FeatureStatusCard(
    feature: EnabledFeature,
    onRefresh: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    when (LocalUiMode.current) {
        UiMode.Miuix -> FeatureStatusCardMiuix(
            feature = feature,
            onRefresh = onRefresh,
            modifier = modifier
        )
        UiMode.Material -> FeatureStatusCardMaterial(
            feature = feature,
            onRefresh = onRefresh,
            modifier = modifier
        )
    }
}
