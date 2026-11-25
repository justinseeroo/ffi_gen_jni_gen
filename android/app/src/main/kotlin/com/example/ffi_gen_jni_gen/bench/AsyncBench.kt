package com.example.ffi_gen_jni_gen.bench

import android.os.Looper
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

/** Native -> Dart notifications. All methods return Unit, so Dart may implement them as non-blocking "listeners". */
interface ProgressListener {
    fun onProgress(requestId: Int, step: Int, threadName: String)

    fun onComplete(requestId: Int, result: Long, threadName: String)
}

/** Native -> Dart request that needs an answer (always blocks the calling native thread until Dart replies). */
interface ValueProvider {
    fun provide(input: Int): Int
}

/** Native-side record of one background job, so Dart can ask afterwards what native actually did. */
class WorkHandle(val requestId: Int) {
    @Volatile
    var cancelled = false
        private set

    val callbacksAttempted = AtomicInteger()
    val callbackFailures = AtomicInteger()

    @Volatile
    var lastFailure: String? = null

    @Volatile
    var finished = false

    fun cancel() {
        cancelled = true
    }

    fun status(): String =
        "attempted=${callbacksAttempted.get()};failures=${callbackFailures.get()};" +
            "finished=$finished;cancelled=$cancelled;lastFailure=${lastFailure ?: "none"}"

    internal fun recordFailure(t: Throwable) {
        callbackFailures.incrementAndGet()
        lastFailure = t.toString().take(200)
    }
}

/**
 * Native side of experiment 3 (native -> Flutter communication, async work,
 * threads, dispose). Reached through jnigen; `channel/AsyncBenchChannel.kt`
 * offers the MethodChannel / EventChannel equivalents.
 */
object AsyncBench {
    private val threadCounter = AtomicInteger()
    private val executor =
        Executors.newCachedThreadPool { runnable ->
            Thread(runnable, "bench-worker-${threadCounter.incrementAndGet()}")
        }
    private val handles = ConcurrentHashMap<Int, WorkHandle>()

    // ---- threads ----

    @JvmStatic
    fun threadName(): String = Thread.currentThread().name

    @JvmStatic
    fun isMainThread(): Boolean = Looper.myLooper() == Looper.getMainLooper()

    // ---- long-running work ----

    /** Blocks the *calling* thread for [millis] (a slow SDK call or blocking I/O). Returns the thread it ran on. */
    @JvmStatic
    fun blockingWork(millis: Int): String {
        Thread.sleep(millis.toLong())
        return threadName()
    }

    /** The same work as a Kotlin suspend function: runs on a worker; jnigen turns it into a Dart Future. */
    @JvmStatic
    suspend fun suspendWork(requestId: Int, millis: Int): String =
        suspendCoroutine { continuation ->
            executor.execute {
                Thread.sleep(millis.toLong())
                continuation.resume("$requestId@${threadName()}")
            }
        }

    /** A suspend function that fails on a worker thread. */
    @JvmStatic
    suspend fun suspendFail(message: String): String =
        suspendCoroutine { continuation ->
            executor.execute { continuation.resumeWithException(IllegalStateException(message)) }
        }

    // ---- callbacks: background thread -> Dart ----

    /**
     * Starts [steps] progress callbacks (every [stepMillis] ms) on a worker
     * thread, then onComplete; returns immediately. With [honorCancel] the
     * worker stops once [WorkHandle.cancel] is called.
     */
    @JvmStatic
    fun startWork(
        requestId: Int,
        steps: Int,
        stepMillis: Int,
        honorCancel: Boolean,
        listener: ProgressListener,
    ): WorkHandle {
        val handle = WorkHandle(requestId)
        handles[requestId] = handle
        executor.execute {
            for (step in 1..steps) {
                if (honorCancel && handle.cancelled) break
                if (stepMillis > 0) Thread.sleep(stepMillis.toLong())
                handle.callbacksAttempted.incrementAndGet()
                try {
                    listener.onProgress(requestId, step, threadName())
                } catch (t: Throwable) {
                    handle.recordFailure(t)
                }
            }
            handle.callbacksAttempted.incrementAndGet()
            try {
                listener.onComplete(requestId, steps.toLong(), threadName())
            } catch (t: Throwable) {
                handle.recordFailure(t)
            }
            handle.finished = true
        }
        return handle
    }

    /**
     * On a worker thread (after [delayMillis]), asks Dart for [count] values
     * one by one (each a blocking round trip), then reports the sum via
     * [listener].
     *
     * Note from jni's native code: a blocking callback that was *queued* to a
     * Dart isolate which then exits is never answered, so the worker would
     * wait forever. The delay lets experiment 3 call this only after the
     * isolate is gone (post fails -> null result), keeping the test
     * deterministic.
     */
    @JvmStatic
    fun startAskDart(
        requestId: Int,
        count: Int,
        delayMillis: Int,
        provider: ValueProvider,
        listener: ProgressListener,
    ): WorkHandle {
        val handle = WorkHandle(requestId)
        handles[requestId] = handle
        executor.execute {
            if (delayMillis > 0) Thread.sleep(delayMillis.toLong())
            var sum = 0L
            for (i in 0 until count) {
                handle.callbacksAttempted.incrementAndGet()
                try {
                    sum += provider.provide(i)
                } catch (t: Throwable) {
                    handle.recordFailure(t)
                }
            }
            try {
                listener.onComplete(requestId, sum, threadName())
            } catch (t: Throwable) {
                handle.recordFailure(t)
            }
            handle.finished = true
        }
        return handle
    }

    @JvmStatic
    fun status(requestId: Int): String = handles[requestId]?.status() ?: "unknown request $requestId"

    // ---- callbacks: on the calling thread ----

    @JvmStatic
    fun callListenerOnCallingThread(listener: ProgressListener, count: Int) {
        val name = threadName()
        for (step in 1..count) listener.onProgress(0, step, name)
    }

    @JvmStatic
    fun askDartOnCallingThread(provider: ValueProvider, count: Int): Long {
        var sum = 0L
        for (i in 0 until count) sum += provider.provide(i)
        return sum
    }

    // ---- deadlock hazard ----

    /**
     * Starts a worker that asks Dart for a value, then makes the *calling*
     * thread wait for that worker (with a timeout so the demo cannot hang
     * the app). If called synchronously from Dart's UI isolate, the worker's
     * callback needs that same, now blocked, isolate: a deadlock that only
     * the timeout breaks.
     */
    @JvmStatic
    fun askDartFromWorkerAndWait(provider: ValueProvider, timeoutMillis: Int): String {
        val latch = CountDownLatch(1)
        var answer: Int? = null
        executor.execute {
            answer = provider.provide(41)
            latch.countDown()
        }
        return if (latch.await(timeoutMillis.toLong(), TimeUnit.MILLISECONDS)) {
            "OK:$answer"
        } else {
            "TIMED_OUT after ${timeoutMillis}ms (worker still waiting for Dart)"
        }
    }
}
