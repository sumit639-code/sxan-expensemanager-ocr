import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Riverpod provider for single-instance AppDatabase lifecycle management.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});
