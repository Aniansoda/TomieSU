#!/usr/bin/env bash
# Run from WSL Ubuntu or an Ubuntu CI runner. Downloads and targets stay in the cache.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"

bootstrap_cache() {
    # Serialize mounting: concurrent WSL jobs must never attach the same image twice.
    mkdir -p /run/lock
    exec {cache_lock}>/run/lock/tomiesu-cache.lock
    flock "$cache_lock"
    if grep -qi microsoft /proc/sys/kernel/osrelease && ! mountpoint -q "$TOMIESU_CACHE"; then
        local windows_profile image image_dir
        windows_profile="${TOMIESU_WINDOWS_PROFILE:-$(find /mnt/c/Users -mindepth 2 -maxdepth 2 -type d -name .codex -printf '%h\n' -quit)}"
        [[ -n "$windows_profile" ]] || tomiesu_die "Set TOMIESU_WINDOWS_PROFILE to a C: user profile."
        image_dir="$windows_profile/.cache/tomiesu"
        image="$image_dir/build-cache.ext4"
        mkdir -p "$image_dir" "$TOMIESU_CACHE"
        if [[ ! -e "$image" ]]; then
            (( $(df -Pk /mnt/c | awk 'END {print $4}') >= 32 * 1024 * 1024 )) ||
                tomiesu_die "C: needs at least 32 GiB available before cache creation."
            truncate -s "${TOMIESU_CACHE_VOLUME_SIZE:-64G}" "$image"
            if command -v fsutil.exe >/dev/null; then
                fsutil.exe sparse setflag "$(wslpath -w "$image")"
            fi
            mkfs.ext4 -F -E nodiscard,lazy_itable_init=1,lazy_journal_init=1 -L tomiesu-cache "$image"
        else
            [[ "$(blkid -o value -s TYPE "$image")" == ext4 ]] ||
                tomiesu_die "Existing cache image is not ext4: $image"
        fi
        mount -o loop,noatime "$image" "$TOMIESU_CACHE"
    fi
    tomiesu_init
    mkdir -p "$TOMIESU_CACHE/downloads" "$TOMIESU_CACHE/apt-cache/archives/partial"
    tomiesu_space
    flock -u "$cache_lock"
    exec {cache_lock}>&-
}

bootstrap_system() {
    bootstrap_cache
    tomiesu_run apt-get update
    tomiesu_run env DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dir::Cache=$TOMIESU_CACHE/apt-cache" install -y --no-install-recommends \
        build-essential ca-certificates clang libclang-dev llvm lld \
        cmake ninja-build pkg-config libssl-dev libelf-dev libzstd-dev zlib1g-dev \
        bc bison flex git curl wget unzip xz-utils zip rsync file jq python3 \
        python3-pyelftools python3-yaml shellcheck openjdk-21-jdk-headless \
        gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu kmod
}

bootstrap_rust() {
    bootstrap_cache
    if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
        tomiesu_run curl --fail --location --retry 3 \
            https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init \
            -o "$TOMIESU_CACHE/downloads/rustup-init"
        chmod +x "$TOMIESU_CACHE/downloads/rustup-init"
        tomiesu_run env RUSTUP_INIT_SKIP_PATH_CHECK=yes \
            "$TOMIESU_CACHE/downloads/rustup-init" -y --no-modify-path --profile minimal \
            --default-toolchain "$TOMIESU_RUST_VERSION"
    fi
    tomiesu_run rustup toolchain install "$TOMIESU_RUST_VERSION" --profile minimal --component clippy,rustfmt
    tomiesu_run rustup default "$TOMIESU_RUST_VERSION"
    tomiesu_run rustup target add --toolchain "$TOMIESU_RUST_VERSION" aarch64-linux-android x86_64-linux-android
    if ! cargo ndk --version >/dev/null 2>&1; then
        tomiesu_run cargo install cargo-ndk --version 4.1.2 --locked
    fi
    tomiesu_run rustc --version
    tomiesu_run cargo ndk --version
}

