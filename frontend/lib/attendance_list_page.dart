import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AttendanceListPage extends StatefulWidget {
  @override
  _AttendanceListPageState createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  List<dynamic> asistencias = [];

  final String asistenciasUrl = kIsWeb
      ? "http://127.0.0.1:8000/asistencias"
      : "http://10.0.2.2:8000/asistencias";

  @override
  void initState() {
    super.initState();
    cargarAsistencias();
  }

  Future<void> cargarAsistencias() async {
    try {
      final response = await http.get(Uri.parse(asistenciasUrl));

      if (response.statusCode == 200) {
        setState(() {
          asistencias = json.decode(response.body)["asistencias"];
        });
      }
    } catch (e) {
      print("❌ Error al cargar asistencias: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Historial de Asistencias")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: cargarAsistencias,
              icon: Icon(Icons.refresh),
              label: Text("Actualizar"),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(
                        label: Text("Persona",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text("Fecha de Creación",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text("Asistencias",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: asistencias.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item["persona"])),
                      DataCell(Text(item["fecha_creacion"])),
                      DataCell(
                        Chip(
                          label: Text(
                            "${item["asistencias"]}",
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ]);
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
