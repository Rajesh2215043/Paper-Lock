import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
import '../utils/categories.dart';
import 'edit_document_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final int documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? document;
  bool isLoading = true;
  bool isSharing = false;
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    refreshDocument();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future refreshDocument() async {
    setState(() => isLoading = true);
    document = await DatabaseHelper.instance.readDocument(widget.documentId);
    setState(() => isLoading = false);
  }

  Future _delete() async {
    if (document != null) {
      await DatabaseHelper.instance.delete(document!.id!);
      for (final path in document!.filePaths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  void _confirmDelete() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, size: 22, color: fg),
            const SizedBox(width: 8),
            Text('Delete?', style: TextStyle(fontSize: 18, color: fg)),
          ],
        ),
        content: Text('This action cannot be undone.',
            style: TextStyle(color: fg.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: fg.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _delete();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('Delete', style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }

  /// Convert images to PDF, or share files directly
  Future<void> _shareDocument() async {
    if (document == null || document!.filePaths.isEmpty) return;

    setState(() => isSharing = true);

    try {
      final isImage = document!.type.startsWith('image/');

      if (isImage) {
        // Convert all images to a single PDF
        final pdf = pw.Document();

        for (final path in document!.filePaths) {
          final file = File(path);
          if (!await file.exists()) continue;

          final bytes = await file.readAsBytes();
          final image = pw.MemoryImage(bytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              build: (context) {
                return pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }

        // Save PDF to temp
        final tempDir = await getTemporaryDirectory();
        final pdfName = document!.title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
        final pdfFile = File('${tempDir.path}/$pdfName.pdf');
        await pdfFile.writeAsBytes(await pdf.save());

        // Share the PDF
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(pdfFile.path, mimeType: 'application/pdf')],
            subject: document!.title,
          ),
        );
      } else {
        // Share non-image files directly
        final files = document!.filePaths
            .where((p) => File(p).existsSync())
            .map((p) => XFile(p))
            .toList();

        await SharePlus.instance.share(
          ShareParams(
            files: files,
            subject: document!.title,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withOpacity(0.5);
    final chipBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade50;
    final borderColor = fg.withOpacity(0.12);

    if (isLoading) {
      return Scaffold(
          body: Center(child: CircularProgressIndicator(color: fg, strokeWidth: 2)));
    }
    if (document == null) {
      return Scaffold(body: Center(child: Text('Not found', style: TextStyle(color: fg))));
    }

    final isImage = document!.type.startsWith('image/');
    final pages = document!.filePaths.length;

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Share button
          isSharing
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _shareDocument,
                  tooltip: 'Share',
                ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final edited = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditDocumentScreen(document: document!),
                ),
              );
              if (edited == true) refreshDocument();
            },
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image viewer ──
            if (isImage && document!.filePaths.isNotEmpty) ...[
              SizedBox(
                height: 340,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => _openViewer(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(document!.filePaths[i]),
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Center(
                                child: Icon(Icons.broken_image_outlined,
                                    size: 48, color: muted)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (pages > 1)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(pages, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: i == _currentPage ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _currentPage ? fg : fg.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ] else ...[
              // Non-image files
              Container(
                height: 200,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getFileIcon(document!.type), size: 56, color: muted),
                      const SizedBox(height: 8),
                      Text(
                        document!.type.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Info ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(document!.title,
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(height: 12),

                  // Meta row
                  Row(
                    children: [
                      Icon(AppCategories.getIcon(document!.category),
                          size: 16, color: muted),
                      const SizedBox(width: 6),
                      Text(document!.category,
                          style: TextStyle(fontSize: 13, color: muted)),
                      const SizedBox(width: 16),
                      Icon(Icons.calendar_today_outlined, size: 14, color: muted),
                      const SizedBox(width: 4),
                      Text(document!.dateAdded.substring(0, 10),
                          style: TextStyle(fontSize: 13, color: muted)),
                      if (pages > 1) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.layers_outlined, size: 14, color: muted),
                        const SizedBox(width: 4),
                        Text('$pages pages',
                            style: TextStyle(fontSize: 13, color: muted)),
                      ],
                    ],
                  ),

                  Divider(height: 32, color: borderColor),

                  // Description
                  Text(document!.description,
                      style: TextStyle(
                          fontSize: 15, height: 1.6, color: fg.withOpacity(0.7))),

                  const SizedBox(height: 24),

                  // Share hint
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isImage
                                ? 'Tap share to send as PDF'
                                : 'Tap share to send file',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullViewer(paths: document!.filePaths, initial: index),
      ),
    );
  }

  IconData _getFileIcon(String type) {
    final t = type.toLowerCase();
    if (t == 'pdf') return Icons.picture_as_pdf_outlined;
    if (t == 'xlsx' || t == 'xls') return Icons.table_chart_outlined;
    if (t == 'doc' || t == 'docx') return Icons.article_outlined;
    if (t == 'ppt' || t == 'pptx') return Icons.slideshow_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _FullViewer extends StatefulWidget {
  final List<String> paths;
  final int initial;
  const _FullViewer({required this.paths, required this.initial});

  @override
  State<_FullViewer> createState() => _FullViewerState();
}

class _FullViewerState extends State<_FullViewer> {
  late PageController _c;
  late int _i;

  @override
  void initState() {
    super.initState();
    _i = widget.initial;
    _c = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_i + 1} / ${widget.paths.length}',
            style: const TextStyle(fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(File(widget.paths[i]), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