bootstrap_android() {
    bootstrap_cache
    local repository="$TOMIESU_CACHE/downloads/android-repository.xml" url checksum archive
    tomiesu_run curl --fail --location --retry 3 \
        https://dl.google.com/android/repository/repository2-3.xml -o "$repository"
    # Select the pinned command-line-tools package and the Linux archive from Google's manifest.
    read -r url checksum < <(python3 - "$repository" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
for package in root.findall("remotePackage"):
    if package.get("path") != "cmdline-tools;23.0":
        continue
    for archive in package.findall("./archives/archive"):
        if archive.findtext("host-os") == "linux":
            complete = archive.find("complete")
            print(complete.findtext("url"), complete.findtext("checksum"))
            sys.exit(0)
raise SystemExit("Pinned cmdline-tools;23.0 Linux archive not found")
PY
    )
    [[ -n "$url" && -n "$checksum" ]] || tomiesu_die "Cannot resolve pinned Android command-line tools."
    archive="$TOMIESU_CACHE/downloads/$url"
    if [[ ! -f "$archive" ]] || ! printf '%s  %s\n' "$checksum" "$archive" | sha1sum --check --status; then
        tomiesu_run curl --fail --location --retry 3 "https://dl.google.com/android/repository/$url" -o "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | sha1sum --check
    if [[ ! -x "$ANDROID_HOME/cmdline-tools/23.0/bin/sdkmanager" ]]; then
        local extract
        extract="$(mktemp -d "$TMPDIR/cmdline-tools.XXXXXX")"
        tomiesu_run unzip -q "$archive" -d "$extract"
        mkdir -p "$ANDROID_HOME/cmdline-tools"
        mv "$extract/cmdline-tools" "$ANDROID_HOME/cmdline-tools/23.0"
        rmdir "$extract"
    fi
    # sdkmanager consumes finite input; avoid a SIGPIPE from yes with pipefail enabled.
    local licenses="$TOMIESU_CACHE/downloads/android-license-answers.txt"
    awk 'BEGIN {for (i=0; i<200; i++) print "y"}' >"$licenses"
    tomiesu_run sdkmanager --sdk_root="$ANDROID_HOME" --licenses <"$licenses"
    local sdk_log
    sdk_log="$TOMIESU_OUT/build-logs/android-packages-$(date -u +%Y%m%dT%H%M%S).raw.log"
    printf 'Installing pinned Android packages; progress log: %s\n' "$sdk_log"
    if ! sdkmanager --sdk_root="$ANDROID_HOME" \
        "platforms;android-37.0" "build-tools;37.0.0" "platform-tools" \
        "ndk;$TOMIESU_NDK_VERSION" "cmake;3.31.6" >"$sdk_log" 2>&1; then
        tr '\r' '\n' <"$sdk_log" | tail -n 35
        tomiesu_die "Android package installation failed."
    fi
    test -f "$ANDROID_HOME/platforms/android-37.0/android.jar"
    test -x "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
    tomiesu_run "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" --version
    tomiesu_space
}

bootstrap_docker() {
    bootstrap_cache
    if docker info >/dev/null 2>&1; then
        tomiesu_run docker info --format '{{.DockerRootDir}}'
        return
    fi
    command -v dockerd >/dev/null || tomiesu_die "Install Docker Engine first."
    mkdir -p "$TOMIESU_CACHE/docker"
    python3 - "$TOMIESU_CACHE" <<'PY'
import json, pathlib, sys
cache = pathlib.Path(sys.argv[1])
config = {
    "hosts": [f"unix://{cache}/docker.sock"],
    "data-root": str(cache / "docker/data"),
    "exec-root": "/run/tomiesu-docker",
    "pidfile": "/run/tomiesu-docker.pid",
    "bridge": "none",
    "iptables": False,
    "ip6tables": False,
    "storage-driver": "overlay2",
}
(cache / "docker-daemon.json").write_text(json.dumps(config, indent=2) + "\n")
PY
    nohup dockerd --config-file="$TOMIESU_CACHE/docker-daemon.json" \
        >"$TOMIESU_CACHE/docker/daemon.log" 2>&1 </dev/null &
    local attempt
    for ((attempt=0; attempt<30; attempt++)); do
        if docker info >/dev/null 2>&1; then
            tomiesu_run docker info --format '{{.DockerRootDir}}'
            return
        fi
        sleep 1
    done
    tail -n 50 "$TOMIESU_CACHE/docker/daemon.log"
    tomiesu_die "Isolated TomieSU Docker daemon did not start."
}

