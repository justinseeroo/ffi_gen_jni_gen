import 'dart:io';

import 'package:ffigen/ffigen.dart';

/// Generates Dart bindings for the iOS APIs listed below into
/// `lib/ffi/ios_bindings.g.dart`.
///
/// Run with `dart run tool/ffigen.dart` after changing the lists. ffigen
/// parses the real iOS SDK headers, so this only runs on macOS with Xcode
/// installed (`xcode-select --install` alone is not enough: it needs the iOS
/// SDK that ships with full Xcode).
void main() {
  if (!Platform.isMacOS) {
    stderr.writeln(
      'tool/ffigen.dart reads the iOS SDK headers, so it must run on macOS '
      'with Xcode installed.',
    );
    exitCode = 1;
    return;
  }

  final packageRoot = Platform.script.resolve('../');
  FfiGenerator(
    headers: Headers(
      entryPoints: [packageRoot.resolve('tool/ffigen/ios_device_features.h')],
      // ffigen defaults to the macOS SDK. Point clang at the iOS SDK instead,
      // with the same minimum version as the Runner target.
      compilerOptions: [
        '-isysroot',
        iosSdkPath,
        '-target',
        'arm64-apple-ios13.0',
        '-Wno-nullability-completeness',
        ..._clangBuiltinIncludes(),
      ],
    ),
    objectiveC: ObjectiveC(
      interfaces: Interfaces(
        include: Declarations.includeSet(_members.keys.toSet()),
        includeMember: Declarations.includeMemberSet(_members),
      ),
    ),
    enums: Enums.includeSet({'UIDeviceBatteryState'}),
    functions: Functions.includeSet({
      'os_proc_available_memory',
      'sysctlbyname',
      'SCNetworkReachabilityCreateWithAddress',
      'SCNetworkReachabilityGetFlags',
      'CFRelease',
    }),
    output: Output(
      dartFile: packageRoot.resolve('lib/ffi/ios_bindings.g.dart'),
    ),
  ).generate();
}

/// Objective-C classes and the members (selectors) the app uses. Keeping the
/// list tight keeps the generated file small.
///
/// Note: a property with a custom getter is named after the getter in Dart,
/// so `batteryMonitoringEnabled` becomes `isBatteryMonitoringEnabled`.
const _members = {
  'UIDevice': {
    'currentDevice',
    'name',
    'model',
    'systemName',
    'systemVersion',
    'isBatteryMonitoringEnabled',
    'setBatteryMonitoringEnabled:',
    'batteryState',
    'batteryLevel',
  },
  'NSProcessInfo': {'processInfo', 'physicalMemory'},
};

/// clang's own headers (`stddef.h`, `stdarg.h`, ...) from the Xcode toolchain.
/// Passing `compilerOptions` replaces ffigen's defaults, which normally add
/// these.
List<String> _clangBuiltinIncludes() {
  final clangDir = Directory(
    '$xcodePath/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang',
  );
  if (!clangDir.existsSync()) return const [];
  for (final version in clangDir.listSync()) {
    final include = Directory('${version.path}/include');
    if (include.existsSync()) return ['-I${include.path}'];
  }
  return const [];
}
