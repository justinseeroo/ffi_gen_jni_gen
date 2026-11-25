import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'data_model.dart';

/// Experiment 2 through the `rnd/data` MethodChannel
/// (`android/.../channel/DataBenchChannel.kt`), calling the same Kotlin
/// `DataBench` as [JniDataClient].
///
/// Typed lists (`Uint8List`, `Int32List`, `Float64List`) are native
/// StandardMessageCodec types; objects are sent as maps.
class ChannelDataClient {
  const ChannelDataClient();

  static const _channel = MethodChannel('rnd/data');

  Future<T> _call<T>(String method, [Object? arguments]) async =>
      (await _channel.invokeMethod<T>(method, arguments)) as T;

  // ---- scalars and nulls ----

  Future<int> echoLong(int value) => _call<int>('echoLong', value);

  Future<Float64List> echoDoubles(Float64List values) =>
      _call<Float64List>('echoDoubles', values);

  Future<String?> echoNullableString(String? value) =>
      _call<String?>('echoNullableString', value);

  // ---- complex objects ----

  Future<String> fingerprint(ProfileData profile) =>
      _call<String>('fingerprint', profile.toMap());

  Future<ProfileData> makeProfile(int i) async =>
      ProfileData.fromMap(await _call<Map<Object?, Object?>>('makeProfile', i));

  Future<List<ProfileData>> makeProfiles(int count) async => [
    for (final map in await _call<List<Object?>>('makeProfiles', count))
      ProfileData.fromMap(map! as Map<Object?, Object?>),
  ];

  Future<ProfileData> echoProfile(ProfileData profile) async =>
      ProfileData.fromMap(
        await _call<Map<Object?, Object?>>('echoProfile', profile.toMap()),
      );

  // ---- bytes ----

  Future<int> byteCount(Uint8List data) => _call<int>('byteCount', data);

  Future<int> checksum(Uint8List data) => _call<int>('checksum', data);

  Future<Uint8List> makeBytes(int size) => _call<Uint8List>('makeBytes', size);

  // ---- ints ----

  Future<int> sumIntArray(Int32List values) =>
      _call<int>('sumIntArray', values);

  Future<Int32List> makeIntArray(int count) =>
      _call<Int32List>('makeIntArray', count);

  Future<int> sumIntList(List<int> values) => _call<int>('sumIntList', values);

  Future<List<int>> makeIntList(int count) async =>
      (await _call<List<Object?>>('makeIntList', count)).cast<int>();
}
