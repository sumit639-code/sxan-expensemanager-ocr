import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/pending_import.dart';

/// Repository responsible for persisting PendingImports locally on disk.
///
/// Ensures pending transactions survive app backgrounding, termination, and process recreation.
class PendingImportRepository {
  File? _storageFile;
  final StreamController<List<PendingImport>> _streamController =
      StreamController<List<PendingImport>>.broadcast();

  PendingImportRepository({File? storageFile}) : _storageFile = storageFile;

  Future<File> _getFile() async {
    if (_storageFile != null) {
      if (!await _storageFile!.exists()) {
        await _storageFile!.writeAsString('[]');
      }
      return _storageFile!;
    }
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/pending_imports.json');
    if (!await file.exists()) {
      await file.writeAsString('[]');
    }
    _storageFile = file;
    return file;
  }

  /// Stream of all active pending imports (excludes completed and discarded).
  Stream<List<PendingImport>> watchActive() {
    // Immediately emit current data
    getAllActive().then((list) {
      if (!_streamController.isClosed) {
        _streamController.add(list);
      }
    });
    return _streamController.stream;
  }

  /// Load all stored PendingImports.
  Future<List<PendingImport>> getAll() async {
    try {
      final file = await _getFile();
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content) as List<dynamic>;
      final list = decoded
          .map((e) => PendingImport.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Error reading pending imports: $e');
      return [];
    }
  }

  /// Load only active imports (processing, readyForReview, failed).
  Future<List<PendingImport>> getAllActive() async {
    final all = await getAll();
    return all
        .where((item) =>
            item.status != PendingImportStatus.completed &&
            item.status != PendingImportStatus.discarded)
        .toList();
  }

  /// Find a specific PendingImport by its ID.
  Future<PendingImport?> getById(String id) async {
    final all = await getAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Save or update a PendingImport item.
  Future<void> save(PendingImport item) async {
    final all = await getAll();
    final index = all.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      all[index] = item;
    } else {
      all.insert(0, item);
    }

    await _writeList(all);
  }

  /// Delete a PendingImport by ID and clean up any associated temporary images.
  Future<void> delete(String id, {bool cleanupImages = true}) async {
    final all = await getAll();
    final item = all.where((e) => e.id == id).firstOrNull;
    if (item != null && cleanupImages) {
      await cleanupImageFiles(item.imagePaths);
    }

    all.removeWhere((e) => e.id == id);
    await _writeList(all);
  }

  /// Mark an import as completed and clean up temporary images.
  Future<void> markCompleted(String id) async {
    final item = await getById(id);
    if (item != null) {
      await save(item.copyWith(status: PendingImportStatus.completed));
      await cleanupImageFiles(item.imagePaths);
    }
  }

  /// Mark an import as discarded and clean up temporary images.
  Future<void> markDiscarded(String id) async {
    final item = await getById(id);
    if (item != null) {
      await save(item.copyWith(status: PendingImportStatus.discarded));
      await cleanupImageFiles(item.imagePaths);
    }
  }

  /// Safely remove cached image files from private storage.
  Future<void> cleanupImageFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Cleaned up shared image: $path');
        }
      } catch (e) {
        debugPrint('Failed to delete temporary image $path: $e');
      }
    }
  }

  Future<void> _writeList(List<PendingImport> list) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
      await file.writeAsString(encoded);

      final active = list
          .where((item) =>
              item.status != PendingImportStatus.completed &&
              item.status != PendingImportStatus.discarded)
          .toList();
      if (!_streamController.isClosed) {
        _streamController.add(active);
      }
    } catch (e) {
      debugPrint('Error writing pending imports: $e');
    }
  }

  void dispose() {
    _streamController.close();
  }
}
