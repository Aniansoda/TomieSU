package io.tomiesu.manager.ui.screen.module

import androidx.annotation.StringRes
import io.tomiesu.manager.R
import io.tomiesu.manager.data.model.Module


@StringRes
fun Module.preinitWarning(): Int? = when (preinit) {
    "no_space" -> R.string.module_preinit_no_space
    "error" -> R.string.module_preinit_error
    "bootloop" -> R.string.module_preinit_bootloop
    "unsupported" -> R.string.module_preinit_unsupported
    else -> null
}
