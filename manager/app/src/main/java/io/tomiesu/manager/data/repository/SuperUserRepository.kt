package io.tomiesu.manager.data.repository

import io.tomiesu.manager.data.model.AppInfo

interface SuperUserRepository {
    suspend fun getAppList(force: Boolean = false): Result<Pair<List<AppInfo>, List<Int>>>
    suspend fun refreshProfiles(currentApps: List<AppInfo>): Result<List<AppInfo>>
}
