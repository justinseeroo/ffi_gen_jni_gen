import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';

/// Registers dependencies, then launches the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const DeviceFeaturesApp());
}
