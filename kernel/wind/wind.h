/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __KSU_H_WIND
#define __KSU_H_WIND

#ifdef CONFIG_WIND
int wind_driver_init(void);
void wind_driver_exit(void);
#else
static inline int wind_driver_init(void) { return 0; }
static inline void wind_driver_exit(void) {}
#endif

#endif /* __KSU_H_WIND */
