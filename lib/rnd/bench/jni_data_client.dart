import 'dart:typed_data';

import 'package:jni/jni.dart';

import '../../jni/bench_bindings.g.dart';
import 'data_model.dart';

/// Experiment 2 through jnigen: converts Dart data to Java objects, calls
/// Kotlin `DataBench`, converts results back, and releases every JNI
/// reference it created. All conversion and cleanup is part of the cost an
/// app pays, so it is all inside the timings.
///
/// Every Java object a binding returns is a JNI *global reference* that must
/// be released (directly, via `releasedBy(arena)`, or `releaseOriginal`).
/// Dart's GC would eventually release them too, but it does not know about
/// the JVM's global-reference limit, so relying on it is unsafe in loops.
class JniDataClient {
  const JniDataClient();

  // ---- scalars and nulls ----

  int echoLong(int value) => DataBench.echoLong(value);

  Float64List echoDoubles(Float64List values) {
    final input = JDoubleArray(values.length)
      ..setRange(0, values.length, values);
    try {
      final output = DataBench.echoDoubles(input);
      try {
        return output.getRange(0, output.length);
      } finally {
        output.release();
      }
    } finally {
      input.release();
    }
  }

  String? echoNullableString(String? value) {
    final argument = value?.toJString();
    try {
      return DataBench.echoNullableString(
        argument,
      )?.toDartString(releaseOriginal: true);
    } finally {
      argument?.release();
    }
  }

  // ---- complex objects ----

  String fingerprint(ProfileData profile) => using(
    (arena) => DataBench.fingerprint(
      _toJava(profile, arena),
    ).toDartString(releaseOriginal: true),
  );

  ProfileData makeProfile(int i) {
    final profile = DataBench.makeProfile(i);
    try {
      return _fromJava(profile);
    } finally {
      profile.release();
    }
  }

  List<ProfileData> makeProfiles(int count) {
    final list = DataBench.makeProfiles(count);
    try {
      final size = list.size();
      return [
        for (var i = 0; i < size; i++) _takeProfile(list.get(i)!),
      ];
    } finally {
      list.release();
    }
  }

  ProfileData echoProfile(ProfileData profile) => using((arena) {
    final echoed = DataBench.echoProfile(_toJava(profile, arena))
      ..releasedBy(arena);
    return _fromJava(echoed);
  });

  /// Builds a Java `Profile`. The profile and every temporary Java object
  /// (strings, list, address) are released when [arena] closes.
  Profile _toJava(ProfileData p, Arena arena) {
    JString j(String s) => s.toJString()..releasedBy(arena);
    final tags = [for (final tag in p.tags) j(tag)].toJList()
      ..releasedBy(arena);
    final address = p.address;
    final javaAddress = address == null
        ? null
        : (Address(
            j(address.city),
            address.postalCode == null ? null : j(address.postalCode!),
          )..releasedBy(arena));
    return Profile(
      p.id,
      j(p.name),
      p.score,
      p.active,
      tags,
      p.email == null ? null : j(p.email!),
      javaAddress,
    )..releasedBy(arena);
  }

  ProfileData _takeProfile(Profile profile) {
    try {
      return _fromJava(profile);
    } finally {
      profile.release();
    }
  }

  /// Reads every field (one JNI call per getter, plus per tag). The caller
  /// still owns [p].
  ProfileData _fromJava(Profile p) {
    final tags = p.tags;
    final List<String> tagList;
    try {
      final size = tags.size();
      tagList = [
        for (var i = 0; i < size; i++)
          tags.get(i)!.toDartString(releaseOriginal: true),
      ];
    } finally {
      tags.release();
    }
    final address = p.address;
    final AddressData? addressData;
    try {
      addressData = address == null
          ? null
          : AddressData(
              address.city.toDartString(releaseOriginal: true),
              address.postalCode?.toDartString(releaseOriginal: true),
            );
    } finally {
      address?.release();
    }
    return ProfileData(
      id: p.id,
      name: p.name.toDartString(releaseOriginal: true),
      score: p.score,
      active: p.active,
      tags: tagList,
      email: p.email?.toDartString(releaseOriginal: true),
      address: addressData,
    );
  }

