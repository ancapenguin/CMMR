import 'package:flutter/material.dart';

enum _CropCorner { topLeft, topRight, bottomLeft, bottomRight }

class CropOverlay extends StatelessWidget {
  const CropOverlay({
    required this.rect,
    required this.onChanged,
    super.key,
  });

  final Rect rect;
  final ValueChanged<Rect> onChanged;

  static const _minimumSize = 0.08;

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
              child: CustomPaint(
                painter: _CropShadePainter(rect),
              ),
            ),
            Positioned.fromRect(
              rect: pixelRect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => _move(details.delta, size),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
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
    const diameter = 28.0;
    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _resize(corner, details.delta, size),
        child: Center(
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
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
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    final paint = Paint()..color = const Color(0x99000000);

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, crop.top), paint);
    canvas.drawRect(
      Rect.fromLTRB(0, crop.bottom, size.width, size.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, crop.top, crop.left, crop.bottom),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(crop.right, crop.top, size.width, crop.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
