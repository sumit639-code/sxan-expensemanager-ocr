import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/python_ocr_response.dart';
import 'ocr_api_config.dart';

/// Base exception for Python OCR API interactions.
class PythonOcrApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const PythonOcrApiException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Thrown when the Python server is offline or connection is refused.
class PythonOcrConnectionException extends PythonOcrApiException {
  const PythonOcrConnectionException(
    super.message, {
    super.originalError,
  });
}

/// Thrown when a request to the Python server times out.
class PythonOcrTimeoutException extends PythonOcrApiException {
  const PythonOcrTimeoutException(
    super.message, {
    super.originalError,
  });
}

/// Result of testing connectivity to a Python OCR API endpoint.
class PythonApiTestResult {
  final bool success;
  final int statusCode;
  final int latencyMs;
  final String endpoint;
  final String message;
  final Map<String, dynamic>? rawResponse;

  const PythonApiTestResult({
    required this.success,
    required this.statusCode,
    required this.latencyMs,
    required this.endpoint,
    required this.message,
    this.rawResponse,
  });

  @override
  String toString() =>
      'PythonApiTestResult(success: $success, endpoint: $endpoint, latency: ${latencyMs}ms, message: $message)';
}

/// Data source client communicating with the Python FastAPI RapidOCR server.
class PythonOcrApi {
  final OcrApiConfig config;
  final http.Client _client;

  PythonOcrApi({
    this.config = const OcrApiConfig(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Verifies that the Python OCR service is reachable and healthy.
  ///
  /// Calls `GET /health`.
  /// Expected response: `{"status": "ok", "service": "expense-ocr"}`
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(config.healthUri)
          .timeout(config.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data['status'] == 'ok' || data['success'] == true;
        }
      }
      return false;
    } on SocketException catch (e) {
      throw PythonOcrConnectionException(
        'Cannot connect to OCR server at ${config.baseUrl}. Please ensure the server is running.',
        originalError: e,
      );
    } on http.ClientException catch (e) {
      throw PythonOcrConnectionException(
        'Connection to OCR service failed. Please check network/USB connection.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw PythonOcrTimeoutException(
        'OCR service health check timed out.',
        originalError: e,
      );
    } catch (e) {
      if (e is PythonOcrApiException) rethrow;
      throw PythonOcrApiException(
        'Unexpected error checking OCR service health: $e',
        originalError: e,
      );
    }
  }

  /// Tests connectivity to a specific endpoint (e.g. `/health`, `/extract`, or `/extract/v2`)
  /// and measures latency in milliseconds.
  Future<PythonApiTestResult> testEndpoint({Uri? targetUri}) async {
    final stopwatch = Stopwatch()..start();
    final uri = targetUri ?? config.healthUri;

    try {
      final response = await _client.get(uri).timeout(config.connectTimeout);
      stopwatch.stop();

      Map<String, dynamic>? decoded;
      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) decoded = json;
      } catch (_) {}

      final isHealthy = response.statusCode == 200;
      final msg = isHealthy
          ? 'Connected successfully (${stopwatch.elapsedMilliseconds}ms)'
          : 'Server responded with HTTP ${response.statusCode}';

      return PythonApiTestResult(
        success: isHealthy,
        statusCode: response.statusCode,
        latencyMs: stopwatch.elapsedMilliseconds,
        endpoint: uri.toString(),
        message: msg,
        rawResponse: decoded,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return PythonApiTestResult(
        success: false,
        statusCode: 0,
        latencyMs: stopwatch.elapsedMilliseconds,
        endpoint: uri.toString(),
        message: 'Connection refused (${e.message}). Ensure server is running on ${config.baseUrl}',
      );
    } on TimeoutException {
      stopwatch.stop();
      return PythonApiTestResult(
        success: false,
        statusCode: 408,
        latencyMs: stopwatch.elapsedMilliseconds,
        endpoint: uri.toString(),
        message: 'Request timed out after ${config.connectTimeout.inSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      return PythonApiTestResult(
        success: false,
        statusCode: 500,
        latencyMs: stopwatch.elapsedMilliseconds,
        endpoint: uri.toString(),
        message: 'Error: $e',
      );
    }
  }

  /// Sends a screenshot image file to the Python OCR API for text extraction.
  ///
  /// Calls `POST /extract` or `POST /extract/v2` as `multipart/form-data` with field `file`.
  Future<PythonOcrResponse> extractFromImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw PythonOcrApiException('Image file does not exist: $imagePath');
    }

    try {
      final request = http.MultipartRequest('POST', config.extractUri);
      final multipartFile = await http.MultipartFile.fromPath('file', imagePath);
      request.files.add(multipartFile);

      final streamedResponse = await _client
          .send(request)
          .timeout(config.receiveTimeout);

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return PythonOcrResponse.fromJson(decoded);
        } else if (decoded is List) {
          // If Python API returns raw list of items directly
          return PythonOcrResponse(
            success: true,
            items: decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => PythonOcrItem.fromJson(e))
                .toList(),
          );
        } else {
          throw const PythonOcrApiException(
            'Invalid response format from OCR API: expected JSON object.',
          );
        }
      } else {
        throw PythonOcrApiException(
          'OCR service returned error (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw PythonOcrConnectionException(
        'Failed to reach OCR server at ${config.baseUrl}. If testing on Android via USB, run "adb reverse tcp:8000 tcp:8000".',
        originalError: e,
      );
    } on http.ClientException catch (e) {
      throw PythonOcrConnectionException(
        'Network error while uploading screenshot to OCR service.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw PythonOcrTimeoutException(
        'OCR processing timed out after ${config.receiveTimeout.inSeconds}s.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw PythonOcrApiException(
        'Failed to parse JSON response from OCR server.',
        originalError: e,
      );
    } catch (e) {
      if (e is PythonOcrApiException) rethrow;
      throw PythonOcrApiException(
        'Error during screenshot extraction: $e',
        originalError: e,
      );
    }
  }

  void close() {
    _client.close();
  }
}
