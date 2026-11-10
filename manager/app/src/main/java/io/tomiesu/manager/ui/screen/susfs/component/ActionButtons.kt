package io.tomiesu.manager.ui.screen.susfs.component

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.tomiesu.manager.ui.LocalUiMode
import io.tomiesu.manager.ui.UiMode
import io.tomiesu.manager.ui.screen.susfs.component.miuix.BottomActionButtonsMiuix
import io.tomiesu.manager.ui.screen.susfs.component.material.BottomActionButtonsMaterial

@Composable
fun BottomActionButtons(
    modifier: Modifier = Modifier,
    primaryButtonText: String,
    onPrimaryClick: () -> Unit,
    secondaryButtonText: String? = null,
    onSecondaryClick: (() -> Unit)? = null,
    isLoading: Boolean = false,
    enabled: Boolean = true
) {
    when (LocalUiMode.current) {
        UiMode.Miuix -> BottomActionButtonsMiuix(
            modifier = modifier,
            primaryButtonText = primaryButtonText,
            onPrimaryClick = onPrimaryClick,
            secondaryButtonText = secondaryButtonText,
            onSecondaryClick = onSecondaryClick,
            isLoading = isLoading,
            enabled = enabled
        )
        UiMode.Material -> BottomActionButtonsMaterial(
            modifier = modifier,
            primaryButtonText = primaryButtonText,
            onPrimaryClick = onPrimaryClick,
            secondaryButtonText = secondaryButtonText,
            onSecondaryClick = onSecondaryClick,
            isLoading = isLoading,
            enabled = enabled
        )
    }
}
