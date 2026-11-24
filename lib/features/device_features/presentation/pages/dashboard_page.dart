import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../cubit/dashboard_cubit.dart';
import '../widgets/battery_section.dart';
import '../widgets/device_info_section.dart';
import '../widgets/memory_section.dart';
import '../widgets/network_section.dart';
import '../widgets/storage_section.dart';

/// Entry point of the feature: creates the [DashboardCubit] and starts it.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..start(),
      child: const DashboardView(),
    );
  }
}

/// The dashboard UI: an app bar with a refresh button and a list of cards.
///
/// Listens to the app lifecycle to pause live updates in the background and
/// resume them when the app returns.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const _sections = <Widget>[
    DeviceInfoSection(),
    BatterySection(),
    MemorySection(),
    StorageSection(),
    NetworkSection(),
  ];

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onResume,
      onPause: () => context.read<DashboardCubit>().pauseLiveUpdates(),
    );
  }

  void _onResume() {
    context.read<DashboardCubit>()
      ..refreshLiveData()
      ..resumeLiveUpdates();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Features via JNI'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DashboardCubit>().refreshLiveData(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        itemBuilder: (_, index) => _sections[index],
        separatorBuilder: (_, _) => const SizedBox(height: 12),
      ),
    );
  }
}
