# Experiment 01: Call overhead and primitive round trip (Android)

**Question:** How much does one Flutter → native call cost with jnigen
compared with a MethodChannel, and do primitive values and strings arrive
intact?

**Status:** ✅ Done on Android, 2026-11-25. FFIgen/iOS still to do (needs a Mac
and an iPhone).

## Setup

| | |
|---|---|
| Device | Xiaomi 2406ERN9CI (`breeze`), Android 16 (API 36), arm64-v8a |
| Build | `--profile` (AOT-compiled Dart, same as release; the APK is debuggable and not R8-shrunk) |
| Flutter | 3.41.6 stable, Dart 3.11.4, jni 1.2.1, jnigen 1.1.0 |
| Battery | 100 %, USB-powered; 34.0 °C before and 33.0 °C after the clean run |
| Native code | `InteropBench.kt`: `noop()`, `add(Int, Int)`, `echo(String)`. Both approaches call this same object. |
| jnigen path | `lib/rnd/bench/jni_bench_client.dart` makes a synchronous static JNI call. `echo` includes the Dart ↔ Java string conversion and releasing the references. |
| MethodChannel path | `lib/rnd/bench/channel_bench_client.dart` uses `StandardMessageCodec`, with each call awaited before the next. `add` sends a map `{a, b}` (the usual plugin style). |
| Method | 1,000 warm-up calls, then 5 timed runs per scenario; the median is reported. Every call's result is checked (0 mismatches in all scenarios). |
| Entry point | `flutter run --profile -t lib/rnd/main_exp01.dart` (static screen, no dashboard, no test binding) |
| Raw data | [`results/exp01_clean_report.json`](results/exp01_clean_report.json) |

The native functions do almost no work, so the times below measure
**communication overhead**.

## Results: time per call (µs, median of 5 runs)

| Operation | Calls | jnigen | MethodChannel | MethodChannel ÷ jnigen |
|---|---:|---:|---:|---:|
| `noop` | 1 | 0.68 \* | 266 | |
| | 1,000 | 0.48 | 154 | |
| | 10,000 | 0.48 | 144 | |
| | 100,000 | **0.41** | **143** | **~350×** |
| `add(int, int)` | 1 | 0.83 \* | 185 | |
| | 1,000 | 0.59 | 166 | |
| | 10,000 | 0.60 | 148 | |
| | 100,000 | **0.58** | **160** | **~280×** |
| `echo` (30-char string with emoji) | 1 | 6.25 \* | 174 | |
| | 1,000 | 7.25 | 162 | |
| | 10,000 | 6.89 | 148 | |
| | 100,000 | **7.44** | **156** | **~21×** |

\* A single jnigen call takes 1–6 µs, which is close to the stopwatch's
resolution and noisy (92–181 % spread across runs). Treat these as
indicative only. Every scenario with 1,000 or more calls had a spread of
≤ 21 % (most were ≤ 10 %).

**Total time for 100,000 calls:** jnigen took 41 ms (`noop`), 58 ms (`add`)
and 744 ms (`echo`). MethodChannel took 14.3 s, 16.0 s and 15.6 s.

## Results: correctness probes

| Probe | jnigen | MethodChannel |
|---|---|---|
| `add` with small, negative and overflowing values (`MAX_INT + 1` wraps) | ✅ | ✅ |
| `add(2147483648, 0)` (argument larger than Kotlin `Int`) | ⚠️ **Silently truncated** to `-2147483648` | ⚠️ **Throws** `PlatformException: Long cannot be cast to Integer` |
| Empty, ASCII, Devanagari/Malayalam/CJK, emoji (surrogate pairs), embedded `\0`, 100k-char string | ✅ exact | ✅ exact |
| Lone UTF-16 surrogate `"x\uD800y"` | ✅ preserved | ⚠️ **Replaced** with U+FFFD (`"x�y"`) |

## What this means

