#!/usr/bin/env bash
# Match the Arm GNU bare-metal release pinned in vendor/kpatch-next CI.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
tomiesu_log kpatch-toolchain
tomiesu_space
name=arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf
archive="$TOMIESU_CACHE/downloads/$name.tar.xz"
directory="$TOMIESU_CACHE/toolchains/$name"
url="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/12.2.rel1/binrel/$name.tar.xz"
mkdir -p "$TOMIESU_CACHE/downloads" "$TOMIESU_CACHE/toolchains" "$TOMIESU_OUT/toolchain"
if [[ ! -x "$directory/bin/aarch64-none-elf-gcc" ]]; then
    tomiesu_run curl --silent --show-error --fail --location --retry 3 --continue-at - "$url" -o "$archive"
    tomiesu_run tar -xJf "$archive" -C "$TOMIESU_CACHE/toolchains"
fi
sha256sum "$archive" >"$TOMIESU_OUT/toolchain/$name.sha256"
tomiesu_run "$directory/bin/aarch64-none-elf-gcc" --version
printf 'TARGET_COMPILE=%s/bin/aarch64-none-elf-\n' "$directory"
tomiesu_space
