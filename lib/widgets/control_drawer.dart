import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';
import '../keyboard_layouts.dart';

class ControlDrawer extends ConsumerWidget {
  final bool holdLockActive;
  final void Function(bool) onHoldLockChanged;
  final VoidCallback onResetHidState;
  final void Function(KeyboardKind) onKeyboardKindChanged;

  const ControlDrawer({
    super.key,
    required this.holdLockActive,
    required this.onHoldLockChanged,
    required this.onResetHidState,
    required this.onKeyboardKindChanged,
  });

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.black.withValues(alpha: 0.35),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required String title,
    required String subtitle,
    required Widget control,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.black.withValues(alpha: 0.08),
      indent: 16,
      endIndent: 16,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    final settings = ref.watch(settingsProvider);

    return Drawer(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.settings,
                    color: Colors.black.withValues(alpha: 0.8),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader("MOUSE CONTROLS"),

                // Sensitivity Custom Block Slider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Builder(
                    builder: (context) {
                      final double sensDpi = settings.sensitivity;
                      final double sensSliderVal = _dpiToSlider(sensDpi);
                      return BlockSlider(
                        value: sensSliderVal,
                        min: 0.0,
                        max: 1.0,
                        label: "Sensitivity: ${_getDpiLabel(sensDpi)}",
                        valueText: "${sensDpi.toInt()} DPI",
                        onChanged: (val) {
                          final targetDpi = _sliderToDpi(val);
                          ref
                              .read(settingsProvider.notifier)
                              .updateSensitivity(targetDpi);
                        },
                      );
                    },
                  ),
                ),

                // Scroll Sensitivity Custom Block Slider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: BlockSlider(
                    value: settings.scrollSensitivity,
                    min: 1.0,
                    max: 5.0,
                    label: "Scroll Sensitivity",
                    valueText:
                        settings.scrollSensitivity.toStringAsFixed(1),
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateScrollSensitivity(val);
                    },
                  ),
                ),

                // Scroll Momentum Custom Block Slider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: BlockSlider(
                    value: settings.scrollMomentum,
                    min: 0.0,
                    max: 1.0,
                    label: "Scroll Momentum",
                    valueText: settings.scrollMomentum == 0.0
                        ? "Off"
                        : "${(settings.scrollMomentum * 100).toStringAsFixed(0)}%",
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateScrollMomentum(val);
                    },
                  ),
                ),

                _buildDivider(),

                // Mouse Acceleration Toggle
                _buildSettingsRow(
                  title: "Mouse Acceleration",
                  subtitle: "Speeds cursor dynamically with motion",
                  control: Switch.adaptive(
                    activeThumbColor: Colors.black,
                    value: settings.mouseAcceleration,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateMouseAcceleration(val);
                    },
                  ),
                ),

                _buildDivider(),

                // Trackpad Left-Side Configuration
                _buildSettingsRow(
                  title: "Trackpad Left-Side",
                  subtitle: "Positions trackpad on the left",
                  control: Switch.adaptive(
                    activeThumbColor: Colors.black,
                    value: settings.trackpadOnLeft,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateTrackpadOnLeft(val);
                    },
                  ),
                ),

                _buildDivider(),

                // Invert Two Finger Scroll Toggle
                _buildSettingsRow(
                  title: "Invert Scroll",
                  subtitle: "Reverse direction of two-finger swipe",
                  control: Switch.adaptive(
                    activeThumbColor: Colors.black,
                    value: settings.invertTwoFingerScroll,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateInvertTwoFingerScroll(val);
                    },
                  ),
                ),

                _buildDivider(),
                _buildSectionHeader("KEYBOARD SETTINGS"),

                // Keyboard layout style selector
                _buildSettingsRow(
                  title: "Layout Style",
                  subtitle: "Select keyboard key layout",
                  control: SizedBox(
                    width: 130,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: DropdownButton<KeyboardKind>(
                        isExpanded: true,
                        value: settings.keyboardKind,
                        dropdownColor: const Color(0xFFFFFFFF),
                        underline: const SizedBox(),
                        icon: const Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: Colors.black54,
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            onKeyboardKindChanged(val);
                          }
                        },
                        items: KeyboardKind.values.map((kind) {
                          return DropdownMenuItem<KeyboardKind>(
                            value: kind,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(kind.name),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                _buildDivider(),
                _buildSectionHeader("UTILITIES"),

                // HoldLock Toggle (Drawer duplicate)
                _buildSettingsRow(
                  title: "HoldLock Mode",
                  subtitle: "Locks modifier and layout keys",
                  control: Switch.adaptive(
                    activeThumbColor: Colors.black,
                    value: holdLockActive,
                    onChanged: onHoldLockChanged,
                  ),
                ),

                _buildDivider(),

                // Reset HID Profile State Utility
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(
                    CupertinoIcons.refresh_thin,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  title: const Text(
                    "Reset HID Profile State",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    onResetHidState();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Bluetooth Keyboard/Mouse State Reset",
                          style: TextStyle(color: Colors.black),
                        ),
                        backgroundColor: const Color(0xFFF4F4F6),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                _buildDivider(),

                // Reset Application Settings
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(
                    CupertinoIcons.trash_slash,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  title: const Text(
                    "Reset Settings",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: Text(
                    connection.isConnected &&
                            connection.connectedDeviceAddress != null
                        ? "Clear configurations for this device"
                        : "Reset settings to defaults",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                  onTap: () async {
                    final address = connection.connectedDeviceAddress;
                    await ref.read(settingsProvider.notifier).resetSettings();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            connection.isConnected && address != null
                                ? "Cleared settings for this device."
                                : "Reset global settings to defaults.",
                            style: const TextStyle(color: Colors.black),
                          ),
                          backgroundColor: const Color(0xFFF4F4F6),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),

                _buildDivider(),
                _buildSectionHeader("CONNECTION INSTRUCTIONS"),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Text(
                    "1. Open your host device's (PC, Mac, Linux) standard Bluetooth (BT) settings.\n\n"
                    "2. Unpair your phone from the host and unpair the host from your phone.\n\n"
                    "3. Open the connection tab on the app (the bar with the Bluetooth ᛒ icon at its right) and press \"Make Discoverable\".\n\n"
                    "4. Ensure host Bluetooth is ON and look for your phone name in the available devices list.\n\n"
                    "5. Go through the pairing flow. After pairing, you should be connected. On subsequent app opens you can simply connect using the in-app paired devices menu.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BlockSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String valueText;
  final ValueChanged<double> onChanged;

  const BlockSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.valueText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset localPos = box.globalToLocal(details.globalPosition);
        final double percent = (localPos.dx / box.size.width).clamp(0.0, 1.0);
        final double newValue = min + percent * (max - min);
        onChanged(newValue);
      },
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset localPos = box.globalToLocal(details.globalPosition);
        final double percent = (localPos.dx / box.size.width).clamp(0.0, 1.0);
        final double newValue = min + percent * (max - min);
        onChanged(newValue);
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double fillWidth =
                constraints.maxWidth * ((value - min) / (max - min));
            return Stack(
              children: [
                // Filled progress track
                Container(
                  width: fillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(9),
                      bottomLeft: const Radius.circular(9),
                      topRight: Radius.circular(
                        fillWidth >= constraints.maxWidth - 2 ? 9 : 0,
                      ),
                      bottomRight: Radius.circular(
                        fillWidth >= constraints.maxWidth - 2 ? 9 : 0,
                      ),
                    ),
                  ),
                ),
                // Text overlay
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          valueText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double _dpiToSlider(double dpi) {
  final double fraction = ((dpi - 200.0) / 7800.0).clamp(0.0, 1.0);
  return math.pow(fraction, 1.0 / 2.5).toDouble();
}

double _sliderToDpi(double t) {
  final double dpi = 200.0 + math.pow(t.clamp(0.0, 1.0), 2.5) * 7800.0;
  return ((dpi / 50.0).round() * 50.0).toDouble();
}

String _getDpiLabel(double dpi) {
  if (dpi < 600) return "Precision";
  if (dpi < 1200) return "Laptop";
  if (dpi < 2400) return "Desktop";
  if (dpi < 4800) return "4K Monitor";
  return "Couch TV";
}
