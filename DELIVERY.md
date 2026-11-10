# TomieSU v1.7.6 (17601) 交付说明

基线：MikSU（MilkSU）→ 改名 TomieSU，功能树对齐 SukiSU-Ultra 全量 + XEKernelPro 隐藏环境。

## 一、本次全量同步结果

| 项 | 数值 |
|---|---|
| 同步 SukiSU Kotlin 文件 | 490 |
| 保留 TomieSU 定制文件 | 11（ghostlock 20 个子文件 + hidepack 4 + XcShim + Stealth 3 + Natives 2） |
| 删除 MikSU 独有子系统 | 26（自我更新/管理器隐藏链，与 SukiSU model 冲突） |
| 版号 | versionName 1.7.6 / versionCode 17601 |

### 已补齐的四块子系统

1. **KPM 模块管理** — `ui/screen/kpm/*`(6) + `ui/viewmodel/KpmViewModel` + `data/repository/KpmRepository{,Impl}` + `KsuCli` 内 `listKpmModules/loadKpmModule/unloadKpmModule/controlKpmModule/getKpmVersion/getKpmModuleCount/getKpmModuleInfo`
2. **SuSFS 状态与配置** — `ui/screen/susfs/*`(59) + `getSuSFSStatus/getSuSFSVersion/getSuSFSVariant/getSuSFSImplementation/getSuSFSFeatures`
3. **动态管理器** — `ui/screen/dynamicmanagers/*` + `addDynamicManager/removeDynamicManager/getDynamicManagers/getDynamicManagerSignature/setDynamicManagersEnabled/runDynamicManagerCommand`
4. **AI 助手** — `ai/host/*`(11)：`AiThemeController` / `AiSusfsController` / `AiExtensionsController` / `AiSuperuserController` / `AiModuleController` / `AiFeatureCatalog` / `AiEnvironment`

外加 `ui/kernelFlash/*`(18)、`ui/screen/extensions/*`、`ui/screen/module*`、`ui/component/*`、`ui/navigation3/*`。

### native 层

`cpp/` 全量换为 SukiSU 版（jni.cc 468 / ksu.cc 360 / ksu.h 108 / uapi 8 头），JNI 前缀改 `Java_io_tomiesu_manager_NativeBridge_*`，共 29 个导出。

- 补 `KSU_GET_INFO_FLAG_MANAGER_HIDE = (1U << 6)` 到 `uapi/supercall.h`
- 回填 MikSU 独有 `is_manager_hide_supported()` / `verify_manager_access()`（ksu.cc + jni.cc）
- `NativeBridge.kt` 增 6 个声明：`getFullVersion` / `getHookType` / `isAvcSpoofEnabled` / `setAvcSpoofEnabled` / `isMountHideEnabled` / `setMountHideEnabled`
- `Natives.kt` 对应增 6 个公开成员
- `libtomiesu.so`：162,376 → 172,592 B

## 二、版本号

```
version.properties
  TOMIESU_VERSION_NAME=1.7.6
  TOMIESU_VERSION_CODE=17601
  TOMIESU_MANAGER_VERSION_CODE=17601
manager/build.gradle.kts
  require(managerVersionCode >= 10000 && ...)   # 原 32800
```

## 三、全局汉化

| 项 | 结果 |
|---|---|
| `values-zh-rCN/strings.xml` | 以 SukiSU 完整中文（1618 条）为底，补 TomieSU 独有 33 条 → **1647 / 1647，缺 0** |
| `values-zh-rCN/milksu.xml` | 60 条对齐 + `home_support_project_url` |
| 重复资源 | 删除 `kpm_title` / `kpm_empty` / `kpm_control` / `home_susfs_version` 与 milksu.xml 的冲突 |
| 硬编码英文 | `SplashScreen` 两句、`AiFeatureCatalog` 7 处响应文案已汉化；`ID:` / `META` / `ZYGISK` / `SHA-256:` / `UID:` / `LOCAL` / `REMOTE` / `LKM ·` 属技术标识，保留 |
| plurals | 5 组随 zh 资源包一并提供 |

