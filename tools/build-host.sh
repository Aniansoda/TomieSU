#!/usr/bin/env bash
# Build the Linux offline image tool from current sources and real Android assets.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
tomiesu_log host-tsud
tomiesu_space
tomiesu_heavy_lock
work="$TOMIESU_CACHE/build/host/source"
mkdir -p "$(dirname "$work")" "$TOMIESU_OUT/tools"
exec {host_lock}>"$TOMIESU_CACHE/build/host.lock"
flock "$host_lock"
if [[ ! -d "$work/.git" ]]; then
    tomiesu_run git clone --shared --no-hardlinks "$TOMIESU_ROOT" "$work"
fi
tomiesu_run rsync -a --delete --exclude=.git --exclude=out --exclude=target \
    --exclude=build --exclude=.gradle --exclude=.kotlin --exclude=.cxx \
    --exclude=node_modules --exclude=local.properties --exclude=dist \
    "$TOMIESU_ROOT/" "$work/"
cd "$work"
export KSU_PACKAGE_NAME="$TOMIESU_PACKAGE_NAME"
# shellcheck source=/dev/null
source <(sed 's/\r$//' "$work/.github/scripts/setup-rust-build.sh") aarch64-linux-android "$TOMIESU_ANDROID_API"
builtins="$("$CLANG_PATH" --print-resource-dir)/lib/linux/libclang_rt.builtins-aarch64-android.a"
export RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wno-unused-command-line-argument -C link-arg=$builtins"
tomiesu_run cargo build --locked --package ksuinit --target aarch64-linux-android --release
unset RUSTFLAGS
assets="$work/userspace/tsud/bin/aarch64"
mkdir -p "$assets"
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/ksuinit" "$assets/ksuinit"
for module in "$TOMIESU_OUT/aarch64/"*.ko; do
    [[ -f "$module" ]] || continue
    cp "$module" "$assets/"
done
for name in kpimg kptools; do
    [[ -s "$TOMIESU_OUT/kpatch/aarch64/$name" ]] || tomiesu_die "Missing source-built $name."
    cp "$TOMIESU_OUT/kpatch/aarch64/$name" "$assets/$name"
done
for kmi in android14-6.1 android12-5.10; do
    for suffix in tomiesu susfs_guard_lkm; do
        [[ -s "$assets/${kmi}_${suffix}.ko" ]] || tomiesu_die "Missing real asset: ${kmi}_${suffix}.ko."
    done
done
tomiesu_run cargo clean --package tsud --target x86_64-unknown-linux-gnu
tomiesu_run cargo build --locked --package tsud --target x86_64-unknown-linux-gnu
cp "$CARGO_TARGET_DIR/x86_64-unknown-linux-gnu/debug/tsud" "$TOMIESU_OUT/tools/tsud"
tomiesu_run "$TOMIESU_OUT/tools/tsud" --help
tomiesu_run file "$TOMIESU_OUT/tools/tsud"
sha256sum "$TOMIESU_OUT/tools/tsud" >"$TOMIESU_OUT/tools/tsud.sha256"
tomiesu_space
