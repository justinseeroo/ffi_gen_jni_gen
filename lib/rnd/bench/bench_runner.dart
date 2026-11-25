/// Small, dependency-free benchmark harness for the interop R&D experiments.
///
/// Fairness rules it enforces:
/// - Every scenario gets the same warm-up before it is timed, so JIT/caches,
///   JNI method-ID lookups and channel setup are not counted.
/// - Every scenario is timed [BenchRunner.runs] times; the median is reported
///   (robust against one-off GC pauses or scheduler hiccups).
/// - The call under test returns whether its result was correct, and the
///   number of mismatches is reported with the timing. A fast wrong answer
///   is not a result.
/// - Synchronous calls (jnigen/ffigen) are timed in a plain loop. Async calls
///   (MethodChannel) are awaited one after another. Wrapping sync calls in
///   Futures would add Dart overhead that is not part of the approach.
library;

/// The timing of one scenario: [calls] calls of [operation] via [approach].
class BenchResult {
  BenchResult({
    required this.approach,
    required this.operation,
    required this.calls,
    required this.runsNs,
    required this.mismatches,
  });

  /// e.g. `jnigen` or `method_channel`.
  final String approach;

  /// e.g. `noop`, `add`, `echo`.
  final String operation;

  /// Calls per timed run.
  final int calls;

  /// Total wall time of each timed run, in nanoseconds.
  final List<int> runsNs;

  /// Calls (across all timed runs) whose result did not match the expected
  /// value. Must be 0 for the timing to count.
  final int mismatches;

  int get medianTotalNs => median(runsNs);

  double get medianPerCallNs => medianTotalNs / calls;

  int get minTotalNs => runsNs.reduce((a, b) => a < b ? a : b);

  int get maxTotalNs => runsNs.reduce((a, b) => a > b ? a : b);

  Map<String, Object> toJson() => {
    'approach': approach,
    'operation': operation,
    'calls': calls,
    'runs_ns': runsNs,
    'median_total_ms': medianTotalNs / 1e6,
    'median_per_call_us': medianPerCallNs / 1e3,
    'min_total_ms': minTotalNs / 1e6,
    'max_total_ms': maxTotalNs / 1e6,
    'mismatches': mismatches,
  };

  @override
  String toString() =>
      '$approach.$operation x$calls: '
      'median ${(medianTotalNs / 1e6).toStringAsFixed(3)} ms total, '
      '${(medianPerCallNs / 1e3).toStringAsFixed(3)} us/call, '
      'mismatches $mismatches';
}

/// Median of [values] (mean of the two middle values for an even count).
int median(List<int> values) {
  if (values.isEmpty) throw ArgumentError('No values');
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) ~/ 2;
}

/// Converts stopwatch [ticks] at [frequency] ticks/second to nanoseconds
/// without 64-bit overflow.
///
/// The naive `ticks * 1e9 ~/ frequency` overflows once `ticks` passes about
/// 9.2e9, which on a nanosecond-resolution clock (Android) is any run longer
/// than about 9.2 s. Splitting into whole seconds and the remainder keeps
/// every intermediate value below 1e18.
int ticksToNanoseconds(int ticks, int frequency) {
  const nsPerSecond = 1000000000;
  return (ticks ~/ frequency) * nsPerSecond +
      (ticks % frequency) * nsPerSecond ~/ frequency;
}

class BenchRunner {
  const BenchRunner({this.runs = 5, this.warmupCalls = 1000});

  final int runs;
  final int warmupCalls;

  static int _elapsedNs(Stopwatch stopwatch) =>
      ticksToNanoseconds(stopwatch.elapsedTicks, stopwatch.frequency);

  /// Times a synchronous [call]. [call] gets the call index and returns
  /// whether its result was correct. [warmupCalls] overrides the runner's
  /// default (e.g. fewer warm-up calls for multi-megabyte payloads).
  BenchResult measureSync({
    required String approach,
    required String operation,
    required int calls,
    required bool Function(int i) call,
    int? warmupCalls,
  }) {
    for (var i = 0; i < (warmupCalls ?? this.warmupCalls); i++) {
      call(i);
    }
    final runsNs = <int>[];
    var mismatches = 0;
    final stopwatch = Stopwatch();
    for (var run = 0; run < runs; run++) {
      var runMismatches = 0;
      stopwatch
        ..reset()
        ..start();
      for (var i = 0; i < calls; i++) {
        if (!call(i)) runMismatches++;
      }
      stopwatch.stop();
      runsNs.add(_elapsedNs(stopwatch));
      mismatches += runMismatches;
    }
    return BenchResult(
      approach: approach,
      operation: operation,
      calls: calls,
      runsNs: runsNs,
      mismatches: mismatches,
    );
  }

  /// Times an asynchronous [call], awaiting each call before the next one.
  Future<BenchResult> measureAsync({
    required String approach,
    required String operation,
    required int calls,
    required Future<bool> Function(int i) call,
    int? warmupCalls,
  }) async {
    for (var i = 0; i < (warmupCalls ?? this.warmupCalls); i++) {
      await call(i);
    }
    final runsNs = <int>[];
    var mismatches = 0;
    final stopwatch = Stopwatch();
    for (var run = 0; run < runs; run++) {
      var runMismatches = 0;
      stopwatch
        ..reset()
        ..start();
      for (var i = 0; i < calls; i++) {
        if (!await call(i)) runMismatches++;
      }
      stopwatch.stop();
      runsNs.add(_elapsedNs(stopwatch));
      mismatches += runMismatches;
    }
    return BenchResult(
      approach: approach,
      operation: operation,
      calls: calls,
      runsNs: runsNs,
      mismatches: mismatches,
    );
  }
}
