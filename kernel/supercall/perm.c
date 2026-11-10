#include <linux/types.h>

#include "supercall/internal.h"
#include "manager/manager_identity.h"
#include "policy/allowlist.h"
#include "tomiesu_root.h"

bool only_manager(void)
{
    return tomiesu_root_is_ready() && is_manager();
}

bool only_root(void)
{
    return tomiesu_root_is_ready() && current_uid().val == 0;
}

bool manager_or_root(void)
{
    return tomiesu_root_is_ready() && (current_uid().val == 0 || is_manager());
}

bool allowed_for_driver(void)
{
    return tomiesu_root_is_ready() &&
           (current_uid().val == 0 || is_manager() ||
            ksu_is_allow_uid_for_current(current_uid().val));
}

bool allowed_for_su(void)
{
    return tomiesu_root_is_ready() &&
           (is_manager() || ksu_is_allow_uid_for_current(current_uid().val));
}
