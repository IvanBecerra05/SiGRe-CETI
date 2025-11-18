import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/firebase_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Database db;
  List<Map<String, dynamic>> registros = [];
  bool isLoading = true;
  DateTime fechaActual = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    db = await DatabaseHelper.openDB();
    await _cargarRegistros();
    // Sincronizar registros pendientes HACIA la nube
    await SyncService.sincronizar();
  }

  Future<void> _cargarRegistros() async {
    setState(() => isLoading = true);

    // 1) Intentar primero desde Firebase (historial global)
    try {
      final registrosFirebase =
          await FirebaseService.obtenerRegistrosPorDia(fechaActual);

      if (registrosFirebase.isNotEmpty) {
        setState(() {
          registros = registrosFirebase;
          isLoading = false;
        });
        return; // usamos los de Firebase y listo
      }
    } catch (e) {
      // Si falla Firebase, caemos al local
      debugPrint('Error obteniendo registros de Firebase: $e');
    }

    // 2) Fallback: cargar solo los registros locales de este dispositivo
    final inicioDia =
        DateTime(fechaActual.year, fechaActual.month, fechaActual.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    final res = await db.rawQuery('''
      SELECT 
        r.id,
        r.fecha,
        r.volumen,
        r.unidad,
        r.foto_path,
        c.nombre as categoria_nombre
      FROM registros r
      INNER JOIN categorias c ON r.categoria_id = c.id
      WHERE r.fecha >= ? AND r.fecha < ?
      ORDER BY r.fecha DESC
    ''', [inicioDia.toIso8601String(), finDia.toIso8601String()]);

    setState(() {
      registros = res;
      isLoading = false;
    });
  }

  Future<void> _eliminarRegistro(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Eliminar este registro LOCAL? (No borra en la nube)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await db.delete('registros', where: 'id = ?', whereArgs: [id]);
      await _cargarRegistros();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro eliminado localmente')),
        );
      }
    }
  }

  void _verDetalles(Map<String, dynamic> registro) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(registro['categoria_nombre'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${_formatearFecha(registro['fecha'])}'),
              const SizedBox(height: 8),
              Text(
                'Cantidad: ${registro['volumen']} ${registro['unidad'] ?? ''}',
              ),
              const SizedBox(height: 16),
              _construirImagenDetalle(registro),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _construirImagenDetalle(Map<String, dynamic> registro) {
    final fotoPath = registro['foto_path'] as String?;
    final fotoUrl = registro['foto_url'] as String?;

    if (fotoPath != null && fotoPath.isNotEmpty) {
      return Image.file(
        File(fotoPath),
        fit: BoxFit.contain,
      );
    } else if (fotoUrl != null && fotoUrl.isNotEmpty) {
      return Image.network(
        fotoUrl,
        fit: BoxFit.contain,
      );
    } else {
      return const Text('Sin foto');
    }
  }

  String _formatearFecha(String fecha) {
    final dt = DateTime.parse(fecha);
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  String _formatearDiaSuperior() {
    final hoy = DateTime.now();
    if (fechaActual.year == hoy.year &&
        fechaActual.month == hoy.month &&
        fechaActual.day == hoy.day) {
      return 'HOY';
    }
    return DateFormat('dd MMMM yyyy').format(fechaActual);
  }

  void _cambiarDia(int dias) {
    setState(() {
      fechaActual = fechaActual.add(Duration(days: dias));
    });
    _cargarRegistros();
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaActual.isAfter(hoy) ? hoy : fechaActual,
      firstDate: DateTime(2020),
      lastDate: hoy,
    );

    if (seleccionada != null) {
      setState(() => fechaActual = seleccionada);
      await _cargarRegistros();
    }
  }

  bool _esHoy() {
    final hoy = DateTime.now();
    return fechaActual.year == hoy.year &&
        fechaActual.month == hoy.month &&
        fechaActual.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    final esHoy = _esHoy();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de registros'),
        actions: [
          IconButton(
            onPressed: _cargarRegistros,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  onPressed: () => _cambiarDia(-1),
                ),
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Text(
                    _formatearDiaSuperior(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                esHoy
                    ? const SizedBox(width: 48)
                    : IconButton(
                        icon: const Icon(Icons.chevron_right, size: 32),
                        onPressed: () => _cambiarDia(1),
                      ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : registros.isEmpty
                    ? const Center(
                        child: Text('No hay registros para este día'),
                      )
                    : ListView.builder(
                        itemCount: registros.length,
                        itemBuilder: (context, index) {
                          final reg = registros[index];
                          final fotoPath = reg['foto_path'] as String?;
                          final fotoUrl = reg['foto_url'] as String?;
                          final tieneFotoLocal =
                              fotoPath != null && fotoPath.isNotEmpty;
                          final tieneFotoRemota =
                              fotoUrl != null && fotoUrl.isNotEmpty;

                          Widget leading;
                          if (tieneFotoLocal) {
                            leading = ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(fotoPath!),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            );
                          } else if (tieneFotoRemota) {
                            leading = ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                fotoUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            );
                          } else {
                            leading = const Icon(Icons.delete, size: 40);
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: leading,
                              title: Text(
                                reg['categoria_nombre'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${reg['volumen']} ${reg['unidad'] ?? ''} - ${_formatearFecha(reg['fecha'])}',
                              ),
                              trailing: reg['id'] is int
                                  ? IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _eliminarRegistro(reg['id'] as int),
                                    )
                                  : null, // los de Firebase no se borran localmente
                              onTap: () => _verDetalles(reg),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
