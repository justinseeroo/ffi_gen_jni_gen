import '../../../../jni/android_bindings.g.dart';
import '../../domain/entities/memory_usage.dart';

/// Data-layer version of [MemoryUsage] built from `ActivityManager.MemoryInfo`.
class MemoryUsageModel extends MemoryUsage {
  const MemoryUsageModel({
    required super.totalBytes,
    required super.availableBytes,
    super.isLowMemory,
  });

  /// Copies the fields of an already-filled [info]. The caller owns [info].
  factory MemoryUsageModel.fromNative(ActivityManager$MemoryInfo info) {
    return MemoryUsageModel(
      totalBytes: info.totalMem,
      availableBytes: info.availMem,
      isLowMemory: info.lowMemory,
    );
  }
}
