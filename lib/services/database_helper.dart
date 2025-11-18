import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Future<Database> openDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'basura_ceti.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categorias(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            medidas TEXT,
            sincronizado INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE registros(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fecha TEXT NOT NULL,
            categoria_id INTEGER NOT NULL,
            volumen REAL,
            unidad TEXT,
            foto_path TEXT,
            sincronizado INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (categoria_id) REFERENCES categorias(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE categorias ADD COLUMN sincronizado INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE registros ADD COLUMN sincronizado INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE categorias ADD COLUMN medidas TEXT',
          );
          await db.execute(
            'ALTER TABLE registros ADD COLUMN unidad TEXT',
          );
        }
      },
    );
  }
}
