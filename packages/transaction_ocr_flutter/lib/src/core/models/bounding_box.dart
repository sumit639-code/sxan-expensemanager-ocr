import 'dart:math';

/// A 2D point representation with double precision coordinates.
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  factory Point2D.fromJson(List<dynamic> json) {
    return Point2D(
      (json[0] as num).toDouble(),
      (json[1] as num).toDouble(),
    );
  }

  List<double> toJson() => [x, y];

  @override
  String toString() => 'Point2D($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point2D &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 1e-5 &&
          (y - other.y).abs() < 1e-5;

  @override
  int get hashCode => Object.hash(x.roundToDouble(), y.roundToDouble());
}

/// A 4-point quad bounding box representation for OCR text lines.
/// Typically ordered clockwise: [Top-Left, Top-Right, Bottom-Right, Bottom-Left].
class BoundingBox {
  final List<Point2D> points;

  BoundingBox(this.points) : assert(points.length == 4, 'BoundingBox requires exactly 4 points');

  factory BoundingBox.fromPoints(List<List<double>> rawPoints) {
    return BoundingBox(rawPoints.map((p) => Point2D(p[0], p[1])).toList());
  }

  factory BoundingBox.fromRect(double minX, double minY, double maxX, double maxY) {
    return BoundingBox([
      Point2D(minX, minY),
      Point2D(maxX, minY),
      Point2D(maxX, maxY),
      Point2D(minX, maxY),
    ]);
  }

  factory BoundingBox.fromJson(List<dynamic> json) {
    final pts = json.map((p) => Point2D.fromJson(p as List<dynamic>)).toList();
    return BoundingBox(pts);
  }

  List<List<double>> toJson() => points.map((p) => p.toJson()).toList();

  double get minX => points.map((p) => p.x).reduce(min);
  double get maxX => points.map((p) => p.x).reduce(max);
  double get minY => points.map((p) => p.y).reduce(min);
  double get maxY => points.map((p) => p.y).reduce(max);

  double get width => maxX - minX;
  double get height => maxY - minY;

  Point2D get center => Point2D(
        points.map((p) => p.x).reduce((a, b) => a + b) / points.length,
        points.map((p) => p.y).reduce((a, b) => a + b) / points.length,
      );

  double get area => max(0.0, width) * max(0.0, height);

  /// Computes Intersection over Union (IoU) with another bounding box using AABB approximation.
  double computeIoU(BoundingBox other) {
    final ix1 = max(minX, other.minX);
    final iy1 = max(minY, other.minY);
    final ix2 = min(maxX, other.maxX);
    final iy2 = min(maxY, other.maxY);

    final iw = max(0.0, ix2 - ix1);
    final ih = max(0.0, iy2 - iy1);
    final interArea = iw * ih;

    final area1 = area;
    final area2 = other.area;
    final unionArea = area1 + area2 - interArea;

    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  /// Computes Intersection over Smaller Box (IoS) to handle nested/contained detections.
  double computeIoS(BoundingBox other) {
    final ix1 = max(minX, other.minX);
    final iy1 = max(minY, other.minY);
    final ix2 = min(maxX, other.maxX);
    final iy2 = min(maxY, other.maxY);

    final iw = max(0.0, ix2 - ix1);
    final ih = max(0.0, iy2 - iy1);
    final interArea = iw * ih;

    final minArea = min(area, other.area);
    if (minArea <= 0) return 0.0;
    return interArea / minArea;
  }

  /// Determines if two bounding boxes cover substantially the same visual region.
  /// Matches Python OcrCandidateConsolidator.are_spatially_overlapping logic.
  bool isSpatiallyOverlapping(
    BoundingBox other, {
    double iouThreshold = 0.35,
    double iosThreshold = 0.60,
  }) {
    if (computeIoU(other) >= iouThreshold) return true;
    if (computeIoS(other) >= iosThreshold) return true;

    final cy1 = (minY + maxY) / 2.0;
    final cy2 = (other.minY + other.maxY) / 2.0;
    final h1 = height;
    final h2 = other.height;
    final avgH = (h1 + h2) / 2.0;

    if (avgH > 0 && (cy1 - cy2).abs() < (0.4 * avgH)) {
      final overlapW = max(0.0, min(maxX, other.maxX) - max(minX, other.minX));
      final minW = min(width, other.width);
      if (minW > 0 && (overlapW / minW) > 0.65) {
        return true;
      }
    }

    return false;
  }

  @override
  String toString() => 'BoundingBox(${toJson()})';
}
