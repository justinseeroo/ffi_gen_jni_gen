import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/network_status.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../cubit/section_state.dart';
import 'info_row.dart';
import 'section_card.dart';

/// Card showing connection type and internet availability.
///
/// Uses `BlocSelector` so it rebuilds only when `state.network` changes.
class NetworkSection extends StatelessWidget {
  const NetworkSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      DashboardCubit,
      DashboardState,
      SectionState<NetworkStatus>
    >(
      selector: (state) => state.network,
      builder: (context, section) => SectionCard<NetworkStatus>(
        title: 'Network',
        icon: Icons.wifi,
        section: section,
        contentBuilder: (network) => Column(
          children: [
            InfoRow(label: 'Connection', value: network.connectionType.label),
            InfoRow(
              label: 'Internet',
              value: network.hasInternet ? 'Available' : 'Unavailable',
            ),
          ],
        ),
      ),
    );
  }
}
