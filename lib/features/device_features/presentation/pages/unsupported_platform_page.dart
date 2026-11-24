import 'package:flutter/material.dart';

/// Shown on platforms without native bindings (anything but Android and iOS).
class UnsupportedPlatformPage extends StatelessWidget {
  const UnsupportedPlatformPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This demo reads native APIs through JNI (Android) and '
            'ffigen (iOS).\n'
            'Run it on an Android or iOS device.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
