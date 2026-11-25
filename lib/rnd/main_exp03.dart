// Standalone entry point for experiment 3 (async work, callbacks, threads,
// concurrency, dispose).
//
//   tool/run_experiment.sh 03 release
//
// Shows a continuously rotating square so UI freezes are visible on the
// phone; UiMonitor measures them from frame timestamps.

import 'package:flutter/widgets.dart';

import 'bench/ui_monitor.dart';
import 'exp03_async.dart';
import 'report_output.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Spinner());
  await WidgetsBinding.instance.endOfFrame;

  final monitor = UiMonitor();
  final report = await runExperiment03(
    monitor: monitor,
    log: (line) => debugPrint('EXP03 $line'),
  );
  monitor.dispose();
  await saveReport('exp03', report);
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF101418),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _controller,
                child: const SizedBox.square(
                  dimension: 80,
                  child: ColoredBox(color: Color(0xFF4FC3F7)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Experiment 03 running…\n(a stutter here = UI freeze)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
