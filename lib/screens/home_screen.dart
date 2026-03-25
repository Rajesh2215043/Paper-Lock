import 'dart:io';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/document.dart';
import '../utils/categories.dart';
import '../utils/theme_provider.dart';
import 'add_document_screen.dart';
import 'document_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const HomeScreen({super.key, required this.themeProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Document> allDocuments;
  late List<Document> filteredDocuments;
  bool isLoading = true;
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    refreshDocuments();
  }

  Future refreshDocuments() async {
    setState(() => isLoading = true);
    allDocuments = await DatabaseHelper.instance.readAllDocuments();
    _applyFilter();
    setState(() => isLoading = false);
  }

  void _applyFilter() {
    if (selectedCategory == 'All') {
      filteredDocuments = List.from(allDocuments);
    } else {
      filteredDocuments =
          allDocuments.where((d) => d.category == selectedCategory).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withOpacity(0.5);
    final cardBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.white;
    final chipBg = theme.brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade100;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.folder_special_outlined, size: 28, color: fg),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search_rounded, size: 26, color: fg),
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: _DocSearch(allDocuments),
                      ).then((_) => refreshDocuments());
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, size: 24, color: fg),
                    onPressed: () async {
                      final imported = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(themeProvider: widget.themeProvider),
                        ),
                      );
                      if (imported == true) refreshDocuments();
                    },
                  ),
                ],
              ),
            ),

            // ── Category Row ──
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _catIcon('All', Icons.grid_view_rounded, fg, chipBg),
                    ...AppCategories.categories
                        .map((c) => _catIcon(c, AppCategories.getIcon(c), fg, chipBg)),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: fg.withOpacity(0.1)),

            // ── Body ──
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: fg, strokeWidth: 2))
                  : filteredDocuments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 56, color: muted),
                              const SizedBox(height: 12),
                              Text('No documents',
                                  style: TextStyle(color: muted, fontSize: 14)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: filteredDocuments.length,
                          itemBuilder: (context, i) =>
                              _docCard(filteredDocuments[i], fg, muted, cardBg, chipBg),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddDocumentScreen()),
          );
          refreshDocuments();
        },
        backgroundColor: fg,
        foregroundColor: theme.scaffoldBackgroundColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _catIcon(String label, IconData icon, Color fg, Color chipBg) {
    final sel = selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() {
        selectedCategory = label;
        _applyFilter();
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sel ? fg : chipBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22,
                  color: sel ? chipBg : fg.withOpacity(0.5)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? fg : fg.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docCard(Document doc, Color fg, Color muted, Color cardBg, Color chipBg) {
    final hasImg = doc.filePaths.isNotEmpty && doc.type.startsWith('image/');
    final pages = doc.filePaths.length;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(documentId: doc.id!)),
        );
        refreshDocuments();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: hasImg
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Image.file(
                              File(doc.filePaths.first),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (c, e, s) => Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 32, color: muted)),
                            ),
                          )
                        : Center(
                            child: Icon(AppCategories.getIcon(doc.category),
                                size: 36, color: muted),
                          ),
                  ),
                  if (pages > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_outlined,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('$pages',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13, color: fg)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(AppCategories.getIcon(doc.category),
                          size: 14, color: muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(doc.category,
                            style: TextStyle(fontSize: 11, color: muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search ──
class _DocSearch extends SearchDelegate<String> {
  final List<Document> docs;
  _DocSearch(this.docs);

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final r = docs
        .where((d) =>
            d.title.toLowerCase().contains(query.toLowerCase()) ||
            d.category.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: r.length,
      itemBuilder: (context, i) {
        final d = r[i];
        return ListTile(
          leading: Icon(AppCategories.getIcon(d.category), color: fg.withOpacity(0.5)),
          title: Text(d.title,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: fg)),
          trailing: Icon(Icons.chevron_right, size: 18, color: fg.withOpacity(0.4)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => DocumentDetailScreen(documentId: d.id!)),
          ),
        );
      },
    );
  }
}
