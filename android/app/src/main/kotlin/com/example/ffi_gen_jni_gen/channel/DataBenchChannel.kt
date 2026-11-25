package com.example.ffi_gen_jni_gen.channel

import com.example.ffi_gen_jni_gen.bench.Address
import com.example.ffi_gen_jni_gen.bench.DataBench
import com.example.ffi_gen_jni_gen.bench.Profile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel (`rnd/data`) front-end for [DataBench], used by experiment 2
 * to compare against the jnigen bindings. Lives outside the `bench` package
 * so jnigen does not generate bindings for Flutter's channel classes.
 *
 * StandardMessageCodec mapping used here:
 * - Dart int -> Integer if it fits 32 bits, else Long (so read as Number)
 * - Dart double -> Double; Float64List -> DoubleArray
 * - Uint8List -> ByteArray; Int32List -> IntArray
 * - List -> ArrayList; Map -> HashMap; null -> null
 * Objects have no codec type: [Profile] is converted to/from a Map by hand,
 * which is exactly what a hand-written plugin has to do.
 */
class DataBenchChannel(messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "rnd/data").setMethodCallHandler { call, result ->
            try {
                result.success(handle(call))
            } catch (e: NotImplementedError) {
                result.notImplemented()
            } catch (e: Exception) {
                result.error("data_bench", e.toString(), null)
            }
        }
    }

    private fun handle(call: MethodCall): Any? {
        val args = call.arguments
        return when (call.method) {
            "echoLong" -> DataBench.echoLong((args as Number).toLong())
            "echoDoubles" -> DataBench.echoDoubles(args as DoubleArray)
            "echoNullableString" -> DataBench.echoNullableString(args as String?)
            "fingerprint" -> DataBench.fingerprint(profileFromMap(args as Map<*, *>))
            "makeProfile" -> profileToMap(DataBench.makeProfile(args as Int))
            "makeProfiles" -> DataBench.makeProfiles(args as Int).map(::profileToMap)
            "echoProfile" -> profileToMap(DataBench.echoProfile(profileFromMap(args as Map<*, *>)))
            "byteCount" -> DataBench.byteCount(args as ByteArray)
            "checksum" -> DataBench.checksum(args as ByteArray)
            "makeBytes" -> DataBench.makeBytes(args as Int)
            "sumIntArray" -> DataBench.sumIntArray(args as IntArray)
            "makeIntArray" -> DataBench.makeIntArray(args as Int)
            "sumIntList" -> DataBench.sumIntList((args as List<*>).map { (it as Number).toInt() })
            "makeIntList" -> DataBench.makeIntList(args as Int)
            else -> throw NotImplementedError()
        }
    }

    private fun profileFromMap(map: Map<*, *>): Profile {
        val address = map["address"] as Map<*, *>?
        return Profile(
            id = (map["id"] as Number).toLong(),
            name = map["name"] as String,
            score = map["score"] as Double,
            active = map["active"] as Boolean,
            tags = (map["tags"] as List<*>).map { it as String },
            email = map["email"] as String?,
            address = address?.let {
                Address(it["city"] as String, it["postalCode"] as String?)
            },
        )
    }

    private fun profileToMap(p: Profile): Map<String, Any?> = mapOf(
        "id" to p.id,
        "name" to p.name,
        "score" to p.score,
        "active" to p.active,
        "tags" to p.tags,
        "email" to p.email,
        "address" to p.address?.let { mapOf("city" to it.city, "postalCode" to it.postalCode) },
    )
}
