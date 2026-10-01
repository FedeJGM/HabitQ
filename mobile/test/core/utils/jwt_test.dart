import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/jwt.dart';

String _makeToken(Object? payload) {
  String segment(Object? value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(payload);
  return '$header.$body.dummy-signature';
}

void main() {
  group('jwtExpiry', () {
    test('returns the expiry for a token with a future exp', () {
      final future = DateTime.now().toUtc().add(const Duration(hours: 1));
      final token = _makeToken({'sub': 'u1', 'exp': future.millisecondsSinceEpoch ~/ 1000});

      final expiry = jwtExpiry(token);

      expect(expiry, isNotNull);
      expect(expiry!.difference(future).inSeconds.abs(), lessThan(2));
    });

    test('returns the expiry for a token with a past exp (still decodes)', () {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final token = _makeToken({'sub': 'u1', 'exp': past.millisecondsSinceEpoch ~/ 1000});

      final expiry = jwtExpiry(token);

      expect(expiry, isNotNull);
      expect(expiry!.isBefore(DateTime.now().toUtc()), isTrue);
    });

    test('returns null for a token that does not have 3 dot-separated parts', () {
      expect(jwtExpiry('not-a-jwt'), isNull);
      expect(jwtExpiry('only.two'), isNull);
    });

    test('returns null when the payload segment is not valid base64/JSON', () {
      expect(jwtExpiry('header.@@@not-base64@@@.signature'), isNull);
    });

    test('returns null when the payload has no exp claim', () {
      final token = _makeToken({'sub': 'u1'});
      expect(jwtExpiry(token), isNull);
    });
  });
}
