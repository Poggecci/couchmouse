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

class KeyboardLayouts {
  static List<List<KeyInfo>> getTklLayout() {
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.2,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 2.8,
        ),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
      ],
      // Row 6
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.25,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.25,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "App", scancode: 0x65, flex: 1.25),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.5,
        ),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  static List<List<KeyInfo>> getFullSizeLayout() {
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.2,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 2.8,
        ),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 1.3),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
      // Row 6 (Ctrl/Alt/Space + arrows)
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.25,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.25,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(label: "App", scancode: 0x65, flex: 1.25),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.5,
        ),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 0.3),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
        const KeyInfo(label: "", scancode: 0, isSpacer: true, flex: 4.3),
      ],
    ];
  }

  static List<List<KeyInfo>> getCompactFullSizeLayout() {
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.0,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 3.0,
        ),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
      ],
      // Row 6 (Spacebar row + arrows + KP 0 / KP Ent)
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.25,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.25,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.25,
        ),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
        const KeyInfo(label: "KP 0", scancode: 0x62, flex: 2.0),
        const KeyInfo(label: "KP .", scancode: 0x63, flex: 1.0),
        const KeyInfo(label: "KP Ent", scancode: 0x58, flex: 1.0),
      ],
    ];
  }

  static List<List<KeyInfo>> getSeventyFiveLayout() {
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.0,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 2.0,
        ),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
      ],
      // Row 6 (Spacebar row + Left/Down/Right)
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.25,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.25,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.25,
        ),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  static List<List<KeyInfo>> getSixtyFiveLayout() {
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.0,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 2.0,
        ),
        const KeyInfo(label: "▲", scancode: 0x52, flex: 1.0),
        const KeyInfo(label: "End", scancode: 0x4D, flex: 1.0),
      ],
      // Row 5 (Spacebar row + Left/Down/Right)
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.25,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.25,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 5.5),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.25,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.25),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.25,
        ),
        const KeyInfo(label: "◀", scancode: 0x50, flex: 1.0),
        const KeyInfo(label: "▼", scancode: 0x51, flex: 1.0),
        const KeyInfo(label: "▶", scancode: 0x4F, flex: 1.0),
      ],
    ];
  }

  static List<List<KeyInfo>> getSixtyPercentLayout() {
    return [
      // Row 1
      [
        const KeyInfo(
          label: "`",
          fnLabel: "Esc",
          scancode: 0x35,
          fnScancode: 0x29,
          flex: 1.2,
        ),
        const KeyInfo(
          label: "1",
          fnLabel: "F1",
          scancode: 0x1E,
          fnScancode: 0x3A,
        ),
        const KeyInfo(
          label: "2",
          fnLabel: "F2",
          scancode: 0x1F,
          fnScancode: 0x3B,
        ),
        const KeyInfo(
          label: "3",
          fnLabel: "F3",
          scancode: 0x20,
          fnScancode: 0x3C,
        ),
        const KeyInfo(
          label: "4",
          fnLabel: "F4",
          scancode: 0x21,
          fnScancode: 0x3D,
        ),
        const KeyInfo(
          label: "5",
          fnLabel: "F5",
          scancode: 0x22,
          fnScancode: 0x3E,
        ),
        const KeyInfo(
          label: "6",
          fnLabel: "F6",
          scancode: 0x23,
          fnScancode: 0x3F,
        ),
        const KeyInfo(
          label: "7",
          fnLabel: "F7",
          scancode: 0x24,
          fnScancode: 0x40,
        ),
        const KeyInfo(
          label: "8",
          fnLabel: "F8",
          scancode: 0x25,
          fnScancode: 0x41,
        ),
        const KeyInfo(
          label: "9",
          fnLabel: "F9",
          scancode: 0x26,
          fnScancode: 0x42,
        ),
        const KeyInfo(
          label: "0",
          fnLabel: "F10",
          scancode: 0x27,
          fnScancode: 0x43,
        ),
        const KeyInfo(
          label: "-",
          fnLabel: "F11",
          scancode: 0x2D,
          fnScancode: 0x44,
        ),
        const KeyInfo(
          label: "=",
          fnLabel: "F12",
          scancode: 0x2E,
          fnScancode: 0x45,
        ),
        const KeyInfo(
          label: "Back",
          fnLabel: "Del",
          scancode: 0x2A,
          fnScancode: 0x4C,
          flex: 1.8,
        ),
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
        const KeyInfo(
          label: "U",
          fnLabel: "Home",
          scancode: 0x18,
          fnScancode: 0x4A,
        ),
        const KeyInfo(
          label: "I",
          fnLabel: "▲",
          scancode: 0x0C,
          fnScancode: 0x52,
        ),
        const KeyInfo(
          label: "O",
          fnLabel: "End",
          scancode: 0x12,
          fnScancode: 0x4D,
        ),
        const KeyInfo(
          label: "P",
          fnLabel: "PgUp",
          scancode: 0x13,
          fnScancode: 0x4B,
        ),
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
        const KeyInfo(
          label: "J",
          fnLabel: "◀",
          scancode: 0x0D,
          fnScancode: 0x50,
        ),
        const KeyInfo(
          label: "K",
          fnLabel: "▼",
          scancode: 0x0E,
          fnScancode: 0x51,
        ),
        const KeyInfo(
          label: "L",
          fnLabel: "▶",
          scancode: 0x0F,
          fnScancode: 0x4F,
        ),
        const KeyInfo(
          label: ";",
          fnLabel: "PgDn",
          scancode: 0x33,
          fnScancode: 0x4E,
        ),
        const KeyInfo(label: "'", scancode: 0x34),
        const KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
      ],
      // Row 4
      [
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x02,
          flex: 2.2,
        ),
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
        const KeyInfo(
          label: "Shift",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x20,
          flex: 2.8,
        ),
      ],
      // Row 5
      [
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x01,
          flex: 1.5,
        ),
        const KeyInfo(
          label: "Win",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x08,
          flex: 1.5,
        ),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x04,
          flex: 1.5,
        ),
        const KeyInfo(label: "Space", scancode: 0x2C, flex: 6.0),
        const KeyInfo(
          label: "Alt",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x40,
          flex: 1.5,
        ),
        const KeyInfo(label: "Fn", scancode: -1, flex: 1.5),
        const KeyInfo(
          label: "Ctrl",
          scancode: 0,
          isModifier: true,
          modifierMask: 0x10,
          flex: 1.5,
        ),
      ],
    ];
  }

  static List<List<KeyInfo>> getLayout(KeyboardKind kind) {
    switch (kind) {
      case KeyboardKind.fullSize:
        return getFullSizeLayout();
      case KeyboardKind.compactFullSize:
        return getCompactFullSizeLayout();
      case KeyboardKind.tenkeyless:
        return getTklLayout();
      case KeyboardKind.seventyFive:
        return getSeventyFiveLayout();
      case KeyboardKind.sixtyFive:
        return getSixtyFiveLayout();
      case KeyboardKind.sixtyPercent:
        return getSixtyPercentLayout();
    }
  }

  static const Map<String, int> charToScancode = {
    'a': 0x04, 'b': 0x05, 'c': 0x06, 'd': 0x07, 'e': 0x08, 'f': 0x09,
    'g': 0x0A, 'h': 0x0B, 'i': 0x0C, 'j': 0x0D, 'k': 0x0E, 'l': 0x0F,
    'm': 0x10, 'n': 0x11, 'o': 0x12, 'p': 0x13, 'q': 0x14, 'r': 0x15,
    's': 0x16, 't': 0x17, 'u': 0x18, 'v': 0x19, 'w': 0x1A, 'x': 0x1B,
    'y': 0x1C, 'z': 0x1D,
    '1': 0x1E, '2': 0x1F, '3': 0x20, '4': 0x21, '5': 0x22,
    '6': 0x23, '7': 0x24, '8': 0x25, '9': 0x26, '0': 0x27,
    '\n': 0x28, // Enter
    '\r': 0x28, // Carriage return
    '\t': 0x2B, // Tab
    ' ': 0x2C, // Space
    '-': 0x2D, // Minus
    '=': 0x2E, // Equals
    '[': 0x2F, // Left Bracket
    ']': 0x30, // Right Bracket
    '\\': 0x31, // Backslash
    ';': 0x33, // Semicolon
    "'": 0x34, // Apostrophe
    '`': 0x35, // Grave Accent
    ',': 0x36, // Comma
    '.': 0x37, // Period
    '/': 0x38, // Slash
  };

  static const Map<String, int> shiftCharToScancode = {
    'A': 0x04,
    'B': 0x05,
    'C': 0x06,
    'D': 0x07,
    'E': 0x08,
    'F': 0x09,
    'G': 0x0A,
    'H': 0x0B,
    'I': 0x0C,
    'J': 0x0D,
    'K': 0x0E,
    'L': 0x0F,
    'M': 0x10,
    'N': 0x11,
    'O': 0x12,
    'P': 0x13,
    'Q': 0x14,
    'R': 0x15,
    'S': 0x16,
    'T': 0x17,
    'U': 0x18,
    'V': 0x19,
    'W': 0x1A,
    'X': 0x1B,
    'Y': 0x1C,
    'Z': 0x1D,
    '!': 0x1E,
    '@': 0x1F,
    '#': 0x20,
    '\$': 0x21,
    '%': 0x22,
    '^': 0x23,
    '&': 0x24,
    '*': 0x25,
    '(': 0x26,
    ')': 0x27,
    '_': 0x2D,
    '+': 0x2E,
    '{': 0x2F,
    '}': 0x30,
    '|': 0x31,
    ':': 0x33,
    '"': 0x34,
    '~': 0x35,
    '<': 0x36,
    '>': 0x37,
    '?': 0x38,
  };
}
