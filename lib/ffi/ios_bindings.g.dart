// PLACEHOLDER: hand-written in the exact shape ffigen 21 generates, so the app
// compiles (and runs) on machines without Xcode. On a Mac, regenerate it with
//
//   dart run tool/ffigen.dart
//
// which overwrites this file with the real ffigen output. Do not edit by hand.

// ignore_for_file: type=lint, unused_import, unused_element
import 'dart:ffi' as ffi;

import 'package:objective_c/objective_c.dart' as objc;

/// UIDevice
extension type UIDevice._(objc.ObjCObject object$)
    implements objc.ObjCObject, objc.NSObject {
  /// Constructs a [UIDevice] that points to the same underlying object as [other].
  UIDevice.as(objc.ObjCObject other) : object$ = other;

  /// Constructs a [UIDevice] that wraps the given raw object pointer.
  UIDevice.fromPointer(
    ffi.Pointer<objc.ObjCObjectImpl> other, {
    bool retain = false,
    bool release = false,
  }) : object$ = objc.ObjCObject(other, retain: retain, release: release);

  /// currentDevice
  static UIDevice getCurrentDevice() {
    final $ret = _objc_msgSend_151sglz(_class_UIDevice, _sel_currentDevice);
    return UIDevice.fromPointer($ret, retain: true, release: true);
  }
}

extension UIDevice$Methods on UIDevice {
  /// batteryLevel
  double get batteryLevel {
    final _$$ref = object$.ref;
    return objc.useMsgSendVariants
        ? _objc_msgSend_2cgrxlFpret(_$$ref.pointer, _sel_batteryLevel)
        : _objc_msgSend_2cgrxl(_$$ref.pointer, _sel_batteryLevel);
  }

  /// batteryState
  UIDeviceBatteryState get batteryState {
    final _$$ref = object$.ref;
    final $ret = _objc_msgSend_1hz7y9r(_$$ref.pointer, _sel_batteryState);
    return UIDeviceBatteryState.fromValue($ret);
  }

  /// isBatteryMonitoringEnabled
  bool get isBatteryMonitoringEnabled {
    final _$$ref = object$.ref;
    return _objc_msgSend_91o635(
      _$$ref.pointer,
      _sel_isBatteryMonitoringEnabled,
    );
  }

  /// setBatteryMonitoringEnabled:
  set isBatteryMonitoringEnabled(bool value) {
    final _$$ref = object$.ref;
    _objc_msgSend_1s56lr9(
      _$$ref.pointer,
      _sel_setBatteryMonitoringEnabled_,
      value,
    );
  }

  /// model
  objc.NSString get model {
    final _$$ref = object$.ref;
    final $ret = _objc_msgSend_151sglz(_$$ref.pointer, _sel_model);
    return objc.NSString.fromPointer($ret, retain: true, release: true);
  }

  /// name
  objc.NSString get name {
    final _$$ref = object$.ref;
    final $ret = _objc_msgSend_151sglz(_$$ref.pointer, _sel_name);
    return objc.NSString.fromPointer($ret, retain: true, release: true);
  }

  /// systemName
  objc.NSString get systemName {
    final _$$ref = object$.ref;
    final $ret = _objc_msgSend_151sglz(_$$ref.pointer, _sel_systemName);
    return objc.NSString.fromPointer($ret, retain: true, release: true);
  }

  /// systemVersion
  objc.NSString get systemVersion {
    final _$$ref = object$.ref;
    final $ret = _objc_msgSend_151sglz(_$$ref.pointer, _sel_systemVersion);
    return objc.NSString.fromPointer($ret, retain: true, release: true);
  }
}

/// NSProcessInfo
extension type NSProcessInfo._(objc.ObjCObject object$)
    implements objc.ObjCObject, objc.NSObject {
  /// Constructs a [NSProcessInfo] that points to the same underlying object as [other].
  NSProcessInfo.as(objc.ObjCObject other) : object$ = other;

  /// Constructs a [NSProcessInfo] that wraps the given raw object pointer.
  NSProcessInfo.fromPointer(
    ffi.Pointer<objc.ObjCObjectImpl> other, {
    bool retain = false,
    bool release = false,
  }) : object$ = objc.ObjCObject(other, retain: retain, release: release);

  /// processInfo
  static NSProcessInfo getProcessInfo() {
    final $ret = _objc_msgSend_151sglz(_class_NSProcessInfo, _sel_processInfo);
    return NSProcessInfo.fromPointer($ret, retain: true, release: true);
  }
}

