import 'package:flutter/material.dart';
import 'screens/registro_screen.dart';
import 'screens/historial_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Basura CETI',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const RegistroScreen(),
        '/historial': (context) => const HistorialScreen(),
      },
    );
  }
}