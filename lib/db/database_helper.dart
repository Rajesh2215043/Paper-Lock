import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('documents.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE documents (
  id $idType,
  title $textType,
  description $textType,
  filePath $textType,
  type $textType,
  category $textType DEFAULT 'Other',
  dateAdded $textType
  )
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN category TEXT NOT NULL DEFAULT 'Other'",
      );
    }
  }

  Future<Document> create(Document document) async {
    final db = await instance.database;
    final id = await db.insert('documents', document.toMap());
    return Document(
      id: id,
      title: document.title,
      description: document.description,
      filePaths: document.filePaths,
      type: document.type,
      category: document.category,
      dateAdded: document.dateAdded,
    );
  }

  Future<Document?> readDocument(int id) async {
    final db = await instance.database;
    final maps = await db.query('documents', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Document.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Document>> readAllDocuments() async {
    final db = await instance.database;
    const orderBy = 'id DESC';
    final result = await db.query('documents', orderBy: orderBy);
    return result.map((json) => Document.fromMap(json)).toList();
  }

  Future<List<Document>> readDocumentsByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'documents',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'id DESC',
    );
    return result.map((json) => Document.fromMap(json)).toList();
  }

  Future<int> update(Document document) async {
    final db = await instance.database;
    return db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
