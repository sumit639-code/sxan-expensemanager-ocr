import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OcrDemoApp());
}

class OcrDemoApp extends StatelessWidget {
  const OcrDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Transaction OCR V2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const OcrHomeScreen(),
    );
  }
}

class OcrHomeScreen extends StatefulWidget {
  const OcrHomeScreen({super.key});

  @override
  State<OcrHomeScreen> createState() => _OcrHomeScreenState();
}

class _OcrHomeScreenState extends State<OcrHomeScreen> {
  late final TransactionOcr _ocr;
  bool _isInitializing = false;
  bool _isProcessing = false;
  String _currentStage = '';
  double _currentProgress = 0.0;
  OcrResult? _lastResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize Local on-device OCR engine
    _ocr = TransactionOcr.local();
    _initOcr();
  }

  Future<void> _initOcr() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await _ocr.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Model initialization failed: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _processSampleImage(Uint8List imageBytes) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _lastResult = null;
    });

    try {
      final result = await _ocr.extractImageBytes(
        imageBytes,
        onProgress: (current, total, stage, progress) {
          setState(() {
            _currentStage = stage;
            _currentProgress = progress;
          });
        },
      );

      setState(() {
        _lastResult = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Extraction failed: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Transaction OCR V2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reinitialize Models',
            onPressed: _isProcessing ? null : _initOcr,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _ocr.isInitialized ? Icons.check_circle : Icons.hourglass_top,
                      color: _ocr.isInitialized ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Engine: ${_ocr.engine.engineName}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _isInitializing
                                ? 'Loading ONNX models into memory...'
                                : (_ocr.isInitialized ? 'Ready for offline inference' : 'Uninitialized'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Indicator
            if (_isProcessing) ...[
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stage: $_currentStage', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _currentProgress),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error Card
            if (_errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Result List
            Expanded(
              child: _lastResult == null
                  ? Center(
                      child: Text(
                        'No transactions extracted yet.\nSelect or process a screenshot to begin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _lastResult!.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _lastResult!.transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              tx.merchantText ?? 'Unknown Merchant',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Date: ${tx.dateText ?? 'Unknown date'}'),
                            trailing: Text(
                              '₹${tx.amountValue ?? tx.amountTextNormalized}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing || !_ocr.isInitialized
            ? null
            : () => _processSampleImage(Uint8List(0)),
        icon: const Icon(Icons.document_scanner),
        label: const Text('Extract Sample'),
      ),
    );
  }
}
