import '../../../../core/error/failure.dart';
import '../../../../core/error/native_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/battery_status.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/entities/memory_usage.dart';
import '../../domain/entities/network_status.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/repositories/device_features_repository.dart';
import '../datasources/native_device_data_source.dart';

/// Implements [DeviceFeaturesRepository] on top of a [NativeDeviceDataSource].
///
/// Responsibilities:
/// - Caches [DeviceInfo], which never changes at runtime.
/// - Converts every exception from the native side into a [Failed] result,
///   so a broken API never crashes the app.
class DeviceFeaturesRepositoryImpl implements DeviceFeaturesRepository {
  DeviceFeaturesRepositoryImpl(this._dataSource);

  final NativeDeviceDataSource _dataSource;
  DeviceInfo? _cachedDeviceInfo;

  @override
  Result<DeviceInfo> getDeviceInfo() {
    final cached = _cachedDeviceInfo;
    if (cached != null) return Success(cached);
    return _guard(() => _cachedDeviceInfo = _dataSource.readDeviceInfo());
  }

  @override
  Result<BatteryStatus> getBatteryStatus() =>
      _guard(_dataSource.readBatteryStatus);

  @override
  Result<MemoryUsage> getMemoryUsage() => _guard(_dataSource.readMemoryUsage);

  @override
  Result<StorageUsage> getStorageUsage() =>
      _guard(_dataSource.readStorageUsage);

  @override
  Result<NetworkStatus> getNetworkStatus() =>
      _guard(_dataSource.readNetworkStatus);

  /// Runs [read] and wraps its outcome in a [Result].
  Result<T> _guard<T>(T Function() read) {
    try {
      return Success(read());
    } on NativeException catch (error) {
      return Failed(Failure(error.message));
    } catch (error) {
      return Failed(Failure('Native call failed: $error'));
    }
  }
}
