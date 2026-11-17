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

## Phase 0 — Tooling & baseline `[x]`
Purpose: make every later phase verifiable in this container.
- [x] Install Flutter SDK (stable) to the scratch area; `flutter pub get`.
- [x] Baseline: run `flutter analyze` and `flutter test` on untouched code;
      record results so later regressions are distinguishable from
      pre-existing issues.
- [x] Install `hid-tools` (PyPI) to decode/validate HID descriptors & reports.
- [x] Set up a throwaway Gradle Kotlin/JVM harness (outside the repo, in
      scratchpad) that compiles the pure-Kotlin gamepad files + JUnit tests.
- Note: Android SDK host (dl.google.com) is blocked → no APK build here.
  Full build happens via GitHub Actions on the fork / on the user's machine.

Exit criteria: baseline results recorded below; harness compiles a hello test.

## Phase 1 — Pure-Kotlin gamepad core `[x]`
No Android imports, so it's unit-testable on the JVM.
- [x] `GamepadDescriptor` bytes (report ID 3) per decision 3/4.
- [x] `GamepadState` (buttons bitmask, hat, 4 stick axes as floats −1..1,
      2 triggers 0..1) + `toReport(): ByteArray` (13 bytes).
- [x] Helpers: float→int16 / uint8 clamping, D-pad booleans → hat value,
      radial deadzone.
- [x] Unit tests: report length, endianness, clamping, hat for all 9
      states, opposing D-pad directions cancel, button bit positions.
- [x] Validate descriptor with `hid-decode`; parse a sample report with
      hid-tools and confirm field values match.

Exit criteria: tests green; hid-tools decodes descriptor with expected usages.

## Phase 2 — Native HID plumbing `[x]`
- [x] Append gamepad collection to `HidDescriptors.COMPOSITE_DESCRIPTOR`.
- [x] SDP subclass `0xC0` → `0xC8` (combo + gamepad).
- [x] `onGetReport` returns a neutral 13-byte report for ID 3.
- [x] `sendGamepadReport(state)` + `releaseGamepad()` (neutral report) wired
      into `onPause`, focus loss, disconnect, `onDestroy`, mirroring
      `releaseKeyboard()`.
- [x] Method-channel: `setGamepadMode(bool)`, `getGamepadMode`.
- [x] Re-validate the full composite descriptor with hid-tools.

Exit criteria: composite descriptor decodes cleanly with 3 collections;
Kotlin harness still green.

## Phase 3 — Native input capture `[x]`
- [x] `GamepadInputMapper` (pure logic, testable): Android keycode →
      button bit; axis readings → state. Handles:
      D-pad as `KEYCODE_DPAD_*` **and** `AXIS_HAT_X/Y`;
      triggers from `AXIS_LTRIGGER/RTRIGGER` **or** `AXIS_BRAKE/GAS` (max);
      digital L2/R2 when the trigger is analog-less;
      right stick from `AXIS_Z/RZ` (fallback `AXIS_RX/RY`).
- [x] `MainActivity` overrides `dispatchKeyEvent` / `dispatchGenericMotionEvent`:
      only when gamepad mode is on, source is GAMEPAD/JOYSTICK/DPAD, and the
      event is from a physical controller; consume it (prevents B→Back).
      Never swallow Volume keys or Home.
- [x] Send only when the encoded report changed; collapse MotionEvent
      batches to the latest sample.
- [x] Unit tests for mapper (pure-logic portion) in the JVM harness.

Exit criteria: mapper tests green; MainActivity type-checks in the
compile-only harness (see Phase 2 log).

## Phase 4 — Flutter UI `[x]`
- [x] Persisted `gamepadMode` setting in `settings_providers.dart`.
- [x] Toggle in `ControlDrawer`; on change call `setGamepadMode` natively.
- [x] Gamepad mode screen: big status (connected host, "controller active"),
      live button/stick indicator fed by a throttled (~30 Hz) native event,
      exit button; keep screen on while active.
- [x] Keyboard/mouse reports are not sent while gamepad mode is active
      (screen replaces trackpad/keyboard).