中文系统下无英文残留。

## 四、构建产物

```
manager/app/build/outputs/apk/debug/TomieSU_1.7.6_17601-debug.apk
41,621,269 bytes
SHA256 1160d51824fd0e8ec145e839fa7bde8804281dd021df7aeee41f67724980e9e1
```

| 条目 | 大小 |
|---|---|
| lib/arm64-v8a/libtomiesu.so | 172,592 |
| lib/arm64-v8a/libtsud.so | 3,977,952 |
| lib/arm64-v8a/libghostlock.so | 413,112 |
| lib/arm64-v8a/libadbroot.so | 120,008 |
| assets/kernel_profiles/ | 85 conf |
| dex | 22 |

## 五、定制保留清单（未被全量同步覆盖）

| 模块 | 文件 |
|---|---|
| GhostLock 隐藏引擎 | `com/ghostlock/app/**` 20 文件、`privilege/GhostLockRunner.kt`(530)、`assets/kernel_profiles/`、`libghostlock.so` |
| 隐身入口 | `privilege/StealthEntrance.kt`、`ui/StealthLaunchActivity.kt`、`ui/screen/settings/StealthEntranceSwitches.kt`、`tsud stealth` 子命令 |
| 隐藏包 | `ui/screen/hidepack/{HideEnvListScreen,OneTapHideScreen,HidePackDownloader,HideEnvEntry}.kt` |
| 设计桥 | `ui/design/XcShim.kt` |
| native 桥 | `Natives.kt` / `NativeBridge.kt` 包装层（`nativeOr` 降级） |
| 路由 | `Route.HideEnvList` / `Route.OneTapHide` / `Route.ColorPalette(section)` / `Route.SuSFS(tab)` |
| 依赖 | `com.typesafe:config:1.4.3`、`androidx.exifinterface:1.3.6`、`sh.calvin.reorderable:3.1.0` |

## 六、设备验证

```bash
adb install -r TomieSU_1.7.6_17601-debug.apk
adb shell dumpsys package io.tomiesu.manager | grep versionName   # 1.7.6
adb shell /data/app/*/io.tomiesu.manager-*/lib/arm64/libtsud.so stealth status
adb shell /data/app/*/io.tomiesu.manager-*/lib/arm64/libtsud.so late-load --allow-shell
```

界面路径：
- KPM：底部 KPM 页签
- SuSFS：设置 → SuSFS
- 动态管理器：设置 → 动态管理器
- 扩展：设置 → 扩展
- 内核刷写：首页 → 刷写
- 主题商店：设置 → 主题 → 主题商店
- 隐藏环境：设置 → 隐藏环境 / 一键隐藏
- 隐身入口：设置 → 隐藏管理器入口

## 七、未验证 / 风险

| 项 | 说明 |
|---|---|
| 实机运行 | 全部改动仅静态编译通过，未上真机；KPM / SuSFS 依赖内核侧 `tsud` 命令存在 |
| tsud 子命令覆盖 | `tsud` 已含 kpm/susfs/dynamic_manager/umount 命令族（SukiSU 同源）；`mount_hide` 本树仍无 |
| 删除的 26 个文件 | MikSU 自我更新链（ManagerApk/ManagerTransfer/ManagerHiding/CoreManagerUpdater 等）备份在 `/tmp/miksu_extra_bak/`，需要时恢复 |
| GhostLock | 需 `uname -r` 命中 85 个 profile 之一 |
| 一键隐藏远端 | `http://42.193.123.248:5244/d/hidepack/manifest.json` 未实测 |


## 八、内核侧（ko）激活与补丁

### 基座选择

**用树内 `kernel/`，不要换 SukiSU 内核仓库。**

证据：

