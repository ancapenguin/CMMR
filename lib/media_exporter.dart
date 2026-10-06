import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class CropPixels {
  const CropPixels({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
  });

  final int width;
  final int height;
  final int x;
  final int y;
}

class MediaExportRequest {
  const MediaExportRequest({
    required this.inputPath,
    required this.start,
    required this.end,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.fastTrim,
    this.crop,
  });

  final String inputPath;
  final Duration start;
  final Duration end;
  final int sourceWidth;
  final int sourceHeight;
  final bool fastTrim;
  final CropPixels? crop;

  Duration get duration => end - start;
}

class MediaExportResult {
  const MediaExportResult({
    required this.outputPath,
    required this.reencoded,
    required this.usedSoftwareFallback,
  });

  final String outputPath;
  final bool reencoded;
  final bool usedSoftwareFallback;
}

class MediaExporter {
  Future<MediaExportResult> export(
    MediaExportRequest request, {
    void Function(double)? onProgress,
  }) async {
    if (request.duration <= Duration.zero) {
      throw ArgumentError('The selected time range is empty.');
    }

    final temp = await getTemporaryDirectory();
    final outputPath =
        '${temp.path}/cmmr_cut_${DateTime.now().millisecondsSinceEpoch}.mp4';

    var reencoded = request.crop != null || !request.fastTrim;
    var usedSoftwareFallback = false;

    if (!reencoded) {
      try {
        await _run(
          _fastTrimArguments(request, outputPath),
          request.duration,
          onProgress,
        );
      } catch (_) {
        reencoded = true;
        await _deleteIfPresent(outputPath);
        onProgress?.call(0);
        await _run(
          _hardwareArguments(request, outputPath),
          request.duration,
          onProgress,
        );
      }
    } else {
      try {
        await _run(
          _hardwareArguments(request, outputPath),
          request.duration,
          onProgress,
        );
      } catch (_) {
        usedSoftwareFallback = true;
        await _deleteIfPresent(outputPath);
        onProgress?.call(0);
        await _run(
          _softwareArguments(request, outputPath),
          request.duration,
          onProgress,
        );
      }
    }

    await Gal.putVideo(outputPath, album: 'CMMR');

    return MediaExportResult(
      outputPath: outputPath,
      reencoded: reencoded,
      usedSoftwareFallback: usedSoftwareFallback,
    );
  }

  List<String> _baseInput(MediaExportRequest request) => [
        '-y',
        '-ss',
        _seconds(request.start),
        '-i',
        request.inputPath,
        '-t',
        _seconds(request.duration),
      ];

  List<String> _fastTrimArguments(
    MediaExportRequest request,
    String outputPath,
  ) {
    return [
      ..._baseInput(request),
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-c',
      'copy',
      '-avoid_negative_ts',
      'make_zero',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  List<String> _hardwareArguments(
    MediaExportRequest request,
    String outputPath,
  ) {
    final outputWidth = request.crop?.width ?? request.sourceWidth;
    final outputHeight = request.crop?.height ?? request.sourceHeight;
    final bitrateKbps =
        ((outputWidth * outputHeight * 5) / 1000).round().clamp(2000, 40000);

    return [
      ..._baseInput(request),
      '-vf',
      _videoFilter(request.crop),
      '-c:v',
      'h264_mediacodec',
      '-b:v',
      '${bitrateKbps}k',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  List<String> _softwareArguments(
    MediaExportRequest request,
    String outputPath,
  ) {
    return [
      ..._baseInput(request),
      '-vf',
      _videoFilter(request.crop),
      '-c:v',
      'mpeg4',
      '-q:v',
      '3',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  String _videoFilter(CropPixels? crop) {
    if (crop == null) {
      return 'format=yuv420p';
    }

    return 'crop=${crop.width}:${crop.height}:${crop.x}:${crop.y},'
        'format=yuv420p';
  }

  Future<void> _run(
    List<String> arguments,
    Duration expectedDuration,
    void Function(double)? onProgress,
  ) async {
    final completer = Completer<Session>();

    await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) {
        if (!completer.isCompleted) {
          completer.complete(session);
        }
      },
      null,
      (statistics) {
        final expectedMs = expectedDuration.inMilliseconds;
        if (expectedMs <= 0) {
          return;
        }
        final progress =
            (statistics.getTime() / expectedMs).clamp(0.0, 1.0).toDouble();
        onProgress?.call(progress);
      },
    );

    final session = await completer.future;
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      onProgress?.call(1);
      return;
    }

    final output = await session.getOutput();
    throw StateError(
      output == null || output.trim().isEmpty
          ? 'FFmpeg failed with return code $returnCode.'
          : output,
    );
  }

  Future<void> _deleteIfPresent(String path) async {
    final output = File(path);
    if (await output.exists()) {
      await output.delete();
    }
  }

  String _seconds(Duration duration) {
    return (duration.inMicroseconds / Duration.microsecondsPerSecond)
        .toStringAsFixed(6);
  }
}
