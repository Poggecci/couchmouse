import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';
import '../gamepad_state.dart';
import '../keyboard_layouts.dart';

class ControlDrawer extends ConsumerStatefulWidget {
  final bool holdLockActive;
  final void Function(bool) onHoldLockChanged;
  final VoidCallback onResetHidState;
  final VoidCallback onShowWalkthrough;
  final VoidCallback onExportSettings;
  final VoidCallback onImportSettings;
  final void Function(KeyboardKind) onKeyboardKindChanged;

  const ControlDrawer({
    super.key,
    required this.holdLockActive,
    required this.onHoldLockChanged,
    required this.onResetHidState,
    required this.onShowWalkthrough,
    required this.onExportSettings,
    required this.onImportSettings,
    required this.onKeyboardKindChanged,
  });

  @override
  ConsumerState<ControlDrawer> createState() => _ControlDrawerState();
}

class _ControlDrawerState extends ConsumerState<ControlDrawer> {
  bool _showAdvanced = false;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.palette.ink.withValues(alpha: 0.35),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control is Switch
              ? SizedBox(
                  height: 30,
                  child: FittedBox(fit: BoxFit.contain, child: control),
                )
              : control,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: context.palette.ink.withValues(alpha: 0.08),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildSlider(BlockSlider slider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: slider,
    );
  }

  void _showSnackBar(String message, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: context.palette.ink)),
        backgroundColor: context.palette.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionStateProvider);
    final settings = ref.watch(settingsProvider);
    final gamepadMode = ref.watch(gamepadModeProvider);
    final gamepadRate = ref.watch(gamepadReportRateProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Drawer(
      width: MediaQuery.sizeOf(context).width,
      shape: const RoundedRectangleBorder(),
      backgroundColor: context.palette.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.settings,
                    color: context.palette.ink.withValues(alpha: 0.8),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.palette.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('closeSettingsButton'),
                    icon: Icon(
                      CupertinoIcons.xmark,
                      color: context.palette.ink,
                    ),
                    tooltip: "Close",
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _buildSectionHeader("MOUSE CONTROLS"),

                  Builder(
                    builder: (context) {
                      final double sensDpi = settings.sensitivity;
                      return _buildSlider(
                        BlockSlider(
                          value: _dpiToSlider(sensDpi),
                          min: 0.0,
                          max: 1.0,
                          label: "Sensitivity: ${_getDpiLabel(sensDpi)}",
                          valueText: "${sensDpi.toInt()} DPI",
                          onChanged: (val) =>
                              notifier.updateSensitivity(_sliderToDpi(val)),
                        ),
                      );
                    },
                  ),

                  _buildSlider(
                    BlockSlider(
                      value: settings.scrollSensitivity,
                      min: 1.0,
                      max: 5.0,
                      label: "Scroll Sensitivity",
                      valueText: settings.scrollSensitivity.toStringAsFixed(1),
                      onChanged: notifier.updateScrollSensitivity,
                    ),
                  ),

                  _buildSlider(
                    BlockSlider(
                      value: settings.scrollMomentum,
                      min: 0.0,
                      max: 1.0,
                      label: "Scroll Momentum",
                      valueText: settings.scrollMomentum == 0.0
                          ? "Off"
                          : "${(settings.scrollMomentum * 100).toStringAsFixed(0)}%",
                      onChanged: notifier.updateScrollMomentum,
                    ),
                  ),

                  _buildDivider(),

                  _buildSettingsRow(
                    title: "Mouse Acceleration",
                    subtitle: "Speeds cursor dynamically with motion",
                    control: Switch.adaptive(
                      activeThumbColor: context.palette.ink,
                      value: settings.mouseAcceleration,
                      onChanged: notifier.updateMouseAcceleration,
                    ),
                  ),

                  _buildDivider(),

                  _buildSettingsRow(
                    title: "Trackball",
                    subtitle: "Flick to keep the cursor gliding",
                    control: Switch.adaptive(
                      activeThumbColor: context.palette.ink,
                      value: settings.trackball,
                      onChanged: notifier.updateTrackball,
                    ),
                  ),
                  if (settings.trackball)
                    _buildSlider(
                      BlockSlider(
                        value: settings.trackballFriction,
                        min: 0.0,
                        max: 1.0,
                        label: "Trackball Friction",
                        valueText:
                            "${(settings.trackballFriction * 100).toStringAsFixed(0)}%",
                        onChanged: notifier.updateTrackballFriction,
                      ),
                    ),

                  _buildDivider(),

                  _buildSettingsRow(
                    title: "Invert Scroll",
                    subtitle: "Reverse direction of two-finger swipe",
                    control: Switch.adaptive(
                      activeThumbColor: context.palette.ink,
                      value: settings.invertTwoFingerScroll,
                      onChanged: notifier.updateInvertTwoFingerScroll,
                    ),
                  ),

                  _buildSectionHeader("LANDSCAPE"),

                  _buildSettingsRow(
                    title: "Trackpad Left-Side",
                    subtitle: "Positions trackpad on the left",
                    control: Switch.adaptive(
                      activeThumbColor: context.palette.ink,
                      value: settings.trackpadOnLeft,
                      onChanged: notifier.updateTrackpadOnLeft,
                    ),
                  ),

                  _buildDivider(),

                  _buildSettingsRow(
                    title: "Keyboard Layout",
                    subtitle: "Select keyboard key layout",
                    control: SizedBox(
                      width: 112,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.palette.ink.withValues(alpha: 0.08),
                          ),
                        ),
                        child: DropdownButton<KeyboardKind>(
                          isExpanded: true,
                          isDense: true,
                          value: settings.keyboardKind,
                          menuWidth: 220,
                          dropdownColor: context.palette.paper,
                          underline: const SizedBox(),
                          icon: Icon(
                            CupertinoIcons.chevron_down,
                            size: 12,
                            color: context.palette.ink.withValues(alpha: 0.54),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: context.palette.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                          onChanged: (val) {
                            if (val != null) {
                              widget.onKeyboardKindChanged(val);
                            }
                          },
                          // Full names don't fit here, so the closed button
                          // shows only the size; the menu lists full names.
                          selectedItemBuilder: (context) => [
                            for (final kind in KeyboardKind.values)
                              Text(RegExp(r'\d+%').firstMatch(kind.name)![0]!),
                          ],
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

                  _buildSettingsRow(
                    title: "HoldLock Mode",
                    subtitle: "Locks modifier and layout keys",
                    control: Switch.adaptive(
                      activeThumbColor: context.palette.ink,
                      value: widget.holdLockActive,
                      onChanged: widget.onHoldLockChanged,
                    ),
                  ),

                  _buildSectionHeader("HELP"),

                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(
                      CupertinoIcons.play_circle,
                      color: context.palette.ink.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    title: Text(
                      "App Walkthrough Tutorial",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.palette.ink,
                      ),
                    ),
                    subtitle: Text(
                      "Guide on connection and gestures",
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.ink.withValues(alpha: 0.4),
                      ),
                    ),
                    onTap: widget.onShowWalkthrough,
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      "Connecting to a computer\n\n"
                      "1. Open your host device's (PC, Mac, Linux) standard Bluetooth (BT) settings.\n\n"
                      "2. Unpair your phone from the host and unpair the host from your phone.\n\n"
                      "3. Open the connection tab on the app (the bar with the Bluetooth ᛒ icon at its right) and press \"Make Discoverable\".\n\n"
                      "4. Ensure host Bluetooth is ON and look for your phone name in the available devices list.\n\n"
                      "5. Go through the pairing flow. After pairing, you should be connected. On subsequent app opens you can simply connect using the in-app paired devices menu.",
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.ink.withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),
                  ),

                  _buildSectionHeader("ADVANCED"),

                  _buildSettingsRow(
                    title: "Advanced Settings",
                    subtitle: "Show extra options",
                    control: Switch.adaptive(
                      key: const Key('advancedSettingsSwitch'),
                      activeThumbColor: context.palette.ink,
                      value: _showAdvanced,
                      onChanged: (val) => setState(() => _showAdvanced = val),
                    ),
                  ),

                  if (_showAdvanced) ...[
                    _buildDivider(),

                    _buildSettingsRow(
                      title: "Rich Typing Mode",
                      subtitle:
                          "Adds a text box for full native system keyboard functionality",
                      control: Switch.adaptive(
                        activeThumbColor: context.palette.ink,
                        value: settings.typingBox,
                        onChanged: notifier.updateTypingBox,
                      ),
                    ),

                    _buildDivider(),

                    _buildSettingsRow(
                      title: "Dark Mode",
                      subtitle: "Follows the system's light or dark theme",
                      control: Switch.adaptive(
                        activeThumbColor: context.palette.ink,
                        value: settings.darkMode,
                        onChanged: notifier.updateDarkMode,
                      ),
                    ),

                    _buildDivider(),

                    _buildSettingsRow(
                      title: "Gamepad Mode",
                      subtitle:
                          "Send this device's physical controls as a gamepad",
                      control: Switch.adaptive(
                        key: const Key('gamepadModeSwitch'),
                        activeThumbColor: context.palette.ink,
                        value: gamepadMode,
                        onChanged: (value) => ref
                            .read(gamepadModeProvider.notifier)
                            .setEnabled(value),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Gamepad Report Rate",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: context.palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Lower it if inputs lag or drop; raise it for smoother sticks",
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.ink.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final hz
                                  in SettingsNotifier.gamepadReportRates)
                                Expanded(
                                  child: _RateOption(
                                    key: Key('gamepadRate_$hz'),
                                    hz: hz,
                                    selected: hz == gamepadRate,
                                    onTap: () => ref
                                        .read(
                                          gamepadReportRateProvider.notifier,
                                        )
                                        .setRate(hz),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    _buildDivider(),

                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
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
                        widget.onResetHidState();
                        Navigator.pop(context);
                        _showSnackBar(
                          "Bluetooth Keyboard/Mouse State Reset",
                          const Duration(seconds: 1),
                        );
                      },
                    ),

                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
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
                          color: context.palette.ink.withValues(alpha: 0.4),
                        ),
                      ),
                      onTap: () async {
                        final address = connection.connectedDeviceAddress;
                        await notifier.resetSettings();
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showSnackBar(
                            connection.isConnected && address != null
                                ? "Cleared settings for this device."
                                : "Reset global settings to defaults.",
                            const Duration(seconds: 2),
                          );
                        }
                      },
                    ),
                    _buildSectionHeader("SETTINGS BACKUP"),

                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Icon(
                        Icons.file_upload_outlined,
                        color: context.palette.ink.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      title: Text(
                        "Export Settings",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.ink,
                        ),
                      ),
                      subtitle: Text(
                        "Save your settings to a backup file",
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.ink.withValues(alpha: 0.4),
                        ),
                      ),
                      onTap: widget.onExportSettings,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Icon(
                        Icons.file_download_outlined,
                        color: context.palette.ink.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      title: Text(
                        "Import Settings",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.ink,
                        ),
                      ),
                      subtitle: Text(
                        "Replace current settings from a backup file",
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.ink.withValues(alpha: 0.4),
                        ),
                      ),
                      onTap: widget.onImportSettings,
                    ),
                  ],
                ],
              ),
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
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.palette.ink.withValues(alpha: 0.06),
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
                    color: context.palette.ink.withValues(alpha: 0.06),
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
                            color: context.palette.ink.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          valueText,
                          style: TextStyle(
                            color: context.palette.ink,
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

class _RateOption extends StatelessWidget {
  final int hz;
  final bool selected;
  final VoidCallback onTap;

  const _RateOption({
    super.key,
    required this.hz,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.palette.ink : context.palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.palette.ink.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          "$hz Hz",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? context.palette.paper
                : context.palette.ink.withValues(alpha: 0.87),
          ),
        ),
      ),
    );
  }
}
