import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'crop_overlay.dart';
import 'media_exporter.dart';
import 'trim_timeline.dart';

enum _EditorTool { trim, crop }

class VideoCutterPage extends StatefulWidget {
  const VideoCutterPage({super.key});

  @override
  State<VideoCutterPage> createState() => _VideoCutterPageState();
}

class _VideoCutterPageState extends State<VideoCutterPage> {
  final _exporter = MediaExporter();

  VideoPlayerController? _controller;
  String? _inputPath;
  String? _fileName;
  RangeValues _trim = const RangeValues(0, 1);
  Rect _crop = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
  double? _cropAspectRatio;
  bool _cropEnabled = false;
  bool _fastTrim = true;
  bool _exporting = false;
  double _progress = 0;
  _EditorTool _tool = _EditorTool.trim;
  List<Uint8List?> _thumbnails = const [];

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_exporting) {
      return;
    }

    final picked = await FilePicker.pickFile(type: FileType.video);
    final path = picked?.path;
    if (picked == null || path == null) {
      if (picked != null) {
        _notify('Bu dosya için kullanılabilir yerel yol alınamadı.');
      }
      return;
    }

    final next = VideoPlayerController.file(File(path));
    try {
      await next.initialize();
      await next.setLooping(false);
    } catch (error) {
      await next.dispose();
      _notify('Video açılamadı: $error');
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
      _crop = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
      _cropAspectRatio = null;
      _cropEnabled = false;
      _fastTrim = true;
      _tool = _EditorTool.trim;
      _progress = 0;
      _thumbnails = const [];
    });

    await old?.dispose();
    _generateThumbnails(path, next.value.duration);
  }

  Future<void> _generateThumbnails(String path, Duration duration) async {
    const count = 9;
    final generated = <Uint8List?>[];

    for (var i = 0; i < count; i++) {
      try {
        final timeMs =
            (((i + 0.5) / count) * duration.inMilliseconds).round();
        generated.add(
          await VideoThumbnail.thumbnailData(
            video: path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 110,
            timeMs: timeMs,
            quality: 58,
          ),
        );
      } catch (_) {
        generated.add(null);
      }
    }

    if (!mounted || _inputPath != path) {
      return;
    }
    setState(() => _thumbnails = generated);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

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

    if (mounted) {
      setState(() {});
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _seek(double seconds) async {
    await _controller?.seekTo(_durationFromSeconds(seconds));
  }

  void _setTrimStart(double start) {
    setState(() => _trim = RangeValues(start, _trim.end));
    _seek(start);
  }

  void _setTrimEnd(double end) {
    setState(() => _trim = RangeValues(_trim.start, end));
    _seek(end);
  }

  void _selectTool(_EditorTool tool) {
    setState(() {
      _tool = tool;
      if (tool == _EditorTool.crop) {
        _cropEnabled = true;
      }
    });
  }

  double? get _lockedNormalizedCropRatio {
    final controller = _controller;
    final target = _cropAspectRatio;
    if (controller == null || target == null) {
      return null;
    }

    final source = controller.value.size;
    if (source.width <= 0 || source.height <= 0) {
      return null;
    }
    return target / (source.width / source.height);
  }

  void _setCropPreset(double? targetAspectRatio) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (targetAspectRatio == null) {
      setState(() {
        _cropEnabled = true;
        _cropAspectRatio = null;
      });
      return;
    }

    final source = controller.value.size;
    if (source.width <= 0 || source.height <= 0) {
      return;
    }

    final normalizedRatio =
        targetAspectRatio / (source.width / source.height);
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
      _cropAspectRatio = targetAspectRatio;
      _crop = Rect.fromLTWH(
        (1 - width) / 2,
        (1 - height) / 2,
        width,
        height,
      );
    });
  }

  void _removeCrop() {
    setState(() {
      _cropEnabled = false;
      _cropAspectRatio = null;
      _crop = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
      _tool = _EditorTool.trim;
    });
  }

  Future<void> _export() async {
    final controller = _controller;
    final inputPath = _inputPath;
    if (controller == null || inputPath == null || _exporting) {
      return;
    }

    final sourceSize = controller.value.size;
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      _notify('Video boyutu okunamadı.');
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
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );

      if (!mounted) {
        return;
      }

      final mode = !result.reencoded
          ? 'Kayıpsız hızlı kesim'
          : result.usedSoftwareFallback
              ? 'Yazılımsal yeniden kodlama'
              : 'Donanım hızlandırmalı yeniden kodlama';
      _notify('Galeriye kaydedildi · $mode');
    } catch (error) {
      if (mounted) {
        _notify('Dışa aktarma başarısız: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
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

    width = width ~/ 2 * 2;
    height = height ~/ 2 * 2;

    return CropPixels(width: width, height: height, x: x, y: y);
  }

  Duration _durationFromSeconds(double seconds) {
    return Duration(microseconds: (seconds * 1000000).round());
  }

  String _formatTime(double seconds) {
    final totalTenths = (seconds * 10).round();
    final totalSeconds = totalTenths ~/ 10;
    final tenths = totalTenths % 10;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}.$tenths';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.$tenths';
  }

  void _notify(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller == null ? 'CMMR Cut' : (_fileName ?? 'CMMR Cut'),
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
            IconButton.filled(
              tooltip: 'Galeriye kaydet',
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.check_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: controller == null
          ? _EmptyState(onPick: _pickVideo)
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final durationSeconds = math
                    .max(
                      0.001,
                      value.duration.inMilliseconds / 1000.0,
                    )
                    .toDouble();
                final positionSeconds =
                    value.position.inMilliseconds / 1000.0;

                return _Editor(
                  controller: controller,
                  value: value,
                  durationSeconds: durationSeconds,
                  positionSeconds: positionSeconds,
                  trim: _trim,
                  crop: _crop,
                  cropEnabled: _cropEnabled,
                  lockedNormalizedCropRatio: _lockedNormalizedCropRatio,
                  cropAspectRatio: _cropAspectRatio,
                  fastTrim: _fastTrim,
                  tool: _tool,
                  thumbnails: _thumbnails,
                  exporting: _exporting,
                  progress: _progress,
                  formatTime: _formatTime,
                  onTogglePlayback: _togglePlayback,
                  onSeek: _seek,
                  onTrimStartChanged: _setTrimStart,
                  onTrimEndChanged: _setTrimEnd,
                  onToolChanged: _selectTool,
                  onCropChanged: (value) => setState(() => _crop = value),
                  onCropPreset: _setCropPreset,
                  onRemoveCrop: _removeCrop,
                  onFastTrimChanged: (value) {
                    setState(() => _fastTrim = value);
                  },
                );
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
                'Zamanı kes veya görüntü alanını kırp. '
                'İşlem cihazda kalır.',
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
    required this.value,
    required this.durationSeconds,
    required this.positionSeconds,
    required this.trim,
    required this.crop,
    required this.cropEnabled,
    required this.lockedNormalizedCropRatio,
    required this.cropAspectRatio,
    required this.fastTrim,
    required this.tool,
    required this.thumbnails,
    required this.exporting,
    required this.progress,
    required this.formatTime,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onTrimStartChanged,
    required this.onTrimEndChanged,
    required this.onToolChanged,
    required this.onCropChanged,
    required this.onCropPreset,
    required this.onRemoveCrop,
    required this.onFastTrimChanged,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final double durationSeconds;
  final double positionSeconds;
  final RangeValues trim;
  final Rect crop;
  final bool cropEnabled;
  final double? lockedNormalizedCropRatio;
  final double? cropAspectRatio;
  final bool fastTrim;
  final _EditorTool tool;
  final List<Uint8List?> thumbnails;
  final bool exporting;
  final double progress;
  final String Function(double) formatTime;
  final VoidCallback onTogglePlayback;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onTrimStartChanged;
  final ValueChanged<double> onTrimEndChanged;
  final ValueChanged<_EditorTool> onToolChanged;
  final ValueChanged<Rect> onCropChanged;
  final ValueChanged<double?> onCropPreset;
  final VoidCallback onRemoveCrop;
  final ValueChanged<bool> onFastTrimChanged;

  @override
  Widget build(BuildContext context) {
    final sourceAspect = value.size.height <= 0
        ? 16 / 9
        : value.size.width / value.size.height;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _VideoStage(
              controller: controller,
              aspectRatio: sourceAspect,
              showCrop: tool == _EditorTool.crop && cropEnabled,
              crop: crop,
              lockedNormalizedCropRatio: lockedNormalizedCropRatio,
              onCropChanged: onCropChanged,
              onTapVideo:
                  tool == _EditorTool.trim && !exporting ? onTogglePlayback : null,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF151B1F),
              border: Border(
                top: BorderSide(color: Color(0xFF2B3238)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: exporting ? null : onTogglePlayback,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTime(positionSeconds),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${formatTime(trim.start)} — ${formatTime(trim.end)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TrimTimeline(
                  durationSeconds: durationSeconds,
                  startSeconds: trim.start,
                  endSeconds: trim.end,
                  positionSeconds: positionSeconds,
                  thumbnails: thumbnails,
                  onStartChanged: onTrimStartChanged,
                  onEndChanged: onTrimEndChanged,
                  onSeek: onSeek,
                ),
                const SizedBox(height: 12),
                SegmentedButton<_EditorTool>(
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
                  selected: {tool},
                  onSelectionChanged: exporting
                      ? null
                      : (selection) => onToolChanged(selection.first),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: tool == _EditorTool.trim
                      ? _TrimControls(
                          key: const ValueKey('trim'),
                          fastTrim: fastTrim,
                          cropEnabled: cropEnabled,
                          exporting: exporting,
                          onChanged: onFastTrimChanged,
                        )
                      : _CropControls(
                          key: const ValueKey('crop'),
                          sourceAspect: sourceAspect,
                          selectedAspect: cropAspectRatio,
                          exporting: exporting,
                          onPreset: onCropPreset,
                          onRemove: onRemoveCrop,
                        ),
                ),
                if (exporting) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.controller,
    required this.aspectRatio,
    required this.showCrop,
    required this.crop,
    required this.lockedNormalizedCropRatio,
    required this.onCropChanged,
    required this.onTapVideo,
  });

  final VideoPlayerController controller;
  final double aspectRatio;
  final bool showCrop;
  final Rect crop;
  final double? lockedNormalizedCropRatio;
  final ValueChanged<Rect> onCropChanged;
  final VoidCallback? onTapVideo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          var width = maxWidth;
          var height = width / aspectRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * aspectRatio;
          }

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapVideo,
                    child: VideoPlayer(controller),
                  ),
                  if (showCrop)
                    CropOverlay(
                      rect: crop,
                      lockedNormalizedAspectRatio:
                          lockedNormalizedCropRatio,
                      onChanged: onCropChanged,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrimControls extends StatelessWidget {
  const _TrimControls({
    required this.fastTrim,
    required this.cropEnabled,
    required this.exporting,
    required this.onChanged,
    super.key,
  });

  final bool fastTrim;
  final bool cropEnabled;
  final bool exporting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final forcedExact = cropEnabled;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Kayıpsız hızlı'),
                selected: fastTrim && !forcedExact,
                onSelected: exporting || forcedExact
                    ? null
                    : (_) => onChanged(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Kare hassas'),
                selected: !fastTrim || forcedExact,
                onSelected:
                    exporting ? null : (_) => onChanged(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          forcedExact
              ? 'Görüntü kırpma açık: yeniden kodlama zorunlu.'
              : fastTrim
                  ? 'Kalite kaybı yok; başlangıç keyframe’e kayabilir.'
                  : 'Kesim hassas; seçilen bölüm yeniden kodlanır.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CropControls extends StatelessWidget {
  const _CropControls({
    required this.sourceAspect,
    required this.selectedAspect,
    required this.exporting,
    required this.onPreset,
    required this.onRemove,
    super.key,
  });

  final double sourceAspect;
  final double? selectedAspect;
  final bool exporting;
  final ValueChanged<double?> onPreset;
  final VoidCallback onRemove;

  bool _selected(double value) {
    final selected = selectedAspect;
    return selected != null && (selected - value).abs() < 0.001;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('Serbest'),
                selected: selectedAspect == null,
                onSelected: exporting ? null : (_) => onPreset(null),
              ),
              const SizedBox(width: 7),
              ChoiceChip(
                label: const Text('Orijinal'),
                selected: _selected(sourceAspect),
                onSelected:
                    exporting ? null : (_) => onPreset(sourceAspect),
              ),
              const SizedBox(width: 7),
              for (final preset in const [
                (1.0, '1:1'),
                (4 / 5, '4:5'),
                (3 / 4, '3:4'),
                (9 / 16, '9:16'),
                (16 / 9, '16:9'),
              ]) ...[
                ChoiceChip(
                  avatar: _selected(preset.$1)
                      ? const Icon(Icons.lock_rounded, size: 16)
                      : null,
                  label: Text(preset.$2),
                  selected: _selected(preset.$1),
                  onSelected:
                      exporting ? null : (_) => onPreset(preset.$1),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.open_with_rounded, size: 17, color: Colors.white54),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'İçeriden sürükle; köşelerin dokunma alanı büyütüldü.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: exporting ? null : onRemove,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Kaldır'),
            ),
          ],
        ),
      ],
    );
  }
}
