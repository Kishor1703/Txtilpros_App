import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Mirrors VITE_API_URL from .env. Change this to point at your backend,
/// e.g. https://backend-sigma-pink.vercel.app/api
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://backend-sigma-pink.vercel.app/api',
);

const String kTokenKey = 'employee-reporting-token';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Direct port of apiRequest() in api.js
class ApiService {
  static Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final future = _send(method, uri, headers, body);
      response = timeout != null ? await future.timeout(timeout) : await future;
    } catch (e) {
      throw ApiException('The request took too long. Please try again.');
    }

    Map<String, dynamic> data = {};
    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      data = {};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException((data['error'] ?? 'Request failed').toString(), statusCode: response.statusCode);
    }
    return data;
  }

  static Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    final encoded = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: encoded);
      case 'PUT':
        return http.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: encoded);
      default:
        return http.get(uri, headers: headers);
    }
  }

  /// Direct port of apiDownload() in api.js — downloads bytes and saves
  /// them to the app documents directory, returning the saved file path.
  static Future<String> download(String path, String filename, String? token) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final response = await http.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Download failed';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        message = (data['error'] ?? message).toString();
      } catch (_) {}
      throw ApiException(message);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}
