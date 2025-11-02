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

  DateTime fechaActual = DateTime.now(); // Fecha visible y filtrada

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

    // Normalizamos fecha a medianoche para comparar solo el día
    final inicioDia =
        DateTime(fechaActual.year, fechaActual.month, fechaActual.day);
    final finDia = inicioDia.add(const Duration(days: 1));

    // Query con filtro por fecha - comparando strings directamente
    final inicioStr = inicioDia.toIso8601String();
    final finStr = finDia.toIso8601String();

    final res = await db.rawQuery('''
      SELECT 
        r.id,
        r.fecha,
        r.volumen,
        r.foto_path,
        c.nombre as categoria_nombre
      FROM registros r
      INNER JOIN categorias c ON r.categoria_id = c.id
      WHERE r.fecha >= ? AND r.fecha < ?
      ORDER BY r.fecha DESC
    ''', [inicioStr, finStr]);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${_formatearFecha(registro['fecha'])}'),
              const SizedBox(height: 8),
              Text('Volumen: ${registro['volumen']} Mt3'),
              const SizedBox(height: 16),
              if (registro['foto_path'] != null)
                Image.file(File(registro['foto_path']), fit: BoxFit.contain)
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

  String _formatearDiaSuperior() {
    final hoy = DateTime.now();
    final esHoy = fechaActual.year == hoy.year &&
        fechaActual.month == hoy.month &&
        fechaActual.day == hoy.day;

    if (esHoy) return 'HOY';
    return DateFormat('dd MMMM yyyy', 'es_MX').format(fechaActual);
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
      // Sin locale - se usa inglés por defecto
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
          // 🔼 Encabezado de fecha y flechas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Flecha izquierda (día anterior)
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  onPressed: () => _cambiarDia(-1),
                ),

                // Texto de fecha / HOY
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

                // Flecha derecha (solo aparece si NO es hoy)
                esHoy
                    ? const SizedBox(width: 48) // espacio vacío para alinear
                    : IconButton(
                        icon: const Icon(Icons.chevron_right, size: 32),
                        onPressed: () => _cambiarDia(1),
                      ),
              ],
            ),
          ),

          // 🔽 Lista de registros
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : registros.isEmpty
                    ? const Center(
                        child: Text('No hay registros para este día'))
                    : ListView.builder(
                        itemCount: registros.length,
                        itemBuilder: (context, index) {
                          final reg = registros[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                              title: Text(
                                reg['categoria_nombre'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${reg['volumen']} Mt3 - ${_formatearFecha(reg['fecha'])}',
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarRegistro(reg['id']),
                              ),
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
