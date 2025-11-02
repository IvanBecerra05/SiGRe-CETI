import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../foto_service.dart';
import 'dart:io';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  late Database db;
  List<Map<String, dynamic>> categorias = [];
  int? categoriaSeleccionada;
  TextEditingController volumenCtrl = TextEditingController();
  String? fotoPath;

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

  Future<void> _agregarCategoria() async {
    final nombreCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Nueva categoría',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (nombreCtrl.text.isNotEmpty) {
                await db.insert('categorias', {'nombre': nombreCtrl.text});
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
    if (categoriaSeleccionada == null || volumenCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Completa todos los campos'),
            backgroundColor: Colors.red),
      );
      return;
    }

    await db.insert('registros', {
      'fecha': DateTime.now().toLocal().toIso8601String(), // ✅ Hora local
      'categoria_id': categoriaSeleccionada,
      'volumen': double.tryParse(volumenCtrl.text) ?? 0,
      'foto_path': fotoPath
    });
    setState(() {
      categoriaSeleccionada = null; // ✅ Reinicia el dropdown
      volumenCtrl.clear();
      fotoPath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro guardado')),
    );
  }

  Future<void> _tomarFoto() async {
    final path = await FotoService.tomarFoto();
    if (path != null) setState(() => fotoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de basura'),
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
                  // 🔹 Parte superior con scroll si crece
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
                            onChanged: (v) =>
                                setState(() => categoriaSeleccionada = v),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: volumenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Volumen (m³)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 20),
                          fotoPath == null
                              ? const Text(
                                  'Sin foto seleccionada',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )
                              : Image.file(File(fotoPath!), height: 200),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _tomarFoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text(
                              'Tomar foto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 🔹 Botones fijos al fondo
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _guardarRegistro,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Guardar registro',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/historial');
                    },
                    icon: const Icon(Icons.history),
                    label: const Text(
                      'Ver historial',
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }
}
