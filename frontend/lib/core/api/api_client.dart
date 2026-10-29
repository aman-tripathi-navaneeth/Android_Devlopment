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

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      // Always use localhost for web — works on both IPv4 and IPv6 in Chrome
      return 'http://localhost:8000/api/v1';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  String _baseUrl = _defaultBaseUrl();

  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<bool> isBackendReachable() async {
    final urls = [
      '$_baseUrl/health',
      if (_baseUrl.contains('127.0.0.1'))
        _baseUrl.replaceAll('127.0.0.1', 'localhost') + '/health'
      else if (_baseUrl.contains('localhost'))
        _baseUrl.replaceAll('localhost', '127.0.0.1') + '/health',
    ];
    for (final url in urls) {
      try {
        final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
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

  Future<List<Map<String, dynamic>>> getSuppliers({
    String storeId = 'main_store',
    bool activeOnly = false,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/stores/$storeId/suppliers?active_only=$activeOnly'))
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

  Future<Map<String, dynamic>> createSupplierStrict({
    String storeId = 'main_store',
    required Map<String, dynamic> payload,
  }) {
    return _postJson('$_baseUrl/stores/$storeId/suppliers', payload, '', timeout: const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> updateSupplierStrict({
    String storeId = 'main_store',
    required String supplierId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/stores/$storeId/suppliers/$supplierId'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decodeAny(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(_errorMessage(decoded, response.body), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>?> getSupplier({
    String storeId = 'main_store',
    required String supplierId,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/stores/$storeId/suppliers/$supplierId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = _decodeAny(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSalesReports({String? status}) async {
    try {
      final url = status != null && status.isNotEmpty
          ? '$_baseUrl/sales-reports?status=$status'
          : '$_baseUrl/sales-reports';
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
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

  Future<Map<String, dynamic>?> getSalesReport(String reportId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/sales-reports/$reportId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = _decodeAny(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Calls PUT /sales-reports/{reportId}/lines to sync resolved lines with the backend
  Future<Map<String, dynamic>?> updateSalesReportLines({
    required String reportId,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse('$_baseUrl/sales-reports/$reportId/lines'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'lines': lines}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeAny(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Calls POST /sales-reports/{reportId}/confirm-and-post which deducts stock
  /// AND marks the backend sales report as POSTED in a single atomic operation.
  Future<Map<String, dynamic>?> confirmSalesReport({
    required String reportId,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/sales-reports/$reportId/confirm-and-post'),
            headers: {
              'content-type': 'application/json',
              'Idempotency-Key': idempotencyKey,
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 30));
      final decoded = _decodeAny(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return decoded;
      }
      final msg = _errorMessage(decoded, response.body);
      throw ApiException('Confirm sales report failed: $msg',
          statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not confirm sales report: $e');
    }
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
    final candidateBases = <String>[
      _baseUrl,
      if (_baseUrl.contains('127.0.0.1'))
        _baseUrl.replaceAll('127.0.0.1', 'localhost')
      else if (_baseUrl.contains('localhost'))
        _baseUrl.replaceAll('localhost', '127.0.0.1'),
    ];

    ApiException? lastApiException;
    dynamic lastNetworkException;

    for (final base in candidateBases) {
      final uri = Uri.parse('$base/ocr/scan-image').replace(queryParameters: {'document_type': documentType});
      final request = http.MultipartRequest('POST', uri);
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

        final decoded = _decodeAny(response.body);
        final msg = _errorMessage(decoded, response.body);
        throw ApiException('OCR failed (HTTP ${response.statusCode}): $msg', statusCode: response.statusCode);
      } on ApiException catch (e) {
        lastApiException = e;
        break;
      } catch (e) {
        lastNetworkException = e;
      }
    }

    if (lastApiException != null) {
      throw lastApiException;
    }
    throw ApiException('Could not reach the backend OCR service: $lastNetworkException');
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
