package com.example.ffi_gen_jni_gen.bench

import java.nio.ByteBuffer
import java.util.Locale

/** Nested value object used inside [Profile]. */
data class Address(val city: String, val postalCode: String?)

/**
 * A "real-world-shaped" object for experiment 2: every common field kind
 * (64-bit int, string, double, boolean, list, nullable string, nullable
 * nested object).
 */
data class Profile(
    val id: Long,
    val name: String,
    val score: Double,
    val active: Boolean,
    val tags: List<String>,
    val email: String?,
    val address: Address?,
)

/**
 * Native side of experiment 2 (complex and large data). Reached both through
 * jnigen (`lib/jni/bench_bindings.g.dart`) and through the `rnd/data`
 * MethodChannel (`channel/DataBenchChannel.kt`).
 *
 * Verification functions ([fingerprint], [checksum], [sumIntArray], ...)
 * compute their result from what Kotlin actually *received*, so Dart can
 * prove the data crossed intact rather than just getting an echo back.
 * The generators ([makeProfile], [makeBytes], ...) are deterministic and
 * mirrored in Dart (`lib/rnd/bench/data_model.dart`).
 */
object DataBench {
    // ---- scalars and nulls ----

    @JvmStatic
    fun echoLong(value: Long): Long = value

    /** Returns a new array (not the same object) with the same values. */
    @JvmStatic
    fun echoDoubles(values: DoubleArray): DoubleArray = values.copyOf()

    @JvmStatic
    fun echoNullableString(value: String?): String? = value

    // ---- complex objects ----

    /** Canonical description of [p]; mirrored exactly by Dart. */
    @JvmStatic
    fun fingerprint(p: Profile): String = buildString {
        val bits = java.lang.Double.doubleToRawLongBits(p.score)
        append("id=").append(p.id)
        append("|name=").append(p.name)
        append("|score=").append(
            String.format(Locale.ROOT, "%08x%08x", bits ushr 32, bits and 0xffffffffL),
        )
        append("|active=").append(p.active)
        append("|tags=").append(p.tags.size).append(':').append(p.tags.joinToString("\u0001"))
        append("|email=").append(p.email ?: "<null>")
        append("|address=")
        val address = p.address
        if (address == null) {
            append("<null>")
        } else {
            append(address.city).append(',').append(address.postalCode ?: "<null>")
        }
    }

    /** Deterministic profile number [i]; mirrored by Dart `expectedProfile`. */
    @JvmStatic
    fun makeProfile(i: Int): Profile = Profile(
        id = i * 1_000_000_007L,
        name = "User $i ✓",
        score = i * 0.25 + 0.1,
        active = i % 2 == 0,
        tags = List(i % 4) { "tag$it" },
        email = if (i % 3 == 0) null else "user$i@example.com",
        address = if (i % 5 == 0) null else Address("City $i", if (i % 2 == 0) null else "PC$i"),
    )

    @JvmStatic
    fun makeProfiles(count: Int): List<Profile> = List(count) { makeProfile(it) }

    /** Returns a new, equal profile (a different object than [p]). */
    @JvmStatic
    fun echoProfile(p: Profile): Profile = p.copy(tags = p.tags.toList())

    // ---- byte arrays (copied across the boundary) ----

    /** Trivial native work: measures the cost of getting bytes *in*. */
    @JvmStatic
    fun byteCount(bytes: ByteArray): Int = bytes.size

    @JvmStatic
    fun checksum(bytes: ByteArray): Long {
        var hash = 0L
        for (b in bytes) hash = hash * 31 + (b.toInt() and 0xff)
        return hash
    }

    /** byte[i] = (i * 31 + 7) & 0xff; mirrored by Dart `patternByte`. */
    @JvmStatic
    fun makeBytes(size: Int): ByteArray = ByteArray(size) { ((it * 31 + 7) and 0xff).toByte() }

    // ---- direct ByteBuffers (native memory Dart can view without copying) ----

    @JvmStatic
    fun directByteCount(buffer: ByteBuffer): Int = buffer.capacity()

    @JvmStatic
    fun directChecksum(buffer: ByteBuffer): Long {
        var hash = 0L
        for (i in 0 until buffer.capacity()) hash = hash * 31 + (buffer.get(i).toInt() and 0xff)
        return hash
    }

    @JvmStatic
    fun makeDirectBytes(size: Int): ByteBuffer {
        val buffer = ByteBuffer.allocateDirect(size)
        for (i in 0 until size) buffer.put(i, ((i * 31 + 7) and 0xff).toByte())
        return buffer
    }

    // ---- native-only baselines ----
    // Same generation work as makeBytes / makeDirectBytes, but only the size
    // crosses back to Dart. Timed via jnigen (~0.5 us call overhead), they
    // give the native computation time to subtract from the "out" timings.

    @JvmStatic
    fun makeBytesNativeOnly(size: Int): Int = makeBytes(size).size

    @JvmStatic
    fun makeDirectBytesNativeOnly(size: Int): Int = makeDirectBytes(size).capacity()

    // ---- int collections: primitive array vs boxed list ----

    @JvmStatic
    fun sumIntArray(values: IntArray): Long {
        var sum = 0L
        for (v in values) sum += v
        return sum
    }

    /** values[i] = i */
    @JvmStatic
    fun makeIntArray(count: Int): IntArray = IntArray(count) { it }

    @JvmStatic
    fun sumIntList(values: List<Int>): Long {
        var sum = 0L
        for (v in values) sum += v
        return sum
    }

    /** values[i] = i */
    @JvmStatic
    fun makeIntList(count: Int): List<Int> = List(count) { it }
}
