import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

import '../../../../core/error/native_exception.dart';
import '../../../../jni/android_bindings.g.dart';
import '../models/battery_status_model.dart';
import '../models/device_info_model.dart';
import '../models/memory_usage_model.dart';
import '../models/network_status_model.dart';
import '../models/storage_usage_model.dart';

/// Low-level source of native device data.
///
/// Methods may throw (e.g. `NativeException` or a Java exception); the
/// repository is responsible for turning those into failures.
abstract interface class NativeDeviceDataSource {
  DeviceInfoModel readDeviceInfo();

  BatteryStatusModel readBatteryStatus();

  MemoryUsageModel readMemoryUsage();

  StorageUsageModel readStorageUsage();

  NetworkStatusModel readNetworkStatus();

  /// Releases any native resources held by the data source.
  void dispose();
}

/// Reads Android APIs directly through the jnigen-generated bindings in
/// `lib/jni/android_bindings.g.dart`. This is the only class in the app that
/// talks to JNI.
///
/// Memory strategy:
/// - Long-lived objects (app context and system services) are fetched once,
///   cached, and released in [dispose].
/// - Short-lived objects created per call are registered with an `Arena`
///   via `using`, so they are released as soon as the call returns.
class JniNativeDeviceDataSource implements NativeDeviceDataSource {
  Context? _context;
  BatteryManager? _batteryManager;
  ActivityManager? _activityManager;
  ConnectivityManager? _connectivityManager;

  Context get _appContext => _context ??= androidApplicationContext.as(
    Context.type,
    releaseOriginal: true,
  );

  BatteryManager get _battery => _batteryManager ??= _systemService(
    Context.BATTERY_SERVICE,
    BatteryManager.type,
  );

  ActivityManager get _activity => _activityManager ??= _systemService(
    Context.ACTIVITY_SERVICE,
    ActivityManager.type,
  );

  ConnectivityManager get _connectivity => _connectivityManager ??=
      _systemService(Context.CONNECTIVITY_SERVICE, ConnectivityManager.type);

  @override
  DeviceInfoModel readDeviceInfo() => DeviceInfoModel.fromNative();

  @override
  BatteryStatusModel readBatteryStatus() =>
      BatteryStatusModel.fromNative(_battery);

  /// Creates an empty `MemoryInfo`, lets `ActivityManager` fill it, then
  /// copies the values into a Dart model.
  @override
  MemoryUsageModel readMemoryUsage() {
    return using((arena) {
      final info = ActivityManager$MemoryInfo()..releasedBy(arena);
      _activity.getMemoryInfo(info);
      return MemoryUsageModel.fromNative(info);
    });
  }

  /// Measures the `/data` partition, where apps and user data are stored.
  @override
  StorageUsageModel readStorageUsage() {
    return using((arena) {
      final dataDirectory = Environment.dataDirectory?..releasedBy(arena);
      final path = dataDirectory?.path?..releasedBy(arena);
      if (path == null) {
        throw const NativeException('Data directory is unavailable');
      }
      final statFs = StatFs(path)..releasedBy(arena);
      return StorageUsageModel.fromNative(statFs);
    });
  }

  @override
  NetworkStatusModel readNetworkStatus() {
    return using((arena) {
      final network = _connectivity.activeNetwork?..releasedBy(arena);
      if (network == null) return const NetworkStatusModel.offline();

      final capabilities = _connectivity.getNetworkCapabilities(network)
        ?..releasedBy(arena);
      return NetworkStatusModel.fromNative(capabilities);
    });
  }

  @override
  void dispose() {
    _batteryManager?.release();
    _activityManager?.release();
    _connectivityManager?.release();
    _context?.release();
    _batteryManager = null;
    _activityManager = null;
    _connectivityManager = null;
    _context = null;
  }

  /// Equivalent of Java's `(T) context.getSystemService(name)`.
  ///
  /// Takes ownership of [serviceName] and releases it. The returned service
  /// is a global reference the caller must eventually release.
  T _systemService<T extends JObject>(JString? serviceName, JType<T> type) {
    return using((arena) {
      if (serviceName == null) {
        throw const NativeException('System service name is unavailable');
      }
      serviceName.releasedBy(arena);
      final service = _appContext.getSystemService$1(serviceName);
      if (service == null) {
        throw NativeException(
          'System service ${serviceName.toDartString()} is unavailable',
        );
      }
      return service.as(type, releaseOriginal: true);
    });
  }
}
