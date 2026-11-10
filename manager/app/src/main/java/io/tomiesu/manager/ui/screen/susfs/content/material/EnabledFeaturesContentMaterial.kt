package io.tomiesu.manager.ui.screen.susfs.content.material

import androidx.compose.runtime.Composable
import io.tomiesu.manager.ui.screen.susfs.content.EnabledFeaturesContent
import io.tomiesu.manager.ui.screen.susfs.util.EnabledFeature

@Composable
fun EnabledFeaturesContentMaterial(
    enabledFeatures: List<EnabledFeature>,
    onRefresh: () -> Unit,
) = EnabledFeaturesContent(enabledFeatures, onRefresh)
