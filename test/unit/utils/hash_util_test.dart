import 'package:flutter_test/flutter_test.dart';
import 'package:reposeance/core/utils/hash_util.dart';

void main() {
  group('HashUtil SHA-256 Vector Tests', () {
    test('computes correct hash for empty string', () {
      expect(
        HashUtil.sha256Hex(''),
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
    });

    test('computes correct hash for standard string "hello"', () {
      expect(
        HashUtil.sha256Hex('hello'),
        equals(
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
        ),
      );
    });

    test(
      'computes correct hash for "The quick brown fox jumps over the lazy dog"',
      () {
        expect(
          HashUtil.sha256Hex('The quick brown fox jumps over the lazy dog'),
          equals(
            'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
          ),
        );
      },
    );
  });
}
