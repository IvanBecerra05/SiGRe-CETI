import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  late Database db;
  List<Map<String, dynamic>> categorias = [];
  bool isLoading = true;

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
    setState(() => isLoading = true);
    final res = await db.query('categorias', orderBy: 'nombre ASC');
    setState(() {
      categorias = res;
      isLoading = false;
    });
  }

  Future<void> _editarCategoria(Map<String, dynamic> categoria) async {
    final nombreCtrl = TextEditingController(text: categoria['nombre']);

    final resultado = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Editar categoría',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nombreCtrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado.isNotEmpty && resultado != categoria['nombre']) {
      await db.update(
        'categorias',
        {'nombre': resultado},
        where: 'id = ?',
        whereArgs: [categoria['id']],
      );
      await _cargarCategorias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría actualizada')),
        );
      }
    }
  }

  Future<void> _eliminarCategoria(Map<String, dynamic> categoria) async {
    // Verificar si tiene registros asociados
    final registros = await db.query(
      'registros',
      where: 'categoria_id = ?',
      whereArgs: [categoria['id']],
    );

    if (registros.isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('No se puede eliminar'),
            content: Text(
              'La categoría "${categoria['nombre']}" tiene ${registros.length} registro(s) asociado(s). '
              'Elimina primero los registros o edita el nombre de la categoría.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Confirmar eliminación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar la categoría "${categoria['nombre']}"?'),
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
      await db.delete('categorias', where: 'id = ?', whereArgs: [categoria['id']]);
      await _cargarCategorias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría eliminada')),
        );
      }
    }
  }

  Future<void> _agregarCategoria() async {
    final nombreCtrl = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Nueva categoría',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nombreCtrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado.isNotEmpty) {
      await db.insert('categorias', {'nombre': resultado});
      await _cargarCategorias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría agregada')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de categorías'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Encabezado
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Edita o elimina categorías existentes',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Lista de categorías
                Expanded(
                  child: categorias.isEmpty
                      ? const Center(
                          child: Text('No hay categorías'),
                        )
                      : ListView.builder(
                          itemCount: categorias.length,
                          itemBuilder: (context, index) {
                            final cat = categorias[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Icon(
                                    Icons.label,
                                    color: Colors.green[700],
                                  ),
                                ),
                                title: Text(
                                  cat['nombre'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => _editarCategoria(cat),
                                      tooltip: 'Editar',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _eliminarCategoria(cat),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCategoria,
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
    );
  }
}