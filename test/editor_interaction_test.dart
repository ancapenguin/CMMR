import 'package:cmmr/crop_overlay.dart';
import 'package:cmmr/trim_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trim handle has a large hit target and updates the range',
      (tester) async {
    RangeValues? changed;
    double? sought;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 120,
              child: TrimTimeline(
                durationSeconds: 20,
                range: const RangeValues(0, 20),
                positionSeconds: 0,
                thumbnailPaths: const [],
                onRangeChanged: (value) => changed = value,
                onSeek: (value) => sought = value,
              ),
            ),
          ),
        ),
      ),
    );

    final handle = find.byKey(const ValueKey('trim-start-handle'));
    expect(handle, findsOneWidget);
    expect(tester.getSize(handle).width, 48);

    await tester.drag(handle, const Offset(40, 0));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.start, closeTo(2, 0.01));
    expect(changed!.end, 20);
    expect(sought, closeTo(2, 0.01));
  });

  testWidgets('locked crop handle keeps its ratio and remains easy to grab',
      (tester) async {
    Rect? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: CropOverlay(
                rect: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
                lockedNormalizedAspectRatio: 1,
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      ),
    );

    final handle =
        find.byKey(const ValueKey('crop-handle-bottomRight'));
    expect(handle, findsOneWidget);
    expect(tester.getSize(handle), const Size(56, 56));

    await tester.drag(handle, const Offset(60, 20));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.width / changed!.height, closeTo(1, 0.001));
  });

  testWidgets('full-frame crop handle stays inside the video canvas',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('crop-canvas'),
              width: 300,
              height: 200,
              child: CropOverlay(
                rect: const Rect.fromLTWH(0, 0, 1, 1),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final canvas = tester.getRect(find.byKey(const ValueKey('crop-canvas')));
    final bottomRight =
        tester.getRect(find.byKey(const ValueKey('crop-handle-bottomRight')));

    expect(bottomRight.right, lessThanOrEqualTo(canvas.right));
    expect(bottomRight.bottom, lessThanOrEqualTo(canvas.bottom));
    expect(bottomRight.left, greaterThanOrEqualTo(canvas.left));
    expect(bottomRight.top, greaterThanOrEqualTo(canvas.top));
  });
}
