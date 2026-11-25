import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/device_features/data/models/device_info_model.dart';
import 'bench/bench_runner.dart';
import 'bench/channel_data_client.dart';
import 'bench/data_model.dart';
import 'bench/jni_data_client.dart';
import 'exp01_call_overhead.dart' show describe, describeValue;

/// Experiment 2: complex and large data transfer, jnigen vs MethodChannel,
/// on Android.
///
/// Part A (probes): each input goes through every approach once and is
/// verified *on the receiving side* (Kotlin fingerprints/checksums what it
/// received; Dart compares what it received against the deterministic
/// generator), including nulls, special doubles, Long extremes, nested
/// objects, empty collections and 0-10 MB byte arrays.
///
/// Part B (timing): cost per call as payload size grows, per direction.
/// "native_only_*" rows time the same native generation work without
/// sending the data back, so communication cost = out - native_only.
Future<Map<String, Object?>> runExperiment02({
  BenchRunner runner = const BenchRunner(),
  void Function(String line)? log,
}) async {
  const jni = JniDataClient();
  const channel = ChannelDataClient();

  final probes = await _runProbes(jni, channel, log);

  final rows = <Map<String, Object?>>[];
  void record(BenchResult result, {required String payload, int? bytes}) {
    final rssMb = ProcessInfo.currentRss / (1 << 20);
    rows.add({
      ...result.toJson(),
      'payload': payload,
      'payload_bytes': ?bytes,
      'rss_mb_after': double.parse(rssMb.toStringAsFixed(1)),
    });
    log?.call('$result | $payload | rss ${rssMb.toStringAsFixed(1)} MB');
  }

  // ---- bytes ----
  const byteSizes = [
    (1024, '1 KB', 500),
    (64 * 1024, '64 KB', 100),
    (1 << 20, '1 MB', 20),
    (10 << 20, '10 MB', 5),
  ];
  for (final (size, label, calls) in byteSizes) {
    final data = _randomBytes(size, seed: size);

    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'bytes_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.byteCount(data) == size,
      ),
      payload: label,
      bytes: size,
    );
    record(
      runner.measureSync(
        approach: 'jnigen_direct',
        operation: 'bytes_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.directByteCount(data) == size,
      ),
      payload: label,
      bytes: size,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'bytes_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => await channel.byteCount(data) == size,
      ),
      payload: label,
      bytes: size,
    );

    record(
      runner.measureSync(
        approach: 'native_only_array',
        operation: 'bytes_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.makeBytesNativeOnly(size) == size,
      ),
      payload: label,
      bytes: size,
    );
    record(
      runner.measureSync(
        approach: 'native_only_direct',
        operation: 'bytes_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.makeDirectBytesNativeOnly(size) == size,
      ),
      payload: label,
      bytes: size,
    );
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'bytes_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => spotCheckPattern(jni.makeBytes(size), size),
      ),
      payload: label,
      bytes: size,
    );
    record(
      runner.measureSync(
        approach: 'jnigen_direct',
        operation: 'bytes_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => spotCheckPattern(jni.makeDirectBytes(size), size),
      ),
      payload: label,
      bytes: size,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'bytes_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => spotCheckPattern(await channel.makeBytes(size), size),
      ),
      payload: label,
      bytes: size,
    );
  }

  // ---- int collections ----
  const arraySizes = [(1000, 200), (100000, 20), (1000000, 5)];
  for (final (count, calls) in arraySizes) {
    final values = Int32List.fromList([for (var i = 0; i < count; i++) i]);
    final sum = count * (count - 1) ~/ 2;
    final label = '$count ints (IntArray)';
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'int_array_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.sumIntArray(values) == sum,
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'int_array_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => await channel.sumIntArray(values) == sum,
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'int_array_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => _checkInts(jni.makeIntArray(count), count),
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'int_array_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => _checkInts(await channel.makeIntArray(count), count),
      ),
      payload: label,
      bytes: count * 4,
    );
  }

  const listSizes = [(1000, 50), (10000, 10), (100000, 3)];
  for (final (count, calls) in listSizes) {
    final values = [for (var i = 0; i < count; i++) i];
    final sum = count * (count - 1) ~/ 2;
    final label = '$count ints (List<Int>)';
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'int_list_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) => jni.sumIntList(values) == sum,
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'int_list_in',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => await channel.sumIntList(values) == sum,
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'int_list_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => _checkInts(jni.makeIntList(count), count),
      ),
      payload: label,
      bytes: count * 4,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'int_list_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => _checkInts(await channel.makeIntList(count), count),
      ),
      payload: label,
      bytes: count * 4,
    );
  }

  // ---- complex objects ----
  final sample = expectedProfile(7);
  final sampleFingerprint = profileFingerprint(sample);
  const profileLabel = '1 Profile (7 fields, nested Address, 3 tags)';
  record(
    runner.measureSync(
      approach: 'jnigen',
      operation: 'profile_in',
      calls: 1000,
      call: (_) => jni.fingerprint(sample) == sampleFingerprint,
    ),
    payload: profileLabel,
  );
  record(
    await runner.measureAsync(
      approach: 'method_channel',
      operation: 'profile_in',
      calls: 1000,
      call: (_) async => await channel.fingerprint(sample) == sampleFingerprint,
    ),
    payload: profileLabel,
  );
  record(
    runner.measureSync(
      approach: 'jnigen',
      operation: 'profile_round_trip',
      calls: 1000,
      call: (_) => jni.echoProfile(sample) == sample,
    ),
    payload: profileLabel,
  );
  record(
    await runner.measureAsync(
      approach: 'method_channel',
      operation: 'profile_round_trip',
      calls: 1000,
      call: (_) async => await channel.echoProfile(sample) == sample,
    ),
    payload: profileLabel,
  );

  const profileCounts = [(10, 200), (100, 50), (1000, 10), (10000, 3)];
  for (final (count, calls) in profileCounts) {
    final first = expectedProfile(0);
    final last = expectedProfile(count - 1);
    bool check(List<ProfileData> list) =>
        list.length == count && list.first == first && list.last == last;
    final label = 'List of $count Profiles';
    record(
      runner.measureSync(
        approach: 'jnigen',
        operation: 'profiles_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) => check(jni.makeProfiles(count)),
      ),
      payload: label,
    );
    record(
      await runner.measureAsync(
        approach: 'method_channel',
        operation: 'profiles_out',
        calls: calls,
        warmupCalls: calls,
        call: (_) async => check(await channel.makeProfiles(count)),
      ),
      payload: label,
    );
  }

  final device = DeviceInfoModel.fromNative();
  return {
    'experiment': '02_data_transfer_android',
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
    'runner': {'runs': runner.runs},
    'max_rss_mb': double.parse(
      (ProcessInfo.maxRss / (1 << 20)).toStringAsFixed(1),
    ),
    'probes': probes,
    'results': rows,
  };
}

