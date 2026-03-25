class Document {
  final int? id;
  final String title;
  final String description;
  final List<String> filePaths; // Multiple images/files
  final String type;
  final String category;
  final String dateAdded;

  Document({
    this.id,
    required this.title,
    required this.description,
    required this.filePaths,
    required this.type,
    required this.category,
    required this.dateAdded,
  });

  /// Store as pipe-separated string in DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'filePath': filePaths.join('|'),
      'type': type,
      'category': category,
      'dateAdded': dateAdded,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    final raw = map['filePath'] as String? ?? '';
    return Document(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      filePaths: raw.split('|').where((p) => p.isNotEmpty).toList(),
      type: map['type'],
      category: map['category'] ?? 'Other',
      dateAdded: map['dateAdded'],
    );
  }
}
