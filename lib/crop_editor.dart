import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum _CropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class CropEditor extends StatefulWidget {
  const CropEditor({
    required this.controller,
    required this.crop,
    required this.onChanged,
    this.lockedNormalizedAspectRatio,
    this.onPrecisionPointChanged,
    this.onPrecisionEnd,
    super.key,
  });

  final VideoPlayerController controller;

  /// Source-space normalized crop rectangle.
  final Rect crop;
  final ValueChanged<Rect> onChanged;

  /// Width / height in normalized source coordinates.
  final double? lockedNormalizedAspectRatio;

  final ValueChanged<Offset>? onPrecisionPointChanged;
  final VoidCallback? onPrecisionEnd;

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  static const _minimumSize = 0.035;
  static const _targetScreenFraction = 0.86;
  static const _maxDisplayScale = 8.0;
  static const _hitSize = 54.0;

  Rect _gestureStartCrop = Rect.zero;
  Offset _gestureStartFocal = Offset.zero;
  Offset _gestureAnchorSource = Offset.zero;
  double _gestureStartDisplayScale = 1;
  bool _scaling = false;

  Rect _dragStartCrop = Rect.zero;
  Offset _dragDelta = Offset.zero;

  double _displayScale(Rect crop) {
    final widthScale =
        _targetScreenFraction / crop.width.clamp(_minimumSize, 1.0);
    final heightScale =
        _targetScreenFraction / crop.height.clamp(_minimumSize, 1.0);
    return math
        .min(widthScale, heightScale)
        .clamp(1.0, _maxDisplayScale)
        .toDouble();
  }

  Offset _sourceAtScreen(
    Offset screen,
    Size size,
    Rect crop,
    double displayScale,
  ) {
    final center = crop.center;
    final viewportCenter = Offset(size.width / 2, size.height / 2);

    return Offset(
      center.dx + (screen.dx - viewportCenter.dx) / (size.width * displayScale),
      center.dy +
          (screen.dy - viewportCenter.dy) / (size.height * displayScale),
    );
  }

  Rect _fitInside(Rect rect) {
    var width = rect.width.clamp(_minimumSize, 1.0).toDouble();
    var height = rect.height.clamp(_minimumSize, 1.0).toDouble();

    final ratio = widget.lockedNormalizedAspectRatio;
    if (ratio != null) {
      if (width / height > ratio) {
        width = height * ratio;
      } else {
        height = width / ratio;
      }

      if (width > 1) {
        width = 1;
        height = width / ratio;
      }
      if (height > 1) {
        height = 1;
        width = height * ratio;
      }
    }

    var left = rect.center.dx - width / 2;
    var top = rect.center.dy - height / 2;

    left = left.clamp(0.0, 1.0 - width).toDouble();
    top = top.clamp(0.0, 1.0 - height).toDouble();

    return Rect.fromLTWH(left, top, width, height);
  }

  Rect _scaleCropAround(
    Rect base,
    Offset anchor,
    double gestureScale,
  ) {
    final safeScale = gestureScale.clamp(0.2, 20.0).toDouble();

    final left = anchor.dx - (anchor.dx - base.left) / safeScale;
    final right = anchor.dx + (base.right - anchor.dx) / safeScale;
    final top = anchor.dy - (anchor.dy - base.top) / safeScale;
    final bottom = anchor.dy + (base.bottom - anchor.dy) / safeScale;

    return _fitInside(Rect.fromLTRB(left, top, right, bottom));
  }

  Rect _translateCrop(Rect crop, Offset sourceDelta) {
    final left =
        (crop.left + sourceDelta.dx).clamp(0.0, 1.0 - crop.width).toDouble();
    final top =
        (crop.top + sourceDelta.dy).clamp(0.0, 1.0 - crop.height).toDouble();
    return Rect.fromLTWH(left, top, crop.width, crop.height);
  }

  void _scaleStart(ScaleStartDetails details, Size size) {
    if (details.pointerCount < 2) return;

    _gestureStartCrop = widget.crop;
    _gestureStartFocal = details.localFocalPoint;
    _gestureStartDisplayScale = _displayScale(widget.crop);
    _gestureAnchorSource = _sourceAtScreen(
      details.localFocalPoint,
      size,
      widget.crop,
      _gestureStartDisplayScale,
    );
    _scaling = true;
  }

  void _scaleUpdate(ScaleUpdateDetails details, Size size) {
    if (!_scaling || details.pointerCount < 2) return;

    var next = _scaleCropAround(
      _gestureStartCrop,
      _gestureAnchorSource,
      details.scale,
    );

    final screenDelta = details.localFocalPoint - _gestureStartFocal;
    final sourceDelta = Offset(
      -screenDelta.dx / (size.width * _gestureStartDisplayScale),
      -screenDelta.dy / (size.height * _gestureStartDisplayScale),
    );

    next = _translateCrop(next, sourceDelta);
    widget.onChanged(next);
  }

  void _scaleEnd(ScaleEndDetails details) {
    _scaling = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = _displayScale(widget.crop);
        final focus = widget.crop.center;

        final matrix = Matrix4.identity()
          ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(
            -focus.dx * size.width,
            -focus.dy * size.height,
            0,
            1,
          );

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) => _scaleStart(details, size),
            onScaleUpdate: (details) => _scaleUpdate(details, size),
            onScaleEnd: _scaleEnd,
            child: Transform(
              key: const ValueKey('crop-editor-transform'),
              alignment: Alignment.topLeft,
              transform: matrix,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    VideoPlayer(widget.controller),
                    _buildOverlay(size, scale),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(Size size, double displayScale) {
    final crop = widget.crop;
    final pixelRect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CropFramePainter(crop, displayScale),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: pixelRect,
          child: GestureDetector(
            key: const ValueKey('crop-move-area'),
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) {
              if (_scaling) return;
              _dragStartCrop = widget.crop;
              _dragDelta = Offset.zero;
            },
            onPanUpdate: (details) {
              if (_scaling) return;
              _dragDelta += details.delta;
              widget.onChanged(
                _moveCrop(_dragStartCrop, _dragDelta, size),
              );
            },
          ),
        ),
        for (final handle in _CropHandle.values)
          _handle(handle, pixelRect, size, displayScale),
      ],
    );
  }

  Widget _handle(
    _CropHandle handle,
    Rect pixelRect,
    Size size,
    double displayScale,
  ) {
    final point = _handlePoint(pixelRect, handle);
    final hitSize = _hitSize / displayScale;

    final left = (point.dx - hitSize / 2)
        .clamp(0.0, math.max(0.0, size.width - hitSize))
        .toDouble();
    final top = (point.dy - hitSize / 2)
        .clamp(0.0, math.max(0.0, size.height - hitSize))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        key: ValueKey('crop-handle-${handle.name}'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          if (_scaling) return;
          _dragStartCrop = widget.crop;
          _dragDelta = Offset.zero;
          widget.onPrecisionPointChanged?.call(
            _handleSourcePoint(widget.crop, handle),
          );
        },
        onPanUpdate: (details) {
          if (_scaling) return;
          _dragDelta += details.delta;
          final next = _resizeCrop(
            _dragStartCrop,
            handle,
            _dragDelta,
            size,
          );
          widget.onChanged(next);
          widget.onPrecisionPointChanged?.call(
            _handleSourcePoint(next, handle),
          );
        },
        onPanEnd: (_) => widget.onPrecisionEnd?.call(),
        onPanCancel: () => widget.onPrecisionEnd?.call(),
        child: Center(
          child: _HandleMark(
            handle: handle,
            displayScale: displayScale,
          ),
        ),
      ),
    );
  }

  Offset _handlePoint(Rect rect, _CropHandle handle) {
    return switch (handle) {
      _CropHandle.topLeft => rect.topLeft,
      _CropHandle.top => Offset(rect.center.dx, rect.top),
      _CropHandle.topRight => rect.topRight,
      _CropHandle.right => Offset(rect.right, rect.center.dy),
      _CropHandle.bottomRight => rect.bottomRight,
      _CropHandle.bottom => Offset(rect.center.dx, rect.bottom),
      _CropHandle.bottomLeft => rect.bottomLeft,
      _CropHandle.left => Offset(rect.left, rect.center.dy),
    };
  }

  Offset _handleSourcePoint(Rect rect, _CropHandle handle) {
    return _handlePoint(rect, handle);
  }

  Rect _moveCrop(Rect base, Offset pixelDelta, Size size) {
    final dx = pixelDelta.dx / size.width;
    final dy = pixelDelta.dy / size.height;
    return _translateCrop(base, Offset(dx, dy));
  }

  Rect _resizeCrop(
    Rect base,
    _CropHandle handle,
    Offset pixelDelta,
    Size size,
  ) {
    final dx = pixelDelta.dx / size.width;
    final dy = pixelDelta.dy / size.height;

    final ratio = widget.lockedNormalizedAspectRatio;
    if (ratio == null) {
      return _resizeFree(base, handle, dx, dy);
    }

    return _resizeLocked(base, handle, dx, dy, ratio);
  }

  Rect _resizeFree(
    Rect base,
    _CropHandle handle,
    double dx,
    double dy,
  ) {
    var left = base.left;
    var top = base.top;
    var right = base.right;
    var bottom = base.bottom;

    if (handle == _CropHandle.topLeft ||
        handle == _CropHandle.left ||
        handle == _CropHandle.bottomLeft) {
      left = (left + dx).clamp(0.0, right - _minimumSize).toDouble();
    }
    if (handle == _CropHandle.topRight ||
        handle == _CropHandle.right ||
        handle == _CropHandle.bottomRight) {
      right = (right + dx).clamp(left + _minimumSize, 1.0).toDouble();
    }
    if (handle == _CropHandle.topLeft ||
        handle == _CropHandle.top ||
        handle == _CropHandle.topRight) {
      top = (top + dy).clamp(0.0, bottom - _minimumSize).toDouble();
    }
    if (handle == _CropHandle.bottomLeft ||
        handle == _CropHandle.bottom ||
        handle == _CropHandle.bottomRight) {
      bottom =
          (bottom + dy).clamp(top + _minimumSize, 1.0).toDouble();
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _resizeLocked(
    Rect base,
    _CropHandle handle,
    double dx,
    double dy,
    double ratio,
  ) {
    if (handle == _CropHandle.left || handle == _CropHandle.right) {
      final movingLeft = handle == _CropHandle.left;
      final fixedX = movingLeft ? base.right : base.left;
      var width = movingLeft ? fixedX - (base.left + dx) : base.right + dx - fixedX;
      width = width.clamp(_minimumSize, 1.0).toDouble();
      var height = width / ratio;
      if (height > 1) {
        height = 1;
        width = height * ratio;
      }

      final centerY = base.center.dy;
      var top = centerY - height / 2;
      top = top.clamp(0.0, 1.0 - height).toDouble();
      final left = movingLeft ? fixedX - width : fixedX;
      return _fitInside(Rect.fromLTWH(left, top, width, height));
    }

    if (handle == _CropHandle.top || handle == _CropHandle.bottom) {
      final movingTop = handle == _CropHandle.top;
      final fixedY = movingTop ? base.bottom : base.top;
      var height =
          movingTop ? fixedY - (base.top + dy) : base.bottom + dy - fixedY;
      height = height.clamp(_minimumSize, 1.0).toDouble();
      var width = height * ratio;
      if (width > 1) {
        width = 1;
        height = width / ratio;
      }

      final centerX = base.center.dx;
      var left = centerX - width / 2;
      left = left.clamp(0.0, 1.0 - width).toDouble();
      final top = movingTop ? fixedY - height : fixedY;
      return _fitInside(Rect.fromLTWH(left, top, width, height));
    }

    final anchor = switch (handle) {
      _CropHandle.topLeft => base.bottomRight,
      _CropHandle.topRight => base.bottomLeft,
      _CropHandle.bottomRight => base.topLeft,
      _CropHandle.bottomLeft => base.topRight,
      _ => base.center,
    };

    final moving = switch (handle) {
      _CropHandle.topLeft => base.topLeft + Offset(dx, dy),
      _CropHandle.topRight => base.topRight + Offset(dx, dy),
      _CropHandle.bottomRight => base.bottomRight + Offset(dx, dy),
      _CropHandle.bottomLeft => base.bottomLeft + Offset(dx, dy),
      _ => base.center,
    };

    var width = (moving.dx - anchor.dx).abs();
    var height = (moving.dy - anchor.dy).abs();

    if (width / math.max(height, 0.0001) > ratio) {
      height = width / ratio;
    } else {
      width = height * ratio;
    }

    width = width.clamp(_minimumSize, 1.0).toDouble();
    height = height.clamp(_minimumSize, 1.0).toDouble();

    final left = moving.dx < anchor.dx ? anchor.dx - width : anchor.dx;
    final top = moving.dy < anchor.dy ? anchor.dy - height : anchor.dy;

    return _fitInside(Rect.fromLTWH(left, top, width, height));
  }
}

class _HandleMark extends StatelessWidget {
  const _HandleMark({
    required this.handle,
    required this.displayScale,
  });

  final _CropHandle handle;
  final double displayScale;

  @override
  Widget build(BuildContext context) {
    final thickness = 4 / displayScale;
    final cornerLength = 20 / displayScale;
    final edgeLength = 26 / displayScale;

    final isCorner = handle == _CropHandle.topLeft ||
        handle == _CropHandle.topRight ||
        handle == _CropHandle.bottomRight ||
        handle == _CropHandle.bottomLeft;

    if (!isCorner) {
      final horizontal =
          handle == _CropHandle.top || handle == _CropHandle.bottom;
      return Container(
        width: horizontal ? edgeLength : thickness,
        height: horizontal ? thickness : edgeLength,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 / displayScale),
        ),
      );
    }

    return SizedBox(
      width: cornerLength,
      height: cornerLength,
      child: CustomPaint(
        painter: _CornerPainter(
          handle: handle,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.handle,
    required this.thickness,
  });

  final _CropHandle handle;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;

    final left = handle == _CropHandle.topLeft ||
        handle == _CropHandle.bottomLeft;
    final top =
        handle == _CropHandle.topLeft || handle == _CropHandle.topRight;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;

    canvas.drawLine(
      Offset(x, y),
      Offset(left ? size.width : 0, y),
      paint,
    );
    canvas.drawLine(
      Offset(x, y),
      Offset(x, top ? size.height : 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.handle != handle ||
        oldDelegate.thickness != thickness;
  }
}

class _CropFramePainter extends CustomPainter {
  const _CropFramePainter(this.crop, this.displayScale);

  final Rect crop;
  final double displayScale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );

    final shade = Paint()..color = const Color(0xA8000000);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), shade);
    canvas.drawRect(
      Rect.fromLTRB(0, rect.bottom, size.width, size.height),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, rect.top, rect.left, rect.bottom),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom),
      shade,
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / displayScale;
    canvas.drawRect(rect, border);

    final grid = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1 / displayScale;

    for (var i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropFramePainter oldDelegate) {
    return oldDelegate.crop != crop ||
        oldDelegate.displayScale != displayScale;
  }
}
