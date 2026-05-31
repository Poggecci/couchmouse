import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ScrollWheel extends StatefulWidget {
  final double height;
  final double width;
  final double scrollSensitivity;
  final bool invertScroll;
  final double scrollMomentum;
  final void Function(double wheel) onScroll;

  const ScrollWheel({
    super.key,
    required this.height,
    this.width = 24.0,
    required this.scrollSensitivity,
    required this.invertScroll,
    required this.scrollMomentum,
    required this.onScroll,
  });

  @override
  State<ScrollWheel> createState() => _ScrollWheelState();
}

class _ScrollWheelState extends State<ScrollWheel>
    with SingleTickerProviderStateMixin {
  double _scrollAngle = 0.0;
  bool _isPressed = false;

  late final Ticker _ticker;
  double _velocity = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final double dt =
        (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0.0) return;

    final double momentum = widget.scrollMomentum;
    if (momentum <= 0.0) {
      _ticker.stop();
      return;
    }

    // Deceleration/friction coefficient.
    // Higher momentum values decrease friction, allowing longer slides.
    final double friction = 1.5 + (1.0 - momentum) * 13.5;

    // Exponential velocity decay
    final double nextVelocity = _velocity * math.exp(-friction * dt);
    final double avgVelocity = (_velocity + nextVelocity) / 2.0;
    final double dy = avgVelocity * dt;

    _velocity = nextVelocity;

    if (_velocity.abs() < 30.0) {
      _ticker.stop();
      _velocity = 0.0;
      return;
    }

    // Send scroll event
    final wheelDelta =
        (widget.invertScroll ? dy : -dy) * 0.25 * widget.scrollSensitivity;
    widget.onScroll(wheelDelta);

    // Update visual rotation angle of the cylinder
    final double deltaAngle = (dy / (widget.height / 2.0));
    setState(() {
      _scrollAngle = (_scrollAngle + deltaAngle) % (2.0 * math.pi);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        if (_ticker.isActive) {
          _ticker.stop();
        }
        _velocity = 0.0;
        setState(() {
          _isPressed = true;
        });
      },
      onVerticalDragUpdate: (details) {
        if (_ticker.isActive) {
          _ticker.stop();
        }
        _velocity = 0.0;

        final dy = details.primaryDelta ?? 0.0;
        if (dy != 0.0) {
          // Send scroll event
          final wheelDelta =
              (widget.invertScroll ? dy : -dy) *
              0.25 *
              widget.scrollSensitivity;
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

        final double momentum = widget.scrollMomentum;
        if (momentum > 0.0) {
          final double vy = details.velocity.pixelsPerSecond.dy;
          if (vy.abs() > 100.0) {
            _velocity = vy;
            _lastElapsed = Duration.zero;
            _ticker.start();
          }
        }
      },
      onVerticalDragCancel: () {
        if (_ticker.isActive) {
          _ticker.stop();
        }
        _velocity = 0.0;
        setState(() {
          _isPressed = false;
        });
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPressed
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
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

  ScrollWheelPainter({required this.scrollAngle, required this.isPressed});

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
          Colors.black.withValues(alpha: 0.02),
          Colors.white,
          Colors.black.withValues(alpha: 0.02),
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
        final double opacity = cosTheta * (isPressed ? 0.6 : 0.3);
        final double strokeWidth = cosTheta * 1.5 + 0.5;

        final Paint ribPaint = Paint()
          ..color = Colors.black.withValues(alpha: opacity)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(3, y), Offset(w - 3, y), ribPaint);
      }
    }

    // Draw a subtle vertical indicator line down the center to emphasize track
    final Paint trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: isPressed ? 0.15 : 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w / 2, 8), Offset(w / 2, h - 8), trackPaint);

    // Draw top and bottom shadow/gradient overlays to fade cylinder ends
    final Paint fadePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFAFAFC),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFFFAFAFC),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fadePaint);
  }

  @override
  bool shouldRepaint(covariant ScrollWheelPainter oldDelegate) {
    return oldDelegate.scrollAngle != scrollAngle ||
        oldDelegate.isPressed != isPressed;
  }
}
