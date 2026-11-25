import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jni/jni.dart';

import '../features/device_features/data/models/device_info_model.dart';
import '../jni/bench_bindings.g.dart';
import 'bench/ui_monitor.dart';

/// Experiment 3: native -> Flutter communication, asynchronous work,
/// threads, concurrency and dispose, jnigen vs MethodChannel/EventChannel,
/// on Android. Every row records what was observed; nothing is assumed.
Future<Map<String, Object?>> runExperiment03({
  required UiMonitor monitor,
  void Function(String line)? log,
}) async {
  final rows = <Map<String, Object?>>[];
  void record(String section, String name, Map<String, Object?> data) {
    final row = {'section': section, 'name': name, ...data};
    rows.add(row);
    log?.call('$row');
  }

  Future<void> guarded(
    String section,
    String name,
    Future<Map<String, Object?>> Function() body,
  ) async {
    try {
      record(section, name, await body());
    } catch (error, stack) {
      record(section, name, {
        'error': '${error.runtimeType}: $error',
        'stack': '$stack'.split('\n').take(3).join(' | '),
      });
    }
  }

  // Let the first frames settle so the refresh interval is known.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  record('setup', 'display', {
    'frame_interval_ms': double.parse(
      monitor.recentFrameIntervalMs.toStringAsFixed(2),
    ),
  });

  await _threads(guarded);
  await _longRunning(guarded, monitor);
  await _asyncErrors(guarded);
  await _callbacks(guarded);
  await _concurrency(guarded, monitor);
  await _dispose(guarded);
  await _deadlock(guarded, monitor);

  final device = DeviceInfoModel.fromNative();
  return {
    'experiment': '03_async_callbacks_android',
    'build_mode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'device': {
      'manufacturer': device.manufacturer,
      'model': device.model,
      'android': device.osVersion,
      'api_level': device.apiLevel,
    },
    'results': rows,
  };
}

typedef _Guarded =
    Future<void> Function(
      String section,
      String name,
      Future<Map<String, Object?>> Function() body,
    );

const _main = MethodChannel('rnd/async');
const _bgSerial = MethodChannel('rnd/async_bg_serial');
const _bgParallel = MethodChannel('rnd/async_bg_parallel');
const _progress = EventChannel('rnd/async_progress');

String _str(JString value) => value.toDartString(releaseOriginal: true);

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000;

// ---------------------------------------------------------------------------
// A. Which thread runs native code?
// ---------------------------------------------------------------------------

Future<void> _threads(_Guarded guarded) async {
  const s = 'A_threads';
  await guarded(s, 'jnigen_from_ui_isolate', () async => {
    'native_thread': _str(AsyncBench.threadName()),
    'is_android_main_thread': AsyncBench.isMainThread,
  });
  await guarded(s, 'jnigen_from_background_isolate', () async {
    final (thread, isMain) = await Isolate.run(
      () => (
        AsyncBench.threadName().toDartString(releaseOriginal: true),
        AsyncBench.isMainThread,
      ),
    );
    return {'native_thread': thread, 'is_android_main_thread': isMain};
  });
  await guarded(s, 'jnigen_suspend_fun_resumes_from', () async => {
    'native_thread': (_str(await AsyncBench.suspendWork(0, 0))).split('@')[1],
  });
  for (final (name, channel) in [
    ('method_channel_default', _main),
    ('method_channel_bg_serial_taskqueue', _bgSerial),
    ('method_channel_bg_parallel_taskqueue', _bgParallel),
  ]) {
    await guarded(s, name, () async => {
      'native_thread': await channel.invokeMethod<String>('threadName'),
      'is_android_main_thread': await channel.invokeMethod<bool>(
        'isMainThread',
      ),
    });
  }
}

// ---------------------------------------------------------------------------
// B. A 1 s native operation: result, wall time, UI freeze
// ---------------------------------------------------------------------------

Future<void> _longRunning(_Guarded guarded, UiMonitor monitor) async {
  const s = 'B_long_running_1000ms';
  Future<void> run(String name, FutureOr<String> Function() op) =>
      guarded(s, name, () async {
        final impact = await monitor.measure(op);
        return {'result': impact.result, ...impact.toJson()};
      });

  await run(
    'baseline_idle_dart_delay',
    () => Future.delayed(const Duration(seconds: 1), () => 'idle'),
  );
  await run(
    'jnigen_sync_on_ui_isolate',
    () => _str(AsyncBench.blockingWork(1000)),
  );
  await run(
    'jnigen_suspend_fun_future',
    () async => _str(await AsyncBench.suspendWork(1, 1000)),
  );
  await run(
    'jnigen_sync_in_isolate_run',
    () => Isolate.run(
      () => AsyncBench.blockingWork(1000).toDartString(releaseOriginal: true),
    ),
  );
  await run(
    'method_channel_default_main_thread',
    () async => (await _main.invokeMethod<String>('blockingWork', 1000))!,
  );
  await run(
    'method_channel_bg_serial_taskqueue',
    () async => (await _bgSerial.invokeMethod<String>('blockingWork', 1000))!,
  );
  await run(
    'method_channel_bg_parallel_taskqueue',
    () async =>
        (await _bgParallel.invokeMethod<String>('blockingWork', 1000))!,
  );
}

