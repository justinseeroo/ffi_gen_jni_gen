// Standalone entry point for experiment 2 (complex and large data).
//
//   flutter run --profile -t lib/rnd/main_exp02.dart
//
// Static screen, no dashboard, no test binding (see main_exp01.dart for
// why). The JSON report is written to Directory.systemTemp (the app's
// code_cache directory on Android); with a profile build, pull it with:
//
//   adb exec-out run-as com.example.ffi_gen_jni_gen cat code_cache/exp02_report.json

import 'package:flutter/material.dart';

import 'exp02_data_transfer.dart';
import 'report_output.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Experiment 02 running…')),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;

  final report = await runExperiment02(
    log: (line) => debugPrint('EXP02 $line'),
  );
  await saveReport('exp02', report);
}
