import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrimTimeline extends StatefulWidget {
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

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  static const double _trackHeight = 72;
  static const double _handleHitWidth = 48;
  static const double _minimumSelectionSeconds = 0.05;

  final ScrollController _scrollController = ScrollController();
  final Map<int, Offset> _pointers = <int, Offset>{};

  double _zoom = 1;
  double _viewportWidth = 1;
  double _maxZoom = 1;
  double _pinchStartZoom = 1;
  double _pinchStartDistance = 0;
  double _pinchAnchorSeconds = 0;
  double _pinchAnchorX = 0;
  bool _pinching = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _computeMaxZoom(double viewportWidth) {
    if (widget.durationSeconds <= 0 || viewportWidth <= 0) return 1;

    // At maximum zoom aim for roughly 160 logical pixels per second.
    // This is enough for comfortable sub-second placement without letting a
    // long clip create an effectively unbounded scroll surface.
    final desired =
        (widget.durationSeconds * 160 / viewportWidth).clamp(1.0, 40.0);
    return desired.toDouble();
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _beginPinch();
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2 && _pinching) {
      _updatePinch();
    }
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _pinching = false;
      _pinchStartDistance = 0;
      if (mounted) setState(() {});
    }
  }

  void _beginPinch() {
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    if (distance <= 0) return;

    final centerX = (points[0].dx + points[1].dx) / 2;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final contentWidth = _viewportWidth * _zoom;

    _pinching = true;
    _pinchStartZoom = _zoom;
    _pinchStartDistance = distance;
    _pinchAnchorX = centerX;
    _pinchAnchorSeconds = widget.durationSeconds <= 0
        ? 0
        : ((offset + centerX) / contentWidth * widget.durationSeconds)
            .clamp(0.0, widget.durationSeconds)
            .toDouble();

    if (mounted) setState(() {});
  }

  void _updatePinch() {
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    if (_pinchStartDistance <= 0 || distance <= 0) return;

    final nextZoom = (_pinchStartZoom * distance / _pinchStartDistance)
        .clamp(1.0, _maxZoom)
        .toDouble();

    if ((nextZoom - _zoom).abs() < 0.001) return;

    setState(() => _zoom = nextZoom);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final contentWidth = _viewportWidth * _zoom;
      final anchorContentX = widget.durationSeconds <= 0
          ? 0.0
          : (_pinchAnchorSeconds / widget.durationSeconds) * contentWidth;
      final target = (anchorContentX - _pinchAnchorX)
          .clamp(
            0.0,
            math.max(0.0, _scrollController.position.maxScrollExtent),
          )
          .toDouble();
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = math.max(1.0, constraints.maxWidth);
          _maxZoom = _computeMaxZoom(_viewportWidth);

          if (_zoom > _maxZoom) {
            _zoom = _maxZoom;
          }

          final safeDuration =
              widget.durationSeconds <= 0 ? 0.001 : widget.durationSeconds;
          final contentWidth = _viewportWidth * _zoom;
          final pixelsPerSecond = contentWidth / safeDuration;

          return Column(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _pointerDown,
                  onPointerMove: _pointerMove,
                  onPointerUp: _pointerUp,
                  onPointerCancel: _pointerUp,
                  child: SingleChildScrollView(
                    key: const ValueKey('trim-timeline-scroll'),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: _pinching || _zoom <= 1.02
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: SizedBox(
                      key: const ValueKey('trim-timeline-content'),
                      width: contentWidth,
                      height: 98,
                      child: _TimelineSurface(
                        durationSeconds: safeDuration,
                        range: widget.range,
                        positionSeconds: widget.positionSeconds,
                        thumbnailPaths: widget.thumbnailPaths,
                        pixelsPerSecond: pixelsPerSecond,
                        onRangeChanged: widget.onRangeChanged,
                        onSeek: widget.onSeek,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _formatTime(widget.range.start, precise: _zoom >= 2),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Expanded(
                    child: Text(
                      '${_formatTime(widget.range.end - widget.range.start, precise: _zoom >= 2)} seçili',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                  Text(
                    _zoom > 1.02
                        ? '×${_zoom.toStringAsFixed(_zoom < 10 ? 1 : 0)}'
                        : _formatTime(widget.range.end),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _zoom > 1.02 ? Colors.white70 : null,
                        ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineSurface extends StatelessWidget {
  const _TimelineSurface({
    required this.durationSeconds,
    required this.range,
    required this.positionSeconds,
    required this.thumbnailPaths,
    required this.pixelsPerSecond,
    required this.onRangeChanged,
    required this.onSeek,
  });

  final double durationSeconds;
  final RangeValues range;
  final double positionSeconds;
  final List<String> thumbnailPaths;
  final double pixelsPerSecond;
  final ValueChanged<RangeValues> onRangeChanged;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startX = range.start / durationSeconds * width;
        final endX = range.end / durationSeconds * width;
        final playheadX =
            positionSeconds.clamp(0.0, durationSeconds) / durationSeconds * width;

        double secondsForX(double x) {
          return (x.clamp(0.0, width) / width * durationSeconds)
              .clamp(range.start, range.end)
              .toDouble();
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 2,
              height: _TrimTimelineState._trackHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    onSeek(secondsForX(details.localPosition.dx)),
                onHorizontalDragUpdate: (details) =>
                    onSeek(secondsForX(details.localPosition.dx)),
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
                        child: const ColoredBox(color: Color(0xAA000000)),
                      ),
                      Positioned(
                        left: endX,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: const ColoredBox(color: Color(0xAA000000)),
                      ),
                      Positioned(
                        left: startX,
                        width: (endX - startX).clamp(0.0, width).toDouble(),
                        top: 0,
                        bottom: 0,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x12000000),
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
              height: _TrimTimelineState._trackHeight + 8,
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
              value: range.start,
              minValue: 0,
              maxValue:
                  range.end - _TrimTimelineState._minimumSelectionSeconds,
              durationSeconds: durationSeconds,
              onChanged: (next) {
                onRangeChanged(RangeValues(next, range.end));
                onSeek(next);
              },
            ),
            _TrimHandle(
              centerX: endX,
              width: width,
              isStart: false,
              value: range.end,
              minValue:
                  range.start + _TrimTimelineState._minimumSelectionSeconds,
              maxValue: durationSeconds,
              durationSeconds: durationSeconds,
              onChanged: (next) {
                onRangeChanged(RangeValues(range.start, next));
                onSeek(next);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 80,
              height: 18,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TimeRulerPainter(
                    durationSeconds: durationSeconds,
                    pixelsPerSecond: pixelsPerSecond,
                    textColor: Colors.white60,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final path in paths)
          Expanded(
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
          ),
      ],
    );
  }
}

class _TrimHandle extends StatefulWidget {
  const _TrimHandle({
    required this.centerX,
    required this.width,
    required this.isStart,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.durationSeconds,
    required this.onChanged,
  });

  final double centerX;
  final double width;
  final bool isStart;
  final double value;
  final double minValue;
  final double maxValue;
  final double durationSeconds;
  final ValueChanged<double> onChanged;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  double _dragStartValue = 0;
  double _dragDx = 0;

  void _startDrag(DragStartDetails details) {
    _dragStartValue = widget.value;
    _dragDx = 0;
  }

  void _updateDrag(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    final next = (_dragStartValue +
            (_dragDx / widget.width) * widget.durationSeconds)
        .clamp(widget.minValue, widget.maxValue)
        .toDouble();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final left = (widget.centerX - _TrimTimelineState._handleHitWidth / 2)
        .clamp(0.0, widget.width - _TrimTimelineState._handleHitWidth)
        .toDouble();

    return Positioned(
      left: left,
      top: 0,
      width: _TrimTimelineState._handleHitWidth,
      height: _TrimTimelineState._trackHeight + 8,
      child: GestureDetector(
        key: ValueKey(
          widget.isStart ? 'trim-start-handle' : 'trim-end-handle',
        ),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _startDrag,
        onHorizontalDragUpdate: _updateDrag,
        child: Align(
          alignment: widget.centerX <= _TrimTimelineState._handleHitWidth / 2
              ? Alignment.centerLeft
              : widget.centerX >=
                      widget.width - _TrimTimelineState._handleHitWidth / 2
                  ? Alignment.centerRight
                  : Alignment.center,
          child: Container(
            width: 10,
            height: _TrimTimelineState._trackHeight + 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(widget.isStart ? 7 : 3),
                right: Radius.circular(widget.isStart ? 3 : 7),
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

class _TimeRulerPainter extends CustomPainter {
  const _TimeRulerPainter({
    required this.durationSeconds,
    required this.pixelsPerSecond,
    required this.textColor,
  });

  final double durationSeconds;
  final double pixelsPerSecond;
  final Color textColor;

  static const List<double> _intervals = [
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2,
    5,
    10,
    30,
    60,
    120,
    300,
  ];

  double get _majorInterval {
    for (final interval in _intervals) {
      if (interval * pixelsPerSecond >= 62) return interval;
    }
    return _intervals.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final interval = _majorInterval;
    final minorInterval = interval / 5;
    final linePaint = Paint()
      ..color = textColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    final minorCount = (durationSeconds / minorInterval).ceil();

    for (var i = 0; i <= minorCount; i++) {
      final seconds = i * minorInterval;
      if (seconds > durationSeconds + 0.0001) break;

      final x = seconds * pixelsPerSecond;
      final major = i % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, major ? 7 : 4),
        linePaint,
      );

      if (!major) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: _formatRulerTime(seconds, precise: interval < 1),
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      painter.paint(canvas, Offset(x + 3, 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.durationSeconds != durationSeconds ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.textColor != textColor;
  }
}

String _formatRulerTime(double seconds, {required bool precise}) {
  final duration = Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
  final minutes = duration.inMinutes;
  final wholeSeconds = duration.inSeconds.remainder(60);

  if (!precise) {
    return '${minutes.toString().padLeft(2, '0')}:'
        '${wholeSeconds.toString().padLeft(2, '0')}';
  }

  final hundredths =
      (duration.inMilliseconds.remainder(1000) / 10).floor();
  return '${minutes.toString().padLeft(2, '0')}:'
      '${wholeSeconds.toString().padLeft(2, '0')}.'
      '${hundredths.toString().padLeft(2, '0')}';
}

String _formatTime(double seconds, {bool precise = false}) {
  final duration = Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);

  final base = hours > 0
      ? '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}'
      : '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';

  if (!precise) return base;

  final hundredths =
      (duration.inMilliseconds.remainder(1000) / 10).floor();
  return '$base.${hundredths.toString().padLeft(2, '0')}';
}
