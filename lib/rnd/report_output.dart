import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Saves an experiment report so it can be collected from any build mode.
///
/// - Writes `<tag>_report.json` to `Directory.systemTemp` (code_cache on
///   Android); readable with `adb run-as` on debuggable (profile) builds.
/// - Also prints the JSON to logcat in numbered chunks
///   (`<TAG>_JSON i/n <chunk>`), because release builds are not debuggable
///   and `run-as` does not work for them. Logcat truncates long lines, so
///   chunks stay well below its limit.
Future<void> saveReport(String tag, Map<String, Object?> report) async {
  final json = jsonEncode(report);
  final file = File('${Directory.systemTemp.path}/${tag}_report.json');
  await file.writeAsString(json);

  const chunkSize = 800;
  final total = (json.length + chunkSize - 1) ~/ chunkSize;
  final upper = tag.toUpperCase();
  for (var i = 0; i < total; i++) {
    final end = (i + 1) * chunkSize;
    debugPrint(
      '${upper}_JSON ${i + 1}/$total '
      '${json.substring(i * chunkSize, end > json.length ? json.length : end)}',
    );
  }
  debugPrint('${upper}_DONE ${file.path}');
}
