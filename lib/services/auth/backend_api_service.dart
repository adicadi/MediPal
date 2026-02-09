import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final int statusCode;
  final String message;

  BackendApiException(this.statusCode, this.message);

  @override
  String toString() =>
      'BackendApiException(statusCode: $statusCode, message: $message)';
}

class BackendApiService {
  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 12);

  String get _baseUrl {
    final configured = dotenv.env['MEDIPAL_API_BASE_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/$'), '');
    }
    return 'http://localhost:8080';
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('GET', url);
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: _buildHeaders(bearerToken: bearerToken),
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw BackendApiException(
        504,
        'Backend request timed out. Check MEDIPAL_API_BASE_URL and backend server.',
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('POST', url);
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: _buildHeaders(bearerToken: bearerToken),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw BackendApiException(
        504,
        'Backend request timed out. Check MEDIPAL_API_BASE_URL and backend server.',
      );
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    String? bearerToken,
  }) async {
    final url = '$_baseUrl$path';
    _logRequest('PATCH', url);
    try {
      final response = await _client
          .patch(
            Uri.parse(url),
            headers: _buildHeaders(bearerToken: bearerToken),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response);
    } on TimeoutException {
      throw BackendApiException(
        504,
        'Backend request timed out. Check MEDIPAL_API_BASE_URL and backend server.',
      );
    }
  }

  Map<String, String> _buildHeaders({String? bearerToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final raw = response.body.trim();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{'data': decoded};
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['error']?.toString() ?? 'Request failed')
        : 'Request failed';
    throw BackendApiException(response.statusCode, message);
  }

  void _logRequest(String method, String url) {
    if (kDebugMode) {
      debugPrint('BackendApiService -> $method $url');
    }
  }
}
