import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// PÁGINA 3 → Lista de asistencia
/// ---------------------------------------------------------------------------
class AttendanceListPage extends StatelessWidget {
  const AttendanceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lista de asistencia")),
      body: const Center(child: Text("📄 Aquí se listará la asistencia.")),
    );
  }
}
