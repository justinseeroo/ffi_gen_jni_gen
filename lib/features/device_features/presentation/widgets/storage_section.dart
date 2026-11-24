import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/storage_usage.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../cubit/section_state.dart';
import 'section_card.dart';
import 'usage_bar.dart';

/// Card showing internal storage usage.
///
/// Uses `BlocSelector` so it rebuilds only when `state.storage` changes.
class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      DashboardCubit,
      DashboardState,
      SectionState<StorageUsage>
    >(
      selector: (state) => state.storage,
      builder: (context, section) => SectionCard<StorageUsage>(
        title: 'Internal storage',
        icon: Icons.sd_storage,
        section: section,
        contentBuilder: (storage) => UsageBar(usage: storage),
      ),
    );
  }
}