  // ---- byte arrays: copied into / out of the Java heap ----

  JByteArray _toJByteArray(Uint8List data) =>
      JByteArray(data.length)..setRange(0, data.length, data);

  int byteCount(Uint8List data) {
    final array = _toJByteArray(data);
    try {
      return DataBench.byteCount(array);
    } finally {
      array.release();
    }
  }

  int checksum(Uint8List data) {
    final array = _toJByteArray(data);
    try {
      return DataBench.checksum(array);
    } finally {
      array.release();
    }
  }

  /// `JByteArray.getRange` returns a *signed* `Int8List`; this re-views the
  /// same memory as unsigned bytes (no copy).
  Uint8List makeBytes(int size) {
    final array = DataBench.makeBytes(size);
    try {
      final signed = array.getRange(0, array.length);
      return signed.buffer.asUint8List(signed.offsetInBytes, signed.length);
    } finally {
      array.release();
    }
  }

  /// What a naive caller gets without the unsigned re-view above.
  Int8List makeBytesRawSigned(int size) {
    final array = DataBench.makeBytes(size);
    try {
      return array.getRange(0, array.length);
    } finally {
      array.release();
    }
  }

  // ---- direct ByteBuffers: native memory shared with Dart ----

  /// One copy: Dart bytes into a newly allocated direct buffer.
  int directByteCount(Uint8List data) {
    final buffer = JByteBuffer.fromList(data);
    try {
      return DataBench.directByteCount(buffer);
    } finally {
      buffer.release();
    }
  }

  int directChecksum(Uint8List data) {
    final buffer = JByteBuffer.fromList(data);
    try {
      return DataBench.directChecksum(buffer);
    } finally {
      buffer.release();
    }
  }

  /// Zero copy: Dart gets a view of the Java buffer's native memory. The
  /// Java buffer stays alive until the returned list is garbage collected.
  Uint8List makeDirectBytes(int size) =>
      DataBench.makeDirectBytes(size).asUint8List(releaseOriginal: true);

  int makeBytesNativeOnly(int size) => DataBench.makeBytesNativeOnly(size);

  int makeDirectBytesNativeOnly(int size) =>
      DataBench.makeDirectBytesNativeOnly(size);

  // ---- ints: primitive array vs boxed list ----

  int sumIntArray(Int32List values) {
    final array = JIntArray(values.length)..setRange(0, values.length, values);
    try {
      return DataBench.sumIntArray(array);
    } finally {
      array.release();
    }
  }

  Int32List makeIntArray(int count) {
    final array = DataBench.makeIntArray(count);
    try {
      return array.getRange(0, array.length);
    } finally {
      array.release();
    }
  }

  /// Each element becomes a Java `Integer` (one JNI call each) and is added
  /// to an `ArrayList` (another JNI call each).
  ///
  /// Each boxed element's JNI global reference is released right after it
  /// is added (the ArrayList keeps the Java object alive). The first version
  /// held them all in an `Arena` until the end: at 100,000 elements that
  /// exceeded Android's limit of 51,200 global references and ART aborted
  /// the whole process (SIGABRT, "global reference table overflow"), which
  /// Dart cannot catch. Never hold O(n) JNI references at once.
  int sumIntList(List<int> values) {
    final list = <JInteger>[].toJList();
    try {
      for (final value in values) {
        final boxed = value.toJInteger();
        list.add(boxed);
        boxed.release();
      }
      return DataBench.sumIntList(list);
    } finally {
      list.release();
    }
  }

  List<int> makeIntList(int count) {
    final list = DataBench.makeIntList(count);
    try {
      final size = list.size();
      final result = List<int>.filled(size, 0);
      for (var i = 0; i < size; i++) {
        final element = list.get(i)!;
        result[i] = element.intValue();
        element.release();
      }
      return result;
    } finally {
      list.release();
    }
  }
}
