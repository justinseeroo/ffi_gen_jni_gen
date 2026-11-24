import 'package:jni/jni.dart';

/// Helpers for converting Java strings returned by generated bindings.
extension NullableJStringConversion on JString? {
  /// Converts to a Dart [String] (empty when `null`) and releases the Java
  /// reference immediately, so callers don't leak JNI global references.
  String toDartStringOrEmpty() {
    final value = this;
    if (value == null) return '';
    return value.toDartString(releaseOriginal: true);
  }
}