- [x] Widget/provider tests; `flutter analyze` clean (no new warnings vs
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

### Phase 0 (done)
- Toolchain: Flutter 3.50.0 stable / Dart 3.14.0 (repo lockfile cannot be
  enforced on this SDK; `pub get` re-resolves and also rewrites
  `analysis_options.yaml`. Those two tool-generated diffs are **never
  committed** on this branch).
- **Baseline `flutter analyze`:** 19 issues, all `info • deprecated_member_use`
  (material/cupertino imports deprecated in Flutter 3.47+). No errors/warnings.
- **Baseline `flutter test`:** 11 pass / **6 fail before any change**:
  5 widget tests in `widget_test.dart` (smoke test, swipe-up accessory bar,
  unfocus exits keyboard mode, soft-keyboard dismissal, lifecycle) and
  `device_sorting_test.dart` "Paired devices are sorted…" — all
  `pumpAndSettle timed out`. Not caused by google_fonts runtime fetching
  (probed). Likely Flutter-version related; out of scope. Regression rule:
  no *new* failures and no new analyzer issues beyond deprecations.
- hid-tools decodes the existing descriptor: report 1 = 8 B payload,
  report 2 = 4 B payload (matches code). Script: scratchpad `tools/decode_desc.py`.
- Kotlin JVM harness (Gradle 8.14 / Kotlin 2.0.21, JVM 17 target) runs JUnit
  against selected pure-Kotlin repo files via `-PpureSources=File.kt,...`.
- Maven Central intermittently returns 429 through the proxy; retrying works.

### Phase 1 (done)
- `GamepadReport.kt`: `GamepadButton` bit indices, `Hat`, `GamepadState`,
  `GamepadReport.encode/axisToInt16/triggerToUint8/applyRadialDeadzone`.
- `HidDescriptors.GAMEPAD_COLLECTION` (93 bytes) — *not yet* in the composite.
- hid-tools: descriptor decodes cleanly; report 3 = 13 B payload. Encoded
  sample reports parsed back by hid-tools give exactly the intended values
  (A=Button1, Start=Button12, hat 5, X −32767, Y 16384, Z 8192, Rz 32767,
  Accelerator 51, Brake 255).
- 11 JUnit tests committed in `android/app/src/test/.../GamepadReportTest.kt`
  (+ `testImplementation junit:4.13.2` in `app/build.gradle.kts`); all pass
  in the JVM harness. Not yet run through AGP itself (no Android SDK here).
- Gotcha: Kotlin `roundToInt` rounds .5 toward +∞ (−16383.5 → −16383).

### Phase 2 (done)
- `COMPOSITE_DESCRIPTOR = KEYBOARD_AND_MOUSE + GAMEPAD_COLLECTION`, declared
  last in the object (Kotlin object init order). Runtime bytes (194) dumped
  from the JVM and decoded by hid-tools: IDs 1/2/3 = 8/4/13-byte payloads.
- SDP subclass 0xC0 → 0xC8. `onGetReport(3)` answers with the last sent report.
- `MainActivity`: `gamepadModeEnabled`, `lastGamepadReport`,
  `sendGamepadState()` (send-on-change), `releaseGamepad()` (neutral report,
  mirrors `releaseKeyboard()`), `resetGamepadReport()` on host connect /
  disconnect / unregister / service loss. Released on pause, focus loss,
  disconnectDevice, destroy. Channel: `setGamepadMode{enabled}`, `getGamepadMode`.
- **New verification tool — Android type check:** scratchpad `typecheck/`
  compiles *all* app Kotlin (`compileOnly`) against Robolectric
  `android-all` API 34 + Flutter 3.50 `flutter.jar` + a 2-class
  `androidx.lifecycle` stub (dl.google.com is blocked, maven.google.com
  redirects there). MainActivity compiles cleanly. Not a substitute for an
  AGP build/R8, but catches API/type errors.

### Phase 3 (done)
- `GamepadInputMapper.kt`: keycode → button bit (BUTTON_A..THUMBR, C/Z);
  D-pad from `KEYCODE_DPAD_*` keys OR `AXIS_HAT_X/Y`; right stick Z/RZ with
  RX/RY fallback (`GamepadAxisLayout.from` per device); triggers =
  max(LTRIGGER, BRAKE) / max(RTRIGGER, GAS); digital-only L2/R2 → full
  pull; analog > 0.5 also sets the L2/R2 button bits; device `flat` used as
  radial deadzone (capped 0.5); NaN/∞ → neutral.
- `MainActivity.dispatchKeyEvent` / `dispatchGenericMotionEvent`: only in
  gamepad mode, only physical non-virtual GAMEPAD/JOYSTICK devices, only
  mapped keys (Back/Volume/Home/DPAD_CENTER pass through); events consumed;
  repeats ignored; send-on-change. `releaseGamepad()` also resets the
  mapper so input can't stick after focus loss.
- **Bug found & fixed by tests:** radial deadzone pulled square-gate
  corners onto the unit circle even with zero deadzone ((1,−1) → 0.707).
  Now a zero deadzone passes values through untouched; added a regression test.
- Verification: 27 repo JUnit tests (+2 harness-only) pass; Android jar on
  the test classpath is compile-only, proving tests only use inlined
  constants. Full app Kotlin type-checks against API 34 + flutter.jar.
- Known limitation: input from multiple physical controllers is merged into
  one virtual pad (last axis sample wins). Fine for a handheld; noted.

### Phase 4 (done)
- `lib/gamepad_state.dart`: `GamepadSnapshot` (+ button/hat constants that
  mirror Kotlin), `gamepadModeProvider` (persisted globally as
  `global_gamepad_mode`, not per host), `gamepadLiveStateProvider`,
  `gamepadControllersProvider`.
- `lib/widgets/gamepad_view.dart`: connection card, detected-controller
  card (warns if none), live `GamepadVisualizer` (fixed 360×190 design in a
  FittedBox), re-pair hint, Exit button. Replaces trackpad/keyboard in both
  orientations; keyboard toggle hidden from the app bar.
- Drawer: new GAMEPAD section with a Gamepad Mode switch.
- `main.dart`: syncs mode to native at start and on change; entering the
  mode resets HID state (releases keys/mouse) and leaves keyboard mode.
- Native additions: `onGamepadState` throttled to ~30 Hz via Handler
  (never in the HID hot path), `getGamepadControllers` +
  `onGamepadControllersChanged` (InputDeviceListener; also invalidates the
  axis-layout cache), FLAG_KEEP_SCREEN_ON while gamepad mode is on.
- **Pre-existing bug found & fixed (separate commit 088aebb):**
  `_resetHidState()` never actually released held mouse buttons
  (`_lastButtonsState` zeroed before the send → send skipped).
- Tests: `test/gamepad_mode_test.dart` 10/10 pass (bounded pumps). Full
  suite: 21 pass / 6 fail — the *same* 6 baseline failures, no regressions.
  Analyzer: only the repo-wide material/cupertino deprecation infos (+2 for
  the new file's imports, same convention as every other widget).

