package com.example.ffi_gen_jni_gen.channel

import android.os.Handler
import android.os.Looper
import com.example.ffi_gen_jni_gen.bench.AsyncBench
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * MethodChannel / EventChannel side of experiment 3.
 *
 * - `rnd/async`: handler on the platform (main) thread, the default.
 * - `rnd/async_bg_serial`: handler on a background TaskQueue (serial, the
 *   TaskQueue default).
 * - `rnd/async_bg_parallel`: handler on a non-serial background TaskQueue.
 * - `rnd/async_progress`: EventChannel streaming progress from a worker.
 *
 * Platform channels may only be *sent to* from the main thread, so worker
 * threads post every callback to the main looper first.
 */
class AsyncBenchChannel(messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newCachedThreadPool()
    private val mainChannel = MethodChannel(messenger, "rnd/async")
    private val callbackStats = ConcurrentHashMap<Int, CallbackStats>()

    @Volatile
    private var streamStats = StreamStats()

    private class CallbackStats {
        val attempted = AtomicInteger()
        val delivered = AtomicInteger()
        val notImplemented = AtomicInteger()
        val errors = AtomicInteger()

        override fun toString() =
            "attempted=${attempted.get()};delivered=${delivered.get()};" +
                "notImplemented=${notImplemented.get()};errors=${errors.get()}"
    }

    private class StreamStats {
        val sent = AtomicInteger()
        val sentAfterCancel = AtomicInteger()

        @Volatile
        var cancelled = false

        override fun toString() =
            "sent=${sent.get()};sentAfterCancel=${sentAfterCancel.get()};cancelled=$cancelled"
    }

    init {
        mainChannel.setMethodCallHandler { call, result -> handleMain(call, result) }

        val serialQueue = messenger.makeBackgroundTaskQueue()
        MethodChannel(messenger, "rnd/async_bg_serial", StandardMethodCodec.INSTANCE, serialQueue)
            .setMethodCallHandler { call, result -> handleWork(call, result) }

        val parallelQueue =
            messenger.makeBackgroundTaskQueue(BinaryMessenger.TaskQueueOptions().setIsSerial(false))
        MethodChannel(messenger, "rnd/async_bg_parallel", StandardMethodCodec.INSTANCE, parallelQueue)
            .setMethodCallHandler { call, result -> handleWork(call, result) }

        EventChannel(messenger, "rnd/async_progress").setStreamHandler(ProgressStream())
    }

    /** Same work on whichever thread the channel's handler runs on. */
    private fun handleWork(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "threadName" -> result.success(AsyncBench.threadName())
            "isMainThread" -> result.success(AsyncBench.isMainThread())
            "blockingWork" -> result.success(AsyncBench.blockingWork(call.arguments as Int))
            "workWithId" -> {
                val id = call.argument<Int>("id")!!
                AsyncBench.blockingWork(call.argument<Int>("millis")!!)
                result.success("$id@${AsyncBench.threadName()}")
            }
            else -> result.notImplemented()
        }
    }

    private fun handleMain(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Reply with an error from a worker thread (async failure).
            "failAsync" -> worker.execute {
                main.post { result.error("native_failure", call.arguments as String, null) }
            }
            // Native asks Dart for `count` values, one after another, then replies with the sum.
            "askDart" -> askDart(0, call.arguments as Int, 0L, result)
            // Worker sends `steps` callbacks to Dart via invokeMethod; Dart may have removed its handler.
            "startCallbacksToDart" -> {
                val id = call.argument<Int>("id")!!
                val steps = call.argument<Int>("steps")!!
                val stepMillis = call.argument<Int>("stepMillis")!!
                val stats = CallbackStats().also { callbackStats[id] = it }
                worker.execute {
                    for (step in 1..steps) {
                        if (stepMillis > 0) Thread.sleep(stepMillis.toLong())
                        main.post {
                            stats.attempted.incrementAndGet()
                            mainChannel.invokeMethod(
                                "onProgress",
                                mapOf("id" to id, "step" to step),
                                object : MethodChannel.Result {
                                    override fun success(r: Any?) { stats.delivered.incrementAndGet() }

                                    override fun error(c: String, m: String?, d: Any?) { stats.errors.incrementAndGet() }

                                    override fun notImplemented() { stats.notImplemented.incrementAndGet() }
                                },
                            )
                        }
                    }
                }
                result.success(null)
            }
            "callbackStatus" -> result.success(callbackStats[call.arguments as Int]?.toString() ?: "unknown")
            "streamStatus" -> result.success(streamStats.toString())
            else -> handleWork(call, result)
        }
    }

    private fun askDart(i: Int, count: Int, sum: Long, result: MethodChannel.Result) {
        if (i == count) {
            result.success(sum)
            return
        }
        mainChannel.invokeMethod(
            "provide",
            i,
            object : MethodChannel.Result {
                override fun success(r: Any?) = askDart(i + 1, count, sum + (r as Int), result)

                override fun error(c: String, m: String?, d: Any?) = result.error(c, m, d)

                override fun notImplemented() = result.error("no_dart_handler", "provide", null)
            },
        )
    }

    /** Streams `steps` progress events from a worker. Keeps sending after cancel, to test that Flutter drops them. */
    private inner class ProgressStream : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            val args = arguments as Map<*, *>
            val steps = args["steps"] as Int
            val stepMillis = args["stepMillis"] as Int
            val stats = StreamStats().also { streamStats = it }
            worker.execute {
                for (step in 1..steps) {
                    if (stepMillis > 0) Thread.sleep(stepMillis.toLong())
                    main.post {
                        if (stats.cancelled) stats.sentAfterCancel.incrementAndGet() else stats.sent.incrementAndGet()
                        events.success(mapOf("step" to step, "thread" to Thread.currentThread().name))
                    }
                }
                main.post { events.endOfStream() }
            }
        }

        override fun onCancel(arguments: Any?) {
            streamStats.cancelled = true
        }
    }
}
