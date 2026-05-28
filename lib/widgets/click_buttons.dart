import 'package:flutter/material.dart';

class ClickButtons extends StatelessWidget {
  final double height;
  final double fontSize;
  final bool compact;
  final bool leftActive;
  final bool rightActive;
  final void Function(TapDownDetails) onLeftTapDown;
  final void Function(TapUpDetails) onLeftTapUp;
  final VoidCallback onLeftTapCancel;
  final void Function(TapDownDetails) onRightTapDown;
  final void Function(TapUpDetails) onRightTapUp;
  final VoidCallback onRightTapCancel;

  const ClickButtons({
    super.key,
    required this.height,
    this.fontSize = 13,
    this.compact = false,
    required this.leftActive,
    required this.rightActive,
    required this.onLeftTapDown,
    required this.onLeftTapUp,
    required this.onLeftTapCancel,
    required this.onRightTapDown,
    required this.onRightTapUp,
    required this.onRightTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onLeftTapDown,
              onTapUp: onLeftTapUp,
              onTapCancel: onLeftTapCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                decoration: BoxDecoration(
                  color: leftActive
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!compact) ...[
                        Icon(
                          Icons.mouse_outlined,
                          color: leftActive
                              ? Colors.black.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.15),
                          size: height < 70 ? 18 : 22,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        compact ? "LEFT" : "LEFT CLICK",
                        style: TextStyle(
                          color: leftActive
                              ? Colors.black
                              : Colors.black.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(width: 0.5, color: Colors.black.withValues(alpha: 0.08)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onRightTapDown,
              onTapUp: onRightTapUp,
              onTapCancel: onRightTapCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                decoration: BoxDecoration(
                  color: rightActive
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!compact) ...[
                        Icon(
                          Icons.mouse_outlined,
                          color: rightActive
                              ? Colors.black.withValues(alpha: 0.8)
                              : Colors.black.withValues(alpha: 0.15),
                          size: height < 70 ? 18 : 22,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        compact ? "RIGHT" : "RIGHT CLICK",
                        style: TextStyle(
                          color: rightActive
                              ? Colors.black
                              : Colors.black.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                          letterSpacing: 0.8,
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
}
