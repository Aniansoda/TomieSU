#!/usr/bin/env bash
# Snapshot completed sources, then build ksuinit -> tsud -> Manager -> signed repack.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
stage="${1:-help}"
tomiesu_log "release-$stage"
tomiesu_space
case "$stage" in
    ksuinit|tsud|manager|manager-tests|manager-lint|manager-assemble|repack) tomiesu_heavy_lock ;;
esac
work="${TOMIESU_RELEASE_SOURCE:-$TOMIESU_CACHE/build/release/source}"
abis="${TOMIESU_ABIS:-arm64-v8a x86_64}"
mkdir -p "$TOMIESU_CACHE/build"
lock_name="$(printf '%s' "$work" | sha256sum | cut -c1-16)"
exec {release_lock}>"$TOMIESU_CACHE/build/release-$lock_name.lock"
flock "$release_lock"
case "$stage" in
    snapshot)
        case "${2:-}" in
            --source-ready) input_state=source-ready ;;
            --preview) input_state=preview ;;
            *) tomiesu_die "Use snapshot --source-ready, or snapshot --preview for provisional compiler feedback." ;;
        esac
        mkdir -p "$(dirname "$work")"
        if [[ ! -d "$work/.git" ]]; then
            tomiesu_run git clone --shared --no-hardlinks "$TOMIESU_ROOT" "$work"
        fi
        tomiesu_run rsync -a --delete --exclude=.git --exclude=out --exclude=target \
            --exclude=build --exclude=.gradle --exclude=.kotlin --exclude=.cxx \
            --exclude=node_modules --exclude=local.properties --exclude=dist \
            "$TOMIESU_ROOT/" "$work/"
        mkdir -p "$TOMIESU_OUT/manifests"
        git -C "$TOMIESU_ROOT" rev-parse HEAD >"$TOMIESU_OUT/manifests/source-head.txt"
        git -C "$TOMIESU_ROOT" diff --binary HEAD >"$TOMIESU_OUT/manifests/source-tracked.patch"
        git -C "$TOMIESU_ROOT" status --short >"$TOMIESU_OUT/manifests/source-status.txt"
        printf '%s\n' "$input_state" >"$work/.tomiesu-input-state"
        printf '%s\n' "$input_state" >"$TOMIESU_OUT/manifests/source-state.txt"
        printf 'Release snapshot: %s\n' "$work"
        ;;
    manager-sync)
        [[ -d "$work/.git" ]] || tomiesu_die "Release snapshot is missing."
        tomiesu_run rsync -a --delete --exclude=build --exclude=.gradle --exclude=.kotlin \
            --exclude=.cxx --exclude=local.properties --exclude=libtsud.so \
            "$TOMIESU_ROOT/manager/" "$work/manager/"
        printf 'Manager preview sources refreshed; real daemon retained.\n'
        ;;
    ksuinit|tsud)
        [[ -d "$work/.git" ]] || tomiesu_die "Release snapshot is missing."
        cd "$work"
        export KSU_PACKAGE_NAME="$TOMIESU_PACKAGE_NAME"
        export LIBCLANG_PATH="${LIBCLANG_PATH:-$(llvm-config --libdir)}"
        for abi in $abis; do
            case "$abi" in
                arm64-v8a) triple=aarch64-linux-android; arch=aarch64 ;;
                x86_64) triple=x86_64-linux-android; arch=x86_64 ;;
                *) tomiesu_die "ABI $abi needs its own pinned build-std toolchain; use arm64-v8a or x86_64." ;;
            esac
            # shellcheck source=/dev/null
            source <(sed 's/\r$//' "$work/.github/scripts/setup-rust-build.sh") "$triple" "$TOMIESU_ANDROID_API"
            if [[ "$stage" == ksuinit ]]; then
                builtins="$("$CLANG_PATH" --print-resource-dir)/lib/linux/libclang_rt.builtins-$arch-android.a"
                [[ -f "$builtins" ]] || tomiesu_die "Missing compiler runtime: $builtins"
                export RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wno-unused-command-line-argument -C link-arg=$builtins"
                tomiesu_run cargo build --locked --package ksuinit --target "$triple" --release
                unset RUSTFLAGS
                mkdir -p "$work/userspace/tsud/bin/$arch" "$TOMIESU_OUT/ksuinit/$abi"
                cp "$CARGO_TARGET_DIR/$triple/release/ksuinit" "$work/userspace/tsud/bin/$arch/ksuinit"
                cp "$CARGO_TARGET_DIR/$triple/release/ksuinit" "$TOMIESU_OUT/ksuinit/$abi/ksuinit"
            else
                [[ -s "$TOMIESU_OUT/ksuinit/$abi/ksuinit" ]] ||
                    tomiesu_die "Build ksuinit before tsud."
                cp "$TOMIESU_OUT/ksuinit/$abi/ksuinit" "$work/userspace/tsud/bin/$arch/ksuinit"
                if [[ "$abi" == arm64-v8a ]]; then
                    for asset in kpimg kptools; do
                        [[ -s "$TOMIESU_OUT/kpatch/aarch64/$asset" ]] || tomiesu_die "Missing source-built $asset."
                        cp "$TOMIESU_OUT/kpatch/aarch64/$asset" "$work/userspace/tsud/bin/aarch64/$asset"
                    done
                fi
                module_dir="$TOMIESU_OUT/$arch"
                for module in "$module_dir/"*_tomiesu.ko "$module_dir/"*_tomiesu-wind.ko "$module_dir/"*_susfs_guard_lkm.ko; do
                    [[ -f "$module" ]] || continue
                    cp "$module" "$work/userspace/tsud/bin/$arch/"
                done
                if [[ "$abi" == arm64-v8a ]]; then
                    [[ -s "$work/userspace/tsud/bin/$arch/android14-6.1_tomiesu.ko" ]] ||
                        tomiesu_die "The priority android14-6.1 root LKM is missing."
                    [[ -s "$work/userspace/tsud/bin/$arch/android14-6.1_susfs_guard_lkm.ko" ]] ||
                        tomiesu_die "The priority android14-6.1 SUSFS LKM is missing."
                    if [[ "${TOMIESU_REQUIRE_FULL_MATRIX:-1}" == 1 ]]; then
                        tomiesu_run python3 "$TOMIESU_ROOT/tools/build-verify-modules.py"
                    else
                        tomiesu_run python3 "$TOMIESU_ROOT/tools/build-verify-modules.py" \
                            --kmi android14-6.1 --kmi android12-5.10
                    fi
                fi
                python3 - "$work/userspace/tsud/bin/$arch" "$TOMIESU_OUT/manifests/embedded-assets-$arch.json" <<'PY'
