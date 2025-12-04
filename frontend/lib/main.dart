import 'package:flutter/material.dart';
import 'package:frontend/attendance_list_page.dart';
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
/// PANTALLA PRINCIPAL CON 3 BOTONES
/// ---------------------------------------------------------------------------
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sistema de Reconocimiento Facial")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // BOTÓN 1 - Reconocimiento facial
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecognizeFacePage()),
                );
              },
              child: const Text("Reconocer rostro"),
            ),
            const SizedBox(height: 20),

            // BOTÓN 2 - Registrar rostro
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterFacePage()),
                );
              },
              child: const Text("Registrar rostro"),
            ),
            const SizedBox(height: 20),

            // BOTÓN 3 - Lista de asistencia
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceListPage()),
                );
              },
              child: const Text("Ver lista de asistencia"),
            ),
          ],
        ),
      ),
    );
  }
}



