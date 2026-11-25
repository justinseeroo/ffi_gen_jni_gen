import 'package:jni/jni.dart';

import '../../jni/bench_bindings.g.dart';

/// Calls the Kotlin `InteropBench` directly through the jnigen bindings.
///
/// Calls are synchronous and run on the calling thread (the Flutter UI
/// thread, when called from the root isolate).
class JniBenchClient {
  const JniBenchClient();

  void noop() => InteropBench.noop();

  /// Kotlin `Int` is 32-bit; the binding passes Dart's 64-bit `int` as a C
  /// `int32`. See the int32 probe in experiment 1 for what happens to larger
  /// values.
  int add(int a, int b) => InteropBench.add(a, b);

  /// Converts the Dart string to a Java string, calls Kotlin, converts the
  /// result back, and releases both Java references. All of that is part of
  /// the real cost of passing a string, so it is all inside the timing.
  String echo(String value) {
    final argument = value.toJString();
    try {
      return InteropBench.echo(argument).toDartString(releaseOriginal: true);
    } finally {
      argument.release();
    }
  }
}
