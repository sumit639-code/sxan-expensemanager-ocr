// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Web (Chrome, Edge, Safari, Firefox) database connection using WebDatabase / IndexedDB.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    return WebDatabase('expense_app', logStatements: true);
  });
}
