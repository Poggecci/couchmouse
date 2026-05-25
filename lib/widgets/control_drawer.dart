import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    final settings = ref.watch(settingsProvider);

    return Drawer(
      backgroundColor: const Color(0xFF13131B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF07070B), Color(0xFF13131B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: Color(0x18FFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x1A00E5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mouse,
                        color: Color(0xFF00E5FF),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "CouchMouse",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Premium Bluetooth Controller",
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "MOUSE CONTROLS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Sensitivity control
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Sensitivity",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "${settings.sensitivity.toStringAsFixed(1)}x",
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF00E5FF),
                            inactiveTrackColor: const Color(0x22FFFFFF),
                            thumbColor: const Color(0xFF0DF5E3),
                            overlayColor: const Color(0x2200E5FF),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: settings.sensitivity,
                            min: 1,
                            max: 30,
                            onChanged: (val) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSensitivity(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Mouse Acceleration Toggle
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    activeThumbColor: const Color(0xFF0DF5E3),
                    title: const Text(
                      "Mouse Acceleration",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Increases cursor speed with rapid swipes",
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    value: settings.mouseAcceleration,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateMouseAcceleration(val);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Trackpad Orientation swap configuration
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    activeThumbColor: const Color(0xFF0DF5E3),
                    title: const Text(
                      "Trackpad Left-Side",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Place trackpad on Left in Landscape mode",
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    value: settings.trackpadOnLeft,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateTrackpadOnLeft(val);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Invert Two Finger Scroll Toggle
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    activeThumbColor: const Color(0xFF0DF5E3),
                    title: const Text(
                      "Invert Two-Finger Scroll",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Invert the scroll direction of two-finger drag",
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    value: settings.invertTwoFingerScroll,
                    onChanged: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateInvertTwoFingerScroll(val);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "KEYBOARD SETTINGS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Keyboard layout style dropdown
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Layout Style",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<KeyboardKind>(
                          initialValue: settings.keyboardKind,
                          dropdownColor: const Color(0xFF13131B),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              onKeyboardKindChanged(val);
                            }
                          },
                          items: KeyboardKind.values.map((kind) {
                            return DropdownMenuItem<KeyboardKind>(
                              value: kind,
                              child: Text(kind.name),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "UTILITIES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // HoldLock Toggle (Drawer duplicate)
                ListTile(
                  leading: Icon(
                    holdLockActive ? Icons.lock : Icons.lock_open,
                    color: holdLockActive
                        ? const Color(0xFFFFCA28)
                        : Colors.white60,
                  ),
                  title: const Text(
                    "HoldLock Mode",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                    activeThumbColor: const Color(0xFFFFCA28),
                    value: holdLockActive,
                    onChanged: onHoldLockChanged,
                  ),
                ),
                // Reset State Utility
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.redAccent),
                  title: const Text(
                    "Reset HID Profile State",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    onResetHidState();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Bluetooth Keyboard/Mouse State Reset"),
                        backgroundColor: Color(0xFF13131B),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                // Reset Application Settings
                ListTile(
                  leading: const Icon(
                    Icons.delete_sweep,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Reset Application Settings",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: Text(
                    connection.isConnected && connection.connectedDeviceAddress != null
                        ? "Reset settings for this device to global defaults"
                        : "Reset global settings to defaults",
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                          ),
                          backgroundColor: const Color(0xFF13131B),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const Divider(color: Color(0x18FFFFFF), height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "CONNECTION INSTRUCTIONS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "1. Open your host device's (PC, Mac, Linux) standard Bluetooth settings.\n"
                    "2. Unpair your phone from the host and unpair the host from your phone.\n"
                    "3. Turn your phone's bluetooth off and on again without leaving the app to bring up the native BT dialog which states your phone is discoverable.\n"
                    "4. Ensure host Bluetooth is ON and look for your phone name in the available devices list.\n"
                    "5. Go through the pairing flow. After pairing, you should be connected. On subsequent app opens you can simply connect using the in-app paired devices menu.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
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
