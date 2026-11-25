// Standalone entry point for experiment 1: the "clean" benchmark run.
//
//   flutter run --profile -t lib/rnd/main_exp01.dart
//
// Unlike integration_test/exp01_call_overhead_test.dart this does not start
// the dashboard (whose 2 s refresh timer and UI rebuilds would run between
// awaited MethodChannel calls but never inside a synchronous jnigen loop,
// biasing the comparison) and does not use the test binding. The screen is
// static, so no frames compete with the benchmark.
//
// The JSON report is written to Directory.systemTemp, which on Android is the
// app's code_cache directory; with a profile
// (debuggable) build, pull it with:
//
//   adb exec-out run-as com.example.ffi_gen_jni_gen cat code_cache/exp01_report.json

import 'package:flutter/material.dart';

import 'exp01_call_overhead.dart';
import 'report_output.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Experiment 01 running…')),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;

  final report = await runExperiment01(
    log: (line) => debugPrint('EXP01 $line'),
  );
  await saveReport('exp01', report);
}
