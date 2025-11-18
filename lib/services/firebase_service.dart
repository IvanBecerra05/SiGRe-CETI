import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Crear categoría en Firestore (ID automático)
  static Future<void> subirCategoria(
    int idLocal,
    String nombre, {
    String? medidas,
  }) async {
    await _db.collection('categorias').add({
      'id_local': idLocal,
      'nombre': nombre,
      'medidas': medidas,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Crear registro en Firestore (ID automático)
  static Future<void> subirRegistro({
    required int idLocal,
    required String fecha,
    required int categoriaId,
    required String categoriaNombre,
    required double? cantidad,
    required String unidad,
    required String? fotoUrl,
  }) async {
    await _db.collection('registros').add({
      'id_local': idLocal,
      'fecha': fecha,
      'categoria_id': categoriaId,
      'categoria_nombre': categoriaNombre,
      'cantidad': cantidad,
      'unidad': unidad,
      'foto_url': fotoUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// 🔹 Registros de un día (para el historial global)
  static Future<List<Map<String, dynamic>>> obtenerRegistrosPorDia(
      DateTime fecha) async {
    final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    final inicioIso = inicioDia.toIso8601String();
    final finIso = finDia.toIso8601String();

    final querySnapshot = await _db
        .collection('registros')
        .where('fecha', isGreaterThanOrEqualTo: inicioIso)
        .where('fecha', isLessThan: finIso)
        .orderBy('fecha', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'fecha': data['fecha'] ?? '',
        'volumen': (data['cantidad'] as num?)?.toDouble() ?? 0.0,
        'unidad': data['unidad'],
        'foto_url': data['foto_url'],
        'foto_path': null,
        'categoria_nombre': data['categoria_nombre'] ?? '',
      };
    }).toList();
  }

  /// 🔹 Todas las categorías en la nube (para sincronizarlas a SQLite)
  static Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final snapshot = await _db.collection('categorias').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'nombre': data['nombre'] ?? '',
        'medidas': data['medidas'] ?? '',
      };
    }).toList();
  }

  /// 🔹 Resumen semanal global de registros (últimos 7 días) desde la nube
  ///
  /// Devuelve: { 'Papel': 12.5, 'Cartón': 3.0, ... }
  static Future<Map<String, double>> obtenerResumenSemanal(
      DateTime desde) async {
    final desdeFecha = DateTime(desde.year, desde.month, desde.day);
    final desdeIso = desdeFecha.toIso8601String();

    final snapshot = await _db
        .collection('registros')
        .where('fecha', isGreaterThanOrEqualTo: desdeIso)
        .get();

    final Map<String, double> resumen = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final categoria = (data['categoria_nombre'] ?? 'Sin categoría') as String;
      final cantidad = (data['cantidad'] as num?)?.toDouble() ?? 0.0;

      resumen[categoria] = (resumen[categoria] ?? 0.0) + cantidad;
    }

    return resumen;
  }
}
