import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class CropOverlay extends StatefulWidget {
  const CropOverlay({
    required this.rect,
    required this.onChanged,
    this.lockedNormalizedAspectRatio,
    this.onPrecisionPointChanged,
    this.onPrecisionEnd,
    this.workspaceScale = 1,
    this.enabled = true,
    super.key,
  });

  final Rect rect;
  final ValueChanged<Rect> onChanged;

  /// Width / height in normalized video coordinates.
  /// Null means freeform resizing.
  final double? lockedNormalizedAspectRatio;

  /// Normalized source point currently manipulated by a crop handle.
  final ValueChanged<Offset>? onPrecisionPointChanged;
  final VoidCallback? onPrecisionEnd;
  final double workspaceScale;
  final bool enabled;

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  static const _minimumSize = 0.08;
  static const hitSize = 56.0;

  Rect _dragStartRect = Rect.zero;
  Offset _dragDelta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hitSize = hitSize / widget.workspaceScale;
        final pixelRect = Rect.fromLTRB(
          widget.rect.left * size.width,
          widget.rect.top * size.height,
          widget.rect.right * size.width,
          widget.rect.bottom * size.height,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropPainter(
                    widget.rect,
                    widget.workspaceScale,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: pixelRect,
              child: GestureDetector(
                key: const ValueKey('crop-move-area'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _dragStartRect = widget.rect;
                  _dragDelta = Offset.zero;
                },
                onPanUpdate: (details) {
                  _dragDelta += details.delta;
                  widget.onChanged(
                    _moveFrom(_dragStartRect, _dragDelta, size),
                  );
                },
                child: const SizedBox.expand(),
              ),
            ),
            _handle(_CropCorner.topLeft, pixelRect.topLeft, size, hitSize),
            _handle(_CropCorner.topRight, pixelRect.topRight, size, hitSize),
            _handle(_CropCorner.bottomLeft, pixelRect.bottomLeft, size, hitSize),
            _handle(_CropCorner.bottomRight, pixelRect.bottomRight, size, hitSize),
          ],
        );
      },
    );
  }

  Widget _handle(
    _CropCorner corner,
    Offset center,
    Size size,
    double hitSize,
  ) {
    final isLeft =
        corner == _CropCorner.topLeft || corner == _CropCorner.bottomLeft;
    final isTop =
        corner == _CropCorner.topLeft || corner == _CropCorner.topRight;

    final left = isLeft ? center.dx : center.dx - hitSize;
    final top = isTop ? center.dy : center.dy - hitSize;

    return Positioned(
      left: left.clamp(0.0, math.max(0.0, size.width - hitSize)),
      top: top.clamp(0.0, math.max(0.0, size.height - hitSize)),
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        key: ValueKey('crop-handle-${corner.name}'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          if (!widget.enabled) return;
          _dragStartRect = widget.rect;
          _dragDelta = Offset.zero;
          widget.onPrecisionPointChanged?.call(_cornerPoint(widget.rect, corner));
        },
        onPanUpdate: (details) {
          if (!widget.enabled) return;
          _dragDelta += details.delta;
          final next = _resizeFrom(
            _dragStartRect,
            corner,
            _dragDelta,
            size,
            widget.lockedNormalizedAspectRatio,
          );
          widget.onChanged(next);
          widget.onPrecisionPointChanged?.call(_cornerPoint(next, corner));
        },
        onPanEnd: (_) {
          if (widget.enabled) widget.onPrecisionEnd?.call();
        },
        onPanCancel: () {
          if (widget.enabled) widget.onPrecisionEnd?.call();
        },
        child: Align(
          alignment: switch (corner) {
            _CropCorner.topLeft => Alignment.topLeft,
            _CropCorner.topRight => Alignment.topRight,
            _CropCorner.bottomLeft => Alignment.bottomLeft,
            _CropCorner.bottomRight => Alignment.bottomRight,
          },
          child: _CornerMark(
            corner: corner,
            displayScale: widget.workspaceScale,
          ),
        ),
      ),
    );
  }

  Offset _cornerPoint(Rect rect, _CropCorner corner) {
    return switch (corner) {
      _CropCorner.topLeft => rect.topLeft,
      _CropCorner.topRight => rect.topRight,
      _CropCorner.bottomLeft => rect.bottomLeft,
      _CropCorner.bottomRight => rect.bottomRight,
    };
  }

  Rect _moveFrom(Rect base, Offset pixelDelta, Size size) {
    final dx = pixelDelta.dx / size.width;
    final dy = pixelDelta.dy / size.height;

    final left = (base.left + dx).clamp(0.0, 1.0 - base.width).toDouble();
    final top = (base.top + dy).clamp(0.0, 1.0 - base.height).toDouble();

    return Rect.fromLTWH(left, top, base.width, base.height);
  }

  Rect _resizeFrom(
    Rect base,
    _CropCorner corner,
    Offset pixelDelta,
    Size size,
    double? ratio,
  ) {
    final dx = pixelDelta.dx / size.width;
    final dy = pixelDelta.dy / size.height;

    if (ratio == null) {
      return _resizeFree(base, corner, dx, dy);
    }

    return _resizeLocked(base, corner, dx, dy, ratio);
  }

  Rect _resizeFree(
    Rect base,
    _CropCorner corner,
    double dx,
    double dy,
  ) {
    var left = base.left;
    var top = base.top;
    var right = base.right;
    var bottom = base.bottom;

    switch (corner) {
      case _CropCorner.topLeft:
        left = (left + dx).clamp(0.0, right - _minimumSize).toDouble();
        top = (top + dy).clamp(0.0, bottom - _minimumSize).toDouble();
        break;
      case _CropCorner.topRight:
        right = (right + dx).clamp(left + _minimumSize, 1.0).toDouble();
        top = (top + dy).clamp(0.0, bottom - _minimumSize).toDouble();
        break;
      case _CropCorner.bottomLeft:
        left = (left + dx).clamp(0.0, right - _minimumSize).toDouble();
        bottom = (bottom + dy)
            .clamp(top + _minimumSize, 1.0)
            .toDouble();
        break;
      case _CropCorner.bottomRight:
        right = (right + dx).clamp(left + _minimumSize, 1.0).toDouble();
        bottom = (bottom + dy)
            .clamp(top + _minimumSize, 1.0)
            .toDouble();
        break;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _resizeLocked(
    Rect base,
    _CropCorner corner,
    double dx,
    double dy,
    double ratio,
  ) {
    final horizontalSign =
        corner == _CropCorner.topLeft || corner == _CropCorner.bottomLeft
            ? -1.0
            : 1.0;
    final verticalSign =
        corner == _CropCorner.topLeft || corner == _CropCorner.topRight
            ? -1.0
            : 1.0;

    final widthDelta = dx * horizontalSign;
    final heightDelta = dy * verticalSign;

    double width;
    double height;
    if (widthDelta.abs() >= (heightDelta * ratio).abs()) {
      width = base.width + widthDelta;
      height = width / ratio;
    } else {
      height = base.height + heightDelta;
      width = height * ratio;
    }

    final anchor = switch (corner) {
      _CropCorner.topLeft => base.bottomRight,
      _CropCorner.topRight => base.bottomLeft,
      _CropCorner.bottomLeft => base.topRight,
      _CropCorner.bottomRight => base.topLeft,
    };

    final maxWidth = horizontalSign < 0 ? anchor.dx : 1 - anchor.dx;
    final maxHeight = verticalSign < 0 ? anchor.dy : 1 - anchor.dy;

    final minWidth = math.max(_minimumSize, _minimumSize * ratio);
    final availableWidth = math.min(maxWidth, maxHeight * ratio);
    width = width.clamp(minWidth, math.max(minWidth, availableWidth)).toDouble();
    height = width / ratio;

    final left = horizontalSign < 0 ? anchor.dx - width : anchor.dx;
    final top = verticalSign < 0 ? anchor.dy - height : anchor.dy;

    return Rect.fromLTWH(left, top, width, height);
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({
    required this.corner,
    required this.displayScale,
  });

  final _CropCorner corner;
  final double displayScale;

  @override
  Widget build(BuildContext context) {
    final length = 19.0 / displayScale;
    final thickness = 4.0 / displayScale;

    return SizedBox(
      width: length,
      height: length,
      child: Stack(
        children: [
          Positioned(
            left: corner == _CropCorner.topLeft ||
                    corner == _CropCorner.bottomLeft
                ? 0
                : null,
            right: corner == _CropCorner.topRight ||
                    corner == _CropCorner.bottomRight
                ? 0
                : null,
            top: 0,
            bottom: 0,
            width: thickness,
            child: const ColoredBox(color: Colors.white),
          ),
          Positioned(
            top: corner == _CropCorner.topLeft ||
                    corner == _CropCorner.topRight
                ? 0
                : null,
            bottom: corner == _CropCorner.bottomLeft ||
                    corner == _CropCorner.bottomRight
                ? 0
                : null,
            left: 0,
            right: 0,
            height: thickness,
            child: const ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.rect, this.displayScale);

  final Rect rect;
  final double displayScale;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );

    final shade = Paint()..color = const Color(0xA8000000);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, crop.top), shade);
    canvas.drawRect(
      Rect.fromLTRB(0, crop.bottom, size.width, size.height),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, crop.top, crop.left, crop.bottom),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(crop.right, crop.top, size.width, crop.bottom),
      shade,
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / displayScale;
    canvas.drawRect(crop, border);

    final grid = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1 / displayScale;

    for (var i = 1; i <= 2; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.displayScale != displayScale;
  }
}
