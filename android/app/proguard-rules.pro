# R8 removes or renames classes that look unused. Classes Dart calls through
# jnigen are only reached via JNI reflection, which R8 cannot see, so they
# must be kept explicitly or profile/release builds fail at runtime with
# ClassNotFoundException / NoSuchMethodError.
#
# Android framework classes (android.*, java.*) need no rule: they live on
# the device, not in the APK.

-keep class com.example.ffi_gen_jni_gen.bench.** { *; }
