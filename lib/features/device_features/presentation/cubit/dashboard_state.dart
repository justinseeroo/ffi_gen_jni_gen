import 'package:equatable/equatable.dart';

import '../../domain/entities/battery_status.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/entities/memory_usage.dart';
import '../../domain/entities/network_status.dart';
import '../../domain/entities/storage_usage.dart';
import 'section_state.dart';

/// Immutable state of the dashboard, holding one [SectionState] per card.
///
/// Equatable equality lets the cubit skip emitting when nothing changed, and
/// lets each card's `BlocSelector` rebuild only when its own section changes.
class DashboardState extends Equatable {
  const DashboardState({
    this.deviceInfo = const SectionLoading(),
    this.battery = const SectionLoading(),
    this.memory = const SectionLoading(),
    this.storage = const SectionLoading(),
    this.network = const SectionLoading(),
  });

  final SectionState<DeviceInfo> deviceInfo;
  final SectionState<BatteryStatus> battery;
  final SectionState<MemoryUsage> memory;
  final SectionState<StorageUsage> storage;
  final SectionState<NetworkStatus> network;

  DashboardState copyWith({
    SectionState<DeviceInfo>? deviceInfo,
    SectionState<BatteryStatus>? battery,
    SectionState<MemoryUsage>? memory,
    SectionState<StorageUsage>? storage,
    SectionState<NetworkStatus>? network,
  }) {
    return DashboardState(
      deviceInfo: deviceInfo ?? this.deviceInfo,
      battery: battery ?? this.battery,
      memory: memory ?? this.memory,
      storage: storage ?? this.storage,
      network: network ?? this.network,
    );
  }

  @override
  List<Object?> get props => [deviceInfo, battery, memory, storage, network];
}
