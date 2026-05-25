import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScrollWheel extends StatefulWidget {
  final double height;
  final double width;
  final double scrollSensitivity;
  final bool invertScroll;
  final void Function(double wheel) onScroll;

  const ScrollWheel({
    super.key,
    required this.height,
    this.width = 28.0,
    required this.scrollSensitivity,
    required this.invertScroll,
    required this.onScroll,
  });

  @override
  State<ScrollWheel> createState() => _ScrollWheelState();
}

class _ScrollWheelState extends State<ScrollWheel> {
  double _scrollAngle = 0.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        setState(() {
          _isPressed = true;
        });
      },
      onVerticalDragUpdate: (details) {
        final dy = details.primaryDelta ?? 0.0;
        if (dy != 0.0) {
          // Send scroll event
          final wheelDelta = (widget.invertScroll ? dy : -dy) * 0.25 * widget.scrollSensitivity;
          widget.onScroll(wheelDelta);

          // Update visual rotation angle of the cylinder
          // Scale it so that dragging rotates the cylinder naturally
          final double deltaAngle = (dy / (widget.height / 2.0));
          setState(() {
            _scrollAngle = (_scrollAngle + deltaAngle) % (2.0 * math.pi);
          });
        }
      },
      onVerticalDragEnd: (details) {
        setState(() {
          _isPressed = false;
        });
      },
      onVerticalDragCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F0F16), Color(0xFF08080C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPressed
                ? const Color(0x3D00E5FF)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CustomPaint(
            painter: ScrollWheelPainter(
              scrollAngle: _scrollAngle,
              isPressed: _isPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class ScrollWheelPainter extends CustomPainter {
  final double scrollAngle;
  final bool isPressed;

  ScrollWheelPainter({
    required this.scrollAngle,
    required this.isPressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cy = h / 2.0;
    final double r = h / 2.0;

    // Draw background highlight/shading for the cylinder structure
    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.8),
          Colors.white.withValues(alpha: 0.05),
          Colors.black.withValues(alpha: 0.8),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sheenPaint);

    // Draw horizontal ribs
    const double thetaStep = 0.22; // approx 12.6 degrees
    
    for (int k = -50; k <= 50; k++) {
      final double theta = (k * thetaStep + scrollAngle) % (2.0 * math.pi);
      double normTheta = theta;
      if (normTheta > math.pi) normTheta -= 2.0 * math.pi;

      if (normTheta >= -math.pi / 2.0 && normTheta <= math.pi / 2.0) {
        final double y = cy + r * math.sin(normTheta);

        final double cosTheta = math.cos(normTheta);
        final double opacity = cosTheta * (isPressed ? 0.8 : 0.4);
        final double strokeWidth = cosTheta * 2.0 + 1.0;

        final Paint ribPaint = Paint()
          ..color = (isPressed ? const Color(0xFF00E5FF) : Colors.white).withValues(alpha: opacity)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(4, y), Offset(w - 4, y), ribPaint);
      }
    }

    // Draw a subtle vertical indicator line down the center to emphasize track
    final Paint trackPaint = Paint()
      ..color = (isPressed ? const Color(0x3300E5FF) : Colors.white10)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w / 2, 8), Offset(w / 2, h - 8), trackPaint);

    // Draw top and bottom shadow/gradient overlays to fade cylinder ends
    final Paint fadePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF08080C),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF0F0F16),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fadePaint);
  }

  @override
  bool shouldRepaint(covariant ScrollWheelPainter oldDelegate) {
    return oldDelegate.scrollAngle != scrollAngle || oldDelegate.isPressed != isPressed;
  }
}
