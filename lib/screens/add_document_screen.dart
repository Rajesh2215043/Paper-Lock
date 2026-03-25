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

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<File> _selectedFiles = [];
  String? _documentType;
  String _selectedCategory = AppCategories.categories.first;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images.map((img) => File(img.path)));
          _documentType = 'image/${p.extension(images.first.path).replaceAll('.', '')}';
        });
      }
    } else {
      final image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedFiles.add(File(image.path));
          _documentType = 'image/${p.extension(image.path).replaceAll('.', '')}';
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null) _selectedFiles.add(File(f.path!));
        }
        if (_selectedFiles.isNotEmpty) {
          String ext = p.extension(_selectedFiles.last.path).replaceAll('.', '').toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
            _documentType = 'image/$ext';
          } else {
            _documentType = ext;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate() && _selectedFiles.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final List<String> saved = [];
      for (final f in _selectedFiles) {
        final name = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}';
        final s = await f.copy('${appDir.path}/$name');
        saved.add(s.path);
      }
      await DatabaseHelper.instance.create(Document(
        title: _titleController.text.toTitleCase(),
        description: _descriptionController.text,
        filePaths: saved,
        type: _documentType ?? 'unknown',
        category: _selectedCategory,
        dateAdded: DateTime.now().toIso8601String(),
      ));
      if (mounted) Navigator.of(context).pop();
    } else if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withOpacity(0.5);
    final chipBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade100;
    final borderColor = fg.withOpacity(0.12);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg),
                decoration: InputDecoration(
                  hintText: 'Document title',
                  hintStyle: TextStyle(color: muted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              TextFormField(
                controller: _descriptionController,
                style: TextStyle(fontSize: 14, color: muted),
                decoration: InputDecoration(
                  hintText: 'Add a description...',
                  hintStyle: TextStyle(color: fg.withOpacity(0.3)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                maxLines: 2,
              ),

              Divider(height: 32, color: borderColor),

              // Category
              Row(
                children: [
                  Icon(Icons.label_outline, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Text('Category',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: fg)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? fg : chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppCategories.getIcon(c),
                              size: 16,
                              color: sel ? theme.scaffoldBackgroundColor : muted),
                          const SizedBox(width: 6),
                          Text(c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: sel ? theme.scaffoldBackgroundColor : fg,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              Divider(height: 32, color: borderColor),

              // Attach
              Row(
                children: [
                  Icon(Icons.attach_file, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Text('${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'}',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: fg)),
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

              // Thumbnails
              if (_selectedFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedFiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _selectedFiles[i];
                      final ext = p.extension(f.path).replaceAll('.', '').toLowerCase();
                      final isImg = ['jpg', 'jpeg', 'png'].contains(ext);
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
                              child: isImg
                                  ? Image.file(f, fit: BoxFit.cover)
                                  : Center(
                                      child: Icon(Icons.insert_drive_file_outlined,
                                          size: 28, color: muted)),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedFiles.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: fg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    color: theme.scaffoldBackgroundColor, size: 14),
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
      ),
    );
  }
}