bool _checkInts(List<int> values, int count) =>
    values.length == count &&
    (count == 0 || (values.first == 0 && values.last == count - 1));

Uint8List _randomBytes(int size, {required int seed}) {
  final random = Random(seed);
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

// ---------------------------------------------------------------------------
// Part A: probes
// ---------------------------------------------------------------------------

typedef _Check = ({bool ok, String value});

_Check _result(bool ok, Object? value) =>
    (ok: ok, value: value is String ? value : describeValue(value));

Future<List<Map<String, Object?>>> _runProbes(
  JniDataClient jni,
  ChannelDataClient channel,
  void Function(String line)? log,
) async {
  final probes = <Map<String, Object?>>[];

  Future<void> probe(
    String name,
    String expected,
    Map<String, FutureOr<_Check> Function()> approaches,
  ) async {
    final results = <String, Object?>{};
    for (final MapEntry(key: approach, value: run) in approaches.entries) {
      _Check check;
      try {
        check = await run();
      } catch (error) {
        check = (ok: false, value: _describeError(error));
      }
      results[approach] = {'ok': check.ok, 'value': check.value};
    }
    final entry = {'name': name, 'expected': expected, 'results': results};
    probes.add(entry);
    log?.call('probe $entry');
  }

  // ---- scalars ----
  for (final (label, value) in [
    ('long_max', 9223372036854775807),
    ('long_min', -9223372036854775808),
    ('long_small_42', 42),
  ]) {
    await probe('${label}_round_trip', '$value', {
      'jnigen': () {
        final r = jni.echoLong(value);
        return _result(r == value, r);
      },
      'method_channel': () async {
        final r = await channel.echoLong(value);
        return _result(r == value, r);
      },
    });
  }

  final doubles = Float64List.fromList([
    double.nan,
    double.infinity,
    double.negativeInfinity,
    -0.0,
    5e-324,
    1.7976931348623157e308,
    0.1,
  ]);
  _Check checkDoubles(Float64List r) {
    final same =
        r.length == doubles.length &&
        [
          for (var i = 0; i < r.length; i++)
            doubleBits(r[i]) == doubleBits(doubles[i]),
        ].every((x) => x);
    return _result(same, same ? 'all 7 values bit-identical' : '$r');
  }

  await probe(
    'double_specials_round_trip',
    'NaN, +inf, -inf, -0.0, 5e-324, max, 0.1 (bit-identical)',
    {
      'jnigen': () => checkDoubles(jni.echoDoubles(doubles)),
      'method_channel': () async =>
          checkDoubles(await channel.echoDoubles(doubles)),
    },
  );

  for (final (label, value) in [
    ('null', null),
    ('empty', ''),
    ('text', 'x'),
  ]) {
    await probe('nullable_string_$label', describe(value), {
      'jnigen': () {
        final r = jni.echoNullableString(value);
        return _result(r == value, describe(r));
      },
      'method_channel': () async {
        final r = await channel.echoNullableString(value);
        return _result(r == value, describe(r));
      },
    });
  }

  // ---- complex objects ----
  const edge = ProfileData(
    id: -9223372036854775808,
    name: '',
    score: -0.0,
    active: false,
    tags: ['', 'ü', '👋🏽', 'a\u0000b'],
    email: '',
    address: AddressData('', ''),
  );
  final unicode = ProfileData(
    id: 3000000000,
    name: 'നമസ്കാരം 世界 👋',
    score: double.nan,
    active: true,
    tags: [for (var i = 0; i < 50; i++) 'tag-$i'],
    email: null,
    address: const AddressData('Kochi', null),
  );
  final samples = {
    'p1_all_fields': expectedProfile(1),
    'p2_null_postal': expectedProfile(2),
    'p4_empty_tags': expectedProfile(4),
    'p15_null_email_and_address': expectedProfile(15),
    'edge_empty_strings_minlong_negzero': edge,
    'unicode_nan_50tags_beyond_int32': unicode,
  };
  for (final MapEntry(key: label, value: p) in samples.entries) {
    final fingerprint = profileFingerprint(p);
    await probe('profile_to_native_$label', describe(fingerprint), {
      'jnigen': () {
        final r = jni.fingerprint(p);
        return _result(r == fingerprint, describe(r));
      },
      'method_channel': () async {
        final r = await channel.fingerprint(p);
        return _result(r == fingerprint, describe(r));
      },
    });
    await probe('profile_round_trip_$label', 'equal to input', {
      'jnigen': () {
        final r = jni.echoProfile(p);
        return _result(r == p, r == p ? 'equal' : '$r');
      },
      'method_channel': () async {
        final r = await channel.echoProfile(p);
        return _result(r == p, r == p ? 'equal' : '$r');
      },
    });
  }
  for (final i in [0, 1, 2, 4, 15]) {
    final expected = expectedProfile(i);
    await probe('profile_from_native_$i', '$expected', {
      'jnigen': () {
        final r = jni.makeProfile(i);
        return _result(r == expected, r == expected ? 'equal' : '$r');
      },
      'method_channel': () async {
        final r = await channel.makeProfile(i);
        return _result(r == expected, r == expected ? 'equal' : '$r');
      },
    });
  }
  for (final count in [0, 1000]) {
    final expected = [for (var i = 0; i < count; i++) expectedProfile(i)];
    _Check check(List<ProfileData> r) {
      final ok = listEquals(r, expected);
      return _result(ok, ok ? 'all $count equal' : 'length ${r.length}');
    }

    await probe('profile_list_from_native_$count', '$count profiles', {
      'jnigen': () => check(jni.makeProfiles(count)),
      'method_channel': () async => check(await channel.makeProfiles(count)),
    });
  }

  // ---- bytes ----
  for (final size in [0, 1, 1024, 1 << 20, 10 << 20]) {
    final data = _randomBytes(size, seed: 7 + size);
    final expected = byteChecksum(data);
    await probe('bytes_to_native_$size', 'checksum $expected', {
      'jnigen': () {
        final r = jni.checksum(data);
        return _result(r == expected, 'checksum $r');
      },
      'jnigen_direct': () {
        final r = jni.directChecksum(data);
        return _result(r == expected, 'checksum $r');
      },
      'method_channel': () async {
        final r = await channel.checksum(data);
        return _result(r == expected, 'checksum $r');
      },
    });

    _Check checkBytes(Uint8List r) {
      final ok = r.length == size && matchesPattern(r);
      return _result(
        ok,
        ok ? 'all $size bytes match' : 'length ${r.length}, mismatch',
      );
    }

    await probe('bytes_from_native_$size', 'makeBytes($size) pattern', {
      'jnigen': () => checkBytes(jni.makeBytes(size)),
      'jnigen_direct': () => checkBytes(jni.makeDirectBytes(size)),
      'method_channel': () async => checkBytes(await channel.makeBytes(size)),
    });
  }
  await probe(
    'bytes_raw_getrange_is_signed',
    'byte[255] = ${patternByte(255)} (unsigned)',
    {
      'jnigen (raw JByteArray.getRange)': () {
        final raw = jni.makeBytesRawSigned(256);
        return _result(
          raw[255] == patternByte(255),
          '${raw.runtimeType}[255] = ${raw[255]}',
        );
      },
    },
  );

  // ---- ints ----
  const int32Min = -2147483648;
  const int32Max = 2147483647;
  final extremes = [int32Min, int32Max, -1, 0, 1];
  await probe('int_array_extremes_to_native', 'sum -1', {
    'jnigen': () {
      final r = jni.sumIntArray(Int32List.fromList(extremes));
      return _result(r == -1, 'sum $r');
    },
    'method_channel': () async {
      final r = await channel.sumIntArray(Int32List.fromList(extremes));
      return _result(r == -1, 'sum $r');
    },
  });
  await probe('int_list_extremes_to_native', 'sum -1', {
    'jnigen': () {
      final r = jni.sumIntList(extremes);
      return _result(r == -1, 'sum $r');
    },
    'method_channel': () async {
      final r = await channel.sumIntList(extremes);
      return _result(r == -1, 'sum $r');
    },
  });
  for (final count in [0, 100000]) {
    bool full(List<int> r) {
      if (r.length != count) return false;
      for (var i = 0; i < count; i++) {
        if (r[i] != i) return false;
      }
      return true;
    }

    await probe('int_array_from_native_$count', '[0..${count - 1}]', {
      'jnigen': () {
        final r = jni.makeIntArray(count);
        return _result(full(r), 'length ${r.length}');
      },
      'method_channel': () async {
        final r = await channel.makeIntArray(count);
        return _result(full(r), 'length ${r.length}');
      },
    });
    await probe('int_list_from_native_$count', '[0..${count - 1}]', {
      'jnigen': () {
        final r = jni.makeIntList(count);
        return _result(full(r), 'length ${r.length}');
      },
      'method_channel': () async {
        final r = await channel.makeIntList(count);
        return _result(full(r), 'length ${r.length}');
      },
    });
  }
  await probe('int_array_empty_to_native', 'sum 0', {
    'jnigen': () {
      final r = jni.sumIntArray(Int32List(0));
      return _result(r == 0, 'sum $r');
    },
    'method_channel': () async {
      final r = await channel.sumIntArray(Int32List(0));
      return _result(r == 0, 'sum $r');
    },
  });

  return probes;
}

String _describeError(Object error) {
  if (error is PlatformException) {
    return 'THREW PlatformException(code: ${error.code}, '
        'message: ${error.message})';
  }
  final text = '$error';
  return 'THREW ${error.runtimeType}: '
      '${text.length > 300 ? '${text.substring(0, 300)}…' : text}';
}
