import 'dart:io';

import 'package:flutter/material.dart';

class TrimTimeline extends StatelessWidget {
  const TrimTimeline({
    required this.durationSeconds,
    required this.range,
    required this.positionSeconds,
    required this.thumbnailPaths,
    required this.onRangeChanged,
    required this.onSeek,
    super.key,
  });

  final double durationSeconds;
  final RangeValues range;
  final double positionSeconds;
  final List<String> thumbnailPaths;
  final ValueChanged<RangeValues> onRangeChanged;
  final ValueChanged<double> onSeek;

  static const double _trackHeight = 72;
  static const double _handleHitWidth = 48;
  static const double _minimumSelectionSeconds = 0.05;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final safeDuration = durationSeconds <= 0 ? 0.001 : durationSeconds;
          final startX = range.start / safeDuration * width;
          final endX = range.end / safeDuration * width;
          final playheadX =
              positionSeconds.clamp(0.0, safeDuration) / safeDuration * width;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                height: _trackHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    onSeek(
                      (details.localPosition.dx / width * safeDuration)
                          .clamp(range.start, range.end)
                          .toDouble(),
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    onSeek(
                      (details.localPosition.dx / width * safeDuration)
                          .clamp(range.start, range.end)
                          .toDouble(),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Filmstrip(paths: thumbnailPaths),
                        Positioned(
                          left: 0,
                          width: startX,
                          top: 0,
                          bottom: 0,
                          child: const ColoredBox(
                            color: Color(0xAA000000),
                          ),
                        ),
                        Positioned(
                          left: endX,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: const ColoredBox(
                            color: Color(0xAA000000),
                          ),
                        ),
                        Positioned(
                          left: startX,
                          width: (endX - startX).clamp(0.0, width).toDouble(),
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (playheadX - 1).clamp(0.0, width - 2).toDouble(),
                top: 0,
                width: 2,
                height: _trackHeight + 10,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _TrimHandle(
                centerX: startX,
                width: width,
                isStart: true,
                onDrag: (delta) {
                  final next = (range.start + delta / width * safeDuration)
                      .clamp(
                        0.0,
                        range.end - _minimumSelectionSeconds,
                      )
                      .toDouble();
                  onRangeChanged(RangeValues(next, range.end));
                  onSeek(next);
                },
              ),
              _TrimHandle(
                centerX: endX,
                width: width,
                isStart: false,
                onDrag: (delta) {
                  final next = (range.end + delta / width * safeDuration)
                      .clamp(
                        range.start + _minimumSelectionSeconds,
                        safeDuration,
                      )
                      .toDouble();
                  onRangeChanged(RangeValues(range.start, next));
                  onSeek(next);
                },
              ),
              Positioned(
                top: 82,
                left: 0,
                child: Text(
                  _format(range.start),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Positioned(
                top: 82,
                right: 0,
                child: Text(
                  _format(range.end),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Positioned(
                top: 82,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    '${_format(range.end - range.start)} seçili',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _format(double seconds) {
    final total = seconds.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final secs = total % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
}

class _Filmstrip extends StatelessWidget {
  const _Filmstrip({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF232B30),
              Color(0xFF101418),
              Color(0xFF232B30),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        for (final path in paths)
          Expanded(
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              height: double.infinity,
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
    required this.width,
    required this.isStart,
    required this.onDrag,
  });

  final double centerX;
  final double width;
  final bool isStart;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final left = (centerX - TrimTimeline._handleHitWidth / 2)
        .clamp(0.0, width - TrimTimeline._handleHitWidth)
        .toDouble();

    return Positioned(
      left: left,
      top: 0,
      width: TrimTimeline._handleHitWidth,
      height: TrimTimeline._trackHeight + 10,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Center(
          child: Container(
            width: 10,
            height: TrimTimeline._trackHeight + 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isStart ? 7 : 3),
                right: Radius.circular(isStart ? 3 : 7),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
