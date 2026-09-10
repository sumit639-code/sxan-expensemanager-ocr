import 'package:drift/drift.dart';

/// Drift database table for local transaction persistence.
///
/// Financial amounts are stored as integers representing minor units (e.g., paise/cents)
/// to ensure exact numerical precision without double floating-point errors.
@DataClassName('TransactionData')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  IntColumn get amount => integer()(); // Minor units (e.g., 32050 for 320.50)
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get title => text()();
  TextColumn get merchant => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text()(); // 'manual', 'screenshot', 'import'
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