extension NSProcessInfo$Methods on NSProcessInfo {
  /// physicalMemory
  int get physicalMemory {
    final _$$ref = object$.ref;
    return _objc_msgSend_xw2lp5(_$$ref.pointer, _sel_physicalMemory);
  }
}

enum UIDeviceBatteryState {
  UIDeviceBatteryStateUnknown(0),
  UIDeviceBatteryStateUnplugged(1),
  UIDeviceBatteryStateCharging(2),
  UIDeviceBatteryStateFull(3);

  final int value;
  const UIDeviceBatteryState(this.value);

  static UIDeviceBatteryState fromValue(int value) => switch (value) {
    0 => UIDeviceBatteryStateUnknown,
    1 => UIDeviceBatteryStateUnplugged,
    2 => UIDeviceBatteryStateCharging,
    3 => UIDeviceBatteryStateFull,
    _ => throw ArgumentError('Unknown value for UIDeviceBatteryState: $value'),
  };
}

final class __CFAllocator extends ffi.Opaque {}

final class sockaddr extends ffi.Opaque {}

final class __SCNetworkReachability extends ffi.Opaque {}

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>()
external void CFRelease(ffi.Pointer<ffi.Void> cf);

@ffi.Native<
  ffi.Pointer<__SCNetworkReachability> Function(
    ffi.Pointer<__CFAllocator>,
    ffi.Pointer<sockaddr>,
  )
>()
external ffi.Pointer<__SCNetworkReachability>
SCNetworkReachabilityCreateWithAddress(
  ffi.Pointer<__CFAllocator> allocator,
  ffi.Pointer<sockaddr> address,
);

@ffi.Native<
  ffi.UnsignedChar Function(
    ffi.Pointer<__SCNetworkReachability>,
    ffi.Pointer<ffi.Uint32>,
  )
>()
external int SCNetworkReachabilityGetFlags(
  ffi.Pointer<__SCNetworkReachability> target,
  ffi.Pointer<ffi.Uint32> flags,
);

@ffi.Native<ffi.Size Function()>()
external int os_proc_available_memory();

@ffi.Native<
  ffi.Int Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Size>,
    ffi.Pointer<ffi.Void>,
    ffi.Size,
  )
>()
external int sysctlbyname(
  ffi.Pointer<ffi.Char> arg0,
  ffi.Pointer<ffi.Void> arg1,
  ffi.Pointer<ffi.Size> arg2,
  ffi.Pointer<ffi.Void> arg3,
  int arg4,
);

late final _class_NSProcessInfo = objc.getClass("NSProcessInfo");
late final _class_UIDevice = objc.getClass("UIDevice");

final _objc_msgSend_151sglz = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.Pointer<objc.ObjCObjectImpl> Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      ffi.Pointer<objc.ObjCObjectImpl> Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();
final _objc_msgSend_1hz7y9r = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.Long Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      int Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();
final _objc_msgSend_1s56lr9 = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.Void Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
          ffi.Bool,
        )
      >
    >()
    .asFunction<
      void Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
        bool,
      )
    >();
final _objc_msgSend_2cgrxl = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.Float Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      double Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();
final _objc_msgSend_2cgrxlFpret = objc.msgSendFpretPointer
    .cast<
      ffi.NativeFunction<
        ffi.Float Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      double Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();
final _objc_msgSend_91o635 = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.Bool Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      bool Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();
final _objc_msgSend_xw2lp5 = objc.msgSendPointer
    .cast<
      ffi.NativeFunction<
        ffi.UnsignedLongLong Function(
          ffi.Pointer<objc.ObjCObjectImpl>,
          ffi.Pointer<objc.ObjCSelector>,
        )
      >
    >()
    .asFunction<
      int Function(
        ffi.Pointer<objc.ObjCObjectImpl>,
        ffi.Pointer<objc.ObjCSelector>,
      )
    >();

late final _sel_batteryLevel = objc.registerName("batteryLevel");
late final _sel_batteryState = objc.registerName("batteryState");
late final _sel_currentDevice = objc.registerName("currentDevice");
late final _sel_isBatteryMonitoringEnabled = objc.registerName(
  "isBatteryMonitoringEnabled",
);
late final _sel_model = objc.registerName("model");
late final _sel_name = objc.registerName("name");
late final _sel_physicalMemory = objc.registerName("physicalMemory");
late final _sel_processInfo = objc.registerName("processInfo");
late final _sel_setBatteryMonitoringEnabled_ = objc.registerName(
  "setBatteryMonitoringEnabled:",
);
late final _sel_systemName = objc.registerName("systemName");
late final _sel_systemVersion = objc.registerName("systemVersion");
