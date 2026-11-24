import '../../../../core/error/native_exception.dart';
import '../../../../ffi/ios_bindings.g.dart';
import '../../../../jni/android_bindings.g.dart';
import '../../domain/entities/battery_status.dart';

/// Data-layer version of [BatteryStatus] built from a native `BatteryManager`.
class BatteryStatusModel extends BatteryStatus {
  const BatteryStatusModel({required super.level, required super.isCharging});

  /// Reads the charge level and charging state. The caller owns [manager].
  factory BatteryStatusModel.fromNative(BatteryManager manager) {
    return BatteryStatusModel(
      level: manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
      isCharging: manager.isCharging,
    );
  }

  /// Reads `UIDevice.batteryLevel` (0.0–1.0) and `batteryState`.
  ///
  /// Battery monitoring must already be enabled on [device]; otherwise iOS
  /// reports level `-1` and state unknown, as it always does on the simulator.
  factory BatteryStatusModel.fromUIDevice(UIDevice device) {
    final level = device.batteryLevel;
    final state = device.batteryState;
    if (level < 0 || state == UIDeviceBatteryState.UIDeviceBatteryStateUnknown) {
      throw const NativeException(
        'Battery state is unknown (the iOS simulator has no battery)',
      );
    }
    return BatteryStatusModel(
      level: (level * 100).round(),
      // Matches Android, which reports a full battery on charger as charging.
      isCharging:
          state == UIDeviceBatteryState.UIDeviceBatteryStateCharging ||
          state == UIDeviceBatteryState.UIDeviceBatteryStateFull,
    );
  }
}
