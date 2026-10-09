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
    this.onScrubPreview,
    this.onScrubEnd,
    super.key,
  });

  final double durationSeconds;
  final RangeValues range;
  final double positionSeconds;
  final List<String> thumbnailPaths;
  final ValueChanged<RangeValues> onRangeChanged;
  final ValueChanged<double> onSeek;
  final ValueChanged<double>? onScrubPreview;
  final ValueChanged<double>? onScrubEnd;

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
  bool _userScrolling = false;
  double? _pendingPreviewSeconds;

  @override
  void didUpdateWidget(covariant TrimTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_userScrolling &&
        !_pinching &&
        (oldWidget.positionSeconds - widget.positionSeconds).abs() > 0.0001) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScrollToPosition(widget.positionSeconds);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _safeDuration() {
    return widget.durationSeconds <= 0 ? 0.001 : widget.durationSeconds;
  }

  double _contentWidth() => _viewportWidth * _zoom;

  double _computeMaxZoom(double viewportWidth) {
    if (widget.durationSeconds <= 0 || viewportWidth <= 0) return 1;

    // Roughly 180 logical px / second at maximum, capped so long videos
    // cannot create absurdly large scroll surfaces.
    final desired =
        (widget.durationSeconds * 180 / viewportWidth).clamp(1.0, 48.0);
    return desired.toDouble();
  }

  double _secondsForOffset(double offset) {
    final duration = _safeDuration();
    final width = _contentWidth();
    if (width <= 0) return 0;

    return (offset / width * duration)
        .clamp(0.0, duration)
        .toDouble();
  }

  double _offsetForSeconds(double seconds) {
    final duration = _safeDuration();
    return (seconds.clamp(0.0, duration) / duration) * _contentWidth();
  }

  void _syncScrollToPosition(double seconds) {
    if (!mounted || !_scrollController.hasClients) return;

    final target = _offsetForSeconds(seconds)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();

    if ((_scrollController.offset - target).abs() > 0.75) {
      _scrollController.jumpTo(target);
    }
  }

  void _previewAtCurrentOffset() {
    if (!_scrollController.hasClients) return;

    final seconds = _secondsForOffset(_scrollController.offset);
    _pendingPreviewSeconds = seconds;
    widget.onScrubPreview?.call(seconds);
  }

  void _commitCurrentOffset() {
    if (!_scrollController.hasClients) return;

    final seconds =
        _pendingPreviewSeconds ?? _secondsForOffset(_scrollController.offset);
    _pendingPreviewSeconds = null;
    widget.onScrubEnd?.call(seconds);
    widget.onSeek(seconds);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrolling = true;
      _previewAtCurrentOffset();
      setState(() {});
      return false;
    }

    if (notification is ScrollUpdateNotification && _userScrolling) {
      _previewAtCurrentOffset();
      return false;
    }

    if (notification is ScrollEndNotification && _userScrolling) {
      _userScrolling = false;
      _commitCurrentOffset();
      setState(() {});
      return false;
    }

    return false;
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

    if (_pointers.length < 2 && _pinching) {
      _pinching = false;
      _pinchStartDistance = 0;
      setState(() {});
      _commitCurrentOffset();
    }
  }

  void _beginPinch() {
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    if (distance <= 0) return;

    final centerX = (points[0].dx + points[1].dx) / 2;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final mediaX = offset + centerX - _viewportWidth / 2;
    final contentWidth = _contentWidth();

    _pinching = true;
    _pinchStartZoom = _zoom;
    _pinchStartDistance = distance;
    _pinchAnchorX = centerX;
    _pinchAnchorSeconds = (mediaX / contentWidth * _safeDuration())
        .clamp(0.0, _safeDuration())
        .toDouble();

    setState(() {});
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

      final newMediaX =
          (_pinchAnchorSeconds / _safeDuration()) * _contentWidth();
      final target = (_viewportWidth / 2 + newMediaX - _pinchAnchorX)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();

      _scrollController.jumpTo(target);
      _previewAtCurrentOffset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportWidth = math.max(1.0, constraints.maxWidth);
          _maxZoom = _computeMaxZoom(_viewportWidth);

          if (_zoom > _maxZoom) {
            _zoom = _maxZoom;
          }

          final safeDuration = _safeDuration();
          final contentWidth = _contentWidth();
          final pixelsPerSecond = contentWidth / safeDuration;
          final sidePadding = _viewportWidth / 2;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_userScrolling && !_pinching) {
              _syncScrollToPosition(widget.positionSeconds);
            }
          });

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: _pointerUp,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: SingleChildScrollView(
                          key: const ValueKey('trim-timeline-scroll'),
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: _pinching
                              ? const NeverScrollableScrollPhysics()
                              : const ClampingScrollPhysics(),
                          child: SizedBox(
                            height: 96,
                            width: contentWidth + _viewportWidth,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: sidePadding,
                                  top: 0,
                                  width: contentWidth,
                                  height: 96,
                                  child: _TimelineContent(
                                    durationSeconds: safeDuration,
                                    range: widget.range,
                                    thumbnailPaths: widget.thumbnailPaths,
                                    pixelsPerSecond: pixelsPerSecond,
                                    onRangeChanged: widget.onRangeChanged,
                                    onPreview: (seconds) {
                                      _pendingPreviewSeconds = seconds;
                                      widget.onScrubPreview?.call(seconds);
                                    },
                                    onCommit: (seconds) {
                                      _pendingPreviewSeconds = null;
                                      widget.onScrubEnd?.call(seconds);
                                      widget.onSeek(seconds);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _viewportWidth / 2 - 1,
                      top: 0,
                      width: 2,
                      height: _trackHeight + 9,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _viewportWidth / 2 - 5,
                      top: 0,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(10, 7),
                          painter: _PlayheadCapPainter(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      _zoom > 1.02
                          ? '×${_zoom.toStringAsFixed(_zoom < 10 ? 1 : 0)}'
                          : '${_formatTime(widget.range.end - widget.range.start)} seçili',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ),
                  Text(
                    _formatTime(widget.range.end, precise: _zoom >= 2),
                    style: Theme.of(context).textTheme.labelMedium,
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

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({
    required this.durationSeconds,
    required this.range,
    required this.thumbnailPaths,
    required this.pixelsPerSecond,
    required this.onRangeChanged,
    required this.onPreview,
    required this.onCommit,
  });

  final double durationSeconds;
  final RangeValues range;
  final List<String> thumbnailPaths;
  final double pixelsPerSecond;
  final ValueChanged<RangeValues> onRangeChanged;
  final ValueChanged<double> onPreview;
  final ValueChanged<double> onCommit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startX = range.start / durationSeconds * width;
        final endX = range.end / durationSeconds * width;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 2,
              height: _TrimTimelineState._trackHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Filmstrip(paths: thumbnailPaths),
                    Positioned(
                      left: 0,
                      width: startX,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: Color(0xB0000000)),
                    ),
                    Positioned(
                      left: endX,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: const ColoredBox(color: Color(0xB0000000)),
                    ),
                    Positioned(
                      left: startX,
                      width: (endX - startX).clamp(0.0, width).toDouble(),
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              bottom: BorderSide(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                onPreview(next);
              },
              onEnd: (next) => onCommit(next),
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
                onPreview(next);
              },
              onEnd: (next) => onCommit(next),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 80,
              height: 16,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TimeRulerPainter(
                    durationSeconds: durationSeconds,
                    pixelsPerSecond: pixelsPerSecond,
                    textColor: Colors.white54,
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
    required this.onEnd,
  });

  final double centerX;
  final double width;
  final bool isStart;
  final double value;
  final double minValue;
  final double maxValue;
  final double durationSeconds;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  State<_TrimHandle> createState() => _TrimHandleState();
}

class _TrimHandleState extends State<_TrimHandle> {
  double _dragStartValue = 0;
  double _dragDx = 0;
  double _lastValue = 0;

  void _startDrag(DragStartDetails details) {
    _dragStartValue = widget.value;
    _lastValue = widget.value;
    _dragDx = 0;
  }

  void _updateDrag(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    final next = (_dragStartValue +
            (_dragDx / widget.width) * widget.durationSeconds)
        .clamp(widget.minValue, widget.maxValue)
        .toDouble();
    _lastValue = next;
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
        onHorizontalDragEnd: (_) => widget.onEnd(_lastValue),
        onHorizontalDragCancel: () => widget.onEnd(_lastValue),
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
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayheadCapPainter extends CustomPainter {
  const _PlayheadCapPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PlayheadCapPainter oldDelegate) {
    return oldDelegate.color != color;
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
        Offset(x, major ? 6 : 3),
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

      painter.paint(canvas, Offset(x + 3, 7));
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
