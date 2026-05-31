import 'package:flutter/material.dart';

class Trackpad extends StatefulWidget {
  final double height;
  final double borderOpacity;
  final double sensitivity;
  final bool mouseAcceleration;
  final bool invertTwoFingerScroll;
  final double scrollSensitivity;
  final void Function({
    required double dx,
    required double dy,
    required double wheel,
  })
  onReport;
  final VoidCallback onTap;

  const Trackpad({
    super.key,
    required this.height,
    this.borderOpacity = 0.08,
    required this.sensitivity,
    required this.mouseAcceleration,
    required this.invertTwoFingerScroll,
    required this.scrollSensitivity,
    required this.onReport,
    required this.onTap,
  });

  @override
  State<Trackpad> createState() => _TrackpadState();
}

class _TrackpadState extends State<Trackpad> {
  Offset? _touchPos;
  List<Offset> _trailPoints = [];

  @override
  Widget build(BuildContext context) {
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

              double rawDx = details.focalPointDelta.dx;
              double rawDy = details.focalPointDelta.dy;

              double scaledDx = rawDx * (widget.sensitivity / 160.0);
              double scaledDy = rawDy * (widget.sensitivity / 160.0);

              if (widget.mouseAcceleration) {
                scaledDx = scaledDx * (1.0 + scaledDx.abs() * 0.05);
                scaledDy = scaledDy * (1.0 + scaledDy.abs() * 0.05);
              }

              widget.onReport(dx: scaledDx, dy: scaledDy, wheel: 0);
            } else if (details.pointerCount == 2) {
              setState(() {
                _touchPos = details.localFocalPoint;
                _trailPoints.clear();
              });

              double dy = details.focalPointDelta.dy;
              double wheelDelta =
                  (widget.invertTwoFingerScroll ? dy : -dy) *
                  0.25 *
                  widget.scrollSensitivity;
              if (wheelDelta != 0) {
                widget.onReport(dx: 0, dy: 0, wheel: wheelDelta);
              }
            }
          },
          onScaleEnd: (details) {
            setState(() {
              _touchPos = null;
              _trailPoints.clear();
            });
          },
          onTap: widget.onTap,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _touchPos != null
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: widget.borderOpacity),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mouse_outlined,
                  size: widget.height < 200 ? 28 : 40,
                  color: _touchPos != null
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  "Trackpad",
                  style: TextStyle(
                    fontSize: widget.height < 200 ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _touchPos != null ? Colors.black : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                if (widget.height >= 180) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Slide to Move • Tap to Click • 2 Fingers to Scroll",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.height < 200 ? 10 : 11,
                      color: _touchPos != null
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ],
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
}

class TrackpadPainter extends CustomPainter {
  final List<Offset> points;
  final Offset? currentPoint;

  TrackpadPainter(this.points, this.currentPoint);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && currentPoint == null) return;

    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        double progress = i / points.length;
        final Paint trailPaint = Paint()
          ..color = Colors.black.withValues(alpha: progress * 0.2)
          ..strokeWidth = progress * 4.0 + 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(points[i], points[i + 1], trailPaint);
      }
    }

    if (currentPoint != null) {
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.01),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: currentPoint!, radius: 36.0));
      canvas.drawCircle(currentPoint!, 36.0, glowPaint);

      final Paint ringPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(currentPoint!, 15.0, ringPaint);

      final Paint dotPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint!, 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrackpadPainter oldDelegate) {
    return true;
  }
}
