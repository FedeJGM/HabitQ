import 'dart:convert';

/// Decodes the `exp` claim from a JWT's payload without verifying its
/// signature. The backend is the source of truth for validity — this is
/// only used client-side to decide when to proactively refresh a token
/// that is still valid but about to expire.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  Object? payload;
  try {
    final normalized = base64Url.normalize(parts[1]);
    payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
  } catch (_) {
    return null;
  }

  if (payload is! Map<String, dynamic>) return null;

  final exp = payload['exp'];
  if (exp is! num) return null;

  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
}
