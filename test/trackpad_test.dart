import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couchmouse/widgets/trackpad.dart';

class _Recorder {
  final List<Offset> moves = [];
  int taps = 0;

  Offset get total => moves.fold(Offset.zero, (sum, move) => sum + move);
}

Future<_Recorder> _pumpTrackpad(
  WidgetTester tester, {
  required bool trackball,
}) async {
  final recorder = _Recorder();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Trackpad(
          height: 400,
          sensitivity: 160,
          mouseAcceleration: false,
          invertTwoFingerScroll: false,
          scrollSensitivity: 1,
          trackball: trackball,
          trackballFriction: 0.5,
          onReport: ({required dx, required dy, required wheel}) {
            recorder.moves.add(Offset(dx, dy));
          },
          onTap: () => recorder.taps++,
        ),
      ),
    ),
  );
  return recorder;
}

Future<void> _flick(WidgetTester tester) async {
  await tester.fling(find.byType(Trackpad), const Offset(150, 0), 2000);
}

void main() {
  testWidgets('A flick keeps the cursor gliding after release', (tester) async {
    final recorder = await _pumpTrackpad(tester, trackball: true);
    await _flick(tester);
    final dragged = recorder.total.dx;

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    expect(recorder.total.dx, greaterThan(dragged));

    await tester.pumpAndSettle();
    final glided = recorder.total.dx - dragged;
    expect(glided, closeTo(2000 / 6, 40));
    expect(recorder.total.dy, closeTo(0, 1e-6));
  });

  testWidgets('Without trackball the cursor stops on release', (tester) async {
    final recorder = await _pumpTrackpad(tester, trackball: false);
    await _flick(tester);
    final dragged = recorder.moves.length;

    await tester.pumpAndSettle();
    expect(recorder.moves.length, dragged);
  });

  testWidgets('A tap during a glide stops it without clicking', (tester) async {
    final recorder = await _pumpTrackpad(tester, trackball: true);
    await _flick(tester);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(Trackpad));
    final stoppedAt = recorder.moves.length;
    await tester.pumpAndSettle();
    expect(recorder.moves.length, stoppedAt);
    expect(recorder.taps, 0);

    await tester.tap(find.byType(Trackpad));
    await tester.pumpAndSettle();
    expect(recorder.taps, 1);
  });
}
