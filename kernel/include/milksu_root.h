/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef TOMIESU_ROOT_H
#define TOMIESU_ROOT_H

#include <linux/module.h>
#include <linux/types.h>

#define TOMIESU_ROOT_API_VERSION 1

struct tomiesu_root_api {
    u32 abi_version;
    u32 struct_size;
    struct module *owner;
    bool (*allow_uid_for_current)(uid_t uid);
    bool (*uid_should_umount)(uid_t uid);
    int (*get_avc_spoof)(bool *enabled);
    int (*set_avc_spoof)(bool enabled);
};

/*
 * Acquire with symbol_get(tomiesu_root_api_get), and retain that symbol reference
 * until all cached callbacks have been removed and drained. A NULL result means
 * the provider is not ready; symbol_put is still required in that case.
 * This kernel-to-kernel API does not change KernelSU UAPI 6.
 */
const struct tomiesu_root_api *tomiesu_root_api_get(void);
void tomiesu_root_set_ready(bool ready);
bool tomiesu_root_is_ready(void);
/* Published raw kernel callbacks require a resident provider in LKM mode. */
void tomiesu_root_pin_callbacks(void);
bool tomiesu_root_callbacks_pinned(void);

#endif
