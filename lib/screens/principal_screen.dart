import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_helper.dart';
import '../services/sync_service.dart';
import '../services/firebase_service.dart';
import '../weather_service.dart';

class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  late Database db;
  Map<String, double> residuosSemana = {};
  bool isLoading = true;

  double? temperatura;
  String? calidadAire;
  Color? colorAQI;
  bool cargandoClima = true;

  @override
  void initState() {
    super.initState();
    _initDB();
    _cargarDatosAmbientales();
  }

  Future<void> _initDB() async {
    db = await DatabaseHelper.openDB();

    // 🔼 Subir pendientes
    await SyncService.sincronizar();

    // 🔽 Traer categorías globales a la BD local
    await SyncService.sincronizarCategoriasDesdeNube();

    // Resumen semanal (Firebase primero, luego local)
    await _cargarResumenSemanal();
  }

  Future<void> _cargarDatosAmbientales() async {
    setState(() => cargandoClima = true);
    final datos = await WeatherService.obtenerDatosAmbientales();

    if (datos != null) {
      setState(() {
        temperatura = datos['temperatura'];
        calidadAire = datos['aqiDescripcion'];
        colorAQI = Color(datos['aqiColor']);
        cargandoClima = false;
      });
    } else {
      setState(() => cargandoClima = false);
    }
  }

  Future<void> _cargarResumenSemanal() async {
    setState(() => isLoading = true);

    final hoy = DateTime.now();
    final inicioSemana = DateTime(hoy.year, hoy.month, hoy.day)
        .subtract(const Duration(days: 7));

    // 1️⃣ Intentar obtener el resumen global desde Firebase
    try {
      final resumenFirebase =
          await FirebaseService.obtenerResumenSemanal(inicioSemana);

      if (resumenFirebase.isNotEmpty) {
        setState(() {
          residuosSemana = resumenFirebase;
          isLoading = false;
        });
        return; // usamos el resumen global
      }
    } catch (e) {
      debugPrint('Error obteniendo resumen semanal de Firebase: $e');
    }

    // 2️⃣ Fallback: usar SQLite local (solo datos de este dispositivo)
    final res = await db.rawQuery('''
      SELECT 
        c.nombre as categoria,
        SUM(r.volumen) as total
      FROM registros r
      INNER JOIN categorias c ON r.categoria_id = c.id
      WHERE r.fecha >= ?
      GROUP BY c.nombre
      ORDER BY total DESC
    ''', [inicioSemana.toIso8601String()]);

    setState(() {
      residuosSemana = {
        for (var row in res)
          row['categoria'] as String: (row['total'] as num?)?.toDouble() ?? 0.0,
      };
      isLoading = false;
    });
  }

  double get _totalSemanal =>
      residuosSemana.values.fold(0.0, (sum, vol) => sum + vol);

  Future<void> _navegarYRecargar(String ruta) async {
    await Navigator.pushNamed(context, ruta);
    await _cargarResumenSemanal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 100, color: Colors.green[700]),
              const SizedBox(height: 16),
              const Text(
                'SiGRe CETI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Sistema de Gestión de Residuos CETI',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text('Registrar residuo'),
                onPressed: () => _navegarYRecargar('/registrar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('Ver historial'),
                onPressed: () => _navegarYRecargar('/historial'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.category),
                label: const Text('Categorías'),
                onPressed: () => Navigator.pushNamed(context, '/categorias'),
              ),
              const SizedBox(height: 32),
              if (cargandoClima)
                const CircularProgressIndicator()
              else if (temperatura != null && calidadAire != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thermostat, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        '${temperatura!.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(height: 20, width: 1, color: Colors.grey[400]),
                      const SizedBox(width: 16),
                      Icon(Icons.air, color: colorAQI),
                      const SizedBox(width: 4),
                      Text(
                        calidadAire ?? '',
                        style: TextStyle(
                          color: colorAQI,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'No se pudo obtener el clima',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month,
                            size: 20, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Residuos separados los últimos 7 días',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const CircularProgressIndicator()
                    else if (residuosSemana.isEmpty)
                      Text(
                        'Sin registros esta semana',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            '${_totalSemanal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          ...residuosSemana.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    entry.value.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
