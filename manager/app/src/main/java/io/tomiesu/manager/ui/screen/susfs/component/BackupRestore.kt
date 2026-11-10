package io.tomiesu.manager.ui.screen.susfs.component

import androidx.compose.runtime.Composable
import io.tomiesu.manager.ui.LocalUiMode
import io.tomiesu.manager.ui.UiMode
import io.tomiesu.manager.ui.screen.susfs.component.miuix.BackupRestoreComponentMiuix
import io.tomiesu.manager.ui.screen.susfs.component.material.BackupRestoreComponentMaterial

@Composable
fun BackupRestoreComponent(
    isLoading: Boolean,
    onLoadingChange: (Boolean) -> Unit,
    onConfigReload: () -> Unit
) {
    when (LocalUiMode.current) {
        UiMode.Miuix -> BackupRestoreComponentMiuix(
            isLoading = isLoading,
            onLoadingChange = onLoadingChange,
            onConfigReload = onConfigReload
        )
        UiMode.Material -> BackupRestoreComponentMaterial(
            isLoading = isLoading,
            onLoadingChange = onLoadingChange,
            onConfigReload = onConfigReload
        )
    }
}
