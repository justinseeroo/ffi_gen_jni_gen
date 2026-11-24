import 'dart:io';

import 'package:jnigen/jnigen.dart';

/// Generates Dart bindings for the Android classes listed below into
/// `lib/jni/android_bindings.g.dart`.
///
/// Run with `dart run tool/jnigen.dart` after changing the class list.
/// `addGradleDeps` lets jnigen find Android SDK classes via the app's Gradle
/// classpath, so the Android project must have been configured at least once.
Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final generator = JniGenerator(
    input: Input(
      classes: [
        'android.content.Context',
        'android.os.Build',
        'android.os.BatteryManager',
        'android.os.StatFs',
        'android.os.Environment',
        'android.app.ActivityManager',
        'android.net.ConnectivityManager',
        'android.net.Network',
        'android.net.NetworkCapabilities',
        'java.io.File',
      ],
      androidSdk: AndroidSdk(addGradleDeps: true, androidExample: packageRoot),
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/jni/android_bindings.g.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
  );
  await generator.generate();
}
