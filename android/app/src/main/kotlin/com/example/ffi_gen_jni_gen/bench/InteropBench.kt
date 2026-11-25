package com.example.ffi_gen_jni_gen.bench

/**
 * Native side of the interop R&D benchmarks.
 *
 * Every function here is reached from Dart in two ways, so both paths run
 * exactly the same native code:
 * - directly, through the jnigen bindings in `lib/jni/bench_bindings.g.dart`;
 * - through the `rnd/bench` MethodChannel registered in `MainActivity`.
 *
 * The functions are deliberately trivial: native work is close to zero, so
 * the measured time is almost entirely Flutter <-> native communication.
 *
 * `@JvmStatic` makes each function a real Java static method, so the jnigen
 * path is a plain static JNI call (no instance reference to manage).
 *
 * Dart only reaches this class through JNI reflection, which R8 cannot see;
 * `proguard-rules.pro` keeps it in profile and release builds.
 */
object InteropBench {
    /** Does nothing: measures the bare cost of a call. */
    @JvmStatic
    fun noop() {}

    /** Two ints in, one int out: the cost of a call with primitive values. */
    @JvmStatic
    fun add(a: Int, b: Int): Int = a + b

    /** Returns its argument: the cost of passing a string both ways. */
    @JvmStatic
    fun echo(value: String): String = value
}
