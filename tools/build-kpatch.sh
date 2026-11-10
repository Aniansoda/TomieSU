#!/usr/bin/env bash
# Build kpimg and host/Android kptools from the vendored, fixed KPatch source.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
tomiesu_log kpatch
tomiesu_space
tomiesu_heavy_lock
source_root="${TOMIESU_SOURCE_ROOT:-$TOMIESU_ROOT}"
vendor="$source_root/vendor/kpatch-next"
[[ -f "$vendor/kernel/Makefile" && -f "$vendor/tools/CMakeLists.txt" ]] ||
    tomiesu_die "Vendored KPatch source is not ready."
work="$TOMIESU_CACHE/build/kpatch-next"
mkdir -p "$work" "$TOMIESU_OUT/kpatch/aarch64" "$TOMIESU_OUT/tools"
exec {build_lock}>"$TOMIESU_CACHE/build/kpatch-next.lock"
flock "$build_lock"
tomiesu_run rsync -a --delete --exclude=.git --exclude=target --exclude=build \
    --exclude='*.o' --exclude='*.elf' --exclude=kpimg --exclude=kptools --exclude=kpatch \
    "$vendor/" "$work/source/"
target_compile="${TOMIESU_KPATCH_TARGET_COMPILE:-$TOMIESU_CACHE/toolchains/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf/bin/aarch64-none-elf-}"
if [[ ! -x "${target_compile}gcc" ]]; then
    bash "$TOMIESU_ROOT/tools/bootstrap-kpatch-toolchain.sh"
fi
tomiesu_run make -C "$work/source/kernel" "TARGET_COMPILE=$target_compile" clean
tomiesu_run make -C "$work/source/kernel" -j"$TOMIESU_JOBS" \
    "TARGET_COMPILE=$target_compile"
mkdir -p "$TOMIESU_OUT/manifests"
tomiesu_run python3 "$vendor/tests/check_loader_relocations.py" \
    --object "$work/source/kernel/patch/module/module.o" \
    --readelf "${target_compile}readelf" \
    --report "$TOMIESU_OUT/manifests/kpatch-loader-relocations.json"
tomiesu_run cmake -S "$work/source/tools" -B "$work/host" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
tomiesu_run cmake --build "$work/host" -j"$TOMIESU_JOBS"
tomiesu_run cmake -S "$work/source/tools" -B "$work/android" -G Ninja \
    "-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DANDROID_PLATFORM=android-26 -DANDROID_ABI=arm64-v8a \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=16384
tomiesu_run cmake --build "$work/android" -j"$TOMIESU_JOBS"
cp "$work/source/kernel/kpimg" "$TOMIESU_OUT/kpatch/aarch64/kpimg"
cp "$work/source/kernel/kpimg.elf" "$TOMIESU_OUT/kpatch/aarch64/kpimg.elf"
cp "$work/android/kptools" "$TOMIESU_OUT/kpatch/aarch64/kptools"
cp "$work/host/kptools" "$TOMIESU_OUT/tools/kptools"
tomiesu_run file "$TOMIESU_OUT/kpatch/aarch64/kptools" "$TOMIESU_OUT/kpatch/aarch64/kpimg.elf"
tomiesu_run "$TOMIESU_OUT/tools/kptools" --help
sha256sum "$TOMIESU_OUT/kpatch/aarch64/"* "$TOMIESU_OUT/tools/kptools" \
    >"$TOMIESU_OUT/kpatch/SHA256SUMS"
cat "$TOMIESU_OUT/kpatch/SHA256SUMS"
python3 - "$vendor" "$TOMIESU_OUT/kpatch/source-manifest.json" "$target_compile" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root, output = map(pathlib.Path, sys.argv[1:3])
sources = []
for directory in ("kernel", "tools", "user"):
    for path in sorted((root / directory).rglob("*")):
        if path.is_file() and path.suffix in (".c", ".h", ".S", ".lds", ".txt"):
            sources.append({"path": str(path.relative_to(root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
compiler = subprocess.check_output([sys.argv[3] + "gcc", "--version"], text=True).splitlines()[0]
import os
output.write_text(json.dumps({
    "compiler": compiler, "source_date_epoch": os.environ["SOURCE_DATE_EPOCH"],
    "source_files": sources,
}, indent=2) + "\n")
PY
tomiesu_space
