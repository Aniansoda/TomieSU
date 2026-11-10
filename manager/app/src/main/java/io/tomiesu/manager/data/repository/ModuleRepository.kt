package io.tomiesu.manager.data.repository

import io.tomiesu.manager.data.model.Module
import io.tomiesu.manager.data.model.ModuleUpdateInfo

interface ModuleRepository {
    suspend fun getModules(): Result<List<Module>>
    suspend fun checkUpdate(module: Module): Result<ModuleUpdateInfo>
}
