import 'package:flutter/services.dart';

/// Calls the same Kotlin `InteropBench` through the `rnd/bench`
/// MethodChannel registered in `MainActivity`: the traditional approach the
/// jnigen bindings are compared against.
///
/// Arguments and results go through `StandardMessageCodec` and the call is
/// asynchronous, as in any real MethodChannel plugin.
class ChannelBenchClient {
  const ChannelBenchClient();

  static const _channel = MethodChannel('rnd/bench');

  Future<void> noop() => _channel.invokeMethod<void>('noop');

  Future<int> add(int a, int b) async {
    final result = await _channel.invokeMethod<int>('add', {'a': a, 'b': b});
    return result!;
  }

  Future<String> echo(String value) async {
    final result = await _channel.invokeMethod<String>('echo', value);
    return result!;
  }
}
