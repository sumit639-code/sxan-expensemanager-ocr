import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_ocr_flutter/transaction_ocr_flutter.dart';

class TestCaseData {
  final String appCategory;
  final String testName;
  final List<OcrItem> tokens;
  final int expectedTransactions;
  final List<ExpectedTx> expectedDetails;

  const TestCaseData({
    required this.appCategory,
    required this.testName,
    required this.tokens,
    required this.expectedTransactions,
    required this.expectedDetails,
  });
}

class ExpectedTx {
  final int expectedAmountMinor;
  final String? expectedMerchant;
  final String? expectedType;

  const ExpectedTx({
    required this.expectedAmountMinor,
    this.expectedMerchant,
    this.expectedType,
  });
}

OcrItem _tok(int idx, String text, double x1, double y1, double x2, double y2, {String? norm}) {
  return OcrItem(
    readingIndex: idx,
    text: text,
    textNormalized: norm ?? text,
    compositeScore: 0.95,
    confidence: 0.95,
    bbox: BoundingBox.fromRect(x1, y1, x2, y2),
  );
}

void main() {
  group('Cross-App Generalization Benchmark (Zero App-Specific Code)', () {
    final testCases = <TestCaseData>[
      // 1. Google Pay History
      TestCaseData(
        appCategory: 'gpay',
        testName: 'Google Pay Multi-transaction Feed',
        tokens: [
          _tok(1, 'Swiggy', 50, 100, 200, 130),
          _tok(2, '₹349.00', 700, 100, 820, 130),
          _tok(3, '18 Sep 2026', 50, 140, 180, 165),

          _tok(4, 'Uber India Systems', 50, 250, 320, 280),
          _tok(5, '₹185.00', 700, 250, 820, 280),
          _tok(6, '17 Sep 2026', 50, 290, 180, 315),
        ],
        expectedTransactions: 2,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 34900, expectedMerchant: 'Swiggy', expectedType: 'expense'),
          const ExpectedTx(expectedAmountMinor: 18500, expectedMerchant: 'Uber India Systems', expectedType: 'expense'),
        ],
      ),

      // 2. PhonePe Single Receipt
      TestCaseData(
        appCategory: 'phonepe',
        testName: 'PhonePe Single Receipt (Paid to Shiva)',
        tokens: [
          _tok(1, 'Payment Successful', 100, 80, 400, 120),
          _tok(2, '₹70', 350, 160, 480, 220),
          _tok(3, 'Paid to Shiva', 100, 250, 300, 280),
          _tok(4, '18 September 2026, 3:15 PM', 100, 310, 420, 340),
          _tok(5, 'Transaction ID: T260918151523456789', 100, 380, 500, 410),
        ],
        expectedTransactions: 1,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 7000, expectedMerchant: 'Shiva', expectedType: 'expense'),
        ],
      ),

      // 3. Navi Single Receipt (Hero Amount Left-Aligned Without Rupee Symbol)
      TestCaseData(
        appCategory: 'navi',
        testName: 'Navi Hero Receipt (Safoora C H)',
        tokens: [
          _tok(1, 'Payment successful', 60, 100, 350, 130),
          _tok(2, '10', 60, 170, 130, 220),
          _tok(3, 'Paid to Safoora C H', 60, 250, 320, 280),
          _tok(4, '18 Sep 2026, 11:20 AM', 60, 310, 360, 340),
          _tok(5, 'UPI Transaction ID: 004415604898', 60, 450, 450, 480),
        ],
        expectedTransactions: 1,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 1000, expectedMerchant: 'Safoora C H', expectedType: 'expense'),
        ],
      ),

      // 4. Paytm Wallet / Payment Screen
      TestCaseData(
        appCategory: 'paytm',
        testName: 'Paytm Receipt (Metro QR Ticket)',
        tokens: [
          _tok(1, 'Payment Done', 80, 100, 300, 130),
          _tok(2, '₹50.00', 80, 160, 200, 210),
          _tok(3, 'To Delhi Metro Rail Corporation', 80, 230, 450, 260),
          _tok(4, 'Order ID: 893489201934', 80, 300, 350, 330),
          _tok(5, '18-09-2026', 80, 360, 220, 390),
        ],
        expectedTransactions: 1,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 5000, expectedMerchant: 'Delhi Metro Rail Corporation', expectedType: 'expense'),
        ],
      ),

      // 5. BHIM UPI Payment
      TestCaseData(
        appCategory: 'bhim',
        testName: 'BHIM UPI Transfer Receipt',
        tokens: [
          _tok(1, 'Transaction Successful', 100, 100, 420, 130),
          _tok(2, '₹2,500', 300, 170, 450, 220),
          _tok(3, 'Beneficiary: Ramesh Verma', 100, 250, 400, 280),
          _tok(4, '18 Sep 2026', 100, 310, 240, 340),
          _tok(5, 'RRN: 426189301923', 100, 370, 350, 400),
        ],
        expectedTransactions: 1,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 250000, expectedMerchant: 'Ramesh Verma', expectedType: 'expense'),
        ],
      ),

      // 6. Bank Application Statement (HDFC/ICICI/SBI-style)
      TestCaseData(
        appCategory: 'bank_apps',
        testName: 'Bank App Account Statement',
        tokens: [
          _tok(1, '18-09-2026', 40, 120, 160, 150),
          _tok(2, 'UPI-STARBUCKS COFFEE-9923', 180, 120, 520, 150),
          _tok(3, '- ₹450.00', 650, 120, 800, 150),

          _tok(4, '17-09-2026', 40, 240, 160, 270),
          _tok(5, 'NEFT-SALARY-TECHCORP', 180, 240, 500, 270),
          _tok(6, '+ ₹65,000.00', 650, 240, 830, 270),
        ],
        expectedTransactions: 2,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 45000, expectedType: 'expense'),
          const ExpectedTx(expectedAmountMinor: 6500000, expectedType: 'income'),
        ],
      ),

      // 7. Unknown / New Payment App Layout
      TestCaseData(
        appCategory: 'unknown',
        testName: 'Completely Unknown Neo-bank Receipt',
        tokens: [
          _tok(1, 'Transfer Completed', 70, 100, 350, 130),
          _tok(2, 'LOVE YOU CHAI', 70, 160, 350, 200),
          _tok(3, '₹36', 70, 220, 160, 270),
          _tok(4, '18 September 2026', 70, 300, 320, 330),
          _tok(5, 'Txn ID: 994827163829', 70, 370, 380, 400),
        ],
        expectedTransactions: 1,
        expectedDetails: [
          const ExpectedTx(expectedAmountMinor: 3600, expectedMerchant: 'LOVE YOU CHAI', expectedType: 'expense'),
        ],
      ),
    ];

    test('Run Full Cross-App Extraction Benchmark', () {
      int totalScreenshots = testCases.length;
      int totalExpected = 0;
      int totalExtracted = 0;
      int exactAmountMatches = 0;
      int exactMerchantMatches = 0;
      int exactTypeMatches = 0;
      int falseTransactions = 0;
      int criticalFinancialErrors = 0;

      for (final tc in testCases) {
        totalExpected += tc.expectedTransactions;

        final result = SpatialLayoutEngine.process(
          items: tc.tokens,
          imgWidth: 900,
          imgHeight: 1600,
        );

        totalExtracted += result.transactions.length;

        if (result.transactions.length > tc.expectedTransactions) {
          falseTransactions += (result.transactions.length - tc.expectedTransactions);
        }

        for (int i = 0; i < tc.expectedDetails.length; i++) {
          final exp = tc.expectedDetails[i];
          if (i < result.transactions.length) {
            final act = result.transactions[i];

            // Amount Check
            if (act.amountMinorUnits == exp.expectedAmountMinor) {
              exactAmountMatches++;
            } else {
              criticalFinancialErrors++;
              // Print error detail
              print('CRITICAL FINANCIAL ERROR in ${tc.testName}: expected ${exp.expectedAmountMinor} paise, got ${act.amountMinorUnits} paise');
            }

            // Merchant Check
            if (exp.expectedMerchant != null) {
              if (act.merchantText != null &&
                  act.merchantText!.toLowerCase().contains(exp.expectedMerchant!.toLowerCase())) {
                exactMerchantMatches++;
              }
            } else {
              exactMerchantMatches++;
            }

            // Type Check
            if (exp.expectedType != null) {
              if (act.transactionType == exp.expectedType) {
                exactTypeMatches++;
              }
            } else {
              exactTypeMatches++;
            }
          }
        }
      }

      final recall = totalExpected > 0 ? (totalExtracted / totalExpected) : 0.0;
      final precision = totalExtracted > 0 ? (exactAmountMatches / totalExtracted) : 0.0;
      final amountAccuracy = totalExpected > 0 ? (exactAmountMatches / totalExpected) : 0.0;
      final merchantAccuracy = totalExpected > 0 ? (exactMerchantMatches / totalExpected) : 0.0;
      final typeAccuracy = totalExpected > 0 ? (exactTypeMatches / totalExpected) : 0.0;

      print('====================================================');
      print('CROSS-APP GENERALIZATION BENCHMARK REPORT');
      print('====================================================');
      print('Screenshots Processed:      $totalScreenshots');
      print('Transactions Expected:      $totalExpected');
      print('Transactions Extracted:     $totalExtracted');
      print('Transaction Recall:         ${(recall * 100).toStringAsFixed(1)}%');
      print('Transaction Precision:      ${(precision * 100).toStringAsFixed(1)}%');
      print('Amount Accuracy:            ${(amountAccuracy * 100).toStringAsFixed(1)}%');
      print('Merchant Accuracy:          ${(merchantAccuracy * 100).toStringAsFixed(1)}%');
      print('Type Accuracy:              ${(typeAccuracy * 100).toStringAsFixed(1)}%');
      print('False Transactions:         $falseTransactions');
      print('CRITICAL FINANCIAL ERRORS:  $criticalFinancialErrors');
      print('====================================================');

      expect(criticalFinancialErrors, 0, reason: 'CRITICAL: Financial amounts must never be corrupted!');
      expect(totalExtracted, equals(totalExpected));
      expect(amountAccuracy, equals(1.0));
      expect(falseTransactions, equals(0));
    });
  });
}
