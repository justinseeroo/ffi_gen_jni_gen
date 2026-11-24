import 'package:bloc_test/bloc_test.dart';
import 'package:ffi_gen_jni_gen/core/error/failure.dart';
import 'package:ffi_gen_jni_gen/core/result/result.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/battery_status.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/device_info.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/memory_usage.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/network_status.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/entities/storage_usage.dart';
import 'package:ffi_gen_jni_gen/features/device_features/domain/repositories/device_features_repository.dart';
import 'package:ffi_gen_jni_gen/features/device_features/presentation/cubit/dashboard_cubit.dart';
import 'package:ffi_gen_jni_gen/features/device_features/presentation/cubit/dashboard_state.dart';
import 'package:ffi_gen_jni_gen/features/device_features/presentation/cubit/section_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeviceFeaturesRepository extends Mock
    implements DeviceFeaturesRepository {}

void main() {
  const deviceInfo = DeviceInfo(
    manufacturer: 'Google',
    brand: 'google',
    model: 'Pixel 8',
    device: 'shiba',
    osName: 'Android',
    osVersion: '15',
    apiLevel: 35,
  );
  const battery = BatteryStatus(level: 80, isCharging: true);
  const memory = MemoryUsage(
    totalBytes: 8000,
    availableBytes: 2000,
    isLowMemory: false,
  );
  const storage = StorageUsage(totalBytes: 1000, availableBytes: 400);
  const network = NetworkStatus(
    connectionType: ConnectionType.wifi,
    hasInternet: true,
  );

  late _MockDeviceFeaturesRepository repository;

  setUp(() {
    repository = _MockDeviceFeaturesRepository();
    when(
      () => repository.getDeviceInfo(),
    ).thenReturn(const Success(deviceInfo));
    when(
      () => repository.getBatteryStatus(),
    ).thenReturn(const Success(battery));
    when(() => repository.getMemoryUsage()).thenReturn(const Success(memory));
    when(() => repository.getStorageUsage()).thenReturn(const Success(storage));
    when(
      () => repository.getNetworkStatus(),
    ).thenReturn(const Success(network));
  });

  DashboardCubit buildCubit() =>
      DashboardCubit(repository, refreshInterval: const Duration(hours: 1));

  test('initial state has every section loading', () {
    expect(buildCubit().state, const DashboardState());
  });

  blocTest<DashboardCubit, DashboardState>(
    'start loads device info and live data',
    build: buildCubit,
    act: (cubit) => cubit.start(),
    expect: () => const [
      DashboardState(deviceInfo: SectionLoaded(deviceInfo)),
      DashboardState(
        deviceInfo: SectionLoaded(deviceInfo),
        battery: SectionLoaded(battery),
        memory: SectionLoaded(memory),
        storage: SectionLoaded(storage),
        network: SectionLoaded(network),
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'a failing section reports an error without affecting the others',
    setUp: () => when(
      () => repository.getBatteryStatus(),
    ).thenReturn(const Failed(Failure('Battery service unavailable'))),
    build: buildCubit,
    act: (cubit) => cubit.refreshLiveData(),
    expect: () => const [
      DashboardState(
        battery: SectionError('Battery service unavailable'),
        memory: SectionLoaded(memory),
        storage: SectionLoaded(storage),
        network: SectionLoaded(network),
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'refresh with unchanged values emits nothing new',
    build: buildCubit,
    seed: () => const DashboardState(
      battery: SectionLoaded(battery),
      memory: SectionLoaded(memory),
      storage: SectionLoaded(storage),
      network: SectionLoaded(network),
    ),
    act: (cubit) => cubit.refreshLiveData(),
    expect: () => const <DashboardState>[],
  );
}
