import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:objective_c/objective_c.dart';

import '../../../../core/error/native_exception.dart';
import '../../../../ffi/ios_bindings.g.dart';
import '../models/battery_status_model.dart';
import '../models/device_info_model.dart';
import '../models/memory_usage_model.dart';
import '../models/network_status_model.dart';
import '../models/storage_usage_model.dart';
import 'native_device_data_source.dart';

/// Reads iOS APIs directly through the ffigen-generated bindings in
/// `lib/ffi/ios_bindings.g.dart` and the Foundation classes that ship with
/// `package:objective_c`. This is the only class in the app that talks to
/// Objective-C or C on iOS.
///
/// Memory strategy (mirrors the JNI data source):
/// - `UIDevice.currentDevice` is fetched once and cached. Dart holds a strong
///   reference that is released when the wrapper is garbage collected.
/// - Each read runs inside an `autoReleasePool`, so objects Objective-C
///   autoreleases during the call are freed as soon as it returns.
/// - Raw C memory comes from an `Arena` via `using`, freed the same way.
///
/// UIKit must be used from the main thread. Flutter on iOS runs the root
/// isolate on the platform (main) thread, so calling this from UI code is
/// safe. Do not call it from a background isolate.
class FfiNativeDeviceDataSource implements NativeDeviceDataSource {
  UIDevice? _device;

  /// The current device, with battery monitoring switched on. Without it iOS
  /// reports battery level `-1`.
  UIDevice get _uiDevice {
    final cached = _device;
    if (cached != null) return cached;
    final device = UIDevice.getCurrentDevice()
      ..isBatteryMonitoringEnabled = true;
    return _device = device;
  }

  @override
  DeviceInfoModel readDeviceInfo() {
    return autoReleasePool(
      () => DeviceInfoModel.fromUIDevice(
        _uiDevice,
        machine: _sysctlString('hw.machine'),
      ),
    );
  }

  @override
  BatteryStatusModel readBatteryStatus() =>
      BatteryStatusModel.fromUIDevice(_uiDevice);

  /// Total RAM from `NSProcessInfo`, and what this app may still allocate
  /// from `os_proc_available_memory` (iOS 13+). iOS has no system-wide
  /// low-memory flag, so `isLowMemory` stays `null`.
  @override
  MemoryUsageModel readMemoryUsage() {
    return autoReleasePool(() {
      final total = NSProcessInfo.getProcessInfo().physicalMemory;
      final available = os_proc_available_memory();
      if (available == 0) {
        // Returned on the simulator and when the process is not memory
        // limited.
        throw const NativeException('Available memory is unavailable');
      }
      return MemoryUsageModel(totalBytes: total, availableBytes: available);
    });
  }

  /// Measures the volume that holds the app's container. "Available for
  /// important usage" matches the free space shown in Settings: it counts
  /// purgeable space iOS would reclaim for the user.
  @override
  StorageUsageModel readStorageUsage() {
    return autoReleasePool(() {
      final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
      final values = NSURL.fileURLWithPath(
        NSString(home),
      ).resourceValuesForKeys(NSArray.of([_totalKey, _importantKey, _freeKey]));
      if (values == null) {
        throw const NativeException('Volume capacity is unavailable');
      }

      final total = _intValue(values, _totalKey);
      final available =
          _intValue(values, _importantKey) ?? _intValue(values, _freeKey);
      if (total == null || available == null) {
        throw const NativeException('Volume capacity is unavailable');
      }
      return StorageUsageModel(totalBytes: total, availableBytes: available);
    });
  }

  /// Asks `SCNetworkReachability` whether the default route (`0.0.0.0`) is
  /// reachable. Checking an address rather than a host name means no DNS
  /// lookup, so the call never blocks.
  @override
  NetworkStatusModel readNetworkStatus() {
    return using((arena) {
      // struct sockaddr_in, zero-filled: sin_len = 16, sin_family = AF_INET.
      final address = arena<Uint8>(16);
      address[0] = 16;
      address[1] = 2;

      final reachability = SCNetworkReachabilityCreateWithAddress(
        nullptr,
        address.cast(),
      );
      if (reachability == nullptr) {
        throw const NativeException('Network reachability is unavailable');
      }
      try {
        final flags = arena<Uint32>();
        if (SCNetworkReachabilityGetFlags(reachability, flags) == 0) {
          throw const NativeException('Network reachability is unavailable');
        }
        return NetworkStatusModel.fromReachabilityFlags(flags.value);
      } finally {
        CFRelease(reachability.cast());
      }
    });
  }

  @override
  void dispose() {
    _device?.isBatteryMonitoringEnabled = false;
    _device = null;
  }

  /// Reads a string `sysctl` value such as `hw.machine`: first asks for the
  /// size, then fills a buffer of that size.
  String _sysctlString(String name) {
    return using((arena) {
      final nativeName = name.toNativeUtf8(allocator: arena).cast<Char>();
      final size = arena<Size>();
      if (sysctlbyname(nativeName, nullptr, size, nullptr, 0) != 0) {
        throw NativeException('sysctl $name is unavailable');
      }
      final buffer = arena<Uint8>(size.value);
      if (sysctlbyname(nativeName, buffer.cast(), size, nullptr, 0) != 0) {
        throw NativeException('sysctl $name is unavailable');
      }
      return buffer.cast<Utf8>().toDartString();
    });
  }

  // NSURLResourceKey constants. Their values are their own names, so
  // building them from strings avoids binding the globals.
  static final _totalKey = NSString('NSURLVolumeTotalCapacityKey');
  static final _importantKey = NSString(
    'NSURLVolumeAvailableCapacityForImportantUsageKey',
  );
  static final _freeKey = NSString('NSURLVolumeAvailableCapacityKey');

  static int? _intValue(NSDictionary values, NSString key) {
    final value = values.objectForKey(key);
    return NSNumber.isA(value) ? NSNumber.as(value!).longLongValue : null;
  }
}
