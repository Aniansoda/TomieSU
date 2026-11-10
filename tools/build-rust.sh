#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
stage="${1:-fetch}"
tomiesu_log "rust-$stage"
tomiesu_space
tomiesu_heavy_lock
baseline="$TOMIESU_CACHE/sources/baseline-$(git -C "$TOMIESU_ROOT" rev-parse --short=12 HEAD)"
if [[ ! -d "$baseline/.git" ]]; then
    mkdir -p "$(dirname "$baseline")"
    tomiesu_run git clone --shared --no-hardlinks "$TOMIESU_ROOT" "$baseline"
fi
cd "$baseline"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
case "$stage" in
    fetch)
        tomiesu_run cargo fetch --locked --manifest-path "$baseline/Cargo.toml"
        find "$CARGO_HOME/git/checkouts" -maxdepth 3 -name Cargo.toml -path '*android_bootimg*' -print
        ;;
    baseline-check|baseline-clippy)
        test -x "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
        export LIBCLANG_PATH="${LIBCLANG_PATH:-$(llvm-config --libdir)}"
        # shellcheck source=/dev/null
        source <(sed 's/\r$//' "$baseline/.github/scripts/setup-rust-build.sh") aarch64-linux-android "$TOMIESU_ANDROID_API"
        operation=check
        [[ "$stage" != baseline-clippy ]] || operation=clippy
        tomiesu_run cargo ndk -t arm64-v8a -P "$TOMIESU_ANDROID_API" "$operation" \
            --locked --workspace --all-targets
        ;;
    baseline-btf-test)
        tomiesu_run cargo test --locked --package tsud --target x86_64-unknown-linux-gnu \
            rejects_conflicting_loading_module_values
        ;;
    host-tests)
        cd "$TOMIESU_ROOT"
        tomiesu_run cargo test --locked --package tsud --target x86_64-unknown-linux-gnu image_transaction
        tomiesu_run cargo test --locked --package tsud --target x86_64-unknown-linux-gnu kpm_image
        tomiesu_run cargo test --locked --package tsud --target x86_64-unknown-linux-gnu
        tomiesu_run bash "$TOMIESU_ROOT/tools/test-kpatch-host.sh" --lock-held
        ;;
    format-check)
        cd "$TOMIESU_ROOT"
        tomiesu_run cargo fmt --all -- --check
        ;;
    android-check|android-clippy)
        cd "$TOMIESU_ROOT"
        test -x "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
        export LIBCLANG_PATH="${LIBCLANG_PATH:-$(llvm-config --libdir)}"
        export KSU_PACKAGE_NAME="$TOMIESU_PACKAGE_NAME"
        # shellcheck source=/dev/null
        source <(sed 's/\r$//' "$TOMIESU_ROOT/.github/scripts/setup-rust-build.sh") aarch64-linux-android "$TOMIESU_ANDROID_API"
        operation=check
        lock_arguments=()
        if [[ "$stage" == android-clippy ]]; then
            operation=clippy
            lock_arguments=(--locked)
        fi
        if [[ "$operation" == clippy ]]; then
            tomiesu_run cargo ndk -t arm64-v8a -P "$TOMIESU_ANDROID_API" "$operation" \
                "${lock_arguments[@]}" --workspace --all-targets -- -D warnings
        else
            tomiesu_run cargo ndk -t arm64-v8a -P "$TOMIESU_ANDROID_API" "$operation" \
                "${lock_arguments[@]}" --workspace --all-targets
        fi
        ;;
    *) tomiesu_die "Usage: $0 {fetch|baseline-check|baseline-clippy|baseline-btf-test|host-tests|format-check|android-check|android-clippy}" ;;
esac
