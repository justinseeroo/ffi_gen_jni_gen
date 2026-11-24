/// Formats a raw byte count for display.
extension ByteFormatter on int {
  static const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// Converts bytes to the largest fitting unit, e.g. `1536` → `1.5 KB`.
  String toReadableBytes({int fractionDigits = 1}) {
    if (this <= 0) return '0 B';

    var value = toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < _units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final digits = unitIndex == 0 ? 0 : fractionDigits;
    return '${value.toStringAsFixed(digits)} ${_units[unitIndex]}';
  }
}
