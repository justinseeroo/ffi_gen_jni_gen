import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver for `flutter drive`. Writes the test's `reportData` to
/// `build/integration_response_data.json`.
Future<void> main() => integrationDriver();
