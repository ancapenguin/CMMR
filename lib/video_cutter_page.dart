import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'crop_overlay.dart';
import 'media_exporter.dart';

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
  Rect _crop = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
  bool _cropEnabled = false;
  bool _fastTrim = true;
  bool _exporting = false;
  double _progress = 0;
  String? _message;

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
      _crop = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
      _cropEnabled = false;
      _fastTrim = true;
      _message = null;
      _progress = 0;
    });

    await old?.dispose();
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
        if (mounted) {
          setState(() {});
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  void _setTrim(RangeValues values) {
    if (values.end - values.start < 0.05) {
      return;
    }
    setState(() => _trim = values);
  }

  Future<void> _seekToTrimStart() async {
    await _controller?.seekTo(_durationFromSeconds(_trim.start));
  }

  void _setCropPreset(double targetAspectRatio) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final source = controller.value.size;
    if (source.width <= 0 || source.height <= 0) {
      return;
    }

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

  Future<void> _export() async {
    final controller = _controller;
    final inputPath = _inputPath;
    if (controller == null || inputPath == null || _exporting) {
      return;
    }

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
          if (mounted) {
            setState(() => _progress = value);
          }
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final mode = !result.reencoded
            ? 'Hızlı, yeniden kodlamasız trim'
            : result.usedSoftwareFallback
                ? 'Yazılımsal yeniden kodlama'
                : 'Donanım hızlandırmalı yeniden kodlama';
        _message = 'Galeriye kaydedildi. $mode kullanıldı.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Dışa aktarma başarısız: $error');
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

  void _setMessage(String message) {
    if (mounted) {
      setState(() => _message = message);
    }
  }

  String _formatTime(double seconds) {
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CMMR Cut'),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: 'Başka video seç',
              onPressed: _exporting ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
            ),
        ],
      ),
      body: controller == null
          ? _EmptyState(onPick: _pickVideo)
          : _Editor(
              controller: controller,
              fileName: _fileName ?? 'Video',
              trim: _trim,
              crop: _crop,
              cropEnabled: _cropEnabled,
              fastTrim: _fastTrim,
              exporting: _exporting,
              progress: _progress,
              message: _message,
              formatTime: _formatTime,
              onTogglePlayback: _togglePlayback,
              onTrimChanged: _setTrim,
              onTrimChangeEnd: (_) => _seekToTrimStart(),
              onCropEnabledChanged: (value) {
                setState(() => _cropEnabled = value);
              },
              onCropChanged: (value) => setState(() => _crop = value),
              onCropPreset: _setCropPreset,
              onFastTrimChanged: (value) {
                setState(() => _fastTrim = value);
              },
              onExport: _export,
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
                'Videonun zamanını kısalt veya görüntünün yalnız istediğin '
                'bölgesini bırak. Her şey cihazda işlenir.',
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
    required this.fileName,
    required this.trim,
    required this.crop,
    required this.cropEnabled,
    required this.fastTrim,
    required this.exporting,
    required this.progress,
    required this.message,
    required this.formatTime,
    required this.onTogglePlayback,
    required this.onTrimChanged,
    required this.onTrimChangeEnd,
    required this.onCropEnabledChanged,
    required this.onCropChanged,
    required this.onCropPreset,
    required this.onFastTrimChanged,
    required this.onExport,
  });

  final VideoPlayerController controller;
  final String fileName;
  final RangeValues trim;
  final Rect crop;
  final bool cropEnabled;
  final bool fastTrim;
  final bool exporting;
  final double progress;
  final String? message;
  final String Function(double) formatTime;
  final VoidCallback onTogglePlayback;
  final ValueChanged<RangeValues> onTrimChanged;
  final ValueChanged<RangeValues> onTrimChangeEnd;
  final ValueChanged<bool> onCropEnabledChanged;
  final ValueChanged<Rect> onCropChanged;
  final ValueChanged<double> onCropPreset;
  final ValueChanged<bool> onFastTrimChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = math
        .max(0.001, controller.value.duration.inMilliseconds / 1000.0)
        .toDouble();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 430, maxWidth: 760),
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: VideoPlayer(controller),
                      ),
                      if (cropEnabled)
                        CropOverlay(
                          rect: crop,
                          onChanged: onCropChanged,
                        ),
                      Center(
                        child: IconButton.filledTonal(
                          onPressed: exporting ? null : onTogglePlayback,
                          iconSize: 34,
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'Zaman',
            child: Column(
              children: [
                RangeSlider(
                  min: 0,
                  max: durationSeconds,
                  values: RangeValues(
                    trim.start.clamp(0, durationSeconds).toDouble(),
                    trim.end.clamp(0, durationSeconds).toDouble(),
                  ),
                  labels: RangeLabels(
                    formatTime(trim.start),
                    formatTime(trim.end),
                  ),
                  onChanged: exporting ? null : onTrimChanged,
                  onChangeEnd: exporting ? null : onTrimChangeEnd,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatTime(trim.start)),
                    Text(
                      '${formatTime(trim.end - trim.start)} seçildi',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(formatTime(trim.end)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Görüntü alanı',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Görüntüyü kırp'),
                  subtitle: const Text(
                    'Açınca beyaz çerçeveyi taşıyıp köşelerinden '
                    'boyutlandırabilirsin.',
                  ),
                  value: cropEnabled,
                  onChanged: exporting ? null : onCropEnabledChanged,
                ),
                if (cropEnabled)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('1:1'),
                        onPressed: exporting ? null : () => onCropPreset(1),
                      ),
                      ActionChip(
                        label: const Text('4:5'),
                        onPressed:
                            exporting ? null : () => onCropPreset(4 / 5),
                      ),
                      ActionChip(
                        label: const Text('9:16'),
                        onPressed:
                            exporting ? null : () => onCropPreset(9 / 16),
                      ),
                      ActionChip(
                        label: const Text('16:9'),
                        onPressed:
                            exporting ? null : () => onCropPreset(16 / 9),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'İşleme',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hızlı trim'),
              subtitle: Text(
                cropEnabled
                    ? 'Görüntü kırpma yeniden kodlama gerektirdiği için '
                        'hızlı trim kullanılamaz.'
                    : 'Yeniden kodlamadan keser; çok hızlıdır fakat başlangıç '
                        'karesi en yakın keyframe’e kayabilir.',
              ),
              value: fastTrim && !cropEnabled,
              onChanged: exporting || cropEnabled ? null : onFastTrimChanged,
            ),
          ),
          const SizedBox(height: 18),
          if (exporting) ...[
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 10),
            Text(
              progress > 0
                  ? 'İşleniyor · %${(progress * 100).round()}'
                  : 'İşlem başlatılıyor…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: exporting ? null : onExport,
            icon: const Icon(Icons.save_alt_rounded),
            label: const Text('Kırp ve galeriye kaydet'),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: message!.startsWith('Dışa')
                    ? Theme.of(context).colorScheme.error
                    : Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
