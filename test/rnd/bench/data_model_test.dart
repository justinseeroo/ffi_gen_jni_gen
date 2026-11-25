import 'dart:typed_data';

import 'package:ffi_gen_jni_gen/rnd/bench/data_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expectedProfile', () {
    test('mirrors the Kotlin generator rules', () {
      final p = expectedProfile(15);
      expect(p.id, 15 * 1000000007);
      expect(p.name, 'User 15 ✓');
      expect(p.score, 15 * 0.25 + 0.1);
      expect(p.active, isFalse);
      expect(p.tags, ['tag0', 'tag1', 'tag2']);
      expect(p.email, isNull); // 15 % 3 == 0
      expect(p.address, isNull); // 15 % 5 == 0
      expect(expectedProfile(1).address, const AddressData('City 1', 'PC1'));
      expect(expectedProfile(2).address, const AddressData('City 2', null));
    });
  });

  group('profileFingerprint', () {
    test('encodes every field, nulls and the raw double bits', () {
      const p = ProfileData(
        id: -1,
        name: 'n',
        score: -0.0,
        active: true,
        tags: ['a', 'b'],
        email: null,
        address: AddressData('c', null),
      );
      expect(
        profileFingerprint(p),
        'id=-1|name=n|score=8000000000000000|active=true'
        '|tags=2:a\u0001b|email=<null>|address=c,<null>',
      );
    });

    test('distinguishes empty string from null', () {
      final withEmpty = profileFingerprint(
        const ProfileData(
          id: 0,
          name: '',
          score: 0,
          active: false,
          tags: [],
          email: '',
          address: null,
        ),
      );
      expect(withEmpty, contains('|email=|'));
    });
  });

  group('ProfileData', () {
    test('survives toMap/fromMap', () {
      for (final i in [0, 1, 2, 4, 15]) {
        final p = expectedProfile(i);
        expect(ProfileData.fromMap(p.toMap()), p);
      }
    });

    test('compares score bit-for-bit (NaN equal, 0.0 != -0.0)', () {
      ProfileData withScore(double s) => ProfileData(
        id: 0,
        name: '',
        score: s,
        active: false,
        tags: const [],
        email: null,
        address: null,
      );
      expect(withScore(double.nan), withScore(double.nan));
      expect(withScore(0.0), isNot(withScore(-0.0)));
    });
  });

  group('bytes', () {
    test('pattern and checksum', () {
      expect(patternByte(255), 232);
      final bytes = Uint8List.fromList([for (var i = 0; i < 300; i++) patternByte(i)]);
      expect(matchesPattern(bytes), isTrue);
      expect(spotCheckPattern(bytes, 300), isTrue);
      expect(spotCheckPattern(bytes, 299), isFalse);
      expect(byteChecksum(Uint8List.fromList([1, 2])), 1 * 31 + 2);
    });
  });
}
