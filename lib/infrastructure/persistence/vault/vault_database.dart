import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:injectable/injectable.dart';

/// The "Safe" - A local SQLite database for storing encrypted data.
@lazySingleton
class VaultDatabase {

  VaultDatabase();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('secure_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table for generic secure documents (JSON blobs)
    await db.execute('''
      CREATE TABLE vault_documents (
        id TEXT PRIMARY KEY,
        collection TEXT NOT NULL,
        encrypted_data TEXT NOT NULL,
        iv TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('CREATE INDEX idx_collection ON vault_documents(collection)');
  }

  Future<void> writeDocument(String collection, String id, String encryptedData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'vault_documents',
      {
        'id': id,
        'collection': collection,
        'encrypted_data': encryptedData,
        'iv': '', // IV is embedded in data in our SecurityService implementation, so we can leave this empty or remove column
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readDocument(String collection, String id) async {
    final db = await database;
    final maps = await db.query(
      'vault_documents',
      columns: ['encrypted_data'],
      where: 'id = ? AND collection = ?',
      whereArgs: [id, collection],
    );

    if (maps.isNotEmpty) {
      return maps.first['encrypted_data'] as String;
    }
    return null;
  }

  Future<List<String>> readCollection(String collection) async {
    final db = await database;
    final maps = await db.query(
      'vault_documents',
      columns: ['encrypted_data'],
      where: 'collection = ?',
      whereArgs: [collection],
    );

    return maps.map((e) => e['encrypted_data'] as String).toList();
  }
  
  Future<void> deleteDocument(String collection, String id) async {
    final db = await database;
    await db.delete(
      'vault_documents', 
      where: 'id = ? AND collection = ?',
      whereArgs: [id, collection]
    );
  }
}
