import 'package:drift/drift.dart';

/// Fallback stub connection.
QueryExecutor openConnection() {
  throw UnsupportedError(
    'Cannot open database without platform connection implementation.',
  );
}
