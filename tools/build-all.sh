#!/usr/bin/env bash
# Full local/CI build after every source owner has declared the inputs ready.
set -Eeuo pipefail
# shellcheck source=build-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/build-common.sh"
tomiesu_freeze "$@"
[[ "${1:-}" == --source-ready ]] || tomiesu_die "Usage: build-all.sh --source-ready"
tomiesu_log all
tomiesu_run bash "$TOMIESU_ROOT/tools/bootstrap-tomiesu.sh" doctor
tomiesu_run bash "$TOMIESU_ROOT/tools/build-signing.sh"
tomiesu_run bash "$TOMIESU_ROOT/tools/build-freeze-kernel.sh" --with-susfs
tomiesu_run python3 "$TOMIESU_ROOT/tools/build-matrix.py" --jobs 1 --stage-assets
tomiesu_run bash "$TOMIESU_ROOT/tools/build-kpatch.sh"
tomiesu_run bash "$TOMIESU_ROOT/tools/build-rust.sh" android-check
tomiesu_run bash "$TOMIESU_ROOT/tools/build-rust.sh" android-clippy
tomiesu_run bash "$TOMIESU_ROOT/tools/build-rust.sh" format-check
tomiesu_run bash "$TOMIESU_ROOT/tools/build-rust.sh" host-tests
tomiesu_run bash "$TOMIESU_ROOT/tools/build-release.sh" snapshot --source-ready
for stage in ksuinit tsud manager repack; do
    tomiesu_run bash "$TOMIESU_ROOT/tools/build-release.sh" "$stage"
done
tomiesu_space
