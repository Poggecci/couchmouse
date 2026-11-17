import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamepad_state.dart';
import 'connection_dashboard.dart';

/// Shown instead of the trackpad/keyboard while gamepad mode is on.
///
/// Physical controller input is captured and sent to the host natively; this
/// screen only reports status and mirrors the live controller state.
class GamepadModeView extends ConsumerWidget {
  final bool isRegistered;
  final VoidCallback onConnectionTap;
  final VoidCallback onExit;

  const GamepadModeView({
    super.key,
    required this.isRegistered,
    required this.onConnectionTap,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllers = ref.watch(gamepadControllersProvider);
    final snapshot = ref.watch(gamepadLiveStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionDashboard(
            isRegistered: isRegistered,
            onTap: onConnectionTap,
          ),
          _ControllerStatus(controllers: controllers),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: FittedBox(
                fit: BoxFit.contain,
                child: GamepadVisualizer(snapshot: snapshot),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              "Your device's buttons and sticks are sent to the connected "
              "host as a Bluetooth gamepad. Keep CouchMouse open while you play. "
              "If the host doesn't see a controller after an update, unpair "
              "and re-pair this device.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              key: const Key('exitGamepadMode'),
              onPressed: onExit,
              icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
              label: const Text("Exit Gamepad Mode"),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControllerStatus extends StatelessWidget {
  final List<String> controllers;

  const _ControllerStatus({required this.controllers});

  @override
  Widget build(BuildContext context) {
    final found = controllers.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: found ? const Color(0xFFF4F4F6) : const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              found
                  ? CupertinoIcons.game_controller_solid
                  : CupertinoIcons.exclamationmark_triangle,
              size: 20,
              color: found ? Colors.black87 : const Color(0xFFFF9500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                found
                    ? controllers.join(', ')
                    : "No physical controller detected",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed-size (360x124) diagram of the controller; scale it with a FittedBox.
class GamepadVisualizer extends StatelessWidget {
  final GamepadSnapshot snapshot;

  const GamepadVisualizer({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return SizedBox(
      width: 360,
      height: 124,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: L1/L2, left stick, D-pad
          Expanded(
            child: Column(
              children: [
                _ShoulderRow(
                  bumperLabel: 'L1',
                  bumper: s.isPressed(GamepadButtons.l1),
                  triggerLabel: 'L2',
                  trigger: s.leftTrigger,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stick(
                      x: s.leftX,
                      y: s.leftY,
                      pressed: s.isPressed(GamepadButtons.l3),
                      label: 'L3',
                    ),
                    _Dpad(snapshot: s),
                  ],
                ),
              ],
            ),
          ),
          // Centre: Select / Mode / Start
          SizedBox(
            width: 72,
            child: Column(
              children: [
                const SizedBox(height: 44),
                _Pill(label: 'SELECT', on: s.isPressed(GamepadButtons.select)),
                const SizedBox(height: 8),
                _Pill(label: 'HOME', on: s.isPressed(GamepadButtons.mode)),
                const SizedBox(height: 8),
                _Pill(label: 'START', on: s.isPressed(GamepadButtons.start)),
              ],
            ),
          ),
          // Right side: R1/R2, face buttons, right stick
          Expanded(
            child: Column(
              children: [
                _ShoulderRow(
                  bumperLabel: 'R1',
                  bumper: s.isPressed(GamepadButtons.r1),
                  triggerLabel: 'R2',
                  trigger: s.rightTrigger,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FaceButtons(snapshot: s),
                    _Stick(
                      x: s.rightX,
                      y: s.rightY,
                      pressed: s.isPressed(GamepadButtons.r3),
                      label: 'R3',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _onColor = Colors.black;
const _offColor = Color(0xFFE5E5EA);

class _ShoulderRow extends StatelessWidget {
  final String bumperLabel;
  final bool bumper;
  final String triggerLabel;
  final double trigger;

  const _ShoulderRow({
    required this.bumperLabel,
    required this.bumper,
    required this.triggerLabel,
    required this.trigger,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  triggerLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: trigger.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: _offColor,
                    color: _onColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Pill(label: bumperLabel, on: bumper, width: double.infinity),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool on;
  final double width;

  const _Pill({required this.label, required this.on, this.width = 64});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: width,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? _onColor : _offColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: on ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _Stick extends StatelessWidget {
  final double x;
  final double y;
  final bool pressed;
  final String label;

  const _Stick({
    required this.x,
    required this.y,
    required this.pressed,
    required this.label,
  });

  static const double _size = 64;
  static const double _knob = 22;

  @override
  Widget build(BuildContext context) {
    const travel = (_size - _knob) / 2;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _offColor,
        border: Border.all(color: pressed ? _onColor : Colors.transparent),
      ),
      child: Stack(
        children: [
          Positioned(
            left: travel + x.clamp(-1.0, 1.0) * travel,
            top: travel + y.clamp(-1.0, 1.0) * travel,
            child: Container(
              width: _knob,
              height: _knob,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pressed ? _onColor : Colors.black54,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 7,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dpad extends StatelessWidget {
  final GamepadSnapshot snapshot;

  const _Dpad({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    Widget cell(bool on, IconData icon) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? _onColor : _offColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 14, color: on ? Colors.white : Colors.black45),
    );
    const gap = SizedBox(width: 22, height: 22);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            gap,
            cell(snapshot.dpadUp, CupertinoIcons.chevron_up),
            gap,
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cell(snapshot.dpadLeft, CupertinoIcons.chevron_left),
            gap,
            cell(snapshot.dpadRight, CupertinoIcons.chevron_right),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            gap,
            cell(snapshot.dpadDown, CupertinoIcons.chevron_down),
            gap,
          ],
        ),
      ],
    );
  }
}

class _FaceButtons extends StatelessWidget {
  final GamepadSnapshot snapshot;

  const _FaceButtons({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    Widget button(String label, int bit) {
      final on = snapshot.isPressed(bit);
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? _onColor : _offColor,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: on ? Colors.white : Colors.black54,
          ),
        ),
      );
    }

    const gap = SizedBox(width: 22, height: 22);
    // Positional layout: Y top, X left, B right, A bottom (Android/Xbox positions).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [gap, button('Y', GamepadButtons.y), gap],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button('X', GamepadButtons.x),
            gap,
            button('B', GamepadButtons.b),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [gap, button('A', GamepadButtons.a), gap],
        ),
      ],
    );
  }
}
