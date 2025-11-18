import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sigre_ceti/firebase_options.dart';
import 'package:sigre_ceti/screens/categorias_screen.dart';
import 'package:sigre_ceti/screens/principal_screen.dart';
import 'package:sigre_ceti/screens/registro_screen.dart';
import 'package:sigre_ceti/screens/historial_screen.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // La seguimos inicializando por si en algún punto usas 'es_MX'
  await initializeDateFormatting('es_MX', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Basura CETI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PrincipalScreen(),
        '/registrar': (context) => const RegistroScreen(),
        '/historial': (context) => const HistorialScreen(),
        '/categorias': (context) => const CategoriasScreen(),
      },
    );
  }
}
