import 'dart:io';

import 'package:get_it/get_it.dart';

import '../../features/device_features/data/datasources/ffi_native_device_data_source.dart';
import '../../features/device_features/data/datasources/native_device_data_source.dart';
import '../../features/device_features/data/repositories/device_features_repository_impl.dart';
import '../../features/device_features/domain/repositories/device_features_repository.dart';
import '../../features/device_features/presentation/cubit/dashboard_cubit.dart';

/// Global service locator.
final GetIt getIt = GetIt.instance;

/// Registers all app dependencies. Call once before `runApp`.
///
/// - The data source is picked by platform: JNI bindings on Android, ffigen
///   bindings on iOS.
/// - Data source and repository are lazy singletons: created on first use and
///   shared, so cached native references live for the whole app.
/// - The cubit is a factory: each page gets a fresh instance that is closed
///   with the page.
void configureDependencies() {
  getIt
    ..registerLazySingleton<NativeDeviceDataSource>(
      Platform.isIOS
          ? FfiNativeDeviceDataSource.new
          : JniNativeDeviceDataSource.new,
      dispose: (dataSource) => dataSource.dispose(),
    )
    ..registerLazySingleton<DeviceFeaturesRepository>(
      () => DeviceFeaturesRepositoryImpl(getIt()),
    )
    ..registerFactory<DashboardCubit>(() => DashboardCubit(getIt()));
}
