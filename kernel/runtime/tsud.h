#ifndef __KSU_H_TSUD
#define __KSU_H_TSUD

#include <asm/syscall.h>

#define TSUD_PATH "/data/adb/tsud"

int ksu_tsud_init(void);
int ksu_tsud_exit(void);

void ksu_execve_hook_tsud(const struct pt_regs *regs);
void ksu_execveat_hook_tsud(const struct pt_regs *regs);
void ksu_stop_input_hook_runtime(void);

#endif
