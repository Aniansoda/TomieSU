package io.tomiesu.manager.ui.screen.umountmanager

import android.annotation.SuppressLint
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import io.tomiesu.manager.R
import io.tomiesu.manager.ui.LocalUiMode
import io.tomiesu.manager.ui.UiMode
import io.tomiesu.manager.ui.component.dialog.ConfirmResult
import io.tomiesu.manager.ui.component.dialog.rememberConfirmDialog
import io.tomiesu.manager.ui.navigation3.LocalNavigator
import io.tomiesu.manager.ui.util.addUmountPath
import io.tomiesu.manager.ui.util.applyUmountConfigToKernel
import io.tomiesu.manager.ui.util.clearCustomUmountPaths
import io.tomiesu.manager.ui.util.listUmountPaths
import io.tomiesu.manager.ui.util.removeUmountPath
import io.tomiesu.manager.ui.util.saveUmountConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@SuppressLint("LocalContextGetResourceValueCall")
@Composable
fun UmountManagerScreen() {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val confirmDialog = rememberConfirmDialog()

    var pathList by remember { mutableStateOf<List<UmountPathEntry>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var showAddDialog by remember { mutableStateOf(false) }

    val confirmActionText = stringResource(R.string.confirm_action)
    val umountPathRemovedText = stringResource(R.string.umount_path_removed)
    val confirmClearCustomPathsText = stringResource(R.string.confirm_clear_custom_paths)
    val customPathsClearedText = stringResource(R.string.custom_paths_cleared)
    val operationFailedText = stringResource(R.string.operation_failed)
    val configAppliedText = stringResource(R.string.config_applied)
    val umountPathAddedText = stringResource(R.string.umount_path_added)
    val confirmDelete = stringResource(R.string.confirm_delete)

    fun loadPaths() {
        scope.launch(Dispatchers.IO) {
            isLoading = true
            val result = listUmountPaths()
            val entries = parseUmountPaths(result)
            withContext(Dispatchers.Main) {
                pathList = entries
                isLoading = false
            }
        }
    }

    LaunchedEffect(Unit) {
        loadPaths()
    }

    val actions = UmountManagerActions(
        onRefresh = { loadPaths() },
        onAddClick = { showAddDialog = true },
        onAddPath = { path, flags ->
            showAddDialog = false

            scope.launch(Dispatchers.IO) {
                val success = addUmountPath(path, flags)
                withContext(Dispatchers.Main) {
                    if (success) {
                        saveUmountConfig()
                        Toast.makeText(context, umountPathAddedText, Toast.LENGTH_SHORT).show()
                        loadPaths()
                    } else {
                        Toast.makeText(context, operationFailedText, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        },
        onDismissAddDialog = { showAddDialog = false },
        onDeletePath = { pathEntry ->
            scope.launch {
                if (confirmDialog.awaitConfirm(
                        title = confirmDelete,
                        content = context.getString(R.string.confirm_delete_umount_path, pathEntry.path)
                    ) == ConfirmResult.Confirmed) {
                    scope.launch(Dispatchers.IO) {
                        val success = removeUmountPath(pathEntry.path)
                        withContext(Dispatchers.Main) {
                            if (success) {
                                Toast.makeText(context, umountPathRemovedText, Toast.LENGTH_SHORT).show()
                                loadPaths()
                            } else {
                                Toast.makeText(context, operationFailedText, Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }
            }
        },
        onClearCustomPaths = {
            scope.launch {
                if (confirmDialog.awaitConfirm(
                        title = confirmActionText,
                        content = confirmClearCustomPathsText
                    ) == ConfirmResult.Confirmed) {
                    withContext(Dispatchers.IO) {
                        val success = clearCustomUmountPaths()
                        withContext(Dispatchers.Main) {
                            if (success) {
                                Toast.makeText(context, customPathsClearedText, Toast.LENGTH_SHORT).show()
                                loadPaths()
                            } else {
                                Toast.makeText(context, operationFailedText, Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }
            }
        },
        onApplyConfig = {
            scope.launch(Dispatchers.IO) {
                val success = applyUmountConfigToKernel()
                withContext(Dispatchers.Main) {
                    if (success) {
                        Toast.makeText(context, configAppliedText, Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(context, operationFailedText, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        },
        onBack = { navigator.pop() }
    )

    val state = UmountManagerUiState(
        pathList = pathList,
        isLoading = isLoading,
        showAddDialog = showAddDialog
    )

    when (LocalUiMode.current) {
        UiMode.Miuix -> UmountManagerMiuix(
            state = state,
            actions = actions
        )
        UiMode.Material -> UmountManagerMaterial(
            state = state,
            actions = actions
        )
    }
}
