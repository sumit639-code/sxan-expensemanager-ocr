import '../entities/extracted_transaction.dart';
import '../entities/ocr_document.dart';

/// Abstract domain interface for converting a normalized [OcrDocument]
/// into candidate [ExtractedTransaction] entities.
///
/// Completely independent of vendor OCR libraries or file systems.
abstract class TransactionParser {
  /// Parses the given normalized [document] and returns identified transaction candidates.
  List<ExtractedTransaction> parse(OcrDocument document);
}
