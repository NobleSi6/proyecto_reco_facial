import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'attendance_list_page.dart';
import 'recognize_face_page.dart';
import 'register_face_page.dart';
import 'bloc/attendance_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainMenuPage(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// PANTALLA PRINCIPAL CON 3 BOTONES
/// ---------------------------------------------------------------------------
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sistema de Reconocimiento Facial"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.face,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                "Sistema de Asistencias",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),

              // BOTÓN 1 - Reconocimiento facial
              _buildMenuButton(
                context,
                icon: Icons.face_retouching_natural,
                label: "Reconocer rostro",
                color: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecognizeFacePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // BOTÓN 2 - Registrar rostro
              _buildMenuButton(
                context,
                icon: Icons.person_add,
                label: "Registrar rostro",
                color: Colors.green,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterFacePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // BOTÓN 3 - Lista de asistencia (CON BLOCPROVIDER)
              _buildMenuButton(
                context,
                icon: Icons.list,
                label: "Ver lista de asistencia",
                color: Colors.orange,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => AttendanceBloc(),
                        child: const AttendanceListPage(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
