import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AttendanceListPage extends StatefulWidget {
  const AttendanceListPage({super.key});

  @override
  AttendanceListPageState createState() => AttendanceListPageState();
}

class AttendanceListPageState extends State<AttendanceListPage> {
  List<dynamic> asistencias = [];
  bool isLoading = false;

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU COMPUTADORA
  static const String BASE_URL = "http://192.168.1.10:8000";

  @override
  void initState() {
    super.initState();
    cargarAsistencias();
  }

  Future<void> cargarAsistencias() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/asistencias'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          asistencias = data["asistencias"] ?? [];
          isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error del servidor: ${response.statusCode}"),
            ),
          );
        }
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error al cargar asistencias: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial de Asistencias")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : cargarAsistencias,
              icon: const Icon(Icons.refresh),
              label: const Text("Actualizar"),
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (asistencias.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No hay registros de asistencia",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          "Persona",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Fecha de Creación",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Asistencias",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: asistencias.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item["persona"] ?? "Sin nombre")),
                          DataCell(Text(item["fecha_creacion"] ?? "Sin fecha")),
                          DataCell(
                            Chip(
                              label: Text(
                                "${item["asistencias"] ?? 0}",
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
