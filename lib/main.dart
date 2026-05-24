import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Start the application allowing all orientations (fluid auto-rotation support)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CouchMouseApp());
}

class CouchMouseApp extends StatelessWidget {
  const CouchMouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CouchMouse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07070B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF0DF5E3),
          surface: Color(0xFF13131B),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

enum KeyboardKind {
  fullSize,
  compactFullSize,
  tenkeyless,
  seventyFive,
  sixtyFive,
  sixtyPercent,
}

extension KeyboardKindExtension on KeyboardKind {
  String get name {
    switch (this) {
      case KeyboardKind.fullSize:
        return "Full-Size (100%)";
      case KeyboardKind.compactFullSize:
        return "Compact Full-Size (96%)";
      case KeyboardKind.tenkeyless:
        return "Tenkeyless / TKL (80%)";
      case KeyboardKind.seventyFive:
        return "75%";
      case KeyboardKind.sixtyFive:
        return "65%";
      case KeyboardKind.sixtyPercent:
        return "60%";
    }
  }
}

class KeyInfo {
  final String label;
  final String? fnLabel;
  final int scancode;
  final int? fnScancode;
  final double flex;
  final bool isModifier;
  final int modifierMask;
  final bool isSpacer;

  const KeyInfo({
    required this.label,
    this.fnLabel,
    required this.scancode,
    this.fnScancode,
    this.flex = 1.0,
    this.isModifier = false,
    this.modifierMask = 0,
    this.isSpacer = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('com.example.couchmouse/hid');

  // Key mappings for TKL layout
  static List<List<KeyInfo>> _getTklLayout() {
    return [
      // Row 1 (F-row)
      [
        const KeyInfo(label: "Esc", scancode: 0x29, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F1", scancode: 0x3A, flex: 1.0),
        const KeyInfo(label: "F2", scancode: 0x3B, flex: 1.0),
        const KeyInfo(label: "F3", scancode: 0x3C, flex: 1.0),
        const KeyInfo(label: "F4", scancode: 0x3D, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F5", scancode: 0x3E, flex: 1.0),
        const KeyInfo(label: "F6", scancode: 0x3F, flex: 1.0),
        const KeyInfo(label: "F7", scancode: 0x40, flex: 1.0),
        const KeyInfo(label: "F8", scancode: 0x41, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F9", scancode: 0x42, flex: 1.0),
        const KeyInfo(label: "F10", scancode: 0x43, flex: 1.0),
        const KeyInfo(label: "F11", scancode: 0x44, flex: 1.0),
        const KeyInfo(label: "F12", scancode: 0x45, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Prt", scancode: 0x46, flex: 1.0),
        const KeyInfo(label: "ScrL", scancode: 0x47, flex: 1.0),
        const KeyInfo(label: "Pse", scancode: 0x48, flex: 1.0),
      ],
      // Row 2
      [
        const KeyInfo(label: "`", scancode: 0x35, flex: 1.0),
        const KeyInfo(label: "1", scancode: 0x1E, flex: 1.0),
        const KeyInfo(label: "2", scancode: 0x1F, flex: 1.0),
        const KeyInfo(label: "3", scancode: 0x20, flex: 1.0),
        const KeyInfo(label: "4", scancode: 0x21, flex: 1.0),
        const KeyInfo(label: "5", scancode: 0x22, flex: 1.0),
        const KeyInfo(label: "6", scancode: 0x23, flex: 1.0),
        const KeyInfo(label: "7", scancode: 0x24, flex: 1.0),
        const KeyInfo(label: "8", scancode: 0x25, flex: 1.0),
        const KeyInfo(label: "9", scancode: 0x26, flex: 1.0),
        const KeyInfo(label: "0", scancode: 0x27, flex: 1.0),
        const KeyInfo(label: "-", scancode: 0x2D, flex: 1.0),
        const KeyInfo(label: "=", scancode: 0x2E, flex: 1.0),
        const KeyInfo(label: "Backspace", scancode: 0x2A, flex: 2.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Ins", scancode: 0x49, flex: 1.0),
        const KeyInfo(label: "Hm", scancode: 0x4A, flex: 1.0),
        const KeyInfo(label: "PUp", scancode: 0x4B, flex: 1.0),
      ],
      // Row 3
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14, flex: 1.0),
        const KeyInfo(label: "W", scancode: 0x1A, flex: 1.0),
        const KeyInfo(label: "E", scancode: 0x08, flex: 1.0),
        const KeyInfo(label: "R", scancode: 0x15, flex: 1.0),
        const KeyInfo(label: "T", scancode: 0x17, flex: 1.0),
        const KeyInfo(label: "Y", scancode: 0x1C, flex: 1.0),
        const KeyInfo(label: "U", scancode: 0x18, flex: 1.0),
        const KeyInfo(label: "I", scancode: 0x0C, flex: 1.0),
        const KeyInfo(label: "O", scancode: 0x12, flex: 1.0),
        const KeyInfo(label: "P", scancode: 0x13, flex: 1.0),
        const KeyInfo(label: "[", scancode: 0x2F, flex: 1.0),
        const KeyInfo(label: "]", scancode: 0x30, flex: 1.0),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Del", scancode: 0x4C, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
        const KeyInfo(label: "PDn", scancode: 0x4E, flex: 1.0),
      ],
      // Row 4
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04, flex: 1.0),
        const KeyInfo(label: "S", scancode: 0x16, flex: 1.0),
        const KeyInfo(label: "D", scancode: 0x07, flex: 1.0),
        const KeyInfo(label: "F", scancode: 0x09, flex: 1.0),
        const KeyInfo(label: "G", scancode: 0x0A, flex: 1.0),
        const KeyInfo(label: "H", scancode: 0x0B, flex: 1.0),
        const KeyInfo(label: "J", scancode: 0x0D, flex: 1.0),
        const KeyInfo(label: "K", scancode: 0x0E, flex: 1.0),
        const KeyInfo(label: "L", scancode: 0x0F, flex: 1.0),
        const KeyInfo(label: ";", scancode: 0x33, flex: 1.0),
        const KeyInfo(label: "'", scancode: 0x34, flex: 1.0),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 3.6),
      ],
      // Row 5
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.2),
        const KeyInfo(label: "Z", scancode: 0x1D, flex: 1.0),
        const KeyInfo(label: "X", scancode: 0x1B, flex: 1.0),
        const KeyInfo(label: "C", scancode: 0x06, flex: 1.0),
        const KeyInfo(label: "V", scancode: 0x19, flex: 1.0),
        const KeyInfo(label: "B", scancode: 0x05, flex: 1.0),
        const KeyInfo(label: "N", scancode: 0x11, flex: 1.0),
        const KeyInfo(label: "M", scancode: 0x10, flex: 1.0),
        const KeyInfo(label: ",", scancode: 0x36, flex: 1.0),
        const KeyInfo(label: ".", scancode: 0x37, flex: 1.0),
        const KeyInfo(label: "/", scancode: 0x38, flex: 1.0),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 2.8),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
      ],
      // Row 6
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.25),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.25),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.25),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.25),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "App", scancode: 0x65, flex: 1.25),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.5),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  // Key mappings for Full-Size (100%) layout
  static List<List<KeyInfo>> _getFullSizeLayout() {
    return [
      // Row 1 (F-row + NumLock cluster)
      [
        const KeyInfo(label: "Esc", scancode: 0x29, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F1", scancode: 0x3A, flex: 1.0),
        const KeyInfo(label: "F2", scancode: 0x3B, flex: 1.0),
        const KeyInfo(label: "F3", scancode: 0x3C, flex: 1.0),
        const KeyInfo(label: "F4", scancode: 0x3D, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F5", scancode: 0x3E, flex: 1.0),
        const KeyInfo(label: "F6", scancode: 0x3F, flex: 1.0),
        const KeyInfo(label: "F7", scancode: 0x40, flex: 1.0),
        const KeyInfo(label: "F8", scancode: 0x41, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.5),
        const KeyInfo(label: "F9", scancode: 0x42, flex: 1.0),
        const KeyInfo(label: "F10", scancode: 0x43, flex: 1.0),
        const KeyInfo(label: "F11", scancode: 0x44, flex: 1.0),
        const KeyInfo(label: "F12", scancode: 0x45, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Prt", scancode: 0x46, flex: 1.0),
        const KeyInfo(label: "ScrL", scancode: 0x47, flex: 1.0),
        const KeyInfo(label: "Pse", scancode: 0x48, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Num", scancode: 0x53, flex: 1.0),
        const KeyInfo(label: "KP /", scancode: 0x54, flex: 1.0),
        const KeyInfo(label: "KP *", scancode: 0x55, flex: 1.0),
        const KeyInfo(label: "KP -", scancode: 0x56, flex: 1.0),
      ],
      // Row 2 (Number row + Ins/Del + KP 7-9)
      [
        const KeyInfo(label: "`", scancode: 0x35, flex: 1.0),
        const KeyInfo(label: "1", scancode: 0x1E, flex: 1.0),
        const KeyInfo(label: "2", scancode: 0x1F, flex: 1.0),
        const KeyInfo(label: "3", scancode: 0x20, flex: 1.0),
        const KeyInfo(label: "4", scancode: 0x21, flex: 1.0),
        const KeyInfo(label: "5", scancode: 0x22, flex: 1.0),
        const KeyInfo(label: "6", scancode: 0x23, flex: 1.0),
        const KeyInfo(label: "7", scancode: 0x24, flex: 1.0),
        const KeyInfo(label: "8", scancode: 0x25, flex: 1.0),
        const KeyInfo(label: "9", scancode: 0x26, flex: 1.0),
        const KeyInfo(label: "0", scancode: 0x27, flex: 1.0),
        const KeyInfo(label: "-", scancode: 0x2D, flex: 1.0),
        const KeyInfo(label: "=", scancode: 0x2E, flex: 1.0),
        const KeyInfo(label: "Backspace", scancode: 0x2A, flex: 2.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Ins", scancode: 0x49, flex: 1.0),
        const KeyInfo(label: "Hm", scancode: 0x4A, flex: 1.0),
        const KeyInfo(label: "PUp", scancode: 0x4B, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "KP 7", scancode: 0x5F, flex: 1.0),
        const KeyInfo(label: "KP 8", scancode: 0x60, flex: 1.0),
        const KeyInfo(label: "KP 9", scancode: 0x61, flex: 1.0),
        const KeyInfo(label: "KP +", scancode: 0x57, flex: 1.0),
      ],
      // Row 3 (Q-P row + Del/End/PgDn + KP 4-6)
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14, flex: 1.0),
        const KeyInfo(label: "W", scancode: 0x1A, flex: 1.0),
        const KeyInfo(label: "E", scancode: 0x08, flex: 1.0),
        const KeyInfo(label: "R", scancode: 0x15, flex: 1.0),
        const KeyInfo(label: "T", scancode: 0x17, flex: 1.0),
        const KeyInfo(label: "Y", scancode: 0x1C, flex: 1.0),
        const KeyInfo(label: "U", scancode: 0x18, flex: 1.0),
        const KeyInfo(label: "I", scancode: 0x0C, flex: 1.0),
        const KeyInfo(label: "O", scancode: 0x12, flex: 1.0),
        const KeyInfo(label: "P", scancode: 0x13, flex: 1.0),
        const KeyInfo(label: "[", scancode: 0x2F, flex: 1.0),
        const KeyInfo(label: "]", scancode: 0x30, flex: 1.0),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "Del", scancode: 0x4C, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
        const KeyInfo(label: "PDn", scancode: 0x4E, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "KP 4", scancode: 0x5C, flex: 1.0),
        const KeyInfo(label: "KP 5", scancode: 0x5D, flex: 1.0),
        const KeyInfo(label: "KP 6", scancode: 0x5E, flex: 1.0),
        const KeyInfo(label: "KP +", scancode: 0x57, flex: 1.0),
      ],
      // Row 4 (A-Enter row + KP 1-3)
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04, flex: 1.0),
        const KeyInfo(label: "S", scancode: 0x16, flex: 1.0),
        const KeyInfo(label: "D", scancode: 0x07, flex: 1.0),
        const KeyInfo(label: "F", scancode: 0x09, flex: 1.0),
        const KeyInfo(label: "G", scancode: 0x0A, flex: 1.0),
        const KeyInfo(label: "H", scancode: 0x0B, flex: 1.0),
        const KeyInfo(label: "J", scancode: 0x0D, flex: 1.0),
        const KeyInfo(label: "K", scancode: 0x0E, flex: 1.0),
        const KeyInfo(label: "L", scancode: 0x0F, flex: 1.0),
        const KeyInfo(label: ";", scancode: 0x33, flex: 1.0),
        const KeyInfo(label: "'", scancode: 0x34, flex: 1.0),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 3.6),
        const KeyInfo(label: "KP 1", scancode: 0x59, flex: 1.0),
        const KeyInfo(label: "KP 2", scancode: 0x5A, flex: 1.0),
        const KeyInfo(label: "KP 3", scancode: 0x5B, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
      // Row 5 (Shift + arrows + KP 0)
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.2),
        const KeyInfo(label: "Z", scancode: 0x1D, flex: 1.0),
        const KeyInfo(label: "X", scancode: 0x1B, flex: 1.0),
        const KeyInfo(label: "C", scancode: 0x06, flex: 1.0),
        const KeyInfo(label: "V", scancode: 0x19, flex: 1.0),
        const KeyInfo(label: "B", scancode: 0x05, flex: 1.0),
        const KeyInfo(label: "N", scancode: 0x11, flex: 1.0),
        const KeyInfo(label: "M", scancode: 0x10, flex: 1.0),
        const KeyInfo(label: ",", scancode: 0x36, flex: 1.0),
        const KeyInfo(label: ".", scancode: 0x37, flex: 1.0),
        const KeyInfo(label: "/", scancode: 0x38, flex: 1.0),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 2.8),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
      // Row 6 (Ctrl/Alt/Space + arrows)
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.25),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.25),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.25),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.25),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "App", scancode: 0x65, flex: 1.25),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.5),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 4.3),
      ],
    ];
  }

  // Key mappings for Compact Full-Size (96%) layout
  static List<List<KeyInfo>> _getCompactFullSizeLayout() {
    return [
      // Row 1 (F-row + NumLock cluster)
      [
        const KeyInfo(label: "Esc", scancode: 0x29, flex: 1.0),
        const KeyInfo(label: "F1", scancode: 0x3A, flex: 1.0),
        const KeyInfo(label: "F2", scancode: 0x3B, flex: 1.0),
        const KeyInfo(label: "F3", scancode: 0x3C, flex: 1.0),
        const KeyInfo(label: "F4", scancode: 0x3D, flex: 1.0),
        const KeyInfo(label: "F5", scancode: 0x3E, flex: 1.0),
        const KeyInfo(label: "F6", scancode: 0x3F, flex: 1.0),
        const KeyInfo(label: "F7", scancode: 0x40, flex: 1.0),
        const KeyInfo(label: "F8", scancode: 0x41, flex: 1.0),
        const KeyInfo(label: "F9", scancode: 0x42, flex: 1.0),
        const KeyInfo(label: "F10", scancode: 0x43, flex: 1.0),
        const KeyInfo(label: "F11", scancode: 0x44, flex: 1.0),
        const KeyInfo(label: "F12", scancode: 0x45, flex: 1.0),
        const KeyInfo(label: "Prt", scancode: 0x46, flex: 1.0),
        const KeyInfo(label: "Ins", scancode: 0x49, flex: 1.0),
        const KeyInfo(label: "Del", scancode: 0x4C, flex: 1.0),
        const KeyInfo(label: "Num", scancode: 0x53, flex: 1.0),
        const KeyInfo(label: "KP /", scancode: 0x54, flex: 1.0),
        const KeyInfo(label: "KP *", scancode: 0x55, flex: 1.0),
        const KeyInfo(label: "KP -", scancode: 0x56, flex: 1.0),
      ],
      // Row 2 (Number row + Home + KP 7-9 + KP +)
      [
        const KeyInfo(label: "`", scancode: 0x35, flex: 1.0),
        const KeyInfo(label: "1", scancode: 0x1E, flex: 1.0),
        const KeyInfo(label: "2", scancode: 0x1F, flex: 1.0),
        const KeyInfo(label: "3", scancode: 0x20, flex: 1.0),
        const KeyInfo(label: "4", scancode: 0x21, flex: 1.0),
        const KeyInfo(label: "5", scancode: 0x22, flex: 1.0),
        const KeyInfo(label: "6", scancode: 0x23, flex: 1.0),
        const KeyInfo(label: "7", scancode: 0x24, flex: 1.0),
        const KeyInfo(label: "8", scancode: 0x25, flex: 1.0),
        const KeyInfo(label: "9", scancode: 0x26, flex: 1.0),
        const KeyInfo(label: "0", scancode: 0x27, flex: 1.0),
        const KeyInfo(label: "-", scancode: 0x2D, flex: 1.0),
        const KeyInfo(label: "=", scancode: 0x2E, flex: 1.0),
        const KeyInfo(label: "Backspace", scancode: 0x2A, flex: 2.0),
        const KeyInfo(label: "Hm", scancode: 0x4A, flex: 1.0),
        const KeyInfo(label: "KP 7", scancode: 0x5F, flex: 1.0),
        const KeyInfo(label: "KP 8", scancode: 0x60, flex: 1.0),
        const KeyInfo(label: "KP 9", scancode: 0x61, flex: 1.0),
        const KeyInfo(label: "KP +", scancode: 0x57, flex: 1.0),
      ],
      // Row 3 (Q-P row + PgUp + KP 4-6 + KP +)
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14, flex: 1.0),
        const KeyInfo(label: "W", scancode: 0x1A, flex: 1.0),
        const KeyInfo(label: "E", scancode: 0x08, flex: 1.0),
        const KeyInfo(label: "R", scancode: 0x15, flex: 1.0),
        const KeyInfo(label: "T", scancode: 0x17, flex: 1.0),
        const KeyInfo(label: "Y", scancode: 0x1C, flex: 1.0),
        const KeyInfo(label: "U", scancode: 0x18, flex: 1.0),
        const KeyInfo(label: "I", scancode: 0x0C, flex: 1.0),
        const KeyInfo(label: "O", scancode: 0x12, flex: 1.0),
        const KeyInfo(label: "P", scancode: 0x13, flex: 1.0),
        const KeyInfo(label: "[", scancode: 0x2F, flex: 1.0),
        const KeyInfo(label: "]", scancode: 0x30, flex: 1.0),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
        const KeyInfo(label: "PUp", scancode: 0x4B, flex: 1.0),
        const KeyInfo(label: "KP 4", scancode: 0x5C, flex: 1.0),
        const KeyInfo(label: "KP 5", scancode: 0x5D, flex: 1.0),
        const KeyInfo(label: "KP 6", scancode: 0x5E, flex: 1.0),
        const KeyInfo(label: "KP +", scancode: 0x57, flex: 1.0),
      ],
      // Row 4 (A-Enter row + PgDn + KP 1-3 + KP Ent)
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04, flex: 1.0),
        const KeyInfo(label: "S", scancode: 0x16, flex: 1.0),
        const KeyInfo(label: "D", scancode: 0x07, flex: 1.0),
        const KeyInfo(label: "F", scancode: 0x09, flex: 1.0),
        const KeyInfo(label: "G", scancode: 0x0A, flex: 1.0),
        const KeyInfo(label: "H", scancode: 0x0B, flex: 1.0),
        const KeyInfo(label: "J", scancode: 0x0D, flex: 1.0),
        const KeyInfo(label: "K", scancode: 0x0E, flex: 1.0),
        const KeyInfo(label: "L", scancode: 0x0F, flex: 1.0),
        const KeyInfo(label: ";", scancode: 0x33, flex: 1.0),
        const KeyInfo(label: "'", scancode: 0x34, flex: 1.0),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
        const KeyInfo(label: "PDn", scancode: 0x4E, flex: 1.0),
        const KeyInfo(label: "KP 1", scancode: 0x59, flex: 1.0),
        const KeyInfo(label: "KP 2", scancode: 0x5A, flex: 1.0),
        const KeyInfo(label: "KP 3", scancode: 0x5B, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
      // Row 5 (Shift + Up + End + KP 0 + KP .)
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.0),
        const KeyInfo(label: "Z", scancode: 0x1D, flex: 1.0),
        const KeyInfo(label: "X", scancode: 0x1B, flex: 1.0),
        const KeyInfo(label: "C", scancode: 0x06, flex: 1.0),
        const KeyInfo(label: "V", scancode: 0x19, flex: 1.0),
        const KeyInfo(label: "B", scancode: 0x05, flex: 1.0),
        const KeyInfo(label: "N", scancode: 0x11, flex: 1.0),
        const KeyInfo(label: "M", scancode: 0x10, flex: 1.0),
        const KeyInfo(label: ",", scancode: 0x36, flex: 1.0),
        const KeyInfo(label: ".", scancode: 0x37, flex: 1.0),
        const KeyInfo(label: "/", scancode: 0x38, flex: 1.0),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 3.0),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
      ],
      // Row 6 (Spacebar row + arrows + KP 0 / KP Ent)
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.25),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.25),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.25),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.25),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.25),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
    ];
  }

  // Key mappings for 75% layout
  static List<List<KeyInfo>> _getSeventyFiveLayout() {
    return [
      // Row 1 (F-row + PrtSc + Ins + Del)
      [
        const KeyInfo(label: "Esc", scancode: 0x29, flex: 1.0),
        const KeyInfo(label: "F1", scancode: 0x3A, flex: 1.0),
        const KeyInfo(label: "F2", scancode: 0x3B, flex: 1.0),
        const KeyInfo(label: "F3", scancode: 0x3C, flex: 1.0),
        const KeyInfo(label: "F4", scancode: 0x3D, flex: 1.0),
        const KeyInfo(label: "F5", scancode: 0x3E, flex: 1.0),
        const KeyInfo(label: "F6", scancode: 0x3F, flex: 1.0),
        const KeyInfo(label: "F7", scancode: 0x40, flex: 1.0),
        const KeyInfo(label: "F8", scancode: 0x41, flex: 1.0),
        const KeyInfo(label: "F9", scancode: 0x42, flex: 1.0),
        const KeyInfo(label: "F10", scancode: 0x43, flex: 1.0),
        const KeyInfo(label: "F11", scancode: 0x44, flex: 1.0),
        const KeyInfo(label: "F12", scancode: 0x45, flex: 1.0),
        const KeyInfo(label: "Prt", scancode: 0x46, flex: 1.0),
        const KeyInfo(label: "Ins", scancode: 0x49, flex: 1.0),
        const KeyInfo(label: "Del", scancode: 0x4C, flex: 1.0),
      ],
      // Row 2 (Number row + Home)
      [
        const KeyInfo(label: "`", scancode: 0x35, flex: 1.0),
        const KeyInfo(label: "1", scancode: 0x1E, flex: 1.0),
        const KeyInfo(label: "2", scancode: 0x1F, flex: 1.0),
        const KeyInfo(label: "3", scancode: 0x20, flex: 1.0),
        const KeyInfo(label: "4", scancode: 0x21, flex: 1.0),
        const KeyInfo(label: "5", scancode: 0x22, flex: 1.0),
        const KeyInfo(label: "6", scancode: 0x23, flex: 1.0),
        const KeyInfo(label: "7", scancode: 0x24, flex: 1.0),
        const KeyInfo(label: "8", scancode: 0x25, flex: 1.0),
        const KeyInfo(label: "9", scancode: 0x26, flex: 1.0),
        const KeyInfo(label: "0", scancode: 0x27, flex: 1.0),
        const KeyInfo(label: "-", scancode: 0x2D, flex: 1.0),
        const KeyInfo(label: "=", scancode: 0x2E, flex: 1.0),
        const KeyInfo(label: "Backspace", scancode: 0x2A, flex: 2.0),
        const KeyInfo(label: "Hm", scancode: 0x4A, flex: 1.0),
      ],
      // Row 3 (Q-P row + PgUp)
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14, flex: 1.0),
        const KeyInfo(label: "W", scancode: 0x1A, flex: 1.0),
        const KeyInfo(label: "E", scancode: 0x08, flex: 1.0),
        const KeyInfo(label: "R", scancode: 0x15, flex: 1.0),
        const KeyInfo(label: "T", scancode: 0x17, flex: 1.0),
        const KeyInfo(label: "Y", scancode: 0x1C, flex: 1.0),
        const KeyInfo(label: "U", scancode: 0x18, flex: 1.0),
        const KeyInfo(label: "I", scancode: 0x0C, flex: 1.0),
        const KeyInfo(label: "O", scancode: 0x12, flex: 1.0),
        const KeyInfo(label: "P", scancode: 0x13, flex: 1.0),
        const KeyInfo(label: "[", scancode: 0x2F, flex: 1.0),
        const KeyInfo(label: "]", scancode: 0x30, flex: 1.0),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
        const KeyInfo(label: "PUp", scancode: 0x4B, flex: 1.0),
      ],
      // Row 4 (A-Enter row + PgDn)
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04, flex: 1.0),
        const KeyInfo(label: "S", scancode: 0x16, flex: 1.0),
        const KeyInfo(label: "D", scancode: 0x07, flex: 1.0),
        const KeyInfo(label: "F", scancode: 0x09, flex: 1.0),
        const KeyInfo(label: "G", scancode: 0x0A, flex: 1.0),
        const KeyInfo(label: "H", scancode: 0x0B, flex: 1.0),
        const KeyInfo(label: "J", scancode: 0x0D, flex: 1.0),
        const KeyInfo(label: "K", scancode: 0x0E, flex: 1.0),
        const KeyInfo(label: "L", scancode: 0x0F, flex: 1.0),
        const KeyInfo(label: ";", scancode: 0x33, flex: 1.0),
        const KeyInfo(label: "'", scancode: 0x34, flex: 1.0),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
        const KeyInfo(label: "PDn", scancode: 0x4E, flex: 1.0),
      ],
      // Row 5 (Shift + Up + End)
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.0),
        const KeyInfo(label: "Z", scancode: 0x1D, flex: 1.0),
        const KeyInfo(label: "X", scancode: 0x1B, flex: 1.0),
        const KeyInfo(label: "C", scancode: 0x06, flex: 1.0),
        const KeyInfo(label: "V", scancode: 0x19, flex: 1.0),
        const KeyInfo(label: "B", scancode: 0x05, flex: 1.0),
        const KeyInfo(label: "N", scancode: 0x11, flex: 1.0),
        const KeyInfo(label: "M", scancode: 0x10, flex: 1.0),
        const KeyInfo(label: ",", scancode: 0x36, flex: 1.0),
        const KeyInfo(label: ".", scancode: 0x37, flex: 1.0),
        const KeyInfo(label: "/", scancode: 0x38, flex: 1.0),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 2.0),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
      ],
      // Row 6 (Spacebar row + Left/Down/Right)
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.25),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.25),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.25),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.25),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.25),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  // Key mappings for 65% layout
  static List<List<KeyInfo>> _getSixtyFiveLayout() {
    return [
      // Row 1 (Number row + Del)
      [
        const KeyInfo(label: "`", scancode: 0x35, flex: 1.0),
        const KeyInfo(label: "1", scancode: 0x1E, flex: 1.0),
        const KeyInfo(label: "2", scancode: 0x1F, flex: 1.0),
        const KeyInfo(label: "3", scancode: 0x20, flex: 1.0),
        const KeyInfo(label: "4", scancode: 0x21, flex: 1.0),
        const KeyInfo(label: "5", scancode: 0x22, flex: 1.0),
        const KeyInfo(label: "6", scancode: 0x23, flex: 1.0),
        const KeyInfo(label: "7", scancode: 0x24, flex: 1.0),
        const KeyInfo(label: "8", scancode: 0x25, flex: 1.0),
        const KeyInfo(label: "9", scancode: 0x26, flex: 1.0),
        const KeyInfo(label: "0", scancode: 0x27, flex: 1.0),
        const KeyInfo(label: "-", scancode: 0x2D, flex: 1.0),
        const KeyInfo(label: "=", scancode: 0x2E, flex: 1.0),
        const KeyInfo(label: "Backspace", scancode: 0x2A, flex: 2.0),
        const KeyInfo(label: "Del", scancode: 0x4C, flex: 1.0),
      ],
      // Row 2 (Q-P row + PgUp)
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14, flex: 1.0),
        const KeyInfo(label: "W", scancode: 0x1A, flex: 1.0),
        const KeyInfo(label: "E", scancode: 0x08, flex: 1.0),
        const KeyInfo(label: "R", scancode: 0x15, flex: 1.0),
        const KeyInfo(label: "T", scancode: 0x17, flex: 1.0),
        const KeyInfo(label: "Y", scancode: 0x1C, flex: 1.0),
        const KeyInfo(label: "U", scancode: 0x18, flex: 1.0),
        const KeyInfo(label: "I", scancode: 0x0C, flex: 1.0),
        const KeyInfo(label: "O", scancode: 0x12, flex: 1.0),
        const KeyInfo(label: "P", scancode: 0x13, flex: 1.0),
        const KeyInfo(label: "[", scancode: 0x2F, flex: 1.0),
        const KeyInfo(label: "]", scancode: 0x30, flex: 1.0),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
        const KeyInfo(label: "PUp", scancode: 0x4B, flex: 1.0),
      ],
      // Row 3 (A-Enter row + PgDn)
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04, flex: 1.0),
        const KeyInfo(label: "S", scancode: 0x16, flex: 1.0),
        const KeyInfo(label: "D", scancode: 0x07, flex: 1.0),
        const KeyInfo(label: "F", scancode: 0x09, flex: 1.0),
        const KeyInfo(label: "G", scancode: 0x0A, flex: 1.0),
        const KeyInfo(label: "H", scancode: 0x0B, flex: 1.0),
        const KeyInfo(label: "J", scancode: 0x0D, flex: 1.0),
        const KeyInfo(label: "K", scancode: 0x0E, flex: 1.0),
        const KeyInfo(label: "L", scancode: 0x0F, flex: 1.0),
        const KeyInfo(label: ";", scancode: 0x33, flex: 1.0),
        const KeyInfo(label: "'", scancode: 0x34, flex: 1.0),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
        const KeyInfo(label: "PDn", scancode: 0x4E, flex: 1.0),
      ],
      // Row 4 (Shift + Up + End)
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.0),
        const KeyInfo(label: "Z", scancode: 0x1D, flex: 1.0),
        const KeyInfo(label: "X", scancode: 0x1B, flex: 1.0),
        const KeyInfo(label: "C", scancode: 0x06, flex: 1.0),
        const KeyInfo(label: "V", scancode: 0x19, flex: 1.0),
        const KeyInfo(label: "B", scancode: 0x05, flex: 1.0),
        const KeyInfo(label: "N", scancode: 0x11, flex: 1.0),
        const KeyInfo(label: "M", scancode: 0x10, flex: 1.0),
        const KeyInfo(label: ",", scancode: 0x36, flex: 1.0),
        const KeyInfo(label: ".", scancode: 0x37, flex: 1.0),
        const KeyInfo(label: "/", scancode: 0x38, flex: 1.0),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 2.0),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
      ],
      // Row 5 (Spacebar row + Left/Down/Right)
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.25),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.25),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.25),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.25),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.25),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  // Key mappings for 60% layout
  static List<List<KeyInfo>> _getSixtyPercentLayout() {
    return [
      // Row 1
      [
        const KeyInfo(label: "`", fnLabel: "Esc", scancode: 0x35, fnScancode: 0x29, flex: 1.2),
        const KeyInfo(label: "1", fnLabel: "F1", scancode: 0x1E, fnScancode: 0x3A),
        const KeyInfo(label: "2", fnLabel: "F2", scancode: 0x1F, fnScancode: 0x3B),
        const KeyInfo(label: "3", fnLabel: "F3", scancode: 0x20, fnScancode: 0x3C),
        const KeyInfo(label: "4", fnLabel: "F4", scancode: 0x21, fnScancode: 0x3D),
        const KeyInfo(label: "5", fnLabel: "F5", scancode: 0x22, fnScancode: 0x3E),
        const KeyInfo(label: "6", fnLabel: "F6", scancode: 0x23, fnScancode: 0x3F),
        const KeyInfo(label: "7", fnLabel: "F7", scancode: 0x24, fnScancode: 0x40),
        const KeyInfo(label: "8", fnLabel: "F8", scancode: 0x25, fnScancode: 0x41),
        const KeyInfo(label: "9", fnLabel: "F9", scancode: 0x26, fnScancode: 0x42),
        const KeyInfo(label: "0", fnLabel: "F10", scancode: 0x27, fnScancode: 0x43),
        const KeyInfo(label: "-", fnLabel: "F11", scancode: 0x2D, fnScancode: 0x44),
        const KeyInfo(label: "=", fnLabel: "F12", scancode: 0x2E, fnScancode: 0x45),
        const KeyInfo(label: "Back", fnLabel: "Del", scancode: 0x2A, fnScancode: 0x4C, flex: 1.8),
      ],
      // Row 2
      [
        const KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
        const KeyInfo(label: "Q", scancode: 0x14),
        const KeyInfo(label: "W", scancode: 0x1A),
        const KeyInfo(label: "E", scancode: 0x08),
        const KeyInfo(label: "R", scancode: 0x15),
        const KeyInfo(label: "T", scancode: 0x17),
        const KeyInfo(label: "Y", scancode: 0x1C),
        const KeyInfo(label: "U", fnLabel: "Home", scancode: 0x18, fnScancode: 0x4A),
        const KeyInfo(label: "I", fnLabel: "▲", scancode: 0x0C, fnScancode: 0x52),
        const KeyInfo(label: "O", fnLabel: "End", scancode: 0x12, fnScancode: 0x4D),
        const KeyInfo(label: "P", fnLabel: "PgUp", scancode: 0x13, fnScancode: 0x4B),
        const KeyInfo(label: "[", scancode: 0x2F),
        const KeyInfo(label: "]", scancode: 0x30),
        const KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
      ],
      // Row 3
      [
        const KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
        const KeyInfo(label: "A", scancode: 0x04),
        const KeyInfo(label: "S", scancode: 0x16),
        const KeyInfo(label: "D", scancode: 0x07),
        const KeyInfo(label: "F", scancode: 0x09),
        const KeyInfo(label: "G", scancode: 0x0A),
        const KeyInfo(label: "H", scancode: 0x0B),
        const KeyInfo(label: "J", fnLabel: "◀", scancode: 0x0D, fnScancode: 0x50),
        const KeyInfo(label: "K", fnLabel: "▼", scancode: 0x0E, fnScancode: 0x51),
        const KeyInfo(label: "L", fnLabel: "▶", scancode: 0x0F, fnScancode: 0x4F),
        const KeyInfo(label: ";", fnLabel: "PgDn", scancode: 0x33, fnScancode: 0x4E),
        const KeyInfo(label: "'", scancode: 0x34),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
      ],
      // Row 4
      [
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.2),
        const KeyInfo(label: "Z", scancode: 0x1D),
        const KeyInfo(label: "X", scancode: 0x1B),
        const KeyInfo(label: "C", scancode: 0x06),
        const KeyInfo(label: "V", scancode: 0x19),
        const KeyInfo(label: "B", scancode: 0x05),
        const KeyInfo(label: "N", scancode: 0x11),
        const KeyInfo(label: "M", scancode: 0x10),
        const KeyInfo(label: ",", scancode: 0x36),
        const KeyInfo(label: ".", scancode: 0x37),
        const KeyInfo(label: "/", scancode: 0x38),
        const KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 2.8),
      ],
      // Row 5
      [
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.5),
        const KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.5),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.5),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.5),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.5),
        const KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x10, flex: 1.5),
      ],
    ];
  }

  List<List<KeyInfo>> get _currentKeyboardLayout {
    switch (_keyboardKind) {
      case KeyboardKind.fullSize:
        return _getFullSizeLayout();
      case KeyboardKind.compactFullSize:
        return _getCompactFullSizeLayout();
      case KeyboardKind.tenkeyless:
        return _getTklLayout();
      case KeyboardKind.seventyFive:
        return _getSeventyFiveLayout();
      case KeyboardKind.sixtyFive:
        return _getSixtyFiveLayout();
      case KeyboardKind.sixtyPercent:
        return _getSixtyPercentLayout();
    }
  }

  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isConnected = false;
  bool _isRegistered = false;
  String? _connectedDeviceName;

  // Trackpad Settings
  double _sensitivity = 3.0;
  bool _mouseAcceleration = false; // Mouse acceleration disabled by default
  bool _trackpadOnLeft = true;     // Trackpad configuration parameter
  KeyboardKind _keyboardKind = KeyboardKind.tenkeyless; // Default TKL style

  // Fraction accumulators for precision control
  double _fractionalDx = 0.0;
  double _fractionalDy = 0.0;
  double _fractionalWheel = 0.0;
  int _lastButtonsState = 0;

  // Trackpad Touch positions for visual trails
  Offset? _touchPos;
  List<Offset> _trailPoints = [];

  // Bottom click zones visual active trigger state
  bool _leftActive = false;
  bool _rightActive = false;

  // Virtual Keyboard State Buffers
  final Set<int> _activeScancodes = {};
  int _modifiersBitmask = 0;
  bool _fnActive = false;
  bool _holdLockActive = false;

  // Layout Management: Forced Landscape Full-Screen Keyboard state
  bool _forcedLandscapeKeyboard = false;

  @override
  void initState() {
    super.initState();
    _checkSupportAndPermissions();
    _setupPlatformChannel();
  }

  void _setupPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectionStateChanged':
          final connected = call.arguments['connected'] as bool;
          final deviceName = call.arguments['deviceName'] as String?;
          setState(() {
            _isConnected = connected;
            _connectedDeviceName = deviceName;
          });
          break;
        case 'onRegistrationChanged':
          final registered = call.arguments['registered'] as bool;
          setState(() {
            _isRegistered = registered;
          });
          break;
      }
    });
  }

  Future<void> _checkSupportAndPermissions() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      setState(() {
        _isSupported = supported;
      });

      if (supported) {
        _checkPermissions();
      }
    } catch (e) {
      debugPrint("Error checking support: $e");
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final sdkVersion = await _channel.invokeMethod<int>('getSdkVersion') ?? 0;
      bool granted = false;

      if (sdkVersion >= 31) {
        PermissionStatus connectStatus = await Permission.bluetoothConnect.status;
        PermissionStatus advertiseStatus = await Permission.bluetoothAdvertise.status;
        PermissionStatus scanStatus = await Permission.bluetoothScan.status;

        granted = connectStatus.isGranted && 
                  advertiseStatus.isGranted && 
                  scanStatus.isGranted;

        if (!granted) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothConnect,
            Permission.bluetoothAdvertise,
            Permission.bluetoothScan,
          ].request();

          granted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
                    (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
                    (statuses[Permission.bluetoothScan]?.isGranted ?? false);
        }
      } else {
        // Under Android 12 (API level 30 and lower), Location runtime is needed for BT scanning/discovery
        PermissionStatus locationStatus = await Permission.location.status;
        granted = locationStatus.isGranted;

        if (!granted) {
          PermissionStatus reqStatus = await Permission.location.request();
          granted = reqStatus.isGranted;
        }
      }

      setState(() {
        _permissionsGranted = granted;
      });

      if (granted) {
        _initializeBluetooth();
      }
    } catch (e) {
      debugPrint("Error running permission checks: $e");
    }
  }

  Future<void> _initializeBluetooth() async {
    try {
      await _channel.invokeMethod('registerAppProfile');
      await _loadConnectionState();
    } catch (e) {
      debugPrint("Error initializing Bluetooth HID: $e");
    }
  }

  Future<void> _loadConnectionState() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getConnectionState');
      if (result != null) {
        setState(() {
          _isConnected = result['connected'] as bool? ?? false;
          _connectedDeviceName = result['deviceName'] as String?;
          _isRegistered = result['registered'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading connection state: $e");
    }
  }

  Future<void> _openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (e) {
      debugPrint("Error opening bluetooth settings: $e");
    }
  }

  // Send Mouse HID Report ID 2
  Future<void> _sendReport({
    required int buttons,
    required double dx,
    required double dy,
    double wheel = 0,
  }) async {
    double totalDx = dx + _fractionalDx;
    double totalDy = dy + _fractionalDy;
    double totalWheel = wheel + _fractionalWheel;

    int intDx = totalDx.truncate();
    int intDy = totalDy.truncate();
    int intWheel = totalWheel.truncate();

    _fractionalDx = totalDx - intDx;
    _fractionalDy = totalDy - intDy;
    _fractionalWheel = totalWheel - intWheel;

    // Clamp coordinates to prevent overflow of relative signed bytes (-127 to 127)
    intDx = intDx.clamp(-127, 127);
    intDy = intDy.clamp(-127, 127);
    intWheel = intWheel.clamp(-127, 127);

    if (intDx != 0 || intDy != 0 || intWheel != 0 || buttons != _lastButtonsState) {
      _lastButtonsState = buttons;
      try {
        await _channel.invokeMethod('sendMouseReport', {
          'buttons': buttons,
          'dx': intDx.toDouble(),
          'dy': intDy.toDouble(),
          'wheel': intWheel,
        });
      } on PlatformException catch (e) {
        debugPrint("Error dispatching HID mouse event: ${e.message}");
      }
    }
  }

  // Send Keyboard HID Report ID 1
  Future<void> _sendKeyboardReport() async {
    List<int> bytes = List.filled(8, 0);
    bytes[0] = _modifiersBitmask;
    bytes[1] = 0; // Reserved byte (constant padding)
    
    int idx = 2;
    for (int scancode in _activeScancodes) {
      if (idx < 8) {
        bytes[idx] = scancode;
        idx++;
      }
    }
    
    try {
      await _channel.invokeMethod('sendKeyboardReport', {'bytes': bytes});
    } on PlatformException catch (e) {
      debugPrint("Error sending HID keyboard report: ${e.message}");
    }
  }

  // Reset all modifier states and active buttons
  void _resetHidState() {
    setState(() {
      _activeScancodes.clear();
      _modifiersBitmask = 0;
      _lastButtonsState = 0;
      _leftActive = false;
      _rightActive = false;
      _fnActive = false;
    });
    // Send zero reports for both keyboard and mouse
    _sendKeyboardReport();
    _sendReport(buttons: 0, dx: 0, dy: 0);
  }

  // Tap-to-click trigger sequence
  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
  }

  // Key operations for Virtual Keyboard
  Future<void> _handleKeyTap(KeyInfo key) async {
    if (key.scancode == -1) {
      // Toggle Fn translation layer
      setState(() {
        _fnActive = !_fnActive;
      });
      return;
    }

    if (key.isModifier) {
      // Tapping sticky modifiers
      setState(() {
        _modifiersBitmask ^= key.modifierMask;
      });
      await _sendKeyboardReport();
      return;
    }

    // Resolve translated scancode depending on Fn active state
    int scancode = (_fnActive && key.fnScancode != null) ? key.fnScancode! : key.scancode;

    if (_holdLockActive) {
      // HoldLock active: Toggle state
      setState(() {
        if (_activeScancodes.contains(scancode)) {
          _activeScancodes.remove(scancode);
        } else {
          if (_activeScancodes.length < 6) {
            _activeScancodes.add(scancode);
          }
        }
      });
      await _sendKeyboardReport();
    } else {
      // Normal: Send press down, delay 15ms, then release
      setState(() {
        _activeScancodes.add(scancode);
      });
      await _sendKeyboardReport();
      await Future.delayed(const Duration(milliseconds: 15));
      setState(() {
        _activeScancodes.remove(scancode);
      });
      await _sendKeyboardReport();
    }
  }

  Future<void> _toggleForcedLandscapeKeyboard() async {
    if (_forcedLandscapeKeyboard) {
      setState(() {
        _forcedLandscapeKeyboard = false;
      });
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      setState(() {
        _forcedLandscapeKeyboard = true;
      });
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // --- UI Layout Generators ---

  Widget _buildUnsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              "Unsupported Device",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse requires Android 9 (API Level 28) or higher for native Bluetooth HID Device Emulation.\n\nYour device's Android version does not support this profile.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_searching, size: 80, color: Color(0xFF00E5FF)),
            const SizedBox(height: 24),
            const Text(
              "Bluetooth Access Required",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse emulates a standard Bluetooth mouse and keyboard. To register this hardware profile, the app requires Bluetooth permission to advertise to hosts.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Grant Permissions"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _openBluetoothSettings,
              child: const Text(
                "Open System Settings",
                style: TextStyle(color: Color(0xFF0DF5E3), fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    Color dotColor = Colors.red;
    if (_isConnected) {
      dotColor = const Color(0xFF0DF5E3);
    } else if (_isRegistered) {
      dotColor = Colors.amber;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDashboard({bool compact = false}) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isConnected ? const Color(0x330DF5E3) : const Color(0x1AFFFFFF),
            width: 1.5,
          ),
          boxShadow: [
            if (_isConnected)
              const BoxShadow(
                color: Color(0x1A0DF5E3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            _buildStatusDot(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isConnected ? "Connected" : "Not Connected",
                    style: TextStyle(
                      fontSize: compact ? 15 : 18,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? const Color(0xFF0DF5E3) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isConnected
                        ? "Connected to ${_connectedDeviceName ?? 'Host Laptop'}"
                        : "Pair via phone's Bluetooth settings as 'CouchMouse'",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _openBluetoothSettings,
              icon: const Icon(Icons.settings_bluetooth),
              color: const Color(0xFF00E5FF),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: compact ? 22 : 26,
              tooltip: "Bluetooth Settings",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackpad({required double height, double borderOpacity = 0.08}) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            setState(() {
              _touchPos = details.localFocalPoint;
              _trailPoints = [details.localFocalPoint];
            });
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 1) {
              setState(() {
                _touchPos = details.localFocalPoint;
                _trailPoints.add(details.localFocalPoint);
                if (_trailPoints.length > 15) {
                  _trailPoints.removeAt(0);
                }
              });

              // Apply sensitivity and mouse acceleration formulas
              double rawDx = details.focalPointDelta.dx;
              double rawDy = details.focalPointDelta.dy;

              double scaledDx = rawDx * _sensitivity;
              double scaledDy = rawDy * _sensitivity;

              if (_mouseAcceleration) {
                scaledDx = scaledDx * (1.0 + scaledDx.abs() * 0.05);
                scaledDy = scaledDy * (1.0 + scaledDy.abs() * 0.05);
              }

              _sendReport(
                buttons: _lastButtonsState,
                dx: scaledDx,
                dy: scaledDy,
                wheel: 0,
              );
            } else if (details.pointerCount == 2) {
              setState(() {
                _touchPos = details.localFocalPoint;
                _trailPoints.clear();
              });

              // Scroll input direction is natural (-dy)
              double dy = details.focalPointDelta.dy;
              double wheelDelta = -dy * 0.25;
              if (wheelDelta != 0) {
                _sendReport(buttons: _lastButtonsState, dx: 0, dy: 0, wheel: wheelDelta);
              }
            }
          },
          onScaleEnd: (details) {
            setState(() {
              _touchPos = null;
              _trailPoints.clear();
            });
          },
          onTap: _tapClick,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F0F16), Color(0xFF08080C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _touchPos != null
                    ? const Color(0x3D00E5FF)
                    : Colors.white.withValues(alpha: borderOpacity),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: height < 200 ? 32 : 48,
                  color: _touchPos != null ? const Color(0xFF00E5FF) : Colors.white12,
                ),
                const SizedBox(height: 12),
                Text(
                  "Trackpad Surface",
                  style: TextStyle(
                    fontSize: height < 200 ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: _touchPos != null ? Colors.white : Colors.white30,
                  ),
                ),
                if (height >= 180) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Slide to Move • Tap to Click • 2 Fingers to Scroll",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: height < 200 ? 11 : 12,
                      color: _touchPos != null ? Colors.white60 : Colors.white24,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
        if (_touchPos != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: TrackpadPainter(_trailPoints, _touchPos),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClickButtons({required double height, double fontSize = 14}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF13131B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x11FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                setState(() => _leftActive = true);
                _sendReport(buttons: 0x01, dx: 0, dy: 0);
              },
              onTapUp: (_) {
                setState(() => _leftActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              onTapCancel: () {
                setState(() => _leftActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  gradient: _leftActive
                      ? const RadialGradient(
                          colors: [Color(0x3300E5FF), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: _leftActive ? const Color(0x0A00E5FF) : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  border: _leftActive
                      ? Border.all(color: const Color(0xFF00E5FF), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mouse,
                        color: _leftActive ? const Color(0xFF00E5FF) : Colors.white38,
                        size: height < 70 ? 20 : 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "LEFT CLICK",
                        style: TextStyle(
                          color: _leftActive ? const Color(0xFF00E5FF) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1.5,
            color: const Color(0x11FFFFFF),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                setState(() => _rightActive = true);
                _sendReport(buttons: 0x02, dx: 0, dy: 0);
              },
              onTapUp: (_) {
                setState(() => _rightActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              onTapCancel: () {
                setState(() => _rightActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  gradient: _rightActive
                      ? const RadialGradient(
                          colors: [Color(0x330DF5E3), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: _rightActive ? const Color(0x0A0DF5E3) : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: _rightActive
                      ? Border.all(color: const Color(0xFF0DF5E3), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mouse_outlined,
                        color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white38,
                        size: height < 70 ? 20 : 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "RIGHT CLICK",
                        style: TextStyle(
                          color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E15),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // HoldLock Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _holdLockActive = !_holdLockActive;
                    if (!_holdLockActive) {
                      _activeScancodes.clear();
                      _sendKeyboardReport();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _holdLockActive ? const Color(0x20FFCA28) : const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _holdLockActive ? const Color(0xFFFFCA28) : const Color(0x18FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _holdLockActive ? Icons.lock : Icons.lock_open,
                        size: 13,
                        color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "HoldLock",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick Reset Button
              GestureDetector(
                onTap: _resetHidState,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x18FFFFFF), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 13, color: Colors.white54),
                      SizedBox(width: 6),
                      Text(
                        "Reset",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            _fnActive ? "FN LAYER: ACTIVE" : "STANDARD LAYER",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _fnActive ? const Color(0xFF00E5FF) : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard({bool compact = false}) {
    double rowHeight = compact ? 38.0 : 48.0;
    double keyFontSize = compact ? 10.0 : 13.0;

    return Container(
      color: const Color(0xFF07070B),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _currentKeyboardLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: row.map((key) {
                if (key.isSpacer) {
                  return Expanded(
                    flex: (key.flex * 10).toInt(),
                    child: const SizedBox(),
                  );
                }

                // Determine layout active state (glow highlight)
                bool isActive = false;
                Color glowColor = const Color(0xFF00E5FF);

                if (key.isModifier) {
                  isActive = (_modifiersBitmask & key.modifierMask) != 0;
                  glowColor = const Color(0xFFE040FB); // Magenta glow for sticky modifiers
                } else if (key.scancode == -1) {
                  isActive = _fnActive;
                  glowColor = const Color(0xFF00E5FF);
                } else {
                  int scancode = (_fnActive && key.fnScancode != null) ? key.fnScancode! : key.scancode;
                  isActive = _activeScancodes.contains(scancode);
                  glowColor = _holdLockActive ? const Color(0xFFFFCA28) : const Color(0xFF0DF5E3);
                }

                // Determine display label
                String label = (_fnActive && key.fnLabel != null) ? key.fnLabel! : key.label;

                return Expanded(
                  flex: (key.flex * 10).toInt(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _handleKeyTap(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        height: rowHeight,
                        decoration: BoxDecoration(
                          color: isActive ? glowColor.withValues(alpha: 0.12) : const Color(0xFF14141E),
                          borderRadius: BorderRadius.circular(compact ? 6 : 8),
                          border: Border.all(
                            color: isActive
                                ? glowColor
                                : Colors.white.withValues(alpha: compact ? 0.05 : 0.08),
                            width: isActive ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            if (isActive)
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.2),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: keyFontSize,
                            fontWeight: FontWeight.bold,
                            color: isActive ? glowColor : Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Main Structural Layout Builders ---

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildConnectionDashboard(compact: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildTrackpad(height: constraints.maxHeight, borderOpacity: 0.1);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildClickButtons(height: 95, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSplitLandscapeLayout() {
    final trackpadColumn = Expanded(
      flex: 4,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_trackpadOnLeft ? 12 : 8, 8, _trackpadOnLeft ? 8 : 12, 8),
        child: Column(
          children: [
            _buildConnectionDashboard(compact: true),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _buildTrackpad(height: constraints.maxHeight, borderOpacity: 0.08);
                },
              ),
            ),
            const SizedBox(height: 8),
            _buildClickButtons(height: 60, fontSize: 11),
          ],
        ),
      ),
    );

    final divider = Container(
      width: 1.5,
      color: const Color(0x18FFFFFF),
      margin: const EdgeInsets.symmetric(vertical: 12),
    );

    final keyboardColumn = Expanded(
      flex: 6,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_trackpadOnLeft ? 8 : 12, 8, _trackpadOnLeft ? 12 : 8, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyboardToolbar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: _buildKeyboard(compact: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _trackpadOnLeft
          ? [trackpadColumn, divider, keyboardColumn]
          : [keyboardColumn, divider, trackpadColumn],
    );
  }

  Widget _buildForcedLandscapeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF13131B),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildStatusDot(),
              const SizedBox(width: 8),
              const Text(
                "CouchMouse",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
              ),
              const SizedBox(width: 12),
              // HoldLock Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _holdLockActive = !_holdLockActive;
                    if (!_holdLockActive) {
                      _activeScancodes.clear();
                      _sendKeyboardReport();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _holdLockActive ? const Color(0x20FFCA28) : const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _holdLockActive ? const Color(0xFFFFCA28) : const Color(0x18FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _holdLockActive ? Icons.lock : Icons.lock_open,
                        size: 11,
                        color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "HoldLock",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Quick Reset Button
              GestureDetector(
                onTap: _resetHidState,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x18FFFFFF), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 11, color: Colors.white54),
                      SizedBox(width: 4),
                      Text(
                        "Reset",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _fnActive ? "FN ACTIVE" : "STANDARD",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: _fnActive ? const Color(0xFF00E5FF) : Colors.white30,
                ),
              ),
              const SizedBox(width: 12),
              // Compact Exit Button
              ElevatedButton.icon(
                onPressed: _toggleForcedLandscapeKeyboard,
                icon: const Icon(Icons.exit_to_app, size: 12),
                label: const Text("Exit"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForcedLandscapeKeyboardLayout() {
    return Column(
      children: [
        _buildForcedLandscapeHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFF07070B),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _buildKeyboard(compact: true),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Scaffold(
        body: SafeArea(child: _buildUnsupportedView()),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        body: SafeArea(child: _buildPermissionsView()),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        // If Forced Landscape Keyboard is enabled, override everything with the full keyboard layout
        bool showFullKeyboard = _forcedLandscapeKeyboard && orientation == Orientation.landscape;

        return Scaffold(
          appBar: showFullKeyboard
              ? null // No appBar when in full screen keyboard
              : AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        orientation == Orientation.portrait ? Icons.mouse : Icons.keyboard,
                        color: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "CouchMouse",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    // Only show forced landscape lock button if currently in portrait
                    if (orientation == Orientation.portrait)
                      IconButton(
                        icon: const Icon(Icons.keyboard, color: Color(0xFF0DF5E3)),
                        onPressed: _toggleForcedLandscapeKeyboard,
                        tooltip: "Full Keyboard Mode",
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
          drawer: showFullKeyboard ? null : _buildDrawer(),
          body: SafeArea(
            child: showFullKeyboard
                ? _buildForcedLandscapeKeyboardLayout()
                : (orientation == Orientation.portrait
                    ? _buildPortraitLayout()
                    : _buildSplitLandscapeLayout()),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
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
                      child: const Icon(Icons.mouse, color: Color(0xFF00E5FF), size: 30),
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                // Sensitivity control
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Sensitivity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("${_sensitivity.toStringAsFixed(1)}x", style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
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
                            value: _sensitivity,
                            min: 0.5,
                            max: 6.0,
                            onChanged: (val) {
                              setState(() {
                                _sensitivity = val;
                              });
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    activeThumbColor: const Color(0xFF0DF5E3),
                    title: const Text("Mouse Acceleration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Increases cursor speed with rapid swipes", style: TextStyle(fontSize: 12, color: Colors.white54)),
                    value: _mouseAcceleration,
                    onChanged: (val) {
                      setState(() {
                        _mouseAcceleration = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Trackpad Orientation swap configuration
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    activeThumbColor: const Color(0xFF0DF5E3),
                    title: const Text("Trackpad Left-Side", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Place trackpad on Left in Landscape mode", style: TextStyle(fontSize: 12, color: Colors.white54)),
                    value: _trackpadOnLeft,
                    onChanged: (val) {
                      setState(() {
                        _trackpadOnLeft = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "KEYBOARD SETTINGS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                // Keyboard layout style dropdown
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Layout Style", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<KeyboardKind>(
                          initialValue: _keyboardKind,
                          dropdownColor: const Color(0xFF13131B),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _keyboardKind = val;
                                // Clear active key codes to prevent sticking
                                _activeScancodes.clear();
                                _sendKeyboardReport();
                              });
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                // HoldLock Toggle (Drawer duplicate)
                ListTile(
                  leading: Icon(
                    _holdLockActive ? Icons.lock : Icons.lock_open,
                    color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white60,
                  ),
                  title: const Text("HoldLock Mode", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  trailing: Switch(
                    activeThumbColor: const Color(0xFFFFCA28),
                    value: _holdLockActive,
                    onChanged: (val) {
                      setState(() {
                        _holdLockActive = val;
                        if (!_holdLockActive) {
                          _activeScancodes.clear();
                          _sendKeyboardReport();
                        }
                      });
                    },
                  ),
                ),
                // Reset State Utility
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.redAccent),
                  title: const Text("Reset HID Profile State", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  onTap: () {
                    _resetHidState();
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
                const Divider(color: Color(0x18FFFFFF), height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "CONNECTION INSTRUCTIONS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "1. Open your host device's (PC, Mac, Linux) standard Bluetooth settings.\n"
                    "2. Tap the Bluetooth settings icon in the top header card to view your phone's system Bluetooth menu.\n"
                    "3. Ensure Bluetooth is ON and pair with 'CouchMouse' from the list.\n"
                    "4. Once paired, CouchMouse acts as a physical peripheral device.",
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
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

class TrackpadPainter extends CustomPainter {
  final List<Offset> points;
  final Offset? currentPoint;

  TrackpadPainter(this.points, this.currentPoint);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && currentPoint == null) return;

    // Draw the neon cyan trail connecting past points
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        double progress = i / points.length; // 0.0 to 1.0
        final Paint trailPaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: progress * 0.4)
          ..strokeWidth = progress * 6.0 + 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(points[i], points[i + 1], trailPaint);
      }
    }

    if (currentPoint != null) {
      // Subtle outer halo glow
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x4000E5FF),
            Color(0x1000E5FF),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: currentPoint!, radius: 44.0));
      canvas.drawCircle(currentPoint!, 44.0, glowPaint);

      // Inner glowing ring outline
      final Paint ringPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(currentPoint!, 18.0, ringPaint);

      // Focal point center dot
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint!, 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrackpadPainter oldDelegate) {
    return true;
  }
}
