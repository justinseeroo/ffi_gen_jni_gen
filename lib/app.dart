import 'dart:io';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/device_features/presentation/pages/dashboard_page.dart';
import 'features/device_features/presentation/pages/unsupported_platform_page.dart';

/// Root widget: sets up theming and picks the start page by platform.
class DeviceFeaturesApp extends StatelessWidget {
  const DeviceFeaturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Device Features',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Platform.isAndroid || Platform.isIOS
          ? const DashboardPage()
          : const UnsupportedPlatformPage(),
    );
  }
}
