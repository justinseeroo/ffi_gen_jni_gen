import 'package:equatable/equatable.dart';

/// Base class for anything measured as "used out of total" bytes.
///
/// Shared by `MemoryUsage` and `StorageUsage` so the UI can render both with
/// the same widget.
abstract class CapacityUsage extends Equatable {
  const CapacityUsage({required this.totalBytes, required this.availableBytes});

  final int totalBytes;
  final int availableBytes;

  int get usedBytes => totalBytes - availableBytes;

  /// Used fraction, 0.0–1.0. Returns 0 when [totalBytes] is unknown.
  double get usedRatio =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0, 1).toDouble();

  @override
  List<Object?> get props => [totalBytes, availableBytes];
}
