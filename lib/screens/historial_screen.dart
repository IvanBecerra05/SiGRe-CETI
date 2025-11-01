import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late Database db;
  List<Map<String, dynamic>> registros = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    db = await DatabaseHelper.openDB();
    await _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() => isLoading = true);
    
    // Query con JOIN para obtener el nombre de la categoría
    final res = await db.rawQuery('''
      SELECT 
        r.id,
        r.fecha,
        r.volumen,
        r.foto_path,
        c.nombre as categoria_nombre
      FROM registros r
      INNER JOIN categorias c ON r.categoria_id = c.id
      ORDER BY r.fecha DESC
    ''');
    
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
        content: const Text('¿Eliminar este registro?'),
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
          const SnackBar(content: Text('Registro eliminado')),
        );
      }
    }
  }

  void _verDetalles(Map<String, dynamic> registro) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(registro['categoria_nombre']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${_formatearFecha(registro['fecha'])}'),
              const SizedBox(height: 8),
              Text('Volumen: ${registro['volumen']} Mt3'),
              const SizedBox(height: 16),
              if (registro['foto_path'] != null)
                Image.file(
                  File(registro['foto_path']),
                  fit: BoxFit.contain,
                )
              else
                const Text('Sin foto'),
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

  String _formatearFecha(String fecha) {
    final dt = DateTime.parse(fecha);
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : registros.isEmpty
              ? const Center(child: Text('No hay registros aún'))
              : ListView.builder(
                  itemCount: registros.length,
                  itemBuilder: (context, index) {
                    final reg = registros[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: reg['foto_path'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(reg['foto_path']),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.delete, size: 40),
                        title: Text(reg['categoria_nombre']),
                        subtitle: Text(
                          '${reg['volumen']} Mt3 - ${_formatearFecha(reg['fecha'])}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarRegistro(reg['id']),
                        ),
                        onTap: () => _verDetalles(reg),
                      ),
                    );
                  },
                ),
    );
  }
}