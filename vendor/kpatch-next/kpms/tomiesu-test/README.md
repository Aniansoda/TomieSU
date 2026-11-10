# TomieSU KPM acceptance fixtures (TEST ONLY)

These minimal fixtures are based on `kpms/demo-hello/hello.c`. They do not
install hooks, alter credentials, hide anything, launch work, or enable
auto-load. Their only effects are explicit kernel log markers and a bounded
control reply. They must never be embedded in boot images or release assets.

| Output file | Kernel module name | Expected result |
| --- | --- | --- |
| `tomiesu-test-echo.kpm` | `tomiesu-test-echo` | init succeeds; ctl0 returns `echo: <literal arguments>`; exit returns 0 |
| `tomiesu-test-no_ctl0.kpm` | `tomiesu-test-no-ctl0` | init succeeds; `has_control=false`; control returns `no_control` |
| `tomiesu-test-init_error.kpm` | `tomiesu-test-init-error` | init returns `-EINVAL`; load fails; successful exit releases the instance |
| `tomiesu-test-exit_error.kpm` | `tomiesu-test-exit-error` | init succeeds; exit returns `-EIO`; code remains resident |

Build from the TomieSU root:

```sh
make -C vendor/kpatch-next/kpms/tomiesu-test \
  TARGET_COMPILE=aarch64-linux-gnu-
make -C vendor/kpatch-next/kpms/tomiesu-test \
  TARGET_COMPILE=aarch64-linux-gnu- host-check
python -m unittest discover -s vendor/kpatch-next/kpms/tomiesu-test -p test_accept_device.py -v
```

The output defaults to `out/test-modules/*.kpm`. A GNU bare-metal prefix can
also be supplied. Files are ELF64 little-endian AArch64 ET_REL objects, and
may only import `printk` and, except for the no-ctl0 fixture,
`compat_copy_to_user`.

The manual acceptance runner, `accept_device.py`, requires an explicitly
selected ADB serial, a remote TomieSU tsud path, and `--execute` to mutate
registry/runtime state. It checks native status first and refuses to load
anything unless the engine is active, configured, supported, and managed by
TomieSU. It imports only these four named fixtures and never enables auto-load.
It also checks each command's JSON envelope and process completion with a
timeout. A hung unload is a failure, never a successful unload.

Successful fixture exits release the runtime instance immediately. Acceptance
checks that the module can reload in the same boot and that removing a loaded
module unloads it and deletes its stored file. Failed initialization also
releases the instance when its exit succeeds. A failed exit preserves the
resident instance and its stored file. The runner leaves only the exit-error
fixture for the test operator to remove after a reboot.

Example after kernel integration and a matching TomieSU tsud are installed:

```sh
python vendor/kpatch-next/kpms/tomiesu-test/accept_device.py \
  --serial SERIAL --tsud /data/local/tmp/tomiesu-tsud \
  --modules-dir out/test-modules --execute \
  --report out/test-modules/device-acceptance.json
```

Without `--execute`, the runner only queries status and does not push/import
files. A blocked device/backend is reported as `blocked`, with zero passed
checks; it is never counted as a device acceptance pass.
