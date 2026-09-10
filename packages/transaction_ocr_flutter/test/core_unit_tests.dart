import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

void main() {
  group('BoundingBox', () {
    test('AABB and center computation', () {
      final bbox = BoundingBox.fromPoints([
        [10.0, 20.0],
        [50.0, 20.0],
        [50.0, 40.0],
        [10.0, 40.0],
      ]);

      expect(bbox.minX, equals(10.0));
      expect(bbox.maxX, equals(50.0));
      expect(bbox.minY, equals(20.0));
      expect(bbox.maxY, equals(40.0));
      expect(bbox.width, equals(40.0));
      expect(bbox.height, equals(20.0));
      expect(bbox.center.x, equals(30.0));
      expect(bbox.center.y, equals(30.0));
      expect(bbox.area, equals(800.0));
    });

    test('IoU and IoS between overlapping boxes', () {
      final box1 = BoundingBox.fromRect(0.0, 0.0, 10.0, 10.0);
      final box2 = BoundingBox.fromRect(5.0, 0.0, 15.0, 10.0);

      // Area1 = 100, Area2 = 100, InterArea = 5*10 = 50, UnionArea = 150
      expect(box1.computeIoU(box2), closeTo(50.0 / 150.0, 1e-4));
      expect(box1.computeIoS(box2), closeTo(50.0 / 100.0, 1e-4));
      expect(box1.isSpatiallyOverlapping(box2, iouThreshold: 0.30), isTrue);
    });

    test('isSpatiallyOverlapping handles nested/contained boxes', () {
      final bigBox = BoundingBox.fromRect(10.0, 10.0, 100.0, 30.0);
      final smallBox = BoundingBox.fromRect(15.0, 12.0, 80.0, 28.0);

      expect(bigBox.isSpatiallyOverlapping(smallBox), isTrue);
    });
  });

  group('OcrCandidateConsolidator', () {
    test('composite scoring gives bonuses to rupee symbol and financial formatting', () {
      final scoreWithRupee = OcrCandidateConsolidator.scoreCandidate('₹5,000', 0.90);
      final scorePlain = OcrCandidateConsolidator.scoreCandidate('5000', 0.90);

      expect(scoreWithRupee, greaterThan(scorePlain));
    });

    test('composite scoring applies penalty to CJK characters', () {
      final scoreChinese = OcrCandidateConsolidator.scoreCandidate('买205', 0.80);
      final scoreClean = OcrCandidateConsolidator.scoreCandidate('₹205', 0.80);

      expect(scoreClean, greaterThan(scoreChinese));
    });

    test('consolidate clusters overlapping detections and ranks best candidate first', () {
      final rawDetections = [
        {
          'text': 'R5,000',
          'confidence': 0.85,
          'bbox': [
            [384.0, 377.0],
            [440.0, 377.0],
            [440.0, 395.0],
            [384.0, 395.0]
          ],
        },
        {
          'text': '₹5,000',
          'confidence': 0.90,
          'bbox': [
            [383.0, 376.0],
            [441.0, 376.0],
            [441.0, 396.0],
            [383.0, 396.0]
          ],
        },
      ];

      final consolidated = OcrCandidateConsolidator.consolidate(rawDetections);
      expect(consolidated.length, equals(1));
      expect(consolidated.first.candidatesCount, equals(2));
      expect(consolidated.first.text, equals('₹5,000'));
      expect(consolidated.first.textNormalized, equals('₹5,000'));
    });
  });

  group('CtcDecoder', () {
    test('decodes character indices and removes consecutive duplicates', () {
      final dict = ['A', 'B', 'C', 'D'];
      final decoder = CtcDecoder(characterDict: dict);

      // Indices: [1, 1, 2, 0, 3, 3] -> 'A', 'B', skip blank, 'C' -> 'ABC'
      final preds = [1, 1, 2, 0, 3, 3];
      final probs = [0.9, 0.95, 0.85, 0.99, 0.92, 0.94];

      final res = decoder.decode(preds, probs);
      expect(res['text'], equals('ABC'));
      expect(res['confidence'], greaterThan(0.8));
    });
  });

  group('DbPostProcessor', () {
    test('filters low score boxes and extracts valid bounding boxes', () {
      final postproc = DbPostProcessor(thresh: 0.3, boxThresh: 0.5);

      // 10x10 map with a 4x4 high confidence block in center
      const int w = 10;
      const int h = 10;
      final List<double> predMap = List.filled(w * h, 0.0);

      for (int y = 3; y <= 6; y++) {
        for (int x = 3; x <= 6; x++) {
          predMap[y * w + x] = 0.95;
        }
      }

      final boxes = postproc.getBoxes(predMap, w, h, 100, 100);
      expect(boxes.isNotEmpty, isTrue);
      final box = boxes.first;
      expect(box.minX, greaterThanOrEqualTo(0.0));
      expect(box.maxX, lessThanOrEqualTo(100.0));
      expect(box.minY, greaterThanOrEqualTo(0.0));
      expect(box.maxY, lessThanOrEqualTo(100.0));
    });
  });
}