// ---------------------------------------------------------------------------
// Errors in asynchronous native work
// ---------------------------------------------------------------------------

Future<void> _asyncErrors(_Guarded guarded) async {
  const s = 'B2_async_errors';
  await guarded(s, 'jnigen_suspend_fun_throws', () async {
    try {
      final r = await AsyncBench.suspendFail('boom'.toJString());
      return {'caught': false, 'result': _str(r)};
    } catch (e) {
      return {
        'caught': true,
        'dart_type': '${e.runtimeType}',
        'message': '$e'.split('\n').first,
      };
    }
  });
  await guarded(s, 'method_channel_error_from_worker', () async {
    try {
      await _main.invokeMethod<void>('failAsync', 'boom');
      return {'caught': false};
    } on PlatformException catch (e) {
      return {
        'caught': true,
        'dart_type': '${e.runtimeType}',
        'code': e.code,
        'message': e.message,
      };
    }
  });
}

// ---------------------------------------------------------------------------
// C. Native -> Dart callbacks
// ---------------------------------------------------------------------------

Future<void> _callbacks(_Guarded guarded) async {
  const s = 'C_callbacks';
  const n = 1000;

  // C1: Kotlin calls Dart on the same thread, inside a Dart -> Kotlin call.
  await guarded(s, 'jnigen_same_thread_void_callback_x10000', () async {
    var count = 0;
    final listener = ProgressListener.implement(
      $ProgressListener(
        onProgress: (id, step, thread) {
          count++;
          thread.release();
        },
        onComplete: (id, result, thread) => thread.release(),
      ),
    );
    final sw = Stopwatch()..start();
    AsyncBench.callListenerOnCallingThread(listener, 10000);
    sw.stop();
    listener.release();
    return {
      'received': count,
      'total_ms': _ms(sw),
      'per_callback_us': sw.elapsedMicroseconds / 10000,
    };
  });
  await guarded(s, 'jnigen_same_thread_value_callback_x10000', () async {
    final provider = ValueProvider.implement(
      $ValueProvider(provide: (i) => i * 2),
    );
    final sw = Stopwatch()..start();
    final sum = AsyncBench.askDartOnCallingThread(provider, 10000);
    sw.stop();
    provider.release();
    return {
      'sum_correct': sum == 10000 * 9999,
      'total_ms': _ms(sw),
      'per_callback_us': sw.elapsedMicroseconds / 10000,
    };
  });

  // C2: a worker thread sends 1000 progress events, then completion.
  Future<Map<String, Object?>> workerEvents({
    required int requestId,
    required bool async,
  }) async {
    final steps = <int>[];
    final threads = <String>{};
    final done = Completer<void>();
    final listener = ProgressListener.implement(
      $ProgressListener(
        onProgress: (id, step, thread) {
          steps.add(step);
          threads.add(_str(thread));
        },
        onProgress$async: async,
        onComplete: (id, result, thread) {
          thread.release();
          done.complete();
        },
        onComplete$async: async,
      ),
    );
    final sw = Stopwatch()..start();
    final handle = AsyncBench.startWork(requestId, n, 0, false, listener);
    await done.future.timeout(const Duration(seconds: 30));
    sw.stop();
    handle.release();
    listener.release();
    return {
      'received': steps.length,
      'in_order': listEquals(steps, [for (var i = 1; i <= n; i++) i]),
      'native_threads': threads.toList(),
      'total_ms': _ms(sw),
      'per_event_us': sw.elapsedMicroseconds / n,
    };
  }

  await guarded(
    s,
    'jnigen_worker_thread_listener_async_x1000',
    () => workerEvents(requestId: 2, async: true),
  );
  await guarded(
    s,
    'jnigen_worker_thread_listener_blocking_x1000',
    () => workerEvents(requestId: 3, async: false),
  );

  await guarded(s, 'event_channel_worker_thread_x1000', () async {
    final steps = <int>[];
    final threads = <String>{};
    final sw = Stopwatch()..start();
    await for (final event in _progress.receiveBroadcastStream({
      'steps': n,
      'stepMillis': 0,
    })) {
      final map = event as Map<Object?, Object?>;
      steps.add(map['step']! as int);
      threads.add(map['thread']! as String);
    }
    sw.stop();
    return {
      'received': steps.length,
      'in_order': listEquals(steps, [for (var i = 1; i <= n; i++) i]),
      'delivered_on_native_thread': threads.toList(),
      'total_ms': _ms(sw),
      'per_event_us': sw.elapsedMicroseconds / n,
    };
  });

  // C3: native asks Dart for a value 1000 times (each waits for Dart).
  await guarded(s, 'jnigen_worker_thread_value_callback_x1000', () async {
    final provider = ValueProvider.implement(
      $ValueProvider(provide: (i) => i * 2),
    );
    final done = Completer<int>();
    final listener = ProgressListener.implement(
      $ProgressListener(
        onProgress: (id, step, thread) => thread.release(),
        onComplete: (id, result, thread) {
          thread.release();
          done.complete(result);
        },
        onComplete$async: true,
      ),
    );
    final sw = Stopwatch()..start();
    final handle = AsyncBench.startAskDart(4, n, 0, provider, listener);
    final sum = await done.future.timeout(const Duration(seconds: 30));
    sw.stop();
    final status = _str(handle.status());
    handle.release();
    provider.release();
    listener.release();
    return {
      'sum_correct': sum == n * (n - 1),
      'native_status': status,
      'total_ms': _ms(sw),
      'per_round_trip_us': sw.elapsedMicroseconds / n,
    };
  });
  await guarded(s, 'method_channel_native_invokes_dart_x1000', () async {
    _main.setMethodCallHandler((call) async {
      if (call.method == 'provide') return (call.arguments as int) * 2;
      throw MissingPluginException();
    });
    final sw = Stopwatch()..start();
    final sum = await _main.invokeMethod<int>('askDart', n);
    sw.stop();
    _main.setMethodCallHandler(null);
    return {
      'sum_correct': sum == n * (n - 1),
      'total_ms': _ms(sw),
      'per_round_trip_us': sw.elapsedMicroseconds / n,
    };
  });
}

