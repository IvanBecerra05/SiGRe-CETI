import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_helper.dart';
import '../services/foto_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  late Database db;
  List<Map<String, dynamic>> categorias = [];
  int? categoriaSeleccionada;
  TextEditingController cantidadCtrl = TextEditingController();
  String? fotoPath;

  List<String> unidadesActuales = [];
  String? unidadSeleccionada;

  @override
  void initState() {
    super.initState();
    _initDB();
  }

  Future<void> _initDB() async {
    db = await DatabaseHelper.openDB();
    await _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final res = await db.query('categorias');
    setState(() => categorias = res);
  }

  void _actualizarUnidadesParaCategoria(int? categoriaId) {
    unidadesActuales = [];
    unidadSeleccionada = null;

    if (categoriaId == null) {
      setState(() {});
      return;
    }

    try {
      final categoria = categorias.firstWhere(
        (c) => c['id'] == categoriaId,
      );
      final medidasStr = categoria['medidas'] as String?;
      if (medidasStr != null && medidasStr.trim().isNotEmpty) {
        unidadesActuales = medidasStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (unidadesActuales.isNotEmpty) {
          // Si solo tiene una, se autoselecciona
          unidadSeleccionada = unidadesActuales.first;
        }
      }
    } catch (_) {
      // si no encontramos la categoría, dejamos listas vacías
    }

    setState(() {});
  }

  Future<void> _agregarCategoria() async {
    final nombreCtrl = TextEditingController();
    final medidasCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Nueva categoría',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: medidasCtrl,
              decoration: const InputDecoration(
                labelText: 'Unidades de medida (separadas por coma)',
                hintText: 'Ej: kg, bolsa, m³',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isNotEmpty) {
                await db.insert('categorias', {
                  'nombre': nombreCtrl.text.trim(),
                  'medidas': medidasCtrl.text.trim(),
                  'sincronizado': 0,
                });
                await _cargarCategorias();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarRegistro() async {
    final cantidadStr = cantidadCtrl.text.trim();

    if (categoriaSeleccionada == null ||
        cantidadStr.isEmpty ||
        unidadSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa categoría, cantidad y unidad de medida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cantidad = double.tryParse(cantidadStr);
    if (cantidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una cantidad numérica válida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fechaIso = DateTime.now().toLocal().toIso8601String();

    await db.insert('registros', {
      'fecha': fechaIso,
      'categoria_id': categoriaSeleccionada,
      'volumen': cantidad,
      'unidad': unidadSeleccionada,
      'foto_path': fotoPath,
      'sincronizado': 0,
    });

    setState(() {
      categoriaSeleccionada = null;
      cantidadCtrl.clear();
      fotoPath = null;
      unidadesActuales = [];
      unidadSeleccionada = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro guardado localmente')),
    );
  }

  Future<void> _tomarFoto() async {
    // Diálogo para elegir cámara o galería
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto con cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir desde galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final localPath = await FotoService.seleccionarImagen(source);
    if (localPath != null && localPath.isNotEmpty) {
      setState(() {
        fotoPath = localPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de residuos'),
        actions: [
          TextButton.icon(
            onPressed: _agregarCategoria,
            icon: Icon(Icons.add, color: Colors.grey[800]),
            label: Text(
              'Categoría',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: categorias.isEmpty
          ? const Center(
              child: Text(
                'Agrega una categoría para comenzar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            decoration:
                                const InputDecoration(labelText: 'Categoría'),
                            value: categoriaSeleccionada,
                            items: categorias.map((c) {
                              return DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(
                                  c['nombre'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                categoriaSeleccionada = v;
                              });
                              _actualizarUnidadesParaCategoria(v);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: cantidadCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Selector de unidad de medida
                          if (categoriaSeleccionada == null)
                            const SizedBox.shrink()
                          else if (unidadesActuales.isEmpty)
                            const Text(
                              'Esta categoría no tiene unidades definidas.\nEdítala en "Categorías".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (unidadesActuales.length == 1 &&
                              unidadSeleccionada != null)
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Unidad de medida',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                unidadSeleccionada!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Unidad de medida',
                                border: OutlineInputBorder(),
                              ),
                              value: unidadSeleccionada,
                              items: unidadesActuales.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(u),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  unidadSeleccionada = v;
                                });
                              },
                            ),

                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _tomarFoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Tomar / elegir foto'),
                          ),
                          const SizedBox(height: 16),
                          fotoPath == null
                              ? const Text(
                                  'Sin foto seleccionada',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              : Image.file(
                                  File(fotoPath!),
                                  height: 200,
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _guardarRegistro,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar registro'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/historial');
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Ver historial'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
