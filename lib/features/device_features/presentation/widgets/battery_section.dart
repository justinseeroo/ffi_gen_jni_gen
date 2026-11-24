import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/battery_status.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../cubit/section_state.dart';
import 'info_row.dart';
import 'section_card.dart';

/// Card showing battery level and charging status.
///
/// Uses `BlocSelector` so it rebuilds only when `state.battery` changes.
class BatterySection extends StatelessWidget {
  const BatterySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      DashboardCubit,
      DashboardState,
      SectionState<BatteryStatus>
    >(
      selector: (state) => state.battery,
      builder: (context, section) => SectionCard<BatteryStatus>(
        title: 'Battery',
        icon: Icons.battery_charging_full,
        section: section,
        contentBuilder: (battery) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: battery.levelRatio,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            InfoRow(label: 'Level', value: '${battery.level}%'),
            InfoRow(
              label: 'Status',
              value: battery.isCharging ? 'Charging' : 'Not charging',
            ),
          ],
        ),
      ),
    );
  }
}
