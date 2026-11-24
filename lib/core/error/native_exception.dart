/// Thrown by the data layer when a native (JNI) value is missing or invalid.
///
/// Caught by the repository and converted into a `Failure`.
class NativeException implements Exception {
  const NativeException(this.message);

  final String message;

  @override
  String toString() => 'NativeException: $message';
}
