# Gamepad Mode: Hardware Test Checklist

The report encoding, descriptor and input mapping are covered by JVM unit
tests, and the UI by Flutter tests. Everything below needs a real device
and a real host, because Bluetooth can't be tested in CI.

Record results inline (✅ / ❌ + notes) so regressions are easy to spot.

## 0. Build & install
- [ ] `flutter build apk --release` succeeds (first full Android Gradle
      build of this branch).
- [ ] `cd android && ./gradlew :app:testDebugUnitTest` passes.
- [ ] Install on the handheld (Odin / Thor / Retroid) running Android 9+.

## 1. Pairing
- [ ] **Unpair** CouchMouse on the host if it was paired before, then pair again.
- [ ] Keyboard and trackpad still work exactly as before (regression check).

## 2. Host sees a gamepad
Pick at least one:
- **Linux:** `evtest`. A new "CouchMouse" event device lists
  `BTN_SOUTH…BTN_THUMBR`, `ABS_X/Y/Z/RZ`, `ABS_GAS/BRAKE`, `ABS_HAT0X/Y`.
  `jstest-gtk` also works.
- **Browser (any OS):** https://hardwaretester.com/gamepad or gamepad-tester.com
- **Windows:** `joy.cpl` → CouchMouse → Properties.
- **Steam:** Settings → Controller → shows a generic gamepad.

- [ ] Gamepad is detected by the host.

## 3. Mapping (gamepad mode on, connected)
| Input | Expected on host | Result |
|---|---|---|
| A / B / X / Y | Buttons 1 / 2 / 4 / 5 (Linux: SOUTH / EAST / NORTH / WEST) | |
| L1 / R1 | Buttons 7 / 8 | |
| L2 / R2 (analog) | Brake / Accelerator axes 0→255; button 9 / 10 past half pull | |
| Select / Start / Home | Buttons 11 / 12 / 13 (Home is often taken by the system; note it) | |
| L3 / R3 | Buttons 14 / 15 | |
| D-pad, all 8 directions | Hat switch; centred when released | |
| Left stick | X / Y, full range both ways, centred at rest | |
| Right stick | Z / Rz, full range both ways, centred at rest | |
| On-screen diagram | Mirrors every input above | |

- [ ] **Windows only:** do the triggers show up in `joy.cpl`? (Brake and
      Accelerator usage support on Windows is unverified. If they're missing,
      note it; the fallback is to switch triggers to Rx/Ry.)
- [ ] Stick at rest reads ~0 with no jitter. If it drifts, note the controller.
- [ ] Odin/Thor "Xbox vs Nintendo layout" setting: note which physical
      button sends A in each mode.

## 4. Behaviour
- [ ] B does **not** close the app or navigate back while gamepad mode is on.
- [ ] Back / Home / Volume still work normally.
- [ ] Hold a button, press Home (or pull down the notification shade)
      → the host sees it released (nothing stuck).
- [ ] Turn gamepad mode off while holding a stick → host returns to centre.
- [ ] Disconnect from the host while holding a button → after reconnecting,
      nothing is stuck.
- [ ] Screen stays on in gamepad mode; normal timeout once it's turned off.
- [ ] Unplug / plug in an external controller (if possible) → the
      controller card updates.
- [ ] Gamepad mode is still on after closing and reopening the app.

## 5. Feel
- [ ] Play a fast game for 10+ minutes: no noticeable lag, dropped
      inputs or disconnects. Note the host OS and Bluetooth adapter.
- [ ] (Optional) Rough latency: film the handheld's button and the
      gamepad tester at 240 fps and count frames.
