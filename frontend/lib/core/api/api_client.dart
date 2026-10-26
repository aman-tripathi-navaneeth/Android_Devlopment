import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Cross-platform API client. Do not use dart:io here: this client is also
/// compiled for Chrome and Platform.isAndroid crashes on Flutter Web.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String _baseUrl = kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? 'http://127.0.0.1:8000/api/v1'
      : 'http://10.0.2.2:8000/api/v1';

  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<bool> isBackendReachable() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getProducts({int limit = 100}) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/products?limit=$limit'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = _decodeAny(response.body);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStockBalance({
    required String storeId,
    required String productId,
  }) async {
    try {
      return await getStockBalanceStrict(storeId: storeId, productId: productId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createMedicine(Map<String, dynamic> payload) async {
    try {
      return await createMedicineStrict(payload);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createMedicineStrict(Map<String, dynamic> payload) {
    return _postJson('$_baseUrl/products', payload, '', timeout: const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> updateMedicineStrict({
    required String productId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/products/$productId'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeAny(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) return decoded;
    throw ApiException(_errorMessage(decoded, response.body), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> getStockBalanceStrict({
    required String storeId,
    required String productId,
  }) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/stores/$storeId/inventory/$productId/balance'))
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeAny(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(_errorMessage(decoded, response.body), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>?> postGoodsReceipt({
    required String storeId,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    try {
      return await _postJson(
        '$_baseUrl/stores/$storeId/inventory/receive',
        payload,
        idempotencyKey,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> postGoodsReceiptStrict({
    required String storeId,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) {
    return _postJson(
      '$_baseUrl/stores/$storeId/inventory/receive',
      payload,
      idempotencyKey,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<Map<String, dynamic>?> postSalesDeduction({
    required String storeId,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    try {
      return await _postJson(
        '$_baseUrl/stores/$storeId/inventory/deduct',
        payload,
        idempotencyKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// Strict variant used by Manual Transaction. It preserves backend errors
  /// and always completes with either a result or a recoverable exception.
  Future<Map<String, dynamic>> postSalesDeductionStrict({
    required String storeId,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    try {
      return await _postJson(
        '$_baseUrl/stores/$storeId/inventory/deduct',
        payload,
        idempotencyKey,
        timeout: const Duration(seconds: 30),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server did not respond in time. The transaction status is uncertain; retrying is safe because the same idempotency key is preserved.',
      );
    } catch (error) {
      throw ApiException('Transaction request failed: $error');
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> payload,
    String idempotencyKey, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'content-type': 'application/json',
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    final decoded = _decodeAny(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(_errorMessage(decoded, response.body), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>?> scanDocumentImage({
    required List<int> imageBytes,
    required String fileName,
    required String mimeType,
    required String documentType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/ocr/scan-image').replace(queryParameters: {'document_type': documentType}),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    ));
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 75));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 201) return _decodeMap(response.body);
      // Propagate meaningful error from backend
      final decoded = _decodeAny(response.body);
      final msg = _errorMessage(decoded, response.body);
      throw ApiException('OCR failed (HTTP \${response.statusCode}): \$msg', statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not reach the backend OCR service: \$e');
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final value = _decodeAny(body);
    if (value is Map<String, dynamic>) return value;
    throw const ApiException('The backend returned an invalid JSON object.');
  }

  dynamic _decodeAny(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(dynamic decoded, String rawBody) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        return detail['message']?.toString() ?? detail.toString();
      }
      if (detail != null) return detail.toString();
    }
    return rawBody.isEmpty ? 'The backend rejected the request.' : rawBody;
  }
}