1. **jnigen calls are about 280–350× cheaper than MethodChannel calls** for
   primitive values on this device: 0.4–0.6 µs against 143–160 µs.
2. **With jnigen, strings cost much more than primitives.** A 30-character
   round trip takes ~7 µs, about 15× a bare call, because the string is
   converted in both directions (UTF-16 copy plus JNI global references).
   That narrows the advantage to ~21× for string calls.
3. **MethodChannel's cost is almost the same for every call** (143–166 µs)
   whatever the data size, at least for small payloads. The fixed cost of
   each call (async round trip and message dispatch) outweighs the encoding
   cost. Experiment 2 will test large payloads.
4. **Practical meaning:** a 60 fps frame lasts 16.7 ms. In that time you can
   make ~110 sequential MethodChannel calls, ~2,300 jnigen string calls or
   ~40,000 jnigen primitive calls. For an occasional call (a button tap, a
   settings read) both are far below what a user could notice. The difference
   matters for chatty APIs: many small calls, per-frame calls, or loops.
5. **Type conversion differs between the two approaches.**
   - jnigen maps Dart's 64-bit `int` to the Kotlin parameter's width and
     **silently truncates** values that don't fit. Validate ranges in Dart, or
     use `Long` in Kotlin.
   - MethodChannel sends large ints as `Long` and fails loudly when Kotlin
     expects `Int`.
   - MethodChannel's UTF-8 encoding corrupts malformed UTF-16 (lone
     surrogates); jnigen's UTF-16 path keeps it.
6. **jnigen calls are synchronous on the UI thread.** The 744 ms of 100k
   `echo` calls froze the UI for 744 ms. Low overhead does not make
   heavy work safe on the UI thread (see experiment 3).

## Issues found during the experiment

- **Timing overflow (fixed).** The first run calculated
  `ticks * 1e9 ~/ frequency`, which overflows int64 for runs longer than
  ~9.2 s on Android's nanosecond clock. This produced negative times for the
  MethodChannel 100k runs. Fixed with `ticksToNanoseconds`, which has unit
  tests.
- **Fairness bias (fixed).** The first run (an integration test that started
  the full dashboard) let the dashboard's 2 s refresh timer and rebuilds run
  *between* awaited MethodChannel calls, but never inside a synchronous jnigen
  loop. MethodChannel times were inflated 1.2–2.4× (for example `noop` at 10k:
  346 µs/call against 144 µs/call in the clean run), while jnigen changed by
  ≤ 25 %. Both entry points now use a static screen.
- **Lesson for real apps:** MethodChannel latency depends on everything else
  queued on the UI thread. jnigen latency does not, but jnigen in turn
  blocks that thread.

## Release build (R8)

- Flutter enables R8 only for `release`. `profile` inherits from `debug`, so
  profile runs **cannot** catch classes that R8 removed.
- `android/app/proguard-rules.pro` keeps `com.example.ffi_gen_jni_gen.bench.**`.
  The release APK's `classes.dex` still contains `InteropBench`, `noop`,
  `echo` and `INSTANCE` (checked statically). A runtime call in a release
  build is not tested yet (planned for experiment 7).

## Not measured here (later experiments)

- Large payloads (byte arrays, collections) and complex objects: experiment 2
- Concurrent MethodChannel calls (`Future.wait`), background threads,
  callbacks, and UI jank during calls: experiment 3
- Memory use: experiment 5
- FFIgen on iOS: needs a Mac with Xcode and an iPhone

## How to reproduce

```sh
flutter build apk --debug && dart run tool/jnigen_bench.dart   # only if InteropBench.kt changes
flutter run --profile -t lib/rnd/main_exp01.dart               # watch for "EXP01_DONE"
adb exec-out run-as com.example.ffi_gen_jni_gen cat code_cache/exp01_report.json
```

Keep the phone unlocked on the experiment screen and don't touch it until
`EXP01_DONE` appears. A run takes about 5–6 minutes, mostly the 100k
MethodChannel runs.
