import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Future<Database> openDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'basura_ceti.db');

    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE categorias(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE registros(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha TEXT NOT NULL,
          categoria_id INTEGER NOT NULL,
          volumen REAL,
          foto_path TEXT,
          FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        )
      ''');
    });
  }
}
