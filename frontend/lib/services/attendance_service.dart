import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';

class AttendanceService {
  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU COMPUTADORA
  static const String baseUrl = "http://192.168.1.10:8000";

  /// Obtener asistencias del día actual
  Future<AttendanceResponse> getAttendanceToday() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/asistencia/hoy'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AttendanceResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener asistencias de una fecha específica
  Future<AttendanceResponse> getAttendanceByDate(String fecha) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/asistencia/fecha/$fecha'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AttendanceResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener asistencias en un rango de fechas
  Future<AttendanceResponse> getAttendanceByRange(
    String fechaInicio,
    String fechaFin,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/asistencia/rango?fecha_inicio=$fechaInicio&fecha_fin=$fechaFin',
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AttendanceResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener asistencias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener historial de un estudiante
  Future<List<AttendanceRecord>> getStudentHistory(String nombre) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/asistencia/estudiante/$nombre'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final historial = (data['historial'] as List?)
                ?.map((item) => AttendanceRecord.fromJson(item))
                .toList() ??
            [];
        return historial;
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener lista de todos los estudiantes
  Future<StudentsResponse> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/estudiantes'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StudentsResponse.fromJson(data);
      } else {
        throw Exception('Error al obtener estudiantes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Descargar reporte Excel (devuelve la URL para descargar)
  String getExcelDownloadUrl({String? fechaInicio, String? fechaFin}) {
    if (fechaInicio != null && fechaFin != null) {
      return '$baseUrl/api/asistencia/exportar/excel?fecha_inicio=$fechaInicio&fecha_fin=$fechaFin';
    } else if (fechaInicio != null) {
      return '$baseUrl/api/asistencia/exportar/excel?fecha_inicio=$fechaInicio';
    } else {
      return '$baseUrl/api/asistencia/exportar/excel';
    }
  }

  /// Descargar reporte Excel de un estudiante
  String getStudentExcelDownloadUrl(String nombre) {
    return '$baseUrl/api/asistencia/exportar/estudiante/$nombre';
  }
}
