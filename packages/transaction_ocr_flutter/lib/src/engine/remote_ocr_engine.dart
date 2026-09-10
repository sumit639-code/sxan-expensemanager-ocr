import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/exceptions/ocr_exceptions.dart';
import '../core/models/ocr_result.dart';
import 'ocr_engine.dart';

/// Remote OCR Engine calling the Python FastAPI server `/extract/v2` endpoint.
/// Useful as a development bridge and reference comparison backend.
class RemoteOcrEngine implements OcrEngine {
  final String baseUrl;
  final HttpClient _httpClient;
  bool _isInitialized = false;

  RemoteOcrEngine({String baseUrl = 'http://localhost:8000'})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _httpClient = HttpClient();

  @override
  String get engineName => 'RapidOCR-Remote-API-V2';

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<OcrResult> extractImage(
    Uint8List imageBytes, {
    String filename = 'screenshot.png',
    OcrProgressCallback? onProgress,
    int currentImage = 1,
    int totalImages = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/extract/v2');

    try {
      onProgress?.call(currentImage, totalImages, 'Uploading to remote OCR server', 0.25);

      final boundary = '----DartBoundary${DateTime.now().millisecondsSinceEpoch}';
      final request = await _httpClient.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');

      final List<int> body = [];
      body.addAll(utf8.encode('--$boundary\r\n'));
      body.addAll(utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="$filename"\r\nContent-Type: image/png\r\n\r\n'));
      body.addAll(imageBytes);
      body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

      request.contentLength = body.length;
      request.add(body);

      onProgress?.call(currentImage, totalImages, 'Processing on server', 0.60);
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw RemoteOcrException(
          'Remote OCR failed with status ${response.statusCode}: $responseBody',
          statusCode: response.statusCode,
        );
      }

      onProgress?.call(currentImage, totalImages, 'Parsing server response', 0.90);
      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
      onProgress?.call(currentImage, totalImages, 'Complete', 1.0);

      return OcrResult.fromJson(jsonMap);
    } catch (e, st) {
      if (e is OcrException) rethrow;
      throw RemoteOcrException(
        'Failed to communicate with remote OCR API at $uri: $e',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _httpClient.close(force: true);
    _isInitialized = false;
  }
}
