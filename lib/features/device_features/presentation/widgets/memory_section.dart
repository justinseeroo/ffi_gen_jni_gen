import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/memory_usage.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../cubit/section_state.dart';
import 'info_row.dart';
import 'section_card.dart';
import 'usage_bar.dart';

/// Card showing RAM usage and, where the OS reports it, the low-memory flag.
///
/// Uses `BlocSelector` so it rebuilds only when `state.memory` changes.
class MemorySection extends StatelessWidget {
  const MemorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      DashboardCubit,
      DashboardState,
      SectionState<MemoryUsage>
    >(
      selector: (state) => state.memory,
      builder: (context, section) => SectionCard<MemoryUsage>(
        title: 'Memory (RAM)',
        icon: Icons.memory,
        section: section,
        contentBuilder: (memory) => Column(
          children: [
            UsageBar(usage: memory),
            if (memory.isLowMemory case final isLow?)
              InfoRow(label: 'Low memory', value: isLow ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }
}
