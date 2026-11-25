package com.example.ffi_gen_jni_gen

import com.example.ffi_gen_jni_gen.bench.InteropBench
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerBenchChannel(flutterEngine)
    }

    /**
     * MethodChannel version of [InteropBench], used only by the R&D benchmarks
     * to compare against the jnigen bindings. The app itself does not use it.
     */
    private fun registerBenchChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rnd/bench")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "noop" -> {
                        InteropBench.noop()
                        result.success(null)
                    }
                    "add" -> {
                        val a = call.argument<Int>("a")
                        val b = call.argument<Int>("b")
                        if (a == null || b == null) {
                            result.error("bad_args", "add needs int a and b", null)
                        } else {
                            result.success(InteropBench.add(a, b))
                        }
                    }
                    "echo" -> {
                        val value = call.arguments as? String
                        if (value == null) {
                            result.error("bad_args", "echo needs a string", null)
                        } else {
                            result.success(InteropBench.echo(value))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
