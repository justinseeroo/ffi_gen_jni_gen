import '../../../../jni/android_bindings.g.dart';
import '../../domain/entities/storage_usage.dart';

/// Data-layer version of [StorageUsage] built from a native `StatFs`.
class StorageUsageModel extends StorageUsage {
  const StorageUsageModel({
    required super.totalBytes,
    required super.availableBytes,
  });

  /// Reads total and available bytes. The caller owns [statFs].
  factory StorageUsageModel.fromNative(StatFs statFs) {
    return StorageUsageModel(
      totalBytes: statFs.totalBytes,
      availableBytes: statFs.availableBytes,
    );
  }
}
