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

  /// [timeout] defaults to 15s; slow endpoints (e.g. POST /chat) pass a longer one.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client
          .post(_uri(path), headers: headers, body: jsonEncode(body))
          .timeout(timeout);
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

  Future<List<dynamic>> getList(String path) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client.get(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
    });
    return _decodeList(response);
  }

  Future<void> delete(String path) async {
    final response = await _send(() async {
      final headers = await _headers();
      return _client.delete(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
    });
    _checkStatus(response);
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

  /// Like [_decode] but for responses with no body to parse (e.g. 204).
  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      throw ApiException(detail is String ? detail : 'Ocurrió un error inesperado.');
    }
  }

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      throw ApiException(detail is String ? detail : 'Ocurrió un error inesperado.');
    }

    return response.body.isEmpty ? <dynamic>[] : jsonDecode(response.body) as List<dynamic>;
  }
}