bootstrap_ddk() {
    bootstrap_docker
    local kmi="${1:-android14-6.1}" image="ghcr.io/ylarod/ddk-min:${1:-android14-6.1}-$TOMIESU_DDK_RELEASE"
    tomiesu_run docker pull "$image"
    mkdir -p "$TOMIESU_OUT/toolchain"
    docker image inspect "$image" --format '{{json .}}' >"$TOMIESU_OUT/toolchain/ddk-$kmi.json"
    # shellcheck disable=SC2016
    tomiesu_run docker run --rm --network host "$image" bash -lc \
        'printf "KDIR=%s\nPATH=%s\nARCH=%s\nCROSS_COMPILE=%s\n" "$KDIR" "$PATH" "$ARCH" "$CROSS_COMPILE"; command -v clang llvm-strip make; du -sh /opt/ddk/*'
    tomiesu_space
}

bootstrap_doctor() {
    bootstrap_cache
    tomiesu_run uname -a
    tomiesu_run java -version
    tomiesu_run rustc --version
    tomiesu_run cargo --version
    tomiesu_run cargo ndk --version
    tomiesu_run rustup target list --installed
    tomiesu_run clang --version
    tomiesu_run sdkmanager --version
    tomiesu_run docker info --format '{{.DockerRootDir}}'
    test -f "$ANDROID_HOME/platforms/android-37.0/android.jar"
    test -x "$ANDROID_HOME/build-tools/37.0.0/apksigner"
    test -x "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"
    mkdir -p "$TOMIESU_OUT/toolchain"
    python3 - "$TOMIESU_OUT/toolchain/ready.json" <<'PY'
import datetime, json, os, pathlib, subprocess, sys
def command(args):
    return subprocess.check_output(args, stderr=subprocess.STDOUT, text=True).strip()
report = {
    "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "rust": command(["rustc", "--version"]),
    "cargo_ndk": command(["cargo", "ndk", "--version"]),
    "rust_targets": command(["rustup", "target", "list", "--installed"]).splitlines(),
    "android_sdk": os.environ["ANDROID_HOME"],
    "android_platform": "android-37.0",
    "android_build_tools": "37.0.0",
    "android_ndk": os.environ["ANDROID_NDK_HOME"],
    "docker_data_root": command(["docker", "info", "--format", "{{.DockerRootDir}}"]),
    "cache": os.environ["TOMIESU_CACHE"],
    "cargo_target": os.environ["CARGO_TARGET_DIR"],
}
pathlib.Path(sys.argv[1]).write_text(json.dumps(report, indent=2) + "\n")
PY
    tomiesu_space
}

stage="${1:-all}"
shift || true
# Mount the C: cache before log initialization creates any cache directories.
bootstrap_cache
tomiesu_freeze "$stage" "$@"
tomiesu_log "bootstrap-$stage"
case "$stage" in
    cache) ;;
    system) bootstrap_system ;;
    rust) bootstrap_rust ;;
    android) bootstrap_android ;;
    docker) bootstrap_docker ;;
    ddk) bootstrap_ddk "$@" ;;
    doctor) bootstrap_doctor ;;
    all)
        bootstrap_system
        bootstrap_rust
        bootstrap_android
        bootstrap_ddk android14-6.1
        bootstrap_doctor
        ;;
    *) tomiesu_die "Usage: $0 {cache|system|rust|android|docker|ddk [KMI]|doctor|all}" ;;
esac