import hashlib, json, pathlib, sys
directory, output = map(pathlib.Path, sys.argv[1:])
assets = []
for path in sorted(directory.iterdir()):
    if path.is_file() and (path.suffix == ".ko" or path.name in ("ksuinit", "kpimg", "kptools")):
        data = path.read_bytes()
        assets.append({"name": path.name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(assets, indent=2) + "\n")
PY
                # rust-embed compression caches directory assets; force a new derive expansion.
                tomiesu_run cargo clean --package tsud --target "$triple" --release
                tomiesu_run cargo build --locked --package tsud --target "$triple" --release
                mkdir -p "$work/manager/app/src/main/jniLibs/$abi" "$TOMIESU_OUT/tsud/$abi"
                cp "$CARGO_TARGET_DIR/$triple/release/tsud" "$work/manager/app/src/main/jniLibs/$abi/libtsud.so"
                cp "$CARGO_TARGET_DIR/$triple/release/tsud" "$TOMIESU_OUT/tsud/$abi/tsud"
            fi
        done
        ;;
    manager|manager-tests|manager-lint|manager-assemble)
        # AGP 9 与 Gradle 9 要求 Java 21；runner 默认 JAVA_HOME 是 17，
        # 会把 -P compileOptions 的 release 21 顶回去。优先用预装 JDK 21。
        if [[ -n "${JAVA_HOME_21_X64:-}" && -x "${JAVA_HOME_21_X64}/bin/javac" ]]; then
            export JAVA_HOME="$JAVA_HOME_21_X64"
        elif [[ -n "${TOMIESU_JDK_HOME:-}" && -x "${TOMIESU_JDK_HOME}/bin/javac" ]]; then
            export JAVA_HOME="$TOMIESU_JDK_HOME"
        fi
        export PATH="$JAVA_HOME/bin:$PATH"
        tomiesu_log "manager-jdk-21"
        export GRADLE_USER_HOME="${TOMIESU_MANAGER_GRADLE_HOME:-$TOMIESU_CACHE/gradle-build}"
        [[ -d "$work/.git" ]] || tomiesu_die "Release snapshot is missing."
        for abi in $abis; do
            [[ -s "$work/manager/app/src/main/jniLibs/$abi/libtsud.so" ]] ||
                tomiesu_die "Build tsud for $abi before Manager."
        done
        [[ -f "$TOMIESU_OUT/private/certificate.json" ]] || bash "$TOMIESU_ROOT/tools/build-signing.sh"
        signing_init="$TOMIESU_OUT/private/gradle-signing.init.gradle"
        python3 "$TOMIESU_ROOT/tools/signing_config.py" \
            --metadata "$TOMIESU_OUT/private/certificate.json" gradle-init --output "$signing_init"
        cd "$work/manager"
        sed -i 's/\r$//' gradlew
        tomiesu_run bash "$TOMIESU_ROOT/tools/bootstrap-gradle.sh"
        mkdir -p "$GRADLE_USER_HOME"
        gradle_arguments=(
            --no-daemon --console=plain --max-workers=1
            -Pandroid.r8.maxWorkers=1 -Dorg.gradle.parallel=false
            '-Dorg.gradle.jvmargs=-Xmx3072m -XX:MaxMetaspaceSize=512m'
            -Pkotlin.compiler.execution.strategy=in-process
            -Pandroid.injected.testOnly=false
            --init-script "$signing_init"
            "-PKSU_PACKAGE_NAME=$TOMIESU_PACKAGE_NAME" -PKSU_NAME=TomieSU
            "-PTOMIESU_ABIS=$abis"
        )
        case "$stage" in
            manager-tests) manager_tasks=(:app:testReleaseUnitTest) ;;
            manager-lint) manager_tasks=(:app:lintRelease) ;;
            manager-assemble) manager_tasks=(:app:assembleRelease) ;;
            manager) manager_tasks=(:app:testReleaseUnitTest :app:lintRelease :app:assembleRelease) ;;
        esac
        for manager_task in "${manager_tasks[@]}"; do
            tomiesu_run bash ./gradlew "${gradle_arguments[@]}" "$manager_task"
        done
        if [[ "$stage" == manager || "$stage" == manager-assemble ]]; then
            mkdir -p "$TOMIESU_OUT/manager"
            # AGP 9.4 keeps the packaged APK in its artifact directory.
            if [[ -d app/build/intermediates/apk/release ]]; then
                mkdir -p app/build/outputs/apk/release
                find app/build/intermediates/apk/release -maxdepth 1 -name '*.apk' -type f \
                    -exec cp '{}' app/build/outputs/apk/release/ \;
            fi
            find app/build/outputs/apk/release -name '*.apk' -type f -exec cp '{}' "$TOMIESU_OUT/manager/" \;
        fi
        ;;
    repack)
        [[ -d "$work/.git" ]] || tomiesu_die "Release snapshot is missing."
        [[ -f "$work/.tomiesu-input-state" && "$(cat "$work/.tomiesu-input-state")" == source-ready ]] ||
            tomiesu_die "Final repack requires a source-ready snapshot."
        # Repack in a temporary view with the existing helper's expected target layout.
        ln -sfn "$CARGO_TARGET_DIR" "$work/target"
        config="$TOMIESU_OUT/private/repack-config.json"
        python3 "$TOMIESU_ROOT/tools/signing_config.py" \
            --metadata "$TOMIESU_OUT/private/certificate.json" repack-config --output "$config" --abis "$abis"
        apk_name="$(python3 "$TOMIESU_ROOT/tools/signing_config.py" \
            --metadata "$TOMIESU_OUT/private/certificate.json" apk-name)"
        tomiesu_run python3 "$TOMIESU_ROOT/tools/build-repack.py" "$work" repack --config "$config" --out-dir "$TOMIESU_OUT/manager"
        tomiesu_run apksigner verify --verbose --print-certs "$TOMIESU_OUT/manager/$apk_name"
        tomiesu_run zipalign -c -P 16 4 "$TOMIESU_OUT/manager/$apk_name"
        python3 "$TOMIESU_ROOT/tools/build-verify.py" "$TOMIESU_OUT/manager/$apk_name"
        python3 - "$work/version.properties" "$TOMIESU_OUT/manager" "$apk_name" <<'PY'
import pathlib, shutil, sys
version_file, directory = map(pathlib.Path, sys.argv[1:3])
version = dict(line.split("=", 1) for line in version_file.read_text().splitlines() if "=" in line)
name = version["TOMIESU_VERSION_NAME"]
code = version.get("TOMIESU_MANAGER_VERSION_CODE", version["TOMIESU_VERSION_CODE"])
target = directory / f"TomieSU_{name}_{code}.apk"
shutil.copy2(directory / sys.argv[3], target)
print(f"Stable release APK: {target}")
PY
        ;;
    *) tomiesu_die "Usage: $0 {snapshot --source-ready|snapshot --preview|manager-sync|ksuinit|tsud|manager|manager-tests|manager-lint|manager-assemble|repack}. Default ABIs: arm64-v8a x86_64." ;;
esac
tomiesu_space