| 判据 | 值 |
|---|---|
| `kernel/MILKSU_HOOK_PROVENANCE.json` | product=TomieSU，backend=`KernelSU-Next ARM64 sys_enter dispatcher`，uapi_version=6 |
| `uapi/supercall.h` vs `manager/app/src/main/cpp/uapi/supercall.h` | `diff` 完全相同 |
| 内核独有能力 | `feature/avc_spoof`、`feature/selinux_hide`、`preinit/`、`susfs/`、`milksu_root.h` —— SukiSU 内核没有 |
| SukiSU 内核多出的 | `extension/` 框架（KPM/SuSFS extension、version_spoof、cpu_spoof）、`feature/uts_spoof` |

结论：基座留树内，只从 SukiSU 内核搬缺口。

### 已打补丁（补齐管理器需要的 3 个 ioctl）

| 文件 | 改动 |
|---|---|
| `kernel/Kbuild:142` | 版本下限 `32800` → `10000`（否则 17601 直接 `$(error)`） |
| `kernel/Kbuild:149` | 新增 `-DKSU_VERSION_FULL=\"v$(TOMIESU_VERSION_NAME)-$(KSU_VERSION)\"` |
| `kernel/Kbuild:57` | 新增 `kernelsu-objs += feature/uts_spoof.o` |
| `kernel/include/ksu.h` | 补 `KSU_VERSION_FULL` 兜底默认值 |
| `kernel/feature/uts_spoof.{c,h}` | 新增，从 SukiSU 移植（62+11 行），`ksu_set_spoof_version()` / `ksu_spoof_version()` |
| `kernel/supercall/dispatch.c` | 新增 3 个 handler + 3 条注册 |

新增 handler：

```c
// 100 GET_FULL_VERSION  perm=manager_or_root  → KSU_VERSION_FULL
// 101 HOOK_TYPE         perm=manager_or_root  → "Sys_Enter Dispatcher"
// 102 SET_SPOOF_VERSION perm=only_root        → ksu_set_spoof_version()
```

结果：dispatch 覆盖 ioctl **25 → 28**，与 `uapi/supercall.h` 的 28 个完全对齐。

### 编译

```bash
# LKM（GKI 设备，需 docker + ddk）
cd kernel && ddk build android14-6.1 ODIR=$PWD/out/6.1 -e CONFIG_KSU=m
# 或一次全 KMI
bash kernel/build-all.sh
```

```bash
# 内建（非 GKI）：把 kernel/ 放进目标内核树，CONFIG_KSU=y，再编 Image
```

本机无 docker 且无目标内核源码树，**ko 编译未执行**。


### 内核模块命名与 Wind 变体

- 产物名 `tomiesu.ko`（原 `kernelsu.ko` 已全仓库改名）。
- 带 Wind 驱动的变体 `tomiesu-wind.ko`，编译时 `CONFIG_WIND=y`。
- `Kbuild:140` 起：`ifeq ($(CONFIG_WIND),y)` 把 `wind/*.o` 并入同一 `tomiesu-objs`。
- `wind/entry.c` 的 `module_init` 被 `WIND_STANDALONE` 条件包住，并入时改由 `core/init.c` 调 `wind_driver_init()` / `wind_driver_exit()`。
- Wind 驱动 8067 行、9 个目标文件，misc 设备名 `windc`（major 10 动态 minor），netlink 通讯在 `wind/nlcomm.c`。

### 管理器开关

安装/加载页「高级选项」新增 `加载 Wind 驱动`：

| 状态 | 行为 |
|---|---|
| 开启 | `tsud late-load --wind` 优先加载 `{kmi}_tomiesu-wind.ko`，缺失时回退并告警 |
| 关闭 | 仅加载 `{kmi}_tomiesu.ko`，纯 root 能力 |

字符串 `install_load_wind` / `install_load_wind_summary` 已双语落盘。

### 编译 wind 变体

```bash
bash tools/build-lkm.sh android14-6.1 wind
# → out/aarch64/android14-6.1_tomiesu-wind.ko
```

容器内校验：产物必须能 `strings | grep windc`，否则构建失败。

### 真机激活

