import 'dart:typed_data';

import 'package:flutter/material.dart';

class TrimTimeline extends StatelessWidget {
  const TrimTimeline({
    required this.durationSeconds,
    required this.startSeconds,
    required this.endSeconds,
    required this.positionSeconds,
    required this.thumbnails,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSeek,
    super.key,
  });

  final double durationSeconds;
  final double startSeconds;
  final double endSeconds;
  final double positionSeconds;
  final List<Uint8List?> thumbnails;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;
  final ValueChanged<double> onSeek;

  static const double _height = 72;
  static const double _handleHitWidth = 48;
  static const double _handleVisualWidth = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final safeDuration = durationSeconds <= 0 ? 1.0 : durationSeconds;
        final startX = (startSeconds / safeDuration).clamp(0.0, 1.0) * width;
        final endX = (endSeconds / safeDuration).clamp(0.0, 1.0) * width;
        final positionX =
            (positionSeconds / safeDuration).clamp(0.0, 1.0) * width;

        double secondsForX(double x) {
          return (x.clamp(0.0, width) / width) * safeDuration;
        }

        return SizedBox(
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        onSeek(secondsForX(details.localPosition.dx)),
                    onHorizontalDragUpdate: (details) =>
                        onSeek(secondsForX(details.localPosition.dx)),
                    child: _ThumbnailStrip(thumbnails: thumbnails),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: startX,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
              Positioned(
                left: endX,
                right: 0,
                top: 0,
                bottom: 0,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
              Positioned(
                left: startX,
                width: (endX - startX).clamp(0.0, width),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: positionX - 1,
                top: -5,
                bottom: -5,
                width: 2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
              _TrimHandle(
                centerX: startX,
                isStart: true,
                onDrag: (dx) {
                  final next = startSeconds + (dx / width) * safeDuration;
                  onStartChanged(
                    next.clamp(0.0, endSeconds - 0.05).toDouble(),
                  );
                },
              ),
              _TrimHandle(
                centerX: endX,
                isStart: false,
                onDrag: (dx) {
                  final next = endSeconds + (dx / width) * safeDuration;
                  onEndChanged(
                    next.clamp(startSeconds + 0.05, safeDuration).toDouble(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({required this.thumbnails});

  final List<Uint8List?> thumbnails;

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF252B30),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bytes in thumbnails)
          Expanded(
            child: bytes == null
                ? const ColoredBox(color: Color(0xFF252B30))
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
      ],
    );
  }
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.centerX,
    required this.isStart,
    required this.onDrag,
  });

  final double centerX;
  final bool isStart;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: centerX - TrimTimeline._handleHitWidth / 2,
      top: -8,
      bottom: -8,
      width: TrimTimeline._handleHitWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Align(
          alignment: isStart ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: TrimTimeline._handleVisualWidth,
            margin: EdgeInsets.only(
              left: isStart ? (TrimTimeline._handleHitWidth -
                      TrimTimeline._handleVisualWidth) /
                  2 : 0,
              right: !isStart ? (TrimTimeline._handleHitWidth -
                      TrimTimeline._handleVisualWidth) /
                  2 : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isStart ? 5 : 2),
                right: Radius.circular(isStart ? 2 : 5),
              ),
            ),
            child: Center(
              child: Container(
                width: 2,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