// ---------------------------------------------------------------------------
// D. 20 concurrent 200 ms requests
// ---------------------------------------------------------------------------

Future<void> _concurrency(_Guarded guarded, UiMonitor monitor) async {
  const s = 'D_concurrency_20x200ms';
  const n = 20;

  Future<void> run(String name, Future<List<String>> Function() op) =>
      guarded(s, name, () async {
        final impact = await monitor.measure(op);
        final results = impact.result ?? const <String>[];
        final matched = [
          for (var i = 0; i < results.length; i++)
            results[i].startsWith('$i@'),
        ].every((x) => x);
        return {
          'responses': results.length,
          'all_matched_to_request': matched && results.length == n,
          'distinct_native_threads': {
            for (final r in results) r.split('@').last,
          }.length,
          ...impact.toJson(),
        };
      });

  await run(
    'jnigen_suspend_futures',
    () => Future.wait([
      for (var i = 0; i < n; i++) AsyncBench.suspendWork(i, 200).then(_str),
    ]),
  );
  await run(
    'jnigen_sync_in_isolate_run_each',
    () => Future.wait([
      for (var i = 0; i < n; i++)
        Isolate.run(
          () =>
              '$i@${AsyncBench.blockingWork(200).toDartString(releaseOriginal: true)}',
        ),
    ]),
  );
  await run(
    'jnigen_sync_on_ui_isolate_sequential',
    () async => [
      for (var i = 0; i < n; i++) '$i@${_str(AsyncBench.blockingWork(200))}',
    ],
  );
  for (final (name, channel) in [
    ('method_channel_bg_parallel_taskqueue', _bgParallel),
    ('method_channel_bg_serial_taskqueue', _bgSerial),
    ('method_channel_default_main_thread', _main),
  ]) {
    await run(
      name,
      () => Future.wait([
        for (var i = 0; i < n; i++)
          channel
              .invokeMethod<String>('workWithId', {'id': i, 'millis': 200})
              .then((r) => r!),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// E. Callbacks after the Dart side is disposed
// ---------------------------------------------------------------------------

Future<void> _dispose(_Guarded guarded) async {
  const s = 'E_dispose';

  // E1/E2: a "screen" listens to 10 progress steps (50 ms apart) and is
  // disposed after step 3: it releases its listener reference, and in E2
  // also cancels the native work.
  Future<Map<String, Object?>> screen({
    required int requestId,
    required bool cancelOnDispose,
  }) async {
    var disposed = false;
    var beforeDispose = 0;
    var afterDispose = 0;
    final completed = Completer<void>();
    final listener = ProgressListener.implement(
      $ProgressListener(
        onProgress: (id, step, thread) {
          thread.release();
          disposed ? afterDispose++ : beforeDispose++;
        },
        onProgress$async: true,
        onComplete: (id, result, thread) {
          thread.release();
          if (!completed.isCompleted) completed.complete();
        },
        onComplete$async: true,
      ),
    );
    final handle = AsyncBench.startWork(
      requestId,
      10,
      50,
      cancelOnDispose,
      listener,
    );
    while (beforeDispose < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // --- dispose ---
    disposed = true;
    if (cancelOnDispose) handle.cancel();
    listener.release(); // Dart drops its reference; Kotlin still holds one.
    await completed.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final status = _str(handle.status());
    handle.release();
    return {
      'callbacks_before_dispose': beforeDispose,
      'callbacks_delivered_after_dispose': afterDispose,
      'native_status': status,
      'app_alive': true,
    };
  }

  await guarded(
    s,
    'jnigen_listener_released_without_cancel',
    () => screen(requestId: 10, cancelOnDispose: false),
  );
  await guarded(
    s,
    'jnigen_listener_released_with_cancel',
    () => screen(requestId: 11, cancelOnDispose: true),
  );

  // E3: callbacks implemented in a background isolate that has exited.
  await guarded(s, 'jnigen_callbacks_into_exited_isolate', () async {
    await Isolate.run(() {
      final listener = ProgressListener.implement(
        $ProgressListener(
          onProgress: (id, step, thread) => thread.release(),
          onComplete: (id, result, thread) => thread.release(),
        ),
      );
      final provider = ValueProvider.implement(
        $ValueProvider(provide: (i) => i),
      );
      // Blocking void callbacks, first one 100 ms after the isolate exits.
      AsyncBench.startWork(30, 5, 100, false, listener);
      // Value-returning callbacks, starting 300 ms later.
      AsyncBench.startAskDart(31, 5, 300, provider, listener);
      return 0;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return {
      'void_callbacks_native_status': _str(AsyncBench.status(30)),
      'value_callbacks_native_status': _str(AsyncBench.status(31)),
      'app_alive': true,
    };
  });

  // E4: EventChannel subscription cancelled after 3 of 10 events.
  await guarded(s, 'event_channel_subscription_cancelled', () async {
    var before = 0;
    var after = 0;
    var cancelled = false;
    late StreamSubscription<dynamic> sub;
    final three = Completer<void>();
    sub = _progress
        .receiveBroadcastStream({'steps': 10, 'stepMillis': 50})
        .listen((_) {
          cancelled ? after++ : before++;
          if (before == 3 && !three.isCompleted) three.complete();
        });
    await three.future;
    cancelled = true;
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return {
      'events_before_cancel': before,
      'events_delivered_after_cancel': after,
      'native_status': await _main.invokeMethod<String>('streamStatus'),
      'app_alive': true,
    };
  });

  // E5: native keeps calling invokeMethod after Dart removed its handler.
  await guarded(s, 'method_channel_handler_removed', () async {
    var before = 0;
    final three = Completer<void>();
    _main.setMethodCallHandler((call) async {
      before++;
      if (before == 3 && !three.isCompleted) three.complete();
      return null;
    });
    await _main.invokeMethod<void>('startCallbacksToDart', {
      'id': 50,
      'steps': 10,
      'stepMillis': 50,
    });
    await three.future;
    _main.setMethodCallHandler(null);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return {
      'callbacks_before_removal': before,
      'native_status': await _main.invokeMethod<String>('callbackStatus', 50),
      'app_alive': true,
    };
  });
}

// ---------------------------------------------------------------------------
// Hazard: a sync jnigen call that waits for a worker which needs the UI
// isolate (documented jnigen deadlock), broken only by a native timeout.
// ---------------------------------------------------------------------------

Future<void> _deadlock(_Guarded guarded, UiMonitor monitor) async {
  await guarded('F_deadlock_hazard', 'jnigen_sync_wait_for_worker_callback', () async {
    var ranDuringCall = false;
    var ran = false;
    final provider = ValueProvider.implement(
      $ValueProvider(
        provide: (i) {
          ran = true;
          return i + 1;
        },
      ),
    );
    final impact = await monitor.measure(() {
      final r = _str(AsyncBench.askDartFromWorkerAndWait(provider, 2000));
      ranDuringCall = ran;
      return r;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    provider.release();
    return {
      'native_result': impact.result,
      'dart_callback_ran_during_call': ranDuringCall,
      'dart_callback_ran_after_call_returned': ran,
      ...impact.toJson(),
    };
  });
}
