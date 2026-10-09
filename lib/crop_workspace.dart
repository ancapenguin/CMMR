import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'crop_overlay.dart';

class CropWorkspace extends StatefulWidget {
  const CropWorkspace({
    required this.controller,
    required this.crop,
    required this.onCropChanged,
    this.lockedNormalizedAspectRatio,
    this.onPrecisionPointChanged,
    this.onPrecisionEnd,
    super.key,
  });

  final VideoPlayerController controller;
  final Rect crop;
  final ValueChanged<Rect> onCropChanged;
  final double? lockedNormalizedAspectRatio;
  final ValueChanged<Offset>? onPrecisionPointChanged;
  final VoidCallback? onPrecisionEnd;

  @override
  State<CropWorkspace> createState() => _CropWorkspaceState();
}

class _CropWorkspaceState extends State<CropWorkspace> {
  final Map<int, Offset> _pointers = <int, Offset>{};

  double _manualScale = 1;
  Offset _focus = const Offset(0.5, 0.5);

  bool _pinching = false;
  double _pinchStartDistance = 0;
  double _pinchStartOverallScale = 1;
  Offset _pinchAnchorSource = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _focus = widget.crop.center;
  }

  @override
  void didUpdateWidget(covariant CropWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.crop != oldWidget.crop && !_pinching) {
      _manualScale = 1;
      _focus = widget.crop.center;
    }
  }

  double _autoScale(Rect crop) {
    const targetFraction = 0.76;
    final widthScale = targetFraction / crop.width.clamp(0.001, 1.0);
    final heightScale = targetFraction / crop.height.clamp(0.001, 1.0);
    return math.min(widthScale, heightScale).clamp(1.0, 6.0).toDouble();
  }

  double _overallScale() {
    return (_autoScale(widget.crop) * _manualScale)
        .clamp(1.0, 8.0)
        .toDouble();
  }

  Offset _clampFocus(Offset value, double scale) {
    if (scale <= 1.0001) return const Offset(0.5, 0.5);

    final halfVisible = 0.5 / scale;
    return Offset(
      value.dx.clamp(halfVisible, 1 - halfVisible).toDouble(),
      value.dy.clamp(halfVisible, 1 - halfVisible).toDouble(),
    );
  }

  Offset _sourceAtScreenPoint(Offset screen, Size size, double scale) {
    final viewportCenter = Offset(size.width / 2, size.height / 2);
    return Offset(
      _focus.dx + (screen.dx - viewportCenter.dx) / (scale * size.width),
      _focus.dy + (screen.dy - viewportCenter.dy) / (scale * size.height),
    );
  }

  void _pointerDown(PointerDownEvent event, Size size) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _beginPinch(size);
    }
  }

  void _pointerMove(PointerMoveEvent event, Size size) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pinching && _pointers.length >= 2) {
      _updatePinch(size);
    }
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _pinching) {
      setState(() => _pinching = false);
    }
  }

  void _beginPinch(Size size) {
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    if (distance <= 0) return;

    final center = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    final currentScale = _overallScale();

    setState(() {
      _pinching = true;
      _pinchStartDistance = distance;
      _pinchStartOverallScale = currentScale;
      _pinchAnchorSource = _sourceAtScreenPoint(center, size, currentScale);
    });
  }

  void _updatePinch(Size size) {
    final points = _pointers.values.take(2).toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    if (_pinchStartDistance <= 0 || distance <= 0) return;

    final center = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );

    final nextScale =
        (_pinchStartOverallScale * distance / _pinchStartDistance)
            .clamp(1.0, 8.0)
            .toDouble();

    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final nextFocus = Offset(
      _pinchAnchorSource.dx -
          (center.dx - viewportCenter.dx) / (nextScale * size.width),
      _pinchAnchorSource.dy -
          (center.dy - viewportCenter.dy) / (nextScale * size.height),
    );

    final autoScale = _autoScale(widget.crop);
    setState(() {
      _manualScale = nextScale / autoScale;
      _focus = _clampFocus(nextFocus, nextScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = _overallScale();
        final focus = _clampFocus(_focus, scale);

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
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _pointerDown(event, size),
            onPointerMove: (event) => _pointerMove(event, size),
            onPointerUp: _pointerUp,
            onPointerCancel: _pointerUp,
            child: Transform(
              key: const ValueKey('crop-workspace-transform'),
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
                    CropOverlay(
                      rect: widget.crop,
                      lockedNormalizedAspectRatio:
                          widget.lockedNormalizedAspectRatio,
                      workspaceScale: scale,
                      enabled: !_pinching,
                      onChanged: widget.onCropChanged,
                      onPrecisionPointChanged:
                          widget.onPrecisionPointChanged,
                      onPrecisionEnd: widget.onPrecisionEnd,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
