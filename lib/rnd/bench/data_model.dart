import 'package:flutter/foundation.dart';

/// Plain-Dart mirror of the Kotlin `Address` data class.
@immutable
class AddressData {
  const AddressData(this.city, this.postalCode);

  final String city;
  final String? postalCode;

  Map<String, Object?> toMap() => {'city': city, 'postalCode': postalCode};

  static AddressData fromMap(Map<Object?, Object?> map) =>
      AddressData(map['city']! as String, map['postalCode'] as String?);

  @override
  bool operator ==(Object other) =>
      other is AddressData &&
      other.city == city &&
      other.postalCode == postalCode;

  @override
  int get hashCode => Object.hash(city, postalCode);

  @override
  String toString() => 'AddressData($city, $postalCode)';
}

/// Plain-Dart mirror of the Kotlin `Profile` data class: what app code would
/// want to work with, whichever approach fetched it.
@immutable
class ProfileData {
  const ProfileData({
    required this.id,
    required this.name,
    required this.score,
    required this.active,
    required this.tags,
    required this.email,
    required this.address,
  });

  final int id;
  final String name;
  final double score;
  final bool active;
  final List<String> tags;
  final String? email;
  final AddressData? address;

  /// MethodChannel encoding: objects have no codec type, so they travel as
  /// maps (what a hand-written plugin does).
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'score': score,
    'active': active,
    'tags': tags,
    'email': email,
    'address': address?.toMap(),
  };

  static ProfileData fromMap(Map<Object?, Object?> map) {
    final address = map['address'] as Map<Object?, Object?>?;
    return ProfileData(
      id: map['id']! as int,
      name: map['name']! as String,
      score: map['score']! as double,
      active: map['active']! as bool,
      tags: (map['tags']! as List<Object?>).cast<String>(),
      email: map['email'] as String?,
      address: address == null ? null : AddressData.fromMap(address),
    );
  }

  /// Field-by-field equality; [score] is compared bit-for-bit so `-0.0` and
  /// `NaN` are checked exactly.
  @override
  bool operator ==(Object other) =>
      other is ProfileData &&
      other.id == id &&
      other.name == name &&
      doubleBits(other.score) == doubleBits(score) &&
      other.active == active &&
      listEquals(other.tags, tags) &&
      other.email == email &&
      other.address == address;

  @override
  int get hashCode =>
      Object.hash(id, name, score, active, Object.hashAll(tags), email, address);

  @override
  String toString() => 'ProfileData(${profileFingerprint(this)})';
}

/// Raw IEEE-754 bits of [value].
int doubleBits(double value) =>
    (ByteData(8)..setFloat64(0, value)).getInt64(0);

/// Mirror of Kotlin `DataBench.fingerprint`. Equal fingerprints prove the
/// native side received exactly the values Dart sent.
String profileFingerprint(ProfileData p) {
  final bits = doubleBits(p.score);
  String hex32(int v) => (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
  final address = p.address;
  return 'id=${p.id}'
      '|name=${p.name}'
      '|score=${hex32(bits >> 32)}${hex32(bits)}'
      '|active=${p.active}'
      '|tags=${p.tags.length}:${p.tags.join('\u0001')}'
      '|email=${p.email ?? '<null>'}'
      '|address=${address == null ? '<null>' : '${address.city},${address.postalCode ?? '<null>'}'}';
}

/// Mirror of Kotlin `DataBench.makeProfile`.
ProfileData expectedProfile(int i) => ProfileData(
  id: i * 1000000007,
  name: 'User $i ✓',
  score: i * 0.25 + 0.1,
  active: i % 2 == 0,
  tags: [for (var t = 0; t < i % 4; t++) 'tag$t'],
  email: i % 3 == 0 ? null : 'user$i@example.com',
  address: i % 5 == 0
      ? null
      : AddressData('City $i', i % 2 == 0 ? null : 'PC$i'),
);

/// Mirror of Kotlin `DataBench.makeBytes`: byte[i] = (i * 31 + 7) & 0xff.
int patternByte(int i) => (i * 31 + 7) & 0xff;

/// Mirror of Kotlin `DataBench.checksum` (64-bit wrapping, like Kotlin Long).
int byteChecksum(Uint8List bytes) {
  var hash = 0;
  for (final b in bytes) {
    hash = hash * 31 + b;
  }
  return hash;
}

/// Whether [bytes] is exactly `makeBytes(bytes.length)`.
bool matchesPattern(Uint8List bytes) {
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != patternByte(i)) return false;
  }
  return true;
}

/// Cheap spot check used inside timed loops: length plus first, middle and
/// last byte. Full verification is done once, outside timing, by the probes.
bool spotCheckPattern(Uint8List bytes, int expectedLength) {
  if (bytes.length != expectedLength) return false;
  if (expectedLength == 0) return true;
  for (final i in [0, expectedLength ~/ 2, expectedLength - 1]) {
    if (bytes[i] != patternByte(i)) return false;
  }
  return true;
}
