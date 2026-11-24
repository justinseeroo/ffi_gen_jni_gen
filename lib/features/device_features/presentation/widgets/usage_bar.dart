import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../domain/entities/capacity_usage.dart';
import 'info_row.dart';

/// Progress bar with used / free / total rows for any [CapacityUsage]
/// (used by both the memory and storage cards).
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.usage});

  final CapacityUsage usage;

  @override
  Widget build(BuildContext context) {
    final percent = (usage.usedRatio * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: usage.usedRatio, minHeight: 10),
        ),
        const SizedBox(height: 8),
        InfoRow(
          label: 'Used',
          value: '${usage.usedBytes.toReadableBytes()} ($percent%)',
        ),
        InfoRow(label: 'Free', value: usage.availableBytes.toReadableBytes()),
        InfoRow(label: 'Total', value: usage.totalBytes.toReadableBytes()),
      ],
    );
  }
}
