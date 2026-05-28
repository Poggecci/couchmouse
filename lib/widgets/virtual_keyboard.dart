import 'package:flutter/material.dart';
import '../keyboard_layouts.dart';

class VirtualKeyboard extends StatelessWidget {
  final bool compact;
  final KeyboardKind keyboardKind;
  final bool fnActive;
  final bool holdLockActive;
  final int modifiersBitmask;
  final Set<int> activeScancodes;
  final void Function(KeyInfo key) onKeyTap;

  const VirtualKeyboard({
    super.key,
    this.compact = false,
    required this.keyboardKind,
    required this.fnActive,
    required this.holdLockActive,
    required this.modifiersBitmask,
    required this.activeScancodes,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    double rowHeight = compact ? 38.0 : 48.0;
    double keyFontSize = compact ? 10.0 : 13.0;
    final layout = KeyboardLayouts.getLayout(keyboardKind);

    return Container(
      color: const Color(0xFFF4F4F6),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: layout.map((row) {
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

                if (key.isModifier) {
                  isActive = (modifiersBitmask & key.modifierMask) != 0;
                } else if (key.scancode == -1) {
                  isActive = fnActive;
                } else {
                  int scancode = (fnActive && key.fnScancode != null)
                      ? key.fnScancode!
                      : key.scancode;
                  isActive = activeScancodes.contains(scancode);
                }

                // Determine display label
                String label = (fnActive && key.fnLabel != null)
                    ? key.fnLabel!
                    : key.label;

                return Expanded(
                  flex: (key.flex * 10).toInt(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => onKeyTap(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        height: rowHeight,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.black
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(compact ? 4 : 6),
                          border: Border.all(
                            color: isActive
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.08),
                            width: isActive ? 1.0 : 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: keyFontSize,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.7),
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
}
