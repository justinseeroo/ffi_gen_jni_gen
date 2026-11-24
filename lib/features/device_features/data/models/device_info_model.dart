import 'package:objective_c/objective_c.dart' show NSStringToString;

import '../../../../ffi/ios_bindings.g.dart';
import '../../../../jni/android_bindings.g.dart';
import '../../../../jni/jstring_extensions.dart';
import '../../domain/entities/device_info.dart';

/// Data-layer version of [DeviceInfo] that knows how to read itself from the
/// native APIs of each platform.
class DeviceInfoModel extends DeviceInfo {
  const DeviceInfoModel({
    required super.manufacturer,
    required super.brand,
    required super.model,
    required super.device,
    required super.osName,
    required super.osVersion,
    super.apiLevel,
  });

  /// Reads the static fields of `android.os.Build` and `Build.VERSION`.
  factory DeviceInfoModel.fromNative() {
    return DeviceInfoModel(
      manufacturer: Build.MANUFACTURER.toDartStringOrEmpty(),
      brand: Build.BRAND.toDartStringOrEmpty(),
      model: Build.MODEL.toDartStringOrEmpty(),
      device: Build.DEVICE.toDartStringOrEmpty(),
      osName: 'Android',
      osVersion: Build$VERSION.RELEASE.toDartStringOrEmpty(),
      apiLevel: Build$VERSION.SDK_INT,
    );
  }

  /// Reads `UIDevice` plus the hardware identifier from `sysctl`.
  ///
  /// [machine] is the `hw.machine` value, e.g. `iPhone15,2` (`arm64` on the
  /// simulator). Since iOS 16, `UIDevice.name` is the generic model name
  /// (`iPhone`) unless the app has the user-assigned-name entitlement.
  factory DeviceInfoModel.fromUIDevice(
    UIDevice device, {
    required String machine,
  }) {
    return DeviceInfoModel(
      manufacturer: 'Apple',
      brand: device.model.toDartString(),
      model: machine,
      device: device.name.toDartString(),
      osName: device.systemName.toDartString(),
      osVersion: device.systemVersion.toDartString(),
    );
  }
}
