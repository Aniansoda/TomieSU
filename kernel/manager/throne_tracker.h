#ifndef __KSU_H_UID_OBSERVER
#define __KSU_H_UID_OBSERVER

#include <linux/list.h>
#include <linux/types.h>
#include "uapi/app_profile.h"
#ifdef CONFIG_KSU_DISABLE_MANAGER
static inline void ksu_throne_tracker_init()
{
}

static inline void ksu_throne_tracker_exit()
{
}

static inline int track_throne(bool prune_only)
{
    (void)prune_only;
    return 0;
}
#else
void ksu_throne_tracker_init();

void ksu_throne_tracker_exit();

int track_throne(bool prune_only);

#endif

/* 管理器 UID 观测表条目，throne_tracker 与 dynamic_sig_fallback 共用 */
struct uid_data {
    struct list_head list;
    u32 uid;
    char package[KSU_MAX_PACKAGE_NAME];
};

#endif
