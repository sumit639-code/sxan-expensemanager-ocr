import 'dart:math';
import 'dart:typed_data';
import '../core/models/bounding_box.dart';

/// Differentiable Binarization (DBNet) Detection Post-processor in pure Dart.
/// Converts DBNet probability map tensor `[1, 1, H, W]` into bounding box polygons.
/// Matches Python `DBPostProcess` in RapidOCR.
class DbPostProcessor {
  final double thresh;
  final double boxThresh;
  final double unclipRatio;
  final int minSize;
  final int maxCandidates;

  DbPostProcessor({
    this.thresh = 0.3,
    this.boxThresh = 0.5,
    this.unclipRatio = 1.6,
    this.minSize = 3,
    this.maxCandidates = 1000,
  });

  /// Extracts bounding box polygons from a 2D probability map.
  ///
  /// - [predMap]: 1D flattened Float32List or `List<double>` of length `height * width` (values 0.0 .. 1.0)
  /// - [mapWidth]: Width of the probability map tensor
  /// - [mapHeight]: Height of the probability map tensor
  /// - [destWidth]: Original screenshot image width in pixels
  /// - [destHeight]: Original screenshot image height in pixels
  List<BoundingBox> getBoxes(
    List<double> predMap,
    int mapWidth,
    int mapHeight,
    int destWidth,
    int destHeight,
  ) {
    if (mapWidth <= 0 || mapHeight <= 0 || predMap.isEmpty) {
      return [];
    }

    // 1. Binary segmentation threshold
    final Uint8List binaryMask = Uint8List(mapWidth * mapHeight);
    for (int i = 0; i < predMap.length; i++) {
      if (predMap[i] > thresh) {
        binaryMask[i] = 1;
      }
    }

    // 2. Connected Component Labeling (2-pass with Union-Find)
    final components = _extractConnectedComponents(binaryMask, mapWidth, mapHeight);

    final List<BoundingBox> detectedBoxes = [];

    for (final comp in components) {
      if (detectedBoxes.length >= maxCandidates) break;

      final minX = comp.minX;
      final maxX = comp.maxX;
      final minY = comp.minY;
      final maxY = comp.maxY;

      final w = maxX - minX + 1;
      final h = maxY - minY + 1;

      if (w < minSize || h < minSize) {
        continue;
      }

      // 3. Compute mean score inside the component region on raw predMap
      double sumScore = 0.0;
      int pixelCount = 0;
      for (int py = minY; py <= maxY; py++) {
        for (int px = minX; px <= maxX; px++) {
          final idx = py * mapWidth + px;
          if (binaryMask[idx] == 1) {
            sumScore += predMap[idx];
            pixelCount++;
          }
        }
      }

      final double score = pixelCount > 0 ? sumScore / pixelCount : 0.0;
      if (score < boxThresh) {
        continue;
      }

      // 4. Polygon Unclip expansion
      // distance = (Area * unclipRatio) / Perimeter
      final double area = (w * h).toDouble();
      final double perimeter = (2 * (w + h)).toDouble();
      final double distance = perimeter > 0 ? (area * unclipRatio) / perimeter : 0.0;

      final double unclipMinX = max(0.0, minX - distance);
      final double unclipMaxX = min((mapWidth - 1).toDouble(), maxX + distance);
      final double unclipMinY = max(0.0, minY - distance);
      final double unclipMaxY = min((mapHeight - 1).toDouble(), maxY + distance);

      // Check min size after unclip
      if ((unclipMaxX - unclipMinX) < minSize + 2 || (unclipMaxY - unclipMinY) < minSize + 2) {
        continue;
      }

      // 5. Rescale coordinates to destination image dimensions
      final double scaleX = destWidth / mapWidth.toDouble();
      final double scaleY = destHeight / mapHeight.toDouble();

      final double finalX1 = (unclipMinX * scaleX).clamp(0.0, destWidth.toDouble());
      final double finalY1 = (unclipMinY * scaleY).clamp(0.0, destHeight.toDouble());
      final double finalX2 = (unclipMaxX * scaleX).clamp(0.0, destWidth.toDouble());
      final double finalY2 = (unclipMaxY * scaleY).clamp(0.0, destHeight.toDouble());

      // 4-point quad: TL, TR, BR, BL
      final box = BoundingBox([
        Point2D(finalX1, finalY1),
        Point2D(finalX2, finalY1),
        Point2D(finalX2, finalY2),
        Point2D(finalX1, finalY2),
      ]);

      detectedBoxes.add(box);
    }

    // 6. Sort boxes in reading order: top-to-bottom, left-to-right
    return sortedBoxes(detectedBoxes);
  }

  /// Sorts boxes in order from top to bottom, left to right.
  /// Matches Python `sorted_boxes`.
  static List<BoundingBox> sortedBoxes(List<BoundingBox> boxes) {
    final sorted = List<BoundingBox>.from(boxes);
    sorted.sort((a, b) {
      final yCmp = a.minY.compareTo(b.minY);
      if (yCmp != 0) return yCmp;
      return a.minX.compareTo(b.minX);
    });

    for (int i = 0; i < sorted.length - 1; i++) {
      if ((sorted[i + 1].minY - sorted[i].minY).abs() < 10 && (sorted[i + 1].minX < sorted[i].minX)) {
        final tmp = sorted[i];
        sorted[i] = sorted[i + 1];
        sorted[i + 1] = tmp;
      }
    }

    return sorted;
  }

  List<_ComponentBounds> _extractConnectedComponents(Uint8List mask, int width, int height) {
    final Int32List labels = Int32List(width * height);
    final List<int> parent = [0];
    int nextLabel = 1;

    int find(int i) {
      var root = i;
      while (parent[root] != root) {
        root = parent[root];
      }
      var curr = i;
      while (curr != root) {
        final nxt = parent[curr];
        parent[curr] = root;
        curr = nxt;
      }
      return root;
    }

    void union(int i, int j) {
      final rootI = find(i);
      final rootJ = find(j);
      if (rootI != rootJ) {
        parent[rootJ] = rootI;
      }
    }

    // Pass 1: Assign initial labels and record equivalences
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        if (mask[idx] == 0) continue;

        final int? up = y > 0 && mask[idx - width] == 1 ? labels[idx - width] : null;
        final int? left = x > 0 && mask[idx - 1] == 1 ? labels[idx - 1] : null;

        if (up == null && left == null) {
          labels[idx] = nextLabel;
          parent.add(nextLabel);
          nextLabel++;
        } else if (up != null && left == null) {
          labels[idx] = up;
        } else if (up == null && left != null) {
          labels[idx] = left;
        } else {
          labels[idx] = up!;
          if (up != left) {
            union(up, left!);
          }
        }
      }
    }

    // Pass 2: Resolve root labels and accumulate bounding boxes
    final Map<int, _ComponentBounds> componentMap = {};

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = y * width + x;
        final rawLabel = labels[idx];
        if (rawLabel == 0) continue;

        final rootLabel = find(rawLabel);
        final bounds = componentMap.putIfAbsent(
          rootLabel,
          () => _ComponentBounds(minX: x, maxX: x, minY: y, maxY: y),
        );
        bounds.update(x, y);
      }
    }

    return componentMap.values.toList();
  }
}

class _ComponentBounds {
  int minX;
  int maxX;
  int minY;
  int maxY;

  _ComponentBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  void update(int x, int y) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
}
