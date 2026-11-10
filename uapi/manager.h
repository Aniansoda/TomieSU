#ifndef __KSU_UAPI_MANAGER_H
#define __KSU_UAPI_MANAGER_H

#include <linux/types.h>

#define KSU_MANAGER_MAX_ENTRIES 16
#define KSU_MANAGER_PACKAGE_LENGTH 128
#define KSU_MANAGER_HASH_LENGTH 64
#define KSU_MAX_DYNAMIC_MANAGERS KSU_MANAGER_MAX_ENTRIES

#define KSU_MANAGER_GET 0
#define KSU_MANAGER_ADD 1
#define KSU_MANAGER_REMOVE 2
#define KSU_MANAGER_SET_ENABLED 3
#define KSU_MANAGER_CLEAR 4

struct ksu_manager_entry {
    __u32 cert_size;
    __u32 uid;
    char package[KSU_MANAGER_PACKAGE_LENGTH];
    char hash[KSU_MANAGER_HASH_LENGTH + 1];
};

struct ksu_manager_cmd {
    __u32 operation;
    __u32 enabled;
    __u32 count;
    __u32 cert_size;
    __u32 uid;
    char package[KSU_MANAGER_PACKAGE_LENGTH];
    char hash[KSU_MANAGER_HASH_LENGTH + 1];
    struct ksu_manager_entry entries[KSU_MANAGER_MAX_ENTRIES];
};


/* 隐藏管理器身份文件格式：/data/user_de/0/<pkg>/files/.manager-identity
 * 全 packed，长度必须等于 sizeof(struct)，读取端用整文件长度做严格校验。 */
#define KSU_MANAGER_IDENTITY_MAGIC 0x4d534d49u /* "MSMI" */
#define KSU_MANAGER_IDENTITY_VERSION 1u

struct ksu_manager_identity_record {
	__u32 magic;
	__u32 version;
	__u32 certificate_size;
	char package[256];
	char certificate_sha256[65];
} __attribute__((packed));

#endif
