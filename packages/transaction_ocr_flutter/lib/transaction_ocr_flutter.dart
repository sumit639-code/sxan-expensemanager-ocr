// Core Configuration & Exceptions
export 'src/core/configuration/ocr_config.dart';
export 'src/core/exceptions/ocr_exceptions.dart';

// Domain Models
export 'src/core/models/bounding_box.dart';
export 'src/core/models/amount_classification.dart';
export 'src/core/models/ocr_item.dart';
export 'src/core/models/semantic_role.dart';
export 'src/core/models/extracted_transaction.dart';
export 'src/core/models/ocr_result.dart';

// Engines
export 'src/engine/ocr_engine.dart';
export 'src/engine/local_ocr_engine.dart';
export 'src/engine/remote_ocr_engine.dart';

// High-level Service
export 'src/services/transaction_ocr_service.dart';

// Parsing & Post-processing (available for custom pipelines)
export 'src/parsing/amount_classifier.dart';
export 'src/parsing/transaction_grouper.dart';
export 'src/parsing/universal_date_detector.dart';
export 'src/parsing/generic_semantic_classifier.dart';
export 'src/parsing/merchant_entity_scorer.dart';
export 'src/parsing/spatial_layout_engine.dart';
export 'src/postprocessing/candidate_consolidator.dart';
export 'src/postprocessing/ctc_decoder.dart';
export 'src/postprocessing/db_postprocessor.dart';
export 'src/preprocessing/image_preprocessor.dart';
