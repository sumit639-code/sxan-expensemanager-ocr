import 'package:intl/intl.dart';

import '../../features/transactions/domain/entities/transaction_entity.dart';

/// Service for exporting financial transaction history to standard CSV format.
class ExportCsvService {
  ExportCsvService._();

  /// Formats a list of [Transaction] records into standard RFC 4180 CSV text.
  static String generateCsv(List<Transaction> transactions) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Date,Type,Amount (INR),Title,Merchant,Category,Note,Source');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final tx in transactions) {
      final dateStr = dateFormat.format(tx.date);
      final typeStr = tx.type.value.toUpperCase();
      final amountStr = (tx.amount / 100.0).toStringAsFixed(2);
      final titleStr = _escapeCsvField(tx.title);
      final merchantStr = _escapeCsvField(tx.merchant ?? '');
      final categoryStr = _escapeCsvField(tx.categoryId ?? '');
      final noteStr = _escapeCsvField(tx.note ?? '');
      final sourceStr = tx.source.value.toUpperCase();

      buffer.writeln(
        '$dateStr,$typeStr,$amountStr,$titleStr,$merchantStr,$categoryStr,$noteStr,$sourceStr',
      );
    }

    return buffer.toString();
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
