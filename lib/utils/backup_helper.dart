import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../models/document.dart';

class BackupHelper {
  /// Export all documents + files into a ZIP
  static Future<File> exportBackup() async {
    final docs = await DatabaseHelper.instance.readAllDocuments();
    final archive = Archive();

    // 1. Add metadata JSON
    final metaList = docs.map((d) => {
      'id': d.id,
      'title': d.title,
      'description': d.description,
      'filePaths': d.filePaths.map((fp) => p.basename(fp)).toList(),
      'type': d.type,
      'category': d.category,
      'dateAdded': d.dateAdded,
    }).toList();

    final jsonBytes = utf8.encode(jsonEncode(metaList));
    archive.addFile(ArchiveFile('backup_meta.json', jsonBytes.length, jsonBytes));

    // 2. Add each document file
    for (final doc in docs) {
      for (final filePath in doc.filePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = p.basename(filePath);
          archive.addFile(ArchiveFile('files/$fileName', bytes.length, bytes));
        }
      }
    }

    // 3. Encode to ZIP
    final zipData = ZipEncoder().encode(archive);

    // 4. Write to temp directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File('${tempDir.path}/doc_wallet_backup_$timestamp.zip');
    await zipFile.writeAsBytes(zipData);

    return zipFile;
  }

  /// Import documents from a ZIP backup
  static Future<int> importBackup(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Find and parse metadata
    final metaFile = archive.findFile('backup_meta.json');
    if (metaFile == null) throw Exception('Invalid backup: no metadata found');

    final metaContent = utf8.decode(metaFile.content as List<int>);
    final List<dynamic> metaList = jsonDecode(metaContent);

    // 2. Get app documents directory for saving files
    final appDir = await getApplicationDocumentsDirectory();
    int importedCount = 0;

    // 3. Extract files and create DB entries
    for (final meta in metaList) {
      final List<String> originalFileNames = List<String>.from(meta['filePaths'] ?? []);
      final List<String> savedPaths = [];

      for (final fileName in originalFileNames) {
        final archiveFile = archive.findFile('files/$fileName');
        if (archiveFile != null) {
          final newPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
          final outFile = File(newPath);
          await outFile.writeAsBytes(archiveFile.content as List<int>);
          savedPaths.add(newPath);
          // Small delay to ensure unique timestamps
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }

      if (savedPaths.isNotEmpty) {
        final doc = Document(
          title: meta['title'] ?? 'Untitled',
          description: meta['description'] ?? '',
          filePaths: savedPaths,
          type: meta['type'] ?? 'unknown',
          category: meta['category'] ?? 'Other',
          dateAdded: meta['dateAdded'] ?? DateTime.now().toIso8601String(),
        );
        await DatabaseHelper.instance.create(doc);
        importedCount++;
      }
    }

    return importedCount;
  }
}