```bash
adb install -r TomieSU_1.7.6_17601-debug.apk
adb push kernel/kernelsu-android14-6.1.ko /data/local/tmp/
adb shell su -c 'mkdir -p /data/adb/tsud && cp /data/local/tmp/kernelsu-android14-6.1.ko /data/adb/tsud/kernelsu.ko'
adb shell su -c '/data/adb/tsud/tsud late-load --allow-shell --kmi android14-6.1'
adb shell su -c '/data/adb/tsud/tsud post-fs-data'
adb shell su -c '/data/adb/tsud/tsud services'
adb shell su -c '/data/adb/tsud/tsud boot-completed'
```

首次无 tsud 时，管理器 `AppZygotePreload` 会从 `libtsud.so` 落地 `/data/adb/tsud/tsud`。

### 验证

```bash
adb shell su -c 'dmesg | grep -i "kernelsu version\|ksu:"'
adb shell su -c '/data/adb/tsud/tsud kpm list'
adb shell su -c '/data/adb/tsud/tsud susfs status'
adb shell su -c '/data/adb/tsud/tsud module list'
```

管理器内：首页应显示 `LKM · 1.7.6`，内核版本来自 `GET_FULL_VERSION`。

LKM 模式重启后内核侧丢失，需 boot 时重载（init 脚本 / `preinit`）。

## 九、回滚

- 全量同步前：`/root/1/inbox/tomie/TomieSU-pre-fullsync.tar.gz`（5.5M）
- 改名之前：`/root/1/inbox/tomie/TomieSU-pre-rename.tar.gz`（4.9M）
- 单文件：工程内 `*.mikbak` / `*.mikbak2` / `*.mikbak3` / `*.mikbak4` / `*.oldshim`
- 删除的 MikSU 子集：`/tmp/miksu_extra_bak/`

## 十、激活隔离（TomieSU 独占）

### 工作目录迁移

`/data/adb/ksu/` → `/data/adb/tomiesu/`，全仓库 0 处残留。

| 位置 | 改动 |
|---|---|
| `userspace/tsud/src/defs.rs:14` | `concatcp!(ADB_DIR, "tomiesu/")` |
| `kernel/feature/adb_root.c:49,69,70` | libadbroot 路径与 LD_PRELOAD |
| `kernel/policy/allowlist.c:74` | `.allowlist` 路径 |
| `kernel/extension/dynamic_manager.c:29` | `.dynamic_managers` 路径 |
| `manager/.../cpp/adbroot.cc:79,80,118` | `.ksurc` 与 `bin` 路径 |
| tsud 15 个 .rs + 管理器 8 个 .kt | kpm/susfs/sulog/boot-patch/stealth/storage |

效果：MilkSU / KernelSU-Next 管理器检查各自的工作目录，看不到别人的痕迹 → 不再互相认领为「已激活」。

### 产品身份 ioctl

```c
// uapi/supercall.h
struct ksu_product_cmd {
    __u32 version_code;
    char product[16];         // "tomiesu"
    char manager_package[64]; // io.tomiesu.manager
    char working_dir[64];     // /data/adb/tomiesu
};
static const __u32 KSU_IOCTL_GET_PRODUCT = _IOC(_IOC_READ, 'K', 103, 0);
```

内核 `dispatch.c:193` `do_get_product()`，perm = `allowed_for_driver`；`include/ksu.h` 定义 `TOMIESU_WORKING_DIR`。

管理器侧链路：`ksu.cc` `DEFINE_CACHED_GETTER(product, ...)` → `jni.cc` `NativeBridge.getProduct()` → `Natives.product` / `Natives.isTomieProduct`。

激活判定加双保险：

```kotlin
val isManager: Boolean
    get() = nativeOr(false) { NativeBridge.isManager } && isTomieProduct
```

内核记录的 manager uid 匹配之后，还要内核自报 `product == "tomiesu"`，否则不认为已激活。

### dispatch 覆盖

ioctl 从 28 增至 **30**（`EXTENSION` + `GET_PRODUCT`），括号平衡 0。

### 版本断言

`userspace/tsud/build.rs:29` 也有一条 `32800` 下限，与 `kernel/Kbuild:142` 同款，已同步放宽到 `10000`。
