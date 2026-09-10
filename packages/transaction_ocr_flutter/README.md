# transaction_ocr_flutter (V2)

A completely **offline**, zero-cloud, on-device OCR and transaction extraction Flutter package. Designed to run directly inside mobile Flutter applications (Android & iOS) with **ONNX Runtime Mobile**.

---

## Architecture (Offline OCR V2)

```
Flutter Expense Application
        ↓
  TransactionOcr
        ↓
  LocalOcrEngine (On-Device)
        ↓
  ONNX Runtime (CPU / Mobile Acceleration)
        ↓
  Bundled Models (DBNet Det + SVTR-LCNet Rec)
        ↓
  Candidate Consolidator & Ranking (IoU / IoS)
        ↓
  Amount Classifier (Multi-layer rejection + ₹ symbol repair)
        ↓
  Transaction Grouper (Spatial Y-Band grouping)
        ↓
  Extracted Transactions (Structured List)
        ↓
  Expense App SQLite Database
```

---

## Bundled OCR Models

The package bundles quantized / optimized ONNX models located under `assets/models/v1.0.0/`:

| Model Asset | Architecture | Size | Description |
| :--- | :--- | :--- | :--- |
| `det_v1.onnx` | DBNet (PP-OCRv3) | **2.43 MB** | Text region detection with dynamic shape support |
| `rec_v1.onnx` | SVTR-LCNet (PP-OCRv3) | **10.69 MB** | Text line recognition & CTC logit predictions |
| `cls_v1.onnx` | PP-OCRv2 Cls | **0.58 MB** | Text orientation classifier (0° vs 180°) |
| `keys_v1.txt` | Dictionary | **33 KB** | 6,625 token character vocabulary |
| **Total Size** | | **~13.73 MB** | Complete offline inference package |

---

## Installation & Setup

Add `transaction_ocr_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  transaction_ocr_flutter:
    path: ../transaction_ocr_flutter # or git / package reference
```

Ensure the model assets are registered under `flutter.assets` in your app's `pubspec.yaml`:

```yaml
flutter:
  assets:
    - packages/transaction_ocr_flutter/assets/models/v1.0.0/det_v1.onnx
    - packages/transaction_ocr_flutter/assets/models/v1.0.0/rec_v1.onnx
    - packages/transaction_ocr_flutter/assets/models/v1.0.0/cls_v1.onnx
    - packages/transaction_ocr_flutter/assets/models/v1.0.0/keys_v1.txt
```

---

## Quick Start Usage

### 1. Single Image Offline Extraction

```dart
import 'dart:io';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() async {
  // 1. Initialize local on-device engine
  final ocr = TransactionOcr.local();
  await ocr.initialize();

  // 2. Extract transaction candidates from screenshot
  final file = File('screenshot.png');
  final result = await ocr.extractImage(
    file,
    onProgress: (current, total, stage, progress) {
      print('Image $current/$total: $stage (${(progress * 100).toInt()}%)');
    },
  );

  // 3. Process structured transaction candidates
  for (final tx in result.transactions) {
    print('Merchant: ${tx.merchantText}');
    print('Amount:   ₹${tx.amountValue}');
    print('Date:     ${tx.dateText}');
    print('Score:    ${tx.groupingConfidence}');
  }

  // 4. Free resources when done
  await ocr.dispose();
}
```

### 2. Batch Screenshot Processing

```dart
final files = [
  File('screenshot_001.png'),
  File('screenshot_002.png'),
  File('screenshot_003.png'),
];

final results = await ocr.extractImages(
  files,
  onProgress: (current, total, stage, progress) {
    print('Processing image $current of $total: $stage');
  },
);
```

### 3. Remote FastAPI Fallback (Development Bridge)

If you wish to benchmark against the Python FastAPI development bridge:

```dart
final ocr = TransactionOcr.remote(baseUrl: 'http://localhost:8000');
final result = await ocr.extractImage(file);
```

---

## V2 Features & Enhancements

1. **Robust Amount Classifier**:
   - Hard-rejects time strings (`16:48`, `08:56`), date labels (`7 September`, `2 days ago`), and UI labels.
   - Enforces spatial right-alignment ($x > 50\%$ width) for unadorned numbers.
   - Normalizes OCR symbol misreads:
     - `R20` $\to$ `₹20`
     - `买205` $\to$ `₹205`
     - `75,000` $\to$ `₹5,000` (leading 7 before thousands-comma)
     - `7205` $\to$ `₹205`

2. **Spatial Transaction Row Grouper**:
   - Groups merchant, date, and amount across Y-axis bands with median row height calculation.
   - Associates sub-merchant date labels located below the merchant name.

3. **Candidate Consolidation**:
   - Merges duplicate / overlapping text detections via IoU ($\ge 0.35$) and IoS ($\ge 0.60$) algorithms.
   - Scores candidates using composite financial heuristics.

---

## Error Handling

The package provides a typed exception hierarchy:

- `ModelLoadException`: Thrown when ONNX assets or dictionary files cannot be loaded.
- `ModelInferenceException`: Thrown when native ONNX inference fails.
- `ImageProcessingException`: Thrown when image decoding or cropping fails.
- `InvalidOcrResultException`: Thrown when OCR output is corrupted.
- `RemoteOcrException`: Thrown when the remote development API fails.

---

## Mobile Platform Configuration

### Android
- Minimum SDK: API 21+ (Android 5.0 Lollipop or higher).
- Supports 16 KB page size requirement on Android 15+.

### iOS
- Minimum iOS Version: iOS 13.0+.
- Supports arm64 device and simulator builds.
