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
    this.fontSize = 14,
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
              onTapDown: onLeftTapDown,
              onTapUp: onLeftTapUp,
              onTapCancel: onLeftTapCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  gradient: leftActive
                      ? const RadialGradient(
                          colors: [Color(0x3300E5FF), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: leftActive
                      ? const Color(0x0A00E5FF)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  border: leftActive
                      ? Border.all(color: const Color(0xFF00E5FF), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!compact) ...[
                        Icon(
                          Icons.mouse,
                          color: leftActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white38,
                          size: height < 70 ? 20 : 28,
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        compact ? "LEFT" : "LEFT CLICK",
                        style: TextStyle(
                          color: leftActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white70,
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
          Container(width: 1.5, color: const Color(0x11FFFFFF)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onRightTapDown,
              onTapUp: onRightTapUp,
              onTapCancel: onRightTapCancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  gradient: rightActive
                      ? const RadialGradient(
                          colors: [Color(0x330DF5E3), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: rightActive
                      ? const Color(0x0A0DF5E3)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: rightActive
                      ? Border.all(color: const Color(0xFF0DF5E3), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!compact) ...[
                        Icon(
                          Icons.mouse_outlined,
                          color: rightActive
                              ? const Color(0xFF0DF5E3)
                              : Colors.white38,
                          size: height < 70 ? 20 : 28,
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        compact ? "RIGHT" : "RIGHT CLICK",
                        style: TextStyle(
                          color: rightActive
                              ? const Color(0xFF0DF5E3)
                              : Colors.white70,
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
}
