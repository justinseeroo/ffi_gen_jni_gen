import 'package:equatable/equatable.dart';

/// Static hardware and OS details of the device.
///
/// These never change while the app runs, so the repository caches them.
class DeviceInfo extends Equatable {
  const DeviceInfo({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.osName,
    required this.osVersion,
    this.apiLevel,
  });

  final String manufacturer;
  final String brand;
  final String model;
  final String device;

  /// e.g. `Android` or `iOS`.
  final String osName;

  /// User-facing OS version, e.g. `15` or `18.1`.
  final String osVersion;

  /// Android SDK level. `null` on platforms without one (iOS).
  final int? apiLevel;

  @override
  List<Object?> get props => [
    manufacturer,
    brand,
    model,
    device,
    osName,
    osVersion,
    apiLevel,
  ];
}
