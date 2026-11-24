import '../../../../core/result/result.dart';
import '../entities/battery_status.dart';
import '../entities/device_info.dart';
import '../entities/memory_usage.dart';
import '../entities/network_status.dart';
import '../entities/storage_usage.dart';

/// Contract for reading native device features.
///
/// Lives in the domain layer so the UI depends on this abstraction, not on
/// JNI. Every method returns a [Result] instead of throwing.
abstract interface class DeviceFeaturesRepository {
  Result<DeviceInfo> getDeviceInfo();

  Result<BatteryStatus> getBatteryStatus();

  Result<MemoryUsage> getMemoryUsage();

  Result<StorageUsage> getStorageUsage();

  Result<NetworkStatus> getNetworkStatus();
}
