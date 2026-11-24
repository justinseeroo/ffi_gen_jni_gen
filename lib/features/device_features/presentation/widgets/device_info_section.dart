import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/device_info.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../cubit/section_state.dart';
import 'info_row.dart';
import 'section_card.dart';

/// Card showing manufacturer, model and OS version.
///
/// Uses `BlocSelector` so it rebuilds only when `state.deviceInfo` changes.
class DeviceInfoSection extends StatelessWidget {
  const DeviceInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      DashboardCubit,
      DashboardState,
      SectionState<DeviceInfo>
    >(
      selector: (state) => state.deviceInfo,
      builder: (context, section) => SectionCard<DeviceInfo>(
        title: 'Device',
        icon: Icons.smartphone,
        section: section,
        contentBuilder: (info) => Column(
          children: [
            InfoRow(label: 'Manufacturer', value: info.manufacturer),
            InfoRow(label: 'Brand', value: info.brand),
            InfoRow(label: 'Model', value: info.model),
            InfoRow(label: 'Device', value: info.device),
            InfoRow(
              label: info.osName,
              value: info.apiLevel == null
                  ? info.osVersion
                  : '${info.osVersion} (API ${info.apiLevel})',
            ),
          ],
        ),
      ),
    );
  }
}
