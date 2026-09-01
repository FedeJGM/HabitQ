import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, Future<String?> Function()? tokenProvider})
      : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? (() => const TokenStorage().read());

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client
          .post(_uri(path), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    });
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client.get(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
    });
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client
          .put(_uri(path), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    });
    return _decode(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor. Verifica tu conexión.');
    }
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _tokenProvider();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'];
      throw ApiException(detail is String ? detail : 'Ocurrió un error inesperado.');
    }

    return decoded;
  }
}
