import 'capacity_usage.dart';

/// Device RAM usage.
///
/// On Android, [availableBytes] is system-wide free memory
/// (`ActivityManager.MemoryInfo`). On iOS it is how much more this app may
/// allocate before the system terminates it (`os_proc_available_memory`), the
/// only figure iOS exposes to apps.
class MemoryUsage extends CapacityUsage {
  const MemoryUsage({
    required super.totalBytes,
    required super.availableBytes,
    this.isLowMemory,
  });

  /// `true` when Android considers the system low on memory and may start
  /// killing background processes. `null` where the OS has no such flag (iOS).
  final bool? isLowMemory;

  @override
  List<Object?> get props => [...super.props, isLowMemory];
}
