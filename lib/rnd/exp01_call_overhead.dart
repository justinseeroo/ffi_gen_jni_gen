import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/device_features/data/models/device_info_model.dart';
import 'bench/bench_runner.dart';
import 'bench/channel_bench_client.dart';
import 'bench/jni_bench_client.dart';

/// Experiment 1: call overhead and primitive round-trip, jnigen vs
/// MethodChannel, on Android.
///
/// Part A, correctness probes: run each input once through both
/// approaches and record exactly what came back (or what was thrown),
/// including edge cases such as int32 overflow, emoji, NUL and lone UTF-16
/// surrogates.
///
/// Part B, timing: `noop`, `add` and `echo` at each call count in
/// [callCounts], through both approaches, with the same warm-up and runs.
///
/// Returns a JSON-serialisable report. Nothing here asserts *which* approach
/// is faster; the numbers are recorded as measured.
Future<Map<String, Object?>> runExperiment01({
  BenchRunner runner = const BenchRunner(),
  List<int> callCounts = const [1, 1000, 10000, 100000],
  void Function(String line)? log,
}) async {
  const jni = JniBenchClient();
  const channel = ChannelBenchClient();

  final probes = await _runProbes(jni, channel);
  for (final probe in probes) {
    log?.call('probe ${probe['name']}: $probe');
  }

  const echoSample = 'Hello, Flutter ⇄ Kotlin 👋🏽 ñ';
  final results = <BenchResult>[];
  void record(BenchResult result) {
    results.add(result);
    log?.call(result.toString());
  }

  for (final calls in callCounts) {
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'noop',
        calls: calls,
        call: (_) {
          jni.noop();
          return true;
        },
      ),
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'noop',
        calls: calls,
        call: (_) async {
          await channel.noop();
          return true;
        },
      ),
    );

    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'add',
        calls: calls,
        call: (i) => jni.add(i, 1) == i + 1,
      ),
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'add',
        calls: calls,
        call: (i) async => await channel.add(i, 1) == i + 1,
      ),
    );

    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'echo',
        calls: calls,
        call: (_) => jni.echo(echoSample) == echoSample,
      ),
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'echo',
        calls: calls,
        call: (_) async => await channel.echo(echoSample) == echoSample,
      ),
    );
  }

  final device = DeviceInfoModel.fromNative();
  return {
    'experiment': '01_call_overhead_android',
    'build_mode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'device': {
      'manufacturer': device.manufacturer,
      'model': device.model,
      'android': device.osVersion,
      'api_level': device.apiLevel,
    },
    'runner': {'runs': runner.runs, 'warmup_calls': runner.warmupCalls},
    'echo_sample': describe(echoSample),
    'probes': probes,
    'results': [for (final r in results) r.toJson()],
  };
}

/// Edge-case inputs, each sent once through both approaches.
Future<List<Map<String, Object?>>> _runProbes(
  JniBenchClient jni,
  ChannelBenchClient channel,
) async {
  final probes = <Map<String, Object?>>[];

  Future<void> probe(
    String name,
    Object? expected,
    Object? Function() viaJni,
    Future<Object?> Function() viaChannel,
  ) async {
    final jniOutcome = _capture(viaJni);
    final channelOutcome = await _captureAsync(viaChannel);
    probes.add({
      'name': name,
      'expected': describeValue(expected),
      'jnigen': jniOutcome.describe(),
      'jnigen_matches': jniOutcome.matches(expected),
      'method_channel': channelOutcome.describe(),
      'method_channel_matches': channelOutcome.matches(expected),
    });
  }

  Future<void> addProbe(String name, int a, int b, int expected) => probe(
    name,
    expected,
    () => jni.add(a, b),
    () => channel.add(a, b),
  );

  Future<void> echoProbe(String name, String value) =>
      probe(name, value, () => jni.echo(value), () => channel.echo(value));

  await addProbe('add_small', 1, 2, 3);
  await addProbe('add_negative', -5, 3, -2);
  // Kotlin Int overflow wraps; both approaches should report Kotlin's value.
  await addProbe('add_int32_overflow', 2147483647, 1, -2147483648);
  // 2^31 does not fit Kotlin's Int. There is no "right" answer: the probe
  // records what each approach does with it (truncate, error, ...).
  await addProbe('add_arg_beyond_int32', 2147483648, 0, 2147483648);

  await echoProbe('echo_empty', '');
  await echoProbe('echo_ascii', 'Hello');
  await echoProbe('echo_unicode_bmp', 'नमस्ते മലയാളം 中文 ñ');
  await echoProbe('echo_emoji_surrogate_pairs', '👋🏽🚀');
  await echoProbe('echo_embedded_nul', 'a\u0000b');
  // A lone surrogate is a valid Dart (UTF-16) string but not valid UTF-8.
  await echoProbe('echo_lone_surrogate', 'x\uD800y');
  await echoProbe('echo_100k_chars', 'abcdefghij' * 10000);

  return probes;
}

class _Outcome {
  _Outcome.value(this.value) : error = null;
  _Outcome.error(this.error) : value = null;

  final Object? value;
  final Object? error;

  bool matches(Object? expected) => error == null && value == expected;

  String describe() {
    final error = this.error;
    if (error == null) return describeValue(value);
    if (error is PlatformException) {
      return 'THREW PlatformException(code: ${error.code}, '
          'message: ${error.message})';
    }
    return 'THREW ${error.runtimeType}: $error';
  }
}

_Outcome _capture(Object? Function() call) {
  try {
    return _Outcome.value(call());
  } catch (error) {
    return _Outcome.error(error);
  }
}

Future<_Outcome> _captureAsync(Future<Object?> Function() call) async {
  try {
    return _Outcome.value(await call());
  } catch (error) {
    return _Outcome.error(error);
  }
}

/// Printable form of a probe value. Long strings are summarised; non-ASCII
/// and control code units are shown as `\uXXXX` so NUL and lone surrogates
/// are visible and survive JSON/log output unchanged.
String describeValue(Object? value) {
  if (value is! String) return '$value';
  if (value.length > 64) {
    return 'String(length: ${value.length}, '
        'start: ${describe(value.substring(0, 16))})';
  }
  return describe(value);
}

String describe(Object? value) {
  if (value is! String) return '$value';
  final buffer = StringBuffer('"');
  for (final unit in value.codeUnits) {
    if (unit >= 0x20 && unit < 0x7F) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    }
  }
  buffer.write('"');
  return buffer.toString();
}
