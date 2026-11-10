#!/usr/bin/env bash
# Shared paths and logging for the TomieSU Linux build tools.
set -Eeuo pipefail

TOMIESU_ROOT="${TOMIESU_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export TOMIESU_ROOT
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$TOMIESU_ROOT" show -s --format=%ct HEAD)}"
export TZ=UTC
export TOMIESU_CACHE="${TOMIESU_CACHE:-/opt/tomiesu}"
export TOMIESU_OUT="${TOMIESU_OUT:-$TOMIESU_ROOT/out}"
export TOMIESU_JOBS="${TOMIESU_JOBS:-2}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$TOMIESU_JOBS}"
export CARGO_INCREMENTAL="${CARGO_INCREMENTAL:-0}"
export TOMIESU_DDK_RELEASE="${TOMIESU_DDK_RELEASE:-20260828}"
export TOMIESU_RUST_VERSION="${TOMIESU_RUST_VERSION:-1.93.1}"
export TOMIESU_NDK_VERSION="${TOMIESU_NDK_VERSION:-29.0.14206865}"
export TOMIESU_ANDROID_API="${TOMIESU_ANDROID_API:-26}"
export TOMIESU_PACKAGE_NAME="${TOMIESU_PACKAGE_NAME:-io.tomiesu.manager}"
export CARGO_HOME="${CARGO_HOME:-$TOMIESU_CACHE/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$TOMIESU_CACHE/rustup}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$TOMIESU_CACHE/cargo-target}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$TOMIESU_CACHE/gradle}"
export ANDROID_HOME="${ANDROID_HOME:-$TOMIESU_CACHE/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$TOMIESU_CACHE/android-user}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$TOMIESU_CACHE/xdg-cache}"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$TOMIESU_NDK_VERSION"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export TMPDIR="${TOMIESU_TMPDIR:-$TOMIESU_CACHE/tmp}"
export DOCKER_HOST="${TOMIESU_DOCKER_HOST:-unix://$TOMIESU_CACHE/docker.sock}"
export DOCKER_CONFIG="${TOMIESU_DOCKER_CONFIG:-$TOMIESU_CACHE/docker-config}"
export PATH="$CARGO_HOME/bin:$ANDROID_HOME/cmdline-tools/23.0/bin:$ANDROID_HOME/build-tools/37.0.0:$PATH"
if [[ -f "$TOMIESU_CACHE/gitconfig" ]]; then
    export GIT_CONFIG_SYSTEM="$TOMIESU_CACHE/gitconfig"
fi

tomiesu_die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

tomiesu_freeze() {
    # Bash reads long scripts incrementally; isolate running jobs from concurrent edits.
    [[ "${TOMIESU_FROZEN_SCRIPT:-}" != "${BASH_SOURCE[1]}" ]] || return 0
    tomiesu_init
    local snapshot original
    original="${BASH_SOURCE[1]}"
    snapshot="$(mktemp -d "$TMPDIR/tool-script.XXXXXX")"
    cp "$original" "$snapshot/$(basename "$original")"
    cp "$(dirname "$original")/build-common.sh" "$snapshot/build-common.sh"
    TOMIESU_FROZEN_SCRIPT="$snapshot/$(basename "$original")"
    export TOMIESU_FROZEN_SCRIPT
    exec bash "$TOMIESU_FROZEN_SCRIPT" "$@"
}

tomiesu_init() {
    local path
    for path in "$TOMIESU_CACHE" "$CARGO_HOME" "$RUSTUP_HOME" "$CARGO_TARGET_DIR" "$GRADLE_USER_HOME"; do
        [[ "$path" != /mnt/d && "$path" != /mnt/d/* ]] ||
            tomiesu_die "Build caches must not use D: ($path)."
    done
    if grep -qi microsoft /proc/sys/kernel/osrelease && [[ "$TOMIESU_CACHE" == /opt/tomiesu ]]; then
        if ! mountpoint -q "$TOMIESU_CACHE"; then
            bash "$TOMIESU_ROOT/tools/bootstrap-tomiesu.sh" cache
        fi
        mountpoint -q "$TOMIESU_CACHE" || tomiesu_die "C: cache volume could not be mounted."
    fi
    mkdir -p "$TOMIESU_OUT/build-logs"
    if [[ ! -e "$TOMIESU_OUT/.gitignore" ]]; then
        printf '*\n' >"$TOMIESU_OUT/.gitignore"
    fi
    mkdir -p "$TOMIESU_CACHE" "$TMPDIR" "$DOCKER_CONFIG"
}

tomiesu_log() {
    tomiesu_init
    local label="${1:?log label required}"
    TOMIESU_LOG="$TOMIESU_OUT/build-logs/$(date -u +%Y%m%dT%H%M%S)-${label}-$$.log"
    export TOMIESU_LOG
    exec > >(tee -a "$TOMIESU_LOG") 2>&1
    printf 'UTC: %s\nLOG: %s\nROOT: %s\nCACHE: %s\n' \
        "$(date -u +%FT%TZ)" "$TOMIESU_LOG" "$TOMIESU_ROOT" "$TOMIESU_CACHE"
    trap 'tomiesu_finish "$?"' EXIT
}

tomiesu_finish() {
    local result="$1"
    trap - EXIT
    printf '\nEXIT: %s UTC: %s\n' "$result" "$(date -u +%FT%TZ)"
    exit "$result"
}

tomiesu_run() {
    printf '\nCOMMAND:'
    printf ' %q' "$@"
    printf '\n'
    "$@"
}

tomiesu_heavy_lock() {
    mkdir -p "$TOMIESU_CACHE/build"
    exec {TOMIESU_HEAVY_LOCK_FD}>"$TOMIESU_CACHE/build/heavy-build.lock"
    printf 'Waiting for the single heavy-build slot (memory-limited WSL).\n'
    flock "$TOMIESU_HEAVY_LOCK_FD"
    printf 'Heavy-build slot acquired; jobs=%s.\n' "$TOMIESU_JOBS"
}

tomiesu_space() {
    df -h "$TOMIESU_CACHE" / /mnt/c /mnt/d 2>/dev/null || df -h "$TOMIESU_CACHE" /
    local available
    available="$(df -Pk "$TOMIESU_CACHE" | awk 'END {print $4}')"
    (( available >= 3 * 1024 * 1024 )) || tomiesu_die "Less than 3 GiB remains in build cache."
    if [[ -d /mnt/c ]]; then
        available="$(df -Pk /mnt/c | awk 'END {print $4}')"
        (( available >= 12 * 1024 * 1024 )) || tomiesu_die "C: has less than 12 GiB available."
    fi
}
