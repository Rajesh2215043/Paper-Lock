import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
import '../utils/categories.dart';
import '../utils/string_extensions.dart';

class EditDocumentScreen extends StatefulWidget {
  final Document document;
  const EditDocumentScreen({super.key, required this.document});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late List<File> _selectedFiles;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _descriptionController = TextEditingController(
      text: widget.document.description,
    );
    _selectedCategory = widget.document.category;
    _selectedFiles = widget.document.filePaths
        .map((path) => File(path))
        .toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) return;
      setState(() {
        _selectedFiles.addAll(images.map((img) => File(img.path)));
      });
      return;
    }

    final image = await _picker.pickImage(source: source);
    if (image == null) return;
    setState(() {
      _selectedFiles.add(File(image.path));
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    setState(() {
      for (final f in result.files) {
        if (f.path != null) {
          _selectedFiles.add(File(f.path!));
        }
      }
    });
  }

  String _detectTypeFromPath(String path) {
    final ext = p.extension(path).replaceAll('.', '').toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return 'image/$ext';
    }
    return ext.isEmpty ? 'unknown' : ext;
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one file')));
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final originalPaths = widget.document.filePaths.toSet();
    final updatedPaths = <String>[];

    for (final file in _selectedFiles) {
      if (originalPaths.contains(file.path)) {
        updatedPaths.add(file.path);
        continue;
      }

      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final copied = await file.copy('${appDir.path}/$name');
      updatedPaths.add(copied.path);
    }

    final keptOriginal = updatedPaths.where(originalPaths.contains).toSet();
    final removedOriginal = originalPaths.difference(keptOriginal);

    // Remove deleted attachments from app storage when possible.
    for (final removedPath in removedOriginal) {
      final removedFile = File(removedPath);
      if (await removedFile.exists()) {
        try {
          await removedFile.delete();
        } catch (_) {
          // Ignore delete failures to avoid blocking save.
        }
      }
    }

    final latestType = updatedPaths.isNotEmpty
        ? _detectTypeFromPath(updatedPaths.last)
        : 'unknown';

    final updated = Document(
      id: widget.document.id,
      title: _titleController.text.toTitleCase(),
      description: _descriptionController.text,
      filePaths: updatedPaths,
      type: latestType,
      category: _selectedCategory,
      dateAdded: widget.document.dateAdded,
    );

    await DatabaseHelper.instance.update(updated);
    if (mounted) Navigator.of(context).pop(true); // return true = edited
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withValues(alpha: 0.5);
    final chipBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade100;
    final borderColor = fg.withValues(alpha: 0.12);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              decoration: InputDecoration(
                hintText: 'Document title',
                hintStyle: TextStyle(color: muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),

            // Description
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(fontSize: 14, color: muted),
              decoration: InputDecoration(
                hintText: 'Description...',
                hintStyle: TextStyle(color: fg.withValues(alpha: 0.3)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              maxLines: 4,
            ),

            Divider(height: 32, color: borderColor),

            // Category
            Row(
              children: [
                Icon(Icons.label_outline, size: 20, color: fg),
                const SizedBox(width: 10),
                Text(
                  'Category',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: fg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppCategories.categories.map((c) {
                final sel = _selectedCategory == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? fg : chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppCategories.getIcon(c),
                          size: 16,
                          color: sel ? theme.scaffoldBackgroundColor : muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sel ? theme.scaffoldBackgroundColor : fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            Divider(height: 32, color: borderColor),

            Row(
              children: [
                Icon(Icons.attach_file, size: 20, color: fg),
                const SizedBox(width: 10),
                Text(
                  '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: fg,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.camera_alt_outlined, color: fg),
                  onPressed: () => _pickImage(ImageSource.camera),
                  tooltip: 'Camera',
                ),
                IconButton(
                  icon: Icon(Icons.photo_library_outlined, color: fg),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  tooltip: 'Gallery',
                ),
                IconButton(
                  icon: Icon(Icons.file_upload_outlined, color: fg),
                  onPressed: _pickFile,
                  tooltip: 'File',
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedFiles.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final file = _selectedFiles[i];
                    final ext = p
                        .extension(file.path)
                        .replaceAll('.', '')
                        .toLowerCase();
                    final isImage = [
                      'jpg',
                      'jpeg',
                      'png',
                      'gif',
                      'webp',
                    ].contains(ext);

                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: isImage
                                ? Image.file(file, fit: BoxFit.cover)
                                : Center(
                                    child: Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 28,
                                      color: muted,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFiles.removeAt(i);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: fg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: theme.scaffoldBackgroundColor,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
