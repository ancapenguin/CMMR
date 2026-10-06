import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'crop_overlay.dart';
import 'media_exporter.dart';
import 'timeline_thumbnail_service.dart';
import 'trim_timeline.dart';

enum _EditorTool { trim, crop }

class VideoCutterPage extends StatefulWidget {
  const VideoCutterPage({super.key});

  @override
  State<VideoCutterPage> createState() => _VideoCutterPageState();
}

class _VideoCutterPageState extends State<VideoCutterPage> {
  final _exporter = MediaExporter();
  final _thumbnailService = TimelineThumbnailService();

  VideoPlayerController? _controller;
  String? _inputPath;
  String? _fileName;
  RangeValues _trim = const RangeValues(0, 1);
  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);
  double? _cropAspectRatio;
  Offset? _cropPrecisionPoint;
  List<String> _timelineThumbnails = const [];
  _EditorTool _activeTool = _EditorTool.trim;
  bool _cropEnabled = false;

  // Exact is the safe default. Fast mode is opt-in because stream copy starts
  // on codec keyframes and therefore may not begin on the exact requested frame.
  bool _fastTrim = false;

  bool _exporting = false;
  double _progress = 0;
  String? _message;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_exporting) return;

    final picked = await FilePicker.pickFile(type: FileType.video);
    final path = picked?.path;
    if (picked == null || path == null) {
      if (picked != null) {
        _setMessage('Bu dosya için kullanılabilir yerel yol alınamadı.');
      }
      return;
    }

    final next = VideoPlayerController.file(File(path));
    try {
      await next.initialize();
      await next.setLooping(false);
    } catch (error) {
      await next.dispose();
      _setMessage('Video açılamadı: $error');
      return;
    }

    final old = _controller;
    final durationSeconds = math
        .max(0.001, next.value.duration.inMilliseconds / 1000.0)
        .toDouble();

    if (!mounted) {
      await next.dispose();
      return;
    }

    setState(() {
      _controller = next;
      _inputPath = path;
      _fileName = picked.name;
      _trim = RangeValues(0, durationSeconds);
      _crop = const Rect.fromLTWH(0, 0, 1, 1);
      _cropAspectRatio = null;
      _cropPrecisionPoint = null;
      _cropEnabled = false;
      _fastTrim = false;
      _activeTool = _EditorTool.trim;
      _timelineThumbnails = const [];
      _message = null;
      _progress = 0;
    });

    await old?.dispose();
    _loadTimelineThumbnails(path, next.value.duration);
  }

  Future<void> _loadTimelineThumbnails(
    String path,
    Duration duration,
  ) async {
    final seconds =
        duration.inMilliseconds / Duration.millisecondsPerSecond;
    final thumbnailCount =
        (seconds * 1.5).round().clamp(12, 80).toInt();

    final thumbnails = await _thumbnailService.generate(
      inputPath: path,
      duration: duration,
      count: thumbnailCount,
    );

    if (!mounted || _inputPath != path) return;
    setState(() => _timelineThumbnails = thumbnails);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      final position = controller.value.position.inMilliseconds / 1000.0;
      if (position < _trim.start || position >= _trim.end) {
        await controller.seekTo(_durationFromSeconds(_trim.start));
      }
      await controller.play();
      _watchTrimEnd(controller);
    }
  }

  Future<void> _watchTrimEnd(VideoPlayerController controller) async {
    while (mounted &&
        identical(controller, _controller) &&
        controller.value.isPlaying) {
      final seconds = controller.value.position.inMilliseconds / 1000.0;
      if (seconds >= _trim.end) {
        await controller.pause();
        await controller.seekTo(_durationFromSeconds(_trim.start));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _setTrim(RangeValues values) {
    if (values.end - values.start < 0.05) return;
    setState(() => _trim = values);
  }

  Future<void> _seek(double seconds) async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    }
    await controller.seekTo(_durationFromSeconds(seconds));
  }

  Future<void> _stepBy(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    }

    final current = controller.value.position.inMicroseconds;
    final target = (current + delta.inMicroseconds).clamp(
      _durationFromSeconds(_trim.start).inMicroseconds,
      _durationFromSeconds(_trim.end).inMicroseconds,
    );

    await controller.seekTo(Duration(microseconds: target));
  }

  void _selectTool(_EditorTool tool) {
    setState(() {
      _activeTool = tool;
      if (tool != _EditorTool.crop) {
        _cropPrecisionPoint = null;
      }
    });
  }

  void _setCropPreset(double? targetAspectRatio) {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _cropAspectRatio = targetAspectRatio;
    });

    if (targetAspectRatio == null) return;

    final source = controller.value.size;
    if (source.width <= 0 || source.height <= 0) return;

    final sourceAspect = source.width / source.height;
    final normalizedRatio = targetAspectRatio / sourceAspect;
    const maximum = 0.92;

    late final double width;
    late final double height;
    if (normalizedRatio >= 1) {
      width = maximum;
      height = maximum / normalizedRatio;
    } else {
      height = maximum;
      width = maximum * normalizedRatio;
    }

    setState(() {
      _cropEnabled = true;
      _crop = Rect.fromLTWH(
        (1 - width) / 2,
        (1 - height) / 2,
        width,
        height,
      );
    });
  }

  void _resetCrop() {
    setState(() {
      _cropEnabled = false;
      _cropAspectRatio = null;
      _cropPrecisionPoint = null;
      _crop = const Rect.fromLTWH(0, 0, 1, 1);
    });
  }

  Future<void> _export() async {
    final controller = _controller;
    final inputPath = _inputPath;
    if (controller == null || inputPath == null || _exporting) return;

    final sourceSize = controller.value.size;
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      _setMessage('Video boyutu okunamadı.');
      return;
    }

    final sourceWidth = sourceSize.width.round();
    final sourceHeight = sourceSize.height.round();
    final crop = _cropEnabled
        ? _cropPixels(_crop, sourceWidth, sourceHeight)
        : null;

    setState(() {
      _exporting = true;
      _progress = 0;
      _message = null;
    });

    try {
      final result = await _exporter.export(
        MediaExportRequest(
          inputPath: inputPath,
          start: _durationFromSeconds(_trim.start),
          end: _durationFromSeconds(_trim.end),
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          fastTrim: _fastTrim && !_cropEnabled,
          crop: crop,
        ),
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );

      if (!mounted) return;

      setState(() {
        final mode = !result.reencoded
            ? 'Hızlı kayıpsız trim'
            : result.usedSoftwareFallback
                ? 'Yazılımsal yeniden kodlama'
                : 'Donanım hızlandırmalı yeniden kodlama';
        _message = 'Galeriye kaydedildi · $mode';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Dışa aktarma başarısız: $error');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  CropPixels _cropPixels(Rect rect, int sourceWidth, int sourceHeight) {
    int evenFloor(double value) {
      final even = value.floor() ~/ 2 * 2;
      return even < 2 ? 2 : even;
    }

    var x = evenFloor(rect.left * sourceWidth);
    var y = evenFloor(rect.top * sourceHeight);
    var width = evenFloor(rect.width * sourceWidth);
    var height = evenFloor(rect.height * sourceHeight);

    final maxWidth = sourceWidth ~/ 2 * 2;
    final maxHeight = sourceHeight ~/ 2 * 2;

    x = x.clamp(0, math.max(0, maxWidth - 2)).toInt();
    y = y.clamp(0, math.max(0, maxHeight - 2)).toInt();
    width = width.clamp(2, math.max(2, maxWidth - x)).toInt();
    height = height.clamp(2, math.max(2, maxHeight - y)).toInt();

    return CropPixels(
      width: width ~/ 2 * 2,
      height: height ~/ 2 * 2,
      x: x,
      y: y,
    );
  }

  bool _isFullFrameCrop(Rect rect) {
    const epsilon = 0.0001;
    return rect.left.abs() < epsilon &&
        rect.top.abs() < epsilon &&
        (rect.right - 1).abs() < epsilon &&
        (rect.bottom - 1).abs() < epsilon;
  }

  Duration _durationFromSeconds(double seconds) {
    return Duration(microseconds: (seconds * 1000000).round());
  }

  void _setMessage(String message) {
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller == null ? 'CMMR Cut' : (_fileName ?? 'Video'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: 'Başka video seç',
              onPressed: _exporting ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
            ),
          if (controller != null)
            TextButton(
              onPressed: _exporting ? null : _export,
              child: const Text('Kaydet'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: controller == null
          ? _EmptyState(onPick: _pickVideo)
          : _Editor(
              controller: controller,
              trim: _trim,
              crop: _crop,
              cropEnabled: _cropEnabled,
              cropAspectRatio: _cropAspectRatio,
              cropPrecisionPoint: _cropPrecisionPoint,
              activeTool: _activeTool,
              fastTrim: _fastTrim,
              exporting: _exporting,
              progress: _progress,
              message: _message,
              thumbnailPaths: _timelineThumbnails,
              onTogglePlayback: _togglePlayback,
              onStepBackward: () =>
                  _stepBy(const Duration(milliseconds: -100)),
              onStepForward: () =>
                  _stepBy(const Duration(milliseconds: 100)),
              onTrimChanged: _setTrim,
              onSeek: _seek,
              onToolChanged: _selectTool,
              onCropChanged: (value) {
                setState(() {
                  _crop = value;
                  _cropEnabled = !_isFullFrameCrop(value);
                });
              },
              onCropPreset: _setCropPreset,
              onCropPrecisionPointChanged: (value) {
                setState(() => _cropPrecisionPoint = value);
              },
              onCropPrecisionEnd: () {
                setState(() => _cropPrecisionPoint = null);
              },
              onResetCrop: _resetCrop,
              onFastTrimChanged: (value) {
                setState(() => _fastTrim = value);
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.content_cut_rounded, size: 64),
              const SizedBox(height: 22),
              Text(
                'İki türlü kırp.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Videonun zamanını kısalt veya görüntünün istediğin '
                'bölgesini bırak. İşlem cihazda yapılır.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.video_file_outlined),
                label: const Text('Video seç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.controller,
    required this.trim,
    required this.crop,
    required this.cropEnabled,
    required this.cropAspectRatio,
    required this.cropPrecisionPoint,
    required this.activeTool,
    required this.fastTrim,
    required this.exporting,
    required this.progress,
    required this.message,
    required this.thumbnailPaths,
    required this.onTogglePlayback,
    required this.onStepBackward,
    required this.onStepForward,
    required this.onTrimChanged,
    required this.onSeek,
    required this.onToolChanged,
    required this.onCropChanged,
    required this.onCropPreset,
    required this.onCropPrecisionPointChanged,
    required this.onCropPrecisionEnd,
    required this.onResetCrop,
    required this.onFastTrimChanged,
  });

  final VideoPlayerController controller;
  final RangeValues trim;
  final Rect crop;
  final bool cropEnabled;
  final double? cropAspectRatio;
  final Offset? cropPrecisionPoint;
  final _EditorTool activeTool;
  final bool fastTrim;
  final bool exporting;
  final double progress;
  final String? message;
  final List<String> thumbnailPaths;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;
  final ValueChanged<RangeValues> onTrimChanged;
  final ValueChanged<double> onSeek;
  final ValueChanged<_EditorTool> onToolChanged;
  final ValueChanged<Rect> onCropChanged;
  final ValueChanged<double?> onCropPreset;
  final ValueChanged<Offset> onCropPrecisionPointChanged;
  final VoidCallback onCropPrecisionEnd;
  final VoidCallback onResetCrop;
  final ValueChanged<bool> onFastTrimChanged;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = math
        .max(0.001, controller.value.duration.inMilliseconds / 1000.0)
        .toDouble();
    final sourceAspect = controller.value.size.height == 0
        ? controller.value.aspectRatio
        : controller.value.size.width / controller.value.size.height;
    final lockedNormalizedAspectRatio =
        cropAspectRatio == null || sourceAspect <= 0
            ? null
            : cropAspectRatio! / sourceAspect;

    final videoAspect =
        controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = math.max(1.0, constraints.maxWidth - 20);
          final trimCanvasHeight = math.min(
            availableWidth / videoAspect,
            constraints.maxHeight * 0.46,
          );

          Widget videoCanvas() {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                  maxHeight: 720,
                ),
                child: AspectRatio(
                  aspectRatio: videoAspect,
                  child: LayoutBuilder(
                    builder: (context, canvasConstraints) {
                      final canvasSize = Size(
                        canvasConstraints.maxWidth,
                        canvasConstraints.maxHeight,
                      );

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.black),
                            VideoPlayer(controller),
                            if (activeTool == _EditorTool.crop)
                              CropOverlay(
                                rect: crop,
                                lockedNormalizedAspectRatio:
                                    lockedNormalizedAspectRatio,
                                onChanged: onCropChanged,
                                onPrecisionPointChanged:
                                    onCropPrecisionPointChanged,
                                onPrecisionEnd: onCropPrecisionEnd,
                              ),
                            if (activeTool == _EditorTool.crop &&
                                cropPrecisionPoint != null)
                              _CropPrecisionLoupe(
                                controller: controller,
                                point: cropPrecisionPoint!,
                                canvasSize: canvasSize,
                              ),
                            if (activeTool == _EditorTool.crop)
                              Positioned(
                                left: 10,
                                bottom: 10,
                                child:
                                    ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: controller,
                                  builder: (context, value, _) {
                                    return IconButton.filledTonal(
                                      tooltip: value.isPlaying
                                          ? 'Duraklat'
                                          : 'Oynat',
                                      onPressed:
                                          exporting ? null : onTogglePlayback,
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              if (activeTool == _EditorTool.crop)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: videoCanvas(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: SizedBox(
                    height: trimCanvasHeight,
                    width: double.infinity,
                    child: videoCanvas(),
                  ),
                ),
              if (activeTool == _EditorTool.trim)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: _TransportBar(
                    controller: controller,
                    disabled: exporting,
                    onTogglePlayback: onTogglePlayback,
                    onStepBackward: onStepBackward,
                    onStepForward: onStepForward,
                  ),
                ),
              if (activeTool == _EditorTool.trim)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      return TrimTimeline(
                        durationSeconds: durationSeconds,
                        range: trim,
                        positionSeconds:
                            value.position.inMilliseconds / 1000.0,
                        thumbnailPaths: thumbnailPaths,
                        onRangeChanged: onTrimChanged,
                        onSeek: onSeek,
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SegmentedButton<_EditorTool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _EditorTool.trim,
                      icon: Icon(Icons.content_cut_rounded),
                      label: Text('Kes'),
                    ),
                    ButtonSegment(
                      value: _EditorTool.crop,
                      icon: Icon(Icons.crop_rounded),
                      label: Text('Kırp'),
                    ),
                  ],
                  selected: {activeTool},
                  onSelectionChanged: exporting
                      ? null
                      : (selection) => onToolChanged(selection.first),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: activeTool == _EditorTool.trim
                    ? _TrimPanel(
                        key: const ValueKey('trim'),
                        fastTrim: fastTrim,
                        cropEnabled: cropEnabled,
                        onChanged: onFastTrimChanged,
                      )
                    : _CropPanel(
                        key: const ValueKey('crop'),
                        enabled: cropEnabled,
                        aspectRatio: cropAspectRatio,
                        onPreset: onCropPreset,
                        onReset: onResetCrop,
                      ),
              ),
              if (exporting)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                  ),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Text(
                    message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: message!.startsWith('Dışa')
                          ? Theme.of(context).colorScheme.error
                          : Colors.white70,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.controller,
    required this.disabled,
    required this.onTogglePlayback,
    required this.onStepBackward,
    required this.onStepForward,
  });

  final VideoPlayerController controller;
  final bool disabled;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final current = value.position;
        final duration = value.duration;

        return SizedBox(
          height: 42,
          child: Row(
            children: [
              TextButton(
                onPressed: disabled ? null : onStepBackward,
                child: const Text('−0.1'),
              ),
              IconButton.filledTonal(
                tooltip: value.isPlaying ? 'Duraklat' : 'Oynat',
                visualDensity: VisualDensity.compact,
                onPressed: disabled ? null : onTogglePlayback,
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              TextButton(
                onPressed: disabled ? null : onStepForward,
                child: const Text('+0.1'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatTransportTime(current)} / '
                  '${_formatTransportTime(duration)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                        color: Colors.white70,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatTransportTime(Duration value) {
  final totalMilliseconds = math.max(0, value.inMilliseconds);
  final minutes = totalMilliseconds ~/ 60000;
  final seconds = (totalMilliseconds ~/ 1000) % 60;
  final hundredths = (totalMilliseconds % 1000) ~/ 10;

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${hundredths.toString().padLeft(2, '0')}';
}

class _CropPrecisionLoupe extends StatelessWidget {
  const _CropPrecisionLoupe({
    required this.controller,
    required this.point,
    required this.canvasSize,
  });

  final VideoPlayerController controller;
  final Offset point;
  final Size canvasSize;

  static const double _diameter = 108;
  static const double _scale = 3;

  @override
  Widget build(BuildContext context) {
    final maxLeft = math.max(10.0, canvasSize.width - _diameter - 10);
    final left = (point.dx * canvasSize.width - _diameter / 2)
        .clamp(10.0, maxLeft)
        .toDouble();

    final top = point.dy < 0.5
        ? math.max(10.0, canvasSize.height - _diameter - 10)
        : 10.0;

    final scaledWidth = canvasSize.width * _scale;
    final scaledHeight = canvasSize.height * _scale;
    final sourceLeft = _diameter / 2 - point.dx * scaledWidth;
    final sourceTop = _diameter / 2 - point.dy * scaledHeight;

    return Positioned(
      key: const ValueKey('crop-precision-loupe'),
      left: left,
      top: top,
      width: _diameter,
      height: _diameter,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: sourceLeft,
                  top: sourceTop,
                  width: scaledWidth,
                  height: scaledHeight,
                  child: VideoPlayer(controller),
                ),
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: _LoupeCrosshairPainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoupeCrosshairPainter extends CustomPainter {
  const _LoupeCrosshairPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black54
      ..strokeWidth = 3;
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      shadow,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      shadow,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      line,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _LoupeCrosshairPainter oldDelegate) => false;
}

class _TrimPanel extends StatelessWidget {
  const _TrimPanel({
    required this.fastTrim,
    required this.cropEnabled,
    required this.onChanged,
    super.key,
  });

  final bool fastTrim;
  final bool cropEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _ModeChoice(
              selected: !fastTrim,
              title: 'Kesin',
              subtitle: cropEnabled
                  ? 'Kırpma nedeniyle zaten yeniden kodlanacak'
                  : 'Tam karede keser',
              onTap: cropEnabled ? null : () => onChanged(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeChoice(
              selected: fastTrim && !cropEnabled,
              title: 'Hızlı',
              subtitle: 'Kayıpsız · keyframe sınırı',
              onTap: cropEnabled ? null : () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropPanel extends StatelessWidget {
  const _CropPanel({
    required this.enabled,
    required this.aspectRatio,
    required this.onPreset,
    required this.onReset,
    super.key,
  });

  final bool enabled;
  final double? aspectRatio;
  final ValueChanged<double?> onPreset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final presets = <(String, double?)>[
      ('Serbest', null),
      ('1:1', 1),
      ('4:5', 4 / 5),
      ('3:4', 3 / 4),
      ('9:16', 9 / 16),
      ('16:9', 16 / 9),
      ('4:3', 4 / 3),
    ];

    bool selected(double? value) {
      if (value == null || aspectRatio == null) return value == aspectRatio;
      return (value - aspectRatio!).abs() < 0.0001;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return ChoiceChip(
                    label: Text(preset.$1),
                    selected: enabled && selected(preset.$2),
                    onSelected: (_) => onPreset(preset.$2),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Kırpmayı sıfırla',
            onPressed: enabled ? onReset : null,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
    );
  }
}
