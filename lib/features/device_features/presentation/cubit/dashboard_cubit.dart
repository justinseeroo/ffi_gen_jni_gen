import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/device_features_repository.dart';
import 'dashboard_state.dart';
import 'section_state.dart';

/// Drives the dashboard: loads static device info once and keeps the live
/// sections (battery, memory, storage, network) refreshed on a timer.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(
    this._repository, {
    Duration refreshInterval = const Duration(seconds: 2),
  }) : _refreshInterval = refreshInterval,
       super(const DashboardState());

  final DeviceFeaturesRepository _repository;
  final Duration _refreshInterval;
  Timer? _refreshTimer;

  /// Loads everything once and starts periodic refreshing.
  void start() {
    emit(state.copyWith(deviceInfo: _toSection(_repository.getDeviceInfo())));
    refreshLiveData();
    resumeLiveUpdates();
  }

  /// Re-reads the sections that change over time. Emits nothing if all
  /// values are the same as before.
  void refreshLiveData() {
    if (isClosed) return;
    emit(
      state.copyWith(
        battery: _toSection(_repository.getBatteryStatus()),
        memory: _toSection(_repository.getMemoryUsage()),
        storage: _toSection(_repository.getStorageUsage()),
        network: _toSection(_repository.getNetworkStatus()),
      ),
    );
  }

  /// (Re)starts the refresh timer.
  void resumeLiveUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refreshLiveData());
  }

  /// Stops the refresh timer, e.g. while the app is in the background, so no
  /// native calls are made when nobody is looking.
  void pauseLiveUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  SectionState<T> _toSection<T>(Result<T> result) {
    return switch (result) {
      Success<T>(:final data) => SectionLoaded(data),
      Failed<T>(:final failure) => SectionError(failure.message),
    };
  }

  @override
  Future<void> close() {
    pauseLiveUpdates();
    return super.close();
  }
}
