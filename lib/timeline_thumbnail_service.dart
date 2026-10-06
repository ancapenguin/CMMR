import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';

class TimelineThumbnailService {
  Future<List<String>> generate({
    required String inputPath,
    required Duration duration,
    int count = 8,
  }) async {
    if (duration <= Duration.zero || count < 2) {
      return const [];
    }

    final root = await getTemporaryDirectory();
    final dir = Directory(
      '${root.path}/cmmr_timeline_${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);

    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final interval = seconds / count;
    final outputPattern = '${dir.path}/frame_%02d.jpg';

    final session = await FFmpegKit.executeWithArguments([
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      inputPath,
      '-vf',
      'fps=1/${interval.toStringAsFixed(6)},scale=180:-2:flags=fast_bilinear',
      '-frames:v',
      '$count',
      '-q:v',
      '6',
      '-an',
      '-sn',
      '-dn',
      '-y',
      outputPattern,
    ]);

    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      await dir.delete(recursive: true);
      return const [];
    }

    final files = await dir
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.jpg'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.map((file) => file.path).toList(growable: false);
  }
}
