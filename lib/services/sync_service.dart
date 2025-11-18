import 'dart:io';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'firebase_service.dart';
import 'cloudinary_service.dart';

class SyncService {
  /// 🔼 Sincroniza categorías y registros locales PENDIENTES con Firebase.
  static Future<void> sincronizar() async {
    final db = await DatabaseHelper.openDB();

    // 🔹 Sincronizar categorías no sincronizadas
    final categoriasPendientes = await db.query(
      'categorias',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );

    for (var c in categoriasPendientes) {
      final idLocal = c['id'] as int;
      final nombre = c['nombre'] as String;
      final medidas = c['medidas'] as String?;

      await FirebaseService.subirCategoria(
        idLocal,
        nombre,
        medidas: medidas,
      );

      await db.update(
        'categorias',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [idLocal],
      );
    }

    // 🔹 Sincronizar registros no sincronizados
    final registrosPendientes = await db.rawQuery('''
      SELECT 
        r.id,
        r.fecha,
        r.categoria_id,
        r.volumen,
        r.unidad,
        r.foto_path,
        c.nombre AS categoria_nombre
      FROM registros r
      INNER JOIN categorias c ON r.categoria_id = c.id
      WHERE r.sincronizado = 0
    ''');

    for (var r in registrosPendientes) {
      final idLocal = r['id'] as int;
      final fecha = r['fecha'] as String;
      final categoriaId = r['categoria_id'] as int;
      final categoriaNombre = r['categoria_nombre'] as String? ?? '';
      final cantidad = (r['volumen'] as num?)?.toDouble();
      final unidad = (r['unidad'] as String?) ?? '';

      String? urlFoto;
      final fotoPath = r['foto_path'] as String?;
      if (fotoPath != null && fotoPath.isNotEmpty) {
        urlFoto = await subirFotoCloudinary(fotoPath);
      }

      await FirebaseService.subirRegistro(
        idLocal: idLocal,
        fecha: fecha,
        categoriaId: categoriaId,
        categoriaNombre: categoriaNombre,
        cantidad: cantidad,
        unidad: unidad,
        fotoUrl: urlFoto,
      );

      await db.update(
        'registros',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [idLocal],
      );
    }
  }

  /// 🔽 Sincroniza categorías desde la nube HACIA SQLite
  ///
  /// - No duplica categorías: compara por nombre.
  /// - Si una categoría local no tiene medidas, pero la remota sí → las actualiza.
  /// - Las que vienen de la nube se marcan como `sincronizado = 1`.
  static Future<void> sincronizarCategoriasDesdeNube() async {
    final db = await DatabaseHelper.openDB();

    try {
      final categoriasRemotas = await FirebaseService.obtenerCategorias();

      for (final cat in categoriasRemotas) {
        final nombre = (cat['nombre'] ?? '') as String;
        final medidas = (cat['medidas'] ?? '') as String;

        if (nombre.trim().isEmpty) continue;

        final existentes = await db.query(
          'categorias',
          where: 'nombre = ?',
          whereArgs: [nombre],
          limit: 1,
        );

        if (existentes.isEmpty) {
          // Categoria nueva para este dispositivo
          await db.insert('categorias', {
            'nombre': nombre,
            'medidas': medidas.trim(),
            'sincronizado': 1, // ya está en nube
          });
        } else {
          // Ya existe localmente: actualizamos medidas si vienen vacías o distintas
          final local = existentes.first;
          final localMedidas = (local['medidas'] ?? '') as String;

          if (localMedidas.trim().isEmpty &&
              medidas.trim().isNotEmpty) {
            await db.update(
              'categorias',
              {
                'medidas': medidas.trim(),
                'sincronizado': 1,
              },
              where: 'id = ?',
              whereArgs: [local['id']],
            );
          }
        }
      }
    } catch (e) {
      print('Error sincronizando categorías desde la nube: $e');
    }
  }

  /// Sube una foto a Cloudinary y devuelve la URL pública
  static Future<String?> subirFotoCloudinary(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        print('El archivo no existe: $path');
        return null;
      }
      final url = await CloudinaryService.subirImagen(file);
      return url;
    } catch (e) {
      print('Error subiendo foto a Cloudinary: $e');
      return null;
    }
  }

  /// Método opcional para subir un registro específico a Firebase.
  static Future<void> subirRegistro({
    required int idLocal,
    required String fecha,
    required int categoriaId,
    required String categoriaNombre,
    required double? cantidad,
    required String unidad,
    String? fotoUrl,
  }) async {
    await FirebaseService.subirRegistro(
      idLocal: idLocal,
      fecha: fecha,
      categoriaId: categoriaId,
      categoriaNombre: categoriaNombre,
      cantidad: cantidad,
      unidad: unidad,
      fotoUrl: fotoUrl,
    );
  }
}
