package io.tomiesu.manager.ui.screen.susfs.util

import android.content.pm.PackageInfo
import io.tomiesu.manager.ui.viewmodel.SuperUserViewModel

object AppInfoCache {
    private val appInfoMap = mutableMapOf<String, CachedAppInfo>()

    data class CachedAppInfo(
        val appName: String,
        val packageInfo: PackageInfo?,
        val drawable: android.graphics.drawable.Drawable?,
        val timestamp: Long = System.currentTimeMillis()
    )

    fun getAppInfo(packageName: String): CachedAppInfo? = appInfoMap[packageName]

    fun putAppInfo(packageName: String, appInfo: CachedAppInfo) {
        appInfoMap[packageName] = appInfo
    }

    fun clearCache() {
        appInfoMap.clear()
    }

    fun getAppInfoFromSuperUser(packageName: String): CachedAppInfo? {
        return SuperUserViewModel.getAppsSafely().find { it.packageName == packageName }?.let { app ->
            CachedAppInfo(appName = app.label, packageInfo = app.packageInfo, drawable = null)
        }
    }
}
