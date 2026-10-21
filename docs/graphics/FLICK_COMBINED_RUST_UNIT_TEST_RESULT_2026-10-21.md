# Fifth Flick native DRM combined package: Rust unit tests completed on Mac Linux VM

Date: 2026-10-21. Git branch: flick-gpu-optimization. The separate package packages.x86_64-linux.flick-qt-egl-qml-tests uses the **same exact pinned Flick commit and ordered patches** as the fifth EGL+DMA-BUF+QML combined production candidate, but enables doCheck=true and cargoTestFlags targeting the Flick Rust binary.

The test-only derivation was built in the dedicated Colima/Rosetta x86_64 Linux Nix 2.28.4 VM on the MacBook with two compilation jobs and a 3 GiB swap safety margin. Sandbox and Rosetta syscall-filter options matched the previously proven build flags. No tablet graphics compositor was stopped or replaced.

## Verified build

| Check | Result |
|---|---|
| Pinned source | upstream Flick 729cdecedad05be3192b21f7d4310eb0ff7ae563 + same native NixOS patches 0001 through 0010, excluding candidate-specific gaps |
| Isolated Nix attribute | packages.x86_64-linux.flick-qt-egl-qml-tests |
| Test-only derivation | /nix/store/wmpvbnr3z1slv23x2s1vvqad3hw9967a-flick-unstable-2026-01-04.drv |
| Rust release compile | 22 min 04 sec |
| Rust release test harness build | 2 min 57 sec |
| Unit tests | 10 passed, 0 failed, 0 ignored, 0 measured, 0 filtered |
| Test duration | 0.12 sec |
| Nix build exit code | 0 |
| Nix test package output | /nix/store/1k1axvnaxkac9sfq8ps5vjx96qwhifxx-flick-unstable-2026-01-04 |
| Nix store integrity verification | PASS |
| Tablet compositor restart | NONE |

## Unit tests

- shell::word_prediction::tests::test_predictions
- shell::word_prediction::tests::test_clear_on_space
- system::battery_tests::discovers_nonstandard_battery_name_and_ignores_mains
- system::battery_tests::ignores_absent_or_capacityless_batteries
- system::battery_tests::selects_multiple_batteries_deterministically
- touch_effects::tests::test_fisheye_creation
- touch_effects::tests::test_ripple_conversion
- touch_effects::tests::test_manager
- viewport::tests::test_coordinate_conversion
- viewport::tests::test_viewport_fit

An exact machine transcript with test names, statuses and exit code is preserved at mvp/native/benchmarks/2026-10-21-flick-combined-rust-unit-tests.txt. The full 2,000+ line Nix release/build log remains preserved in the ignored MacBook .flick-nix-candidate/combined-rust-tests-nix-build.log.

These tests exercise core Rust logic and compile the integration patch stack; they do not instantiate a real DRM/Wayland compositor, test Qt wl_buffer import or measure any CPU gains from the built candidate. Separately, the Lenovo tablet's real Intel Bay Trail GLES2 draw/readback and the VM root/systemd rollback rehearsals all passed without activating Flick.
