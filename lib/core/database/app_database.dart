import 'package:drift/drift.dart';

import 'connection/connection.dart' as impl;
import 'database_tables.dart';

part 'app_database.g.dart';

/// AppDatabase is the SQLite source of truth for V1 local-first persistence.
@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.openConnection());

  /// Constructor for unit tests using in-memory databases.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}
