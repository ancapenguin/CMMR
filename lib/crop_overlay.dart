import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class CropOverlay extends StatelessWidget {
  const CropOverlay({
    required this.rect,
    required this.onChanged,
    this.lockedNormalizedAspectRatio,
    super.key,
  });

  final Rect rect;
  final ValueChanged<Rect> onChanged;

  /// Width / height in normalized video coordinates.
  /// Null means freeform resizing.
  final double? lockedNormalizedAspectRatio;

  static const _minimumSize = 0.08;
  static const _handleHitSize = 56.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pixelRect = Rect.fromLTRB(
          rect.left * size.width,
          rect.top * size.height,
          rect.right * size.width,
          rect.bottom * size.height,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropPainter(rect),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: pixelRect,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => _move(details.delta, size),
                child: const SizedBox.expand(),
              ),
            ),
            _handle(_CropCorner.topLeft, pixelRect.topLeft, size),
            _handle(_CropCorner.topRight, pixelRect.topRight, size),
            _handle(_CropCorner.bottomLeft, pixelRect.bottomLeft, size),
            _handle(_CropCorner.bottomRight, pixelRect.bottomRight, size),
          ],
        );
      },
    );
  }

  Widget _handle(_CropCorner corner, Offset center, Size size) {
    return Positioned(
      left: center.dx - _handleHitSize / 2,
      top: center.dy - _handleHitSize / 2,
      width: _handleHitSize,
      height: _handleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _resize(corner, details.delta, size),
        child: Center(
          child: _CornerMark(corner: corner),
        ),
      ),
    );
  }

  void _move(Offset delta, Size size) {
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    final left =
        (rect.left + dx).clamp(0.0, 1.0 - rect.width).toDouble();
    final top =
        (rect.top + dy).clamp(0.0, 1.0 - rect.height).toDouble();

    onChanged(Rect.fromLTWH(left, top, rect.width, rect.height));
  }

  void _resize(_CropCorner corner, Offset delta, Size size) {
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;
    final ratio = lockedNormalizedAspectRatio;

    if (ratio == null) {
      _resizeFree(corner, dx, dy);
      return;
    }

    _resizeLocked(corner, dx, dy, ratio);
  }

  void _resizeFree(_CropCorner corner, double dx, double dy) {
    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;

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
        bottom =
            (bottom + dy).clamp(top + _minimumSize, 1.0).toDouble();
        break;
      case _CropCorner.bottomRight:
        right = (right + dx).clamp(left + _minimumSize, 1.0).toDouble();
        bottom =
            (bottom + dy).clamp(top + _minimumSize, 1.0).toDouble();
        break;
    }

    onChanged(Rect.fromLTRB(left, top, right, bottom));
  }

  void _resizeLocked(
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
      width = rect.width + widthDelta;
      height = width / ratio;
    } else {
      height = rect.height + heightDelta;
      width = height * ratio;
    }

    final anchor = switch (corner) {
      _CropCorner.topLeft => rect.bottomRight,
      _CropCorner.topRight => rect.bottomLeft,
      _CropCorner.bottomLeft => rect.topRight,
      _CropCorner.bottomRight => rect.topLeft,
    };

    final maxWidth = horizontalSign < 0 ? anchor.dx : 1 - anchor.dx;
    final maxHeight = verticalSign < 0 ? anchor.dy : 1 - anchor.dy;

    final minWidth = math.max(_minimumSize, _minimumSize * ratio);
    width = width.clamp(minWidth, math.min(maxWidth, maxHeight * ratio));
    height = width / ratio;

    final left = horizontalSign < 0 ? anchor.dx - width : anchor.dx;
    final top = verticalSign < 0 ? anchor.dy - height : anchor.dy;

    onChanged(Rect.fromLTWH(left, top, width, height));
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.corner});

  final _CropCorner corner;

  @override
  Widget build(BuildContext context) {
    const length = 19.0;
    const thickness = 4.0;

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
  const _CropPainter(this.rect);

  final Rect rect;

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
      ..strokeWidth = 2;
    canvas.drawRect(crop, border);

    final grid = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1;

    for (var i = 1; i <= 2; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
