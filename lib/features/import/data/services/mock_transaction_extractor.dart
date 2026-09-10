import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../../../shared/enums/transaction_enums.dart';
import '../../domain/entities/extracted_transaction.dart';
import '../../domain/entities/extraction_result.dart';
import '../../domain/services/transaction_extractor.dart';

/// ⚠️ DEVELOPMENT ONLY: Mock implementation of [TransactionExtractor].
///
/// Simulates extraction of transactions from payment history screenshots (e.g. UPI, GPay, Paytm, PhonePe, Credit Cards).
/// Returns realistic transactions with varied confidence scores and supports progress callbacks.
///
/// NOTE: This does NOT run any actual OCR or AI model. It is designed to be seamlessly
/// replaced by OnDeviceTransactionExtractor or VisionTransactionExtractor in a future phase.
class MockTransactionExtractor implements TransactionExtractor {
  final Duration stepDelay;
  final bool simulatePartialFailure;
  final Uuid _uuid;

  MockTransactionExtractor({
    this.stepDelay = const Duration(milliseconds: 350),
    this.simulatePartialFailure = false,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<ExtractionResult> extractTransactions(
    List<String> imagePaths, {
    void Function(String step, double progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      return const ExtractionResult(
        transactions: [],
        successfulImages: [],
        errors: ['No screenshot images provided'],
      );
    }

    // Step 1: Reading screenshots
    onProgress?.call('Reading screenshots...', 0.20);
    if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);

    // Step 2: Finding transactions
    onProgress?.call('Finding transactions...', 0.40);
    if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);

    // Step 3: Reading dates
    onProgress?.call('Reading dates...', 0.60);
    if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);

    // Step 4: Detecting amounts
    onProgress?.call('Detecting amounts...', 0.75);
    if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);

    // Step 5: Categorizing transactions
    onProgress?.call('Categorizing transactions...', 0.85);
    if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);

    final successfulImages = <String>[];
    final failedImages = <String>[];
    final errors = <String>[];
    final extracted = <ExtractedTransaction>[];

    final now = DateTime.now();

    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      final imageName = _shortName(path);

      // Simulate partial failure for the 3rd image if specifically flagged
      if (simulatePartialFailure && i == 2) {
        failedImages.add(path);
        errors.add('$imageName could not be read or is too blurry.');
        continue;
      }

      successfulImages.add(path);

      // Distribute realistic mock transactions across images
      if (i == 0) {
        extracted.addAll([
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Swiggy',
            title: 'Swiggy Food Delivery',
            amount: 42000, // ₹420.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'food',
            date: now.subtract(const Duration(days: 1)),
            confidence: 0.98,
            sourceReference: imageName,
            rawText: 'Paid to Swiggy UPI Ref 3241098 ₹420.00 SUCCESS',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Uber',
            title: 'Uber Ride',
            amount: 28000, // ₹280.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'transport',
            date: now.subtract(const Duration(days: 2)),
            confidence: 0.95,
            sourceReference: imageName,
            rawText: 'Uber India Systems Pvt Ltd ₹280.00 Debited from A/c',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Amazon',
            title: 'Amazon Marketplace',
            amount: 129900, // ₹1,299.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'shopping',
            date: now.subtract(const Duration(days: 2)),
            confidence: 0.92,
            sourceReference: imageName,
            rawText: 'Amazon Pay Balance debit ₹1,299 Order #402-918237',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Local Vendor',
            title: 'UPI Transfer',
            amount: 15000, // ₹150.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: null, // Incomplete category
            date: now.subtract(const Duration(days: 3)),
            confidence: 0.54, // Low confidence -> "Needs review"
            sourceReference: imageName,
            rawText: 'Transfer to 9876543210@paytm ₹150.00',
          ),
        ]);
      } else if (i == 1) {
        extracted.addAll([
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Zomato',
            title: 'Zomato Order',
            amount: 65000, // ₹650.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'food',
            date: now.subtract(const Duration(days: 1)),
            confidence: 0.96,
            sourceReference: imageName,
            rawText: 'Zomato Media Pvt Ltd Paid ₹650.00 via GPay',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Blinkit',
            title: 'Blinkit Groceries',
            amount: 54000, // ₹540.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'groceries',
            date: now.subtract(const Duration(days: 3)),
            confidence: 0.88,
            sourceReference: imageName,
            rawText: 'Blinkit Commerce ₹540.00 Debited',
          ),
          // Intra-batch duplicate to test requirement 17 (identical to Uber from image 0):
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Uber',
            title: 'Uber Ride',
            amount: 28000, // ₹280.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'transport',
            date: now.subtract(const Duration(days: 2)),
            confidence: 0.94,
            sourceReference: imageName,
            rawText: 'Uber India ₹280.00 Duplicate Receipt',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Freelance Client',
            title: 'Project Milestone Payout',
            amount: 1500000, // ₹15,000.00
            currency: 'INR',
            type: TransactionType.income,
            categoryId: 'income',
            date: now.subtract(const Duration(days: 4)),
            confidence: 0.91,
            sourceReference: imageName,
            rawText: 'IMPS Credit from ACME CORP Ref #8271 ₹15,000.00',
          ),
        ]);
      } else {
        // Additional images generate coffee/subscriptions
        extracted.addAll([
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Starbucks Coffee',
            title: 'Starbucks Coffee',
            amount: 35000, // ₹350.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'food',
            date: now.subtract(Duration(days: i + 1)),
            confidence: 0.97,
            sourceReference: imageName,
            rawText: 'Tata Starbucks Pvt Ltd ₹350.00',
          ),
          ExtractedTransaction(
            id: _uuid.v4(),
            merchant: 'Netflix',
            title: 'Netflix Subscription',
            amount: 64900, // ₹649.00
            currency: 'INR',
            type: TransactionType.expense,
            categoryId: 'entertainment',
            date: now.subtract(Duration(days: i + 2)),
            confidence: 0.89,
            sourceReference: imageName,
            rawText: 'Netflix Entertainment ₹649.00 Auto-debit',
          ),
        ]);
      }
    }

    return ExtractionResult(
      transactions: extracted,
      successfulImages: successfulImages,
      failedImages: failedImages,
      errors: errors,
    );
  }

  static String _shortName(String path) {
    if (path.isEmpty) return 'Screenshot';
    final normalized = path.replaceAll(r'\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : 'Screenshot';
  }
}
