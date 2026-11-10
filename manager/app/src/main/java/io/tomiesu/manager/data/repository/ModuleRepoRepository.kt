package io.tomiesu.manager.data.repository

import io.tomiesu.manager.data.model.RepoModuleDetail
import io.tomiesu.manager.data.model.RepoModuleList
import io.tomiesu.manager.data.registry.UpdateVerification

interface ModuleRepoRepository {
    
    suspend fun fetchModules(): Result<RepoModuleList>

    /**
     * Detail (and readme) of a module in the current index. Fails with
     * [io.tomiesu.manager.data.registry.ModuleNotInIndexException] if it is not listed.
     */
    suspend fun fetchDetail(moduleId: String): Result<RepoModuleDetail>

    
    suspend fun fetchChangelogHtml(moduleId: String, tag: String?): String?

    /**
     * How an `updateJson` update of an installed module must be verified: against the matching
     * registry release, rejected, or legacy (not a registry update).
     */
    suspend fun resolveUpdate(moduleId: String, updateJsonUrl: String, zipUrl: String, versionCode: Long): UpdateVerification

    
    suspend fun fetchRegistryText(url: String): String?

    
    fun isRegistryUrl(url: String): Boolean
}
