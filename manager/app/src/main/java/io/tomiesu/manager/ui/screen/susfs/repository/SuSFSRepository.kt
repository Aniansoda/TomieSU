package io.tomiesu.manager.ui.screen.susfs.repository

import android.content.Context
import io.tomiesu.manager.ui.screen.susfs.util.AppInfo
import io.tomiesu.manager.ui.screen.susfs.util.EnabledFeature
import io.tomiesu.manager.ui.screen.susfs.util.ModuleConfig
import io.tomiesu.manager.ui.screen.susfs.util.SlotInfo

interface SuSFSRepositoryInterface {
    suspend fun loadInitialConfig(context: Context): Result<ModuleConfig>
    suspend fun getEnabledFeatures(context: Context): Result<List<EnabledFeature>>
    suspend fun getInstalledApps(): Result<List<AppInfo>>
    suspend fun getSlotInfo(context: Context): Result<Pair<List<SlotInfo>, String>>
}
