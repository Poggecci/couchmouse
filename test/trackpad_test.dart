import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couchmouse/widgets/trackpad.dart';

class _Recorder {
  final List<Offset> moves = [];
  int taps = 0;
  double wheel = 0;

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
            recorder.wheel += wheel;
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

  testWidgets('Lifting after a two-finger scroll does not glide', (
    tester,
  ) async {
    final recorder = await _pumpTrackpad(tester, trackball: true);
    final center = tester.getCenter(find.byType(Trackpad));
    final first = await tester.startGesture(center - const Offset(20, 0));
    final second = await tester.startGesture(center + const Offset(20, 0));
    for (var i = 1; i <= 4; i++) {
      final time = Duration(milliseconds: i * 10);
      await first.moveBy(const Offset(0, 20), timeStamp: time);
      await second.moveBy(const Offset(0, 20), timeStamp: time);
    }
    await second.up(timeStamp: const Duration(milliseconds: 45));
    // Flutter can begin another scale sequence for the remaining finger.
    for (var i = 5; i <= 8; i++) {
      await first.moveBy(
        const Offset(20, 0),
        timeStamp: Duration(milliseconds: i * 10),
      );
    }
    await first.up(timeStamp: const Duration(milliseconds: 85));
    expect(recorder.wheel, isNot(0));
    expect(recorder.total.dx, greaterThan(0));
    final releasedAt = recorder.moves.length;
    await tester.pumpAndSettle();
    expect(recorder.moves.length, releasedAt);
  });

  testWidgets('A canceled flick does not glide', (tester) async {
    final recorder = await _pumpTrackpad(tester, trackball: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Trackpad)),
    );
    for (var i = 1; i <= 5; i++) {
      await gesture.moveBy(
        const Offset(20, 0),
        timeStamp: Duration(milliseconds: i * 10),
      );
    }
    await gesture.cancel(timeStamp: const Duration(milliseconds: 55));
    expect(recorder.total.dx, greaterThan(0));
    final canceledAt = recorder.moves.length;
    await tester.pumpAndSettle();
    expect(recorder.moves.length, canceledAt);
  });
}
