import '../../../settings/domain/entities/app_settings.dart';

/// Configuration for communicating with the Python OCR FastAPI backend.
class OcrApiConfig {
  /// Base URL of the Python OCR server.
  /// Defaults to `http://127.0.0.1:8000`.
  ///
  /// Note for Android USB debugging:
  /// Run `adb reverse tcp:8000 tcp:8000` to allow the device to connect to `127.0.0.1:8000`.
  final String baseUrl;

  /// Active API endpoint version (V1: `/extract`, V2: `/extract/v2`).
  final PythonApiVersion apiVersion;

  /// Timeout for establishing connection.
  final Duration connectTimeout;

  /// Timeout for receiving response after connection is established.
  final Duration receiveTimeout;

  const OcrApiConfig({
    this.baseUrl = 'http://127.0.0.1:8000',
    this.apiVersion = PythonApiVersion.v2,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  /// Health endpoint URI: `GET /health`
  Uri get healthUri => Uri.parse('$baseUrl/health');

  /// Active extract endpoint URI: `POST /extract` or `POST /extract/v2`
  Uri get extractUri => Uri.parse('$baseUrl${apiVersion.endpoint}');

  /// V1 extract endpoint URI: `POST /extract`
  Uri get extractV1Uri => Uri.parse('$baseUrl/extract');

  /// V2 extract endpoint URI: `POST /extract/v2`
  Uri get extractV2Uri => Uri.parse('$baseUrl/extract/v2');

  OcrApiConfig copyWith({
    String? baseUrl,
    PythonApiVersion? apiVersion,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) {
    return OcrApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiVersion: apiVersion ?? this.apiVersion,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    );
  }

  @override
  String toString() =>
      'OcrApiConfig(baseUrl: $baseUrl, version: ${apiVersion.value}, endpoint: ${apiVersion.endpoint})';
}
