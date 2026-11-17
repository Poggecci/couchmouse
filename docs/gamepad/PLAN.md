# Gamepad Forwarding — Working Plan

Branch: `feature/gamepad-controller` (remote `upstream` = Poggecci/couchmouse).
Goal: let an Android handheld (AYN Odin / Thor, Retroid, etc.) act as a
Bluetooth gamepad for a host, reusing CouchMouse's existing
`BluetoothHidDevice` registration alongside the keyboard and mouse.

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked

---

## Fixed design decisions (decide once, don't re-litigate)

1. **One composite descriptor, always registered.** Keyboard (ID 1), mouse
   (ID 2) and gamepad (ID 3) are top-level collections of the same
   descriptor. "Gamepad mode" only changes which reports we send. Hosts
   cache the descriptor, so swapping descriptors at runtime would force a
   re-pair each time.
2. **Generic HID gamepad, not Xbox emulation.** `BluetoothHidDeviceAppSdpSettings`
   cannot set VID/PID, so XInput spoofing is impossible without root.
   Primary target hosts: Steam Input (any OS), Linux, Android/Android TV,
   DirectInput/SDL titles on Windows.
3. **Report ID 3 layout (13 bytes):**
   | Bytes | Field | Encoding |
   |---|---|---|
   | 0–1 | 16 buttons | bitfield, little-endian, button N = bit N-1 |
   | 2 | Hat switch (low nibble) + 4 bits padding | 0=N,1=NE,…,7=NW, 8 = centred (null state) |
   | 3–4 | Left stick X | int16 LE, −32767..32767 |
   | 5–6 | Left stick Y | int16 LE |
   | 7–8 | Right stick X (usage Z) | int16 LE |
   | 9–10 | Right stick Y (usage Rz) | int16 LE |
   | 11 | Right trigger (Simulation: Accelerator) | uint8 0..255 |
   | 12 | Left trigger (Simulation: Brake) | uint8 0..255 |

   Axis usages follow the Android / Stadia / 8BitDo-D-input convention
   (X,Y,Z,Rz sticks; Accelerator/Brake triggers), which Linux maps to
   ABS_X/Y/Z/RZ/GAS/BRAKE and Android's `Generic.kl` maps natively.
   Windows DirectInput handling of Accelerator/Brake is **unverified** —
   flagged in the test matrix; fallback is Rx/Ry for triggers.
4. **Button order mirrors Linux `BTN_GAMEPAD` / Android `Generic.kl`**, so
   Linux `hid-input` (button N → `BTN_GAMEPAD + N-1`) and Android hosts get
   correct labels for free:
   1 A(South) · 2 B(East) · 3 C(unused) · 4 X(North) · 5 Y(West) · 6 Z(unused)
   · 7 L1 · 8 R1 · 9 L2(digital) · 10 R2(digital) · 11 Select · 12 Start
   · 13 Mode/Home · 14 L3 · 15 R3 · 16 unused.
5. **Input capture is native** (`dispatchKeyEvent` / `dispatchGenericMotionEvent`
   in `MainActivity`), sending reports directly from Kotlin. Flutter only
   toggles the mode and displays state — no Dart round-trip in the hot path.
6. **Out of scope for this branch:** button remapping UI, rumble/force
   feedback, background (non-foreground) forwarding, on-screen touch
   controls. Listed under "Future" so they're not forgotten.

---

## Phase 0 — Tooling & baseline `[ ]`
Purpose: make every later phase verifiable in this container.
- [ ] Install Flutter SDK (stable) to the scratch area; `flutter pub get`.
- [ ] Baseline: run `flutter analyze` and `flutter test` on untouched code;
      record results so later regressions are distinguishable from
      pre-existing issues.
- [ ] Install `hid-tools` (PyPI) to decode/validate HID descriptors & reports.
- [ ] Set up a throwaway Gradle Kotlin/JVM harness (outside the repo, in
      scratchpad) that compiles the pure-Kotlin gamepad files + JUnit tests.
- Note: Android SDK host (dl.google.com) is blocked → no APK build here.
  Full build happens via GitHub Actions on the fork / on the user's machine.

Exit criteria: baseline results recorded below; harness compiles a hello test.

