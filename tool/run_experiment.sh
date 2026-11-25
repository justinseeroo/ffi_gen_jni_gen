#!/usr/bin/env bash
# Builds, installs and runs one R&D experiment on a connected Android device,
# then collects its JSON report from logcat.
#
#   tool/run_experiment.sh 02 release        # or: profile
#   ANDROID_SERIAL=<id> tool/run_experiment.sh 01 profile
#
# Output: build/rnd/exp<NN>_<mode>.log (logcat) and exp<NN>_<mode>.json.
#
# Requires `flutter` and `adb` on PATH (or FLUTTER / ADB env vars).
# Keep the phone unlocked on the experiment screen until it finishes; the
# script keeps the screen awake while USB-powered and restores it afterwards.
set -euo pipefail

NN="${1:?experiment number, e.g. 01}"
MODE="${2:-release}"
FLUTTER="${FLUTTER:-flutter}"
ADB="${ADB:-adb}"
TAG="EXP${NN}"
OUT="build/rnd"
LOG="$OUT/exp${NN}_${MODE}.log"
JSON="$OUT/exp${NN}_${MODE}.json"
mkdir -p "$OUT"

"$ADB" get-state >/dev/null
"$FLUTTER" build apk "--$MODE" -t "lib/rnd/main_exp${NN}.dart"
"$ADB" install -r "build/app/outputs/flutter-apk/app-${MODE}.apk"

restore() { "$ADB" shell svc power stayon false || true; }
trap restore EXIT
"$ADB" shell svc power stayon usb
"$ADB" shell dumpsys battery | grep -E "level|temperature" | sed 's/^/before: /' > "$LOG"

FILTER=(-v brief flutter:I AndroidRuntime:E DEBUG:F '*:S')
"$ADB" logcat -G 16M || true   # bigger buffer so long runs are not rotated out
"$ADB" logcat -c
"$ADB" shell am start -n com.example.ffi_gen_jni_gen/.MainActivity
# Poll a one-shot dump (`logcat -d`) until the end marker or a native crash
# (e.g. a JNI abort). Streaming `logcat | grep -m1` hangs once the app goes
# quiet, because logcat only notices the closed pipe on its next line.
deadline=$((SECONDS + 3600))
until "$ADB" logcat -d "${FILTER[@]}" \
    | grep -qE "${TAG}_DONE|Fatal signal|FATAL EXCEPTION|Abort message"; do
  if ((SECONDS > deadline)); then echo "Timed out" >&2; break; fi
  sleep 5
done
"$ADB" logcat -d "${FILTER[@]}" >> "$LOG"

"$ADB" shell dumpsys battery | grep -E "level|temperature" | sed 's/^/after: /' >> "$LOG"

if grep -q "${TAG}_DONE" "$LOG"; then
  # Reassemble "<TAG>_JSON i/n <chunk>" lines in order.
  grep -o "${TAG}_JSON [0-9]*/[0-9]* .*" "$LOG" \
    | sed -E "s/^${TAG}_JSON ([0-9]+)\/[0-9]+ /\1\t/" \
    | sort -n -k1,1 | cut -f2- | tr -d '\r\n' > "$JSON"
  echo "Report: $JSON ($(wc -c < "$JSON") bytes)"
else
  echo "Experiment did not finish; see $LOG" >&2
  grep -E "Abort message|Fatal signal|FATAL EXCEPTION" "$LOG" >&2 || true
  exit 1
fi
