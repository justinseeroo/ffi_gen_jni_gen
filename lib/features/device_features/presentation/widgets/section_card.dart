import 'package:flutter/material.dart';

import '../cubit/section_state.dart';

/// Reusable card that renders a [SectionState]: a spinner while loading,
/// an error message on failure, or [contentBuilder]'s output when loaded.
class SectionCard<T> extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.section,
    required this.contentBuilder,
  });

  final String title;
  final IconData icon;
  final SectionState<T> section;
  final Widget Function(T data) contentBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            switch (section) {
              SectionLoading<T>() => const Center(
                child: CircularProgressIndicator(),
              ),
              SectionLoaded<T>(:final data) => contentBuilder(data),
              SectionError<T>(:final message) => Text(
                message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            },
          ],
        ),
      ),
    );
  }
}
