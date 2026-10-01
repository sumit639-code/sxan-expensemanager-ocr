import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/src/parsing/transaction_grouper.dart';

void main() {
  test('Run TransactionGrouper on all 8 Navi sample screenshots', () {
    final file = File(
        r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\126f3c7c-b149-43d4-bc34-dc77efc1ca14\scratch\all_sample_ocr.json');
    if (!file.existsSync()) return;
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);

    for (final entry in data.entries) {
      final fname = entry.key;
      final items = (entry.value as List).map((it) => it as Map<String, dynamic>).toList();

      // Estimate image size from max bbox
      double maxX = 720;
      double maxY = 1600;
      for (final it in items) {
        final b = it['bbox'] as List;
        if ((b[2] as num).toDouble() > maxX) maxX = (b[2] as num).toDouble();
        if ((b[3] as num).toDouble() > maxY) maxY = (b[3] as num).toDouble();
      }

      final res = TransactionGrouper.group(
        detections: items,
        imgWidth: maxX.round() + 20,
        imgHeight: maxY.round() + 20,
      );

      print('========================================');
      print('FILE: $fname');
      print('Candidates (${res.transactionCandidates.length}):');
      for (final tx in res.transactionCandidates) {
        print('  • ${tx.merchantText} | ₹${tx.amountValue} (raw: "${tx.amountTextRaw}", minor: ${tx.amountMinorUnits}) | ${tx.dateText} | type: ${tx.transactionType}');
      }
    }
  });
}