## Phase 1 — Pure-Kotlin gamepad core `[ ]`
No Android imports, so it's unit-testable on the JVM.
- [ ] `GamepadDescriptor` bytes (report ID 3) per decision 3/4.
- [ ] `GamepadState` (buttons bitmask, hat, 4 stick axes as floats −1..1,
      2 triggers 0..1) + `toReport(): ByteArray` (13 bytes).
- [ ] Helpers: float→int16 / uint8 clamping, D-pad booleans → hat value,
      radial deadzone.
- [ ] Unit tests: report length, endianness, clamping, hat for all 9
      states, opposing D-pad directions cancel, button bit positions.
- [ ] Validate descriptor with `hid-decode`; parse a sample report with
      hid-tools and confirm field values match.

Exit criteria: tests green; hid-tools decodes descriptor with expected usages.

## Phase 2 — Native HID plumbing `[ ]`
- [ ] Append gamepad collection to `HidDescriptors.COMPOSITE_DESCRIPTOR`.
- [ ] SDP subclass `0xC0` → `0xC8` (combo + gamepad).
- [ ] `onGetReport` returns a neutral 13-byte report for ID 3.
- [ ] `sendGamepadReport(state)` + `releaseGamepad()` (neutral report) wired
      into `onPause`, focus loss, disconnect, `onDestroy`, mirroring
      `releaseKeyboard()`.
- [ ] Method-channel: `setGamepadMode(bool)`, `getGamepadMode`.
- [ ] Re-validate the full composite descriptor with hid-tools.

Exit criteria: composite descriptor decodes cleanly with 3 collections;
Kotlin harness still green.

## Phase 3 — Native input capture `[ ]`
- [ ] `GamepadInputMapper` (pure logic, testable): Android keycode →
      button bit; axis readings → state. Handles:
      D-pad as `KEYCODE_DPAD_*` **and** `AXIS_HAT_X/Y`;
      triggers from `AXIS_LTRIGGER/RTRIGGER` **or** `AXIS_BRAKE/GAS` (max);
      digital L2/R2 when the trigger is analog-less;
      right stick from `AXIS_Z/RZ` (fallback `AXIS_RX/RY`).
- [ ] `MainActivity` overrides `dispatchKeyEvent` / `dispatchGenericMotionEvent`:
      only when gamepad mode is on, source is GAMEPAD/JOYSTICK/DPAD, and the
      event is from a physical controller; consume it (prevents B→Back).
      Never swallow Volume keys or Home.
- [ ] Send only when the encoded report changed; collapse MotionEvent
      batches to the latest sample.
- [ ] Unit tests for mapper (pure-logic portion) in the JVM harness.

Exit criteria: mapper tests green; MainActivity changes reviewed line-by-line
(cannot compile Android code here — flag that explicitly).

## Phase 4 — Flutter UI `[ ]`
- [ ] Persisted `gamepadMode` setting in `settings_providers.dart`.
- [ ] Toggle in `ControlDrawer`; on change call `setGamepadMode` natively.
- [ ] Gamepad mode screen: big status (connected host, "controller active"),
      live button/stick indicator fed by a throttled (~30 Hz) native event,
      exit button; keep screen on while active.
- [ ] Keyboard/mouse reports are not sent while gamepad mode is active
      (screen replaces trackpad/keyboard).
- [ ] Widget/provider tests; `flutter analyze` clean (no new warnings vs
      baseline).

Exit criteria: analyze + tests green.

## Phase 5 — Docs & hand-off `[ ]`
- [ ] README: gamepad section, report 3 layout, host compatibility table,
      XInput caveat (use Steam Input / wrapper), "unpair & re-pair after
      updating" note.
- [ ] `docs/gamepad/TESTING.md`: manual test checklist for real hardware
      (Linux `evtest`/`jstest`, gamepad-tester.com, Steam, Windows
      `joy.cpl`, Android TV) incl. the Accelerator/Brake-on-Windows check.
- [ ] Final review of the whole diff; commit per phase.

## Phase 6 — Publish `[!]` blocked on fork
- [ ] User creates fork `xyzz5/couchmouse` (session can't create forks).
- [ ] Attach fork, add as `origin`, push branch.
- [ ] Optionally trigger the release workflow on the fork to get an APK.
- [ ] PR only if the user asks.

---

## Future (not this branch)
Button remapping UI · rumble via output report · on-screen touch gamepad for
phones · per-host trigger-usage preset · foreground service for screen-off use.

---

## Log
(Notes, baseline results and surprises recorded here as phases complete.)
