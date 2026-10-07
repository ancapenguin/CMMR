import 'package:cmmr/crop_editor.dart';
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

  testWidgets('timeline pinch zoom expands the editable time surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 130,
              child: TrimTimeline(
                durationSeconds: 20,
                range: const RangeValues(0, 20),
                positionSeconds: 5,
                thumbnailPaths: const [],
                onRangeChanged: (_) {},
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final contentFinder =
        find.byKey(const ValueKey('trim-timeline-content'));
    final scrollFinder =
        find.byKey(const ValueKey('trim-timeline-scroll'));

    final initialWidth = tester.getSize(contentFinder).width;
    expect(initialWidth, closeTo(400, 0.1));

    final center = tester.getCenter(scrollFinder);
    final first =
        await tester.startGesture(center + const Offset(-45, 0), pointer: 1);
    final second =
        await tester.startGesture(center + const Offset(45, 0), pointer: 2);
    await tester.pump();

    await first.moveTo(center + const Offset(-120, 0));
    await second.moveTo(center + const Offset(120, 0));
    await tester.pump();

    expect(tester.getSize(contentFinder).width, greaterThan(initialWidth));

    await first.up();
    await second.up();
    await tester.pump();
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

  testWidgets('crop handle accumulates the full drag and reports precision point',
      (tester) async {
    Rect? changed;
    Offset? precisionPoint;
    var precisionEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: CropOverlay(
                rect: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
                onChanged: (value) => changed = value,
                onPrecisionPointChanged: (value) => precisionPoint = value,
                onPrecisionEnd: () => precisionEnded = true,
              ),
            ),
          ),
        ),
      ),
    );

    final handle =
        find.byKey(const ValueKey('crop-handle-bottomRight'));
    final gesture = await tester.startGesture(tester.getCenter(handle));

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.width, closeTo(0.5 + 40 / 300, 0.002));
    expect(precisionPoint, isNotNull);
    expect(precisionEnded, isTrue);
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

  testWidgets('crop editor exposes edge and corner handles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              var crop = const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6);
              return SizedBox(
                width: 320,
                height: 180,
                child: CropEditor(
                  controller: VideoPlayerController.networkUrl(
                    Uri.parse('https://example.invalid/video.mp4'),
                  ),
                  media: const ColoredBox(color: Colors.black),
                  crop: crop,
                  onChanged: (value) => setState(() => crop = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    for (final name in [
      'topLeft',
      'top',
      'topRight',
      'right',
      'bottomRight',
      'bottom',
      'bottomLeft',
      'left',
    ]) {
      expect(find.byKey(ValueKey('crop-handle-$name')), findsOneWidget);
    }
  });

  testWidgets('pinch out shrinks source crop and pinch in enlarges it',
      (tester) async {
    Rect crop = const Rect.fromLTWH(0.15, 0.15, 0.7, 0.7);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 320,
                height: 180,
                child: CropEditor(
                  controller: VideoPlayerController.networkUrl(
                    Uri.parse('https://example.invalid/video.mp4'),
                  ),
                  media: const ColoredBox(color: Colors.black),
                  crop: crop,
                  onChanged: (value) => setState(() => crop = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    final editor = find.byKey(const ValueKey('crop-editor-transform'));
    final center = tester.getCenter(editor);

    final first =
        await tester.startGesture(center + const Offset(-30, 0), pointer: 11);
    final second =
        await tester.startGesture(center + const Offset(30, 0), pointer: 12);
    await tester.pump();

    await first.moveTo(center + const Offset(-70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();

    final afterZoomIn = crop;
    expect(afterZoomIn.width, lessThan(0.7));
    expect(afterZoomIn.height, lessThan(0.7));

    await first.moveTo(center + const Offset(-20, 0));
    await second.moveTo(center + const Offset(20, 0));
    await tester.pump();

    expect(crop.width, greaterThan(afterZoomIn.width));
    expect(crop.height, greaterThan(afterZoomIn.height));

    await first.up();
    await second.up();
    await tester.pump();
  });
}
