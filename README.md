# Native Device Features

A Flutter sample that reads native device features directly from Dart using
generated bindings: [jnigen](https://pub.dev/packages/jnigen) on Android and
[ffigen](https://pub.dev/packages/ffigen) on iOS. No platform channels and no
Kotlin, Java, Swift or Objective-C glue code.

| Feature | Android API | iOS API |
|---|---|---|
| Device info | `android.os.Build` | `UIDevice` + `sysctlbyname("hw.machine")` |
| Battery | `BatteryManager` | `UIDevice.batteryLevel` / `batteryState` |
| Memory | `ActivityManager.MemoryInfo` | `NSProcessInfo.physicalMemory` + `os_proc_available_memory` |
| Storage | `StatFs` + `Environment` | `NSURL` volume capacity keys |
| Network | `ConnectivityManager` + `NetworkCapabilities` | `SCNetworkReachability` |

iOS differences:

- Memory "available" is how much more this app may allocate before iOS
  terminates it. iOS doesn't expose system-wide free RAM, and it has no
  low-memory flag, so that row is hidden.
- On the simulator there is no battery and no memory limit, so those two cards
  show an error. Use a real device.

## Stack

- Clean Architecture (data / domain / presentation), feature-first
- `flutter_bloc` (Cubit) for state management
- `get_it` for dependency injection, which picks the data source per platform
- `equatable` for value equality
- `bloc_test` + `mocktail` for tests

## Project structure

```
lib/
├── core/            di, error, result, theme, utils
├── jni/             jnigen bindings (Android) + JNI helpers
├── ffi/             ffigen bindings (iOS)
├── features/device_features/
│   ├── data/        JNI + FFI data sources, models, repository impl
│   ├── domain/      entities, repository contract
│   └── presentation/ cubit, pages, widgets
├── app.dart
└── main.dart
tool/jnigen.dart              Android bindings generator config
tool/ffigen.dart              iOS bindings generator config
tool/ffigen/ios_device_features.h   headers ffigen parses
```

## Run

```sh
flutter pub get
flutter run        # Android device/emulator, or iOS device (on a Mac)
flutter test
```

## Regenerate bindings

### Android (any OS)

Edit the class list in `tool/jnigen.dart`, then:

```sh
dart run tool/jnigen.dart
```

Output: `lib/jni/android_bindings.g.dart` (do not edit by hand).

### iOS (macOS + Xcode only)

ffigen reads the iOS SDK headers, so it only runs on a Mac with Xcode
installed. Edit the lists in `tool/ffigen.dart`, then:

```sh
dart run tool/ffigen.dart
```

Output: `lib/ffi/ios_bindings.g.dart` (do not edit by hand). The committed
copy was first written by hand in ffigen's output format so the project builds
on Windows/Linux too. Running the command above replaces it with the real
output.

## Running on iOS (on a Mac)

1. Install Xcode (from the App Store) and open it once to accept the licence.
2. `flutter pub get`
3. `dart run tool/ffigen.dart` to regenerate the iOS bindings (see above).
4. Open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target, go to
   **Signing & Capabilities**, choose your Apple ID team, and change the
   bundle identifier (`com.example.ffiGenJniGen`) to something unique.
5. Connect the iPhone and trust the computer, then run `flutter run`. The first
   time, approve the developer profile on the phone under
   Settings > General > VPN & Device Management.
