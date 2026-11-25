// Experiment 1: call overhead and primitive round-trip, jnigen vs
// MethodChannel. Android only. Run on a physical device in profile mode:
//
//   flutter drive --profile \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/exp01_call_overhead_test.dart
//
// The full report is written to build/integration_response_data.json and
// each line is also printed to the console.

import 'dart:convert';
import 'dart:io';

import 'package:ffi_gen_jni_gen/rnd/exp01_call_overhead.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'experiment 01: call overhead jnigen vs MethodChannel',
    (tester) async {
      // A static screen, NOT the dashboard: its 2 s refresh timer and
      // rebuilds run between awaited MethodChannel calls but never inside a
      // synchronous jnigen loop, which inflated MethodChannel times ~1.2-2.4x
      // in the first run. The `rnd/bench` channel is registered natively in
      // MainActivity.configureFlutterEngine, so the app's main() isn't needed.
      // For the reference numbers use lib/rnd/main_exp01.dart (no test
      // binding at all).
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: Text('Experiment 01 running…')),
        ),
      );

      final report = await runExperiment01(
        log: (line) => debugPrint('EXP01 $line'),
      );
      binding.reportData = report;
      debugPrint('EXP01_REPORT ${jsonEncode(report)}');

      // The run is valid only if every timed call returned the right value.
      final results = report['results']! as List;
      for (final result in results.cast<Map<String, Object>>()) {
        expect(
          result['mismatches'],
          0,
          reason: '${result['approach']}.${result['operation']}',
        );
      }
    },
    skip: !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
