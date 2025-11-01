import 'package:flutter/material.dart';
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
        title: const Text('Nueva categoría'),
        content: TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
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
    if (categoriaSeleccionada == null || volumenCtrl.text.isEmpty) return;

    await db.insert('registros', {
      'fecha': DateTime.now().toIso8601String(),
      'categoria_id': categoriaSeleccionada,
      'volumen': double.tryParse(volumenCtrl.text) ?? 0,
      'foto_path': fotoPath
    });

    setState(() {
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
        title: const Text('Registro de basura'),
        actions: [
          IconButton(onPressed: _agregarCategoria, icon: const Icon(Icons.add)),
        ],
      ),
      body: categorias.isEmpty
          ? const Center(child: Text('Agrega una categoría para comenzar'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    value: categoriaSeleccionada,
                    items: categorias.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['nombre']),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => categoriaSeleccionada = v),
                  ),
                  TextField(
                    controller: volumenCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Volumen (Mt3)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  fotoPath == null
                      ? const Text('Sin foto seleccionada')
                      : Image.file(File(fotoPath!), height: 200),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _tomarFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tomar foto'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _guardarRegistro,
                    child: const Text('Guardar registro'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/historial');
                    },
                    child: const Text('Ver historial'),
                  )
                ],
              ),
            ),
    );
  }
}
