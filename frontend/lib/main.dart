import 'package:flutter/material.dart';
import 'package:frontend/attendance_list_page.dart';
import 'package:frontend/attendance_report_page.dart';
import 'package:frontend/recognize_face_page.dart';
import 'package:frontend/register_face_page.dart';

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
/// PANTALLA PRINCIPAL CON 4 BOTONES
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
              // Header
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
                        builder: (_) => const RecognizeFacePage()),
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
                    MaterialPageRoute(builder: (_) => const RegisterFacePage()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // BOTÓN 3 - Lista de asistencia (legacy)
              _buildMenuButton(
                context,
                icon: Icons.list,
                label: "Lista de asistencia",
                color: Colors.orange,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AttendanceListPage()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // BOTÓN 4 - Reportes de asistencia (NUEVO)
              _buildMenuButton(
                context,
                icon: Icons.assessment,
                label: "Reportes de asistencia",
                color: Colors.purple,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceReportPage(),
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
