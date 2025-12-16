import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/config/api_config.dart';
import 'package:http/http.dart' as http;

import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final String baseUrl = ApiConfig.baseUrl;

  AttendanceBloc() : super(AttendanceInitial()) {

    // ===============================
    // OBTENER ASISTENCIAS
    // ===============================
    on<FetchAttendanceEvent>((event, emit) async {
      emit(AttendanceLoading());

      try {
        final response = await http
            .get(Uri.parse("$baseUrl/asistencias"))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          emit(AttendanceError(
              "Error del servidor (${response.statusCode})"));
          return;
        }

        final decoded = json.decode(response.body);

        if (decoded is! Map || decoded["asistencias"] is! List) {
          emit(const AttendanceError("Formato inválido"));
          return;
        }

        final List<Map<String, dynamic>> asistencias =
            List<Map<String, dynamic>>.from(
          decoded["asistencias"].map((e) {
            return {
              "persona": e["persona"] ?? "Sin nombre",
              "asistencias": e["asistencias"] ?? 0,
              "fechas": List<String>.from(e["fechas"] ?? []),
            };
          }),
        );

        emit(AttendanceLoaded(asistencias));

      } on TimeoutException {
        emit(const AttendanceError("Tiempo de espera agotado"));
      } on SocketException {
        emit(const AttendanceError("No se pudo conectar al servidor"));
      } catch (e) {
        emit(AttendanceError("Error inesperado: $e"));
      }
    });

    // ===============================
    // EDITAR NOMBRE DE PERSONA
    // ===============================
    on<UpdatePersonNameEvent>((event, emit) async {
      emit(AttendanceLoading());

      try {
        final response = await http
            .put(
              Uri.parse("$baseUrl/personas/${event.oldName}"),
              headers: {"Content-Type": "application/json"},
              body: json.encode({
                "nuevo_nombre": event.newName,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          emit(AttendanceError(
              "Error al editar (${response.statusCode})"));
          return;
        }

        // Refrescar lista
        add(FetchAttendanceEvent());

      } on TimeoutException {
        emit(const AttendanceError("Tiempo de espera agotado"));
      } on SocketException {
        emit(const AttendanceError("Sin conexión al servidor"));
      } catch (e) {
        emit(AttendanceError("Error: $e"));
      }
    });

    // ===============================
    // ELIMINAR PERSONA
    // ===============================
    on<DeletePersonEvent>((event, emit) async {
      emit(AttendanceLoading());

      try {
        final response = await http
            .delete(
              Uri.parse("$baseUrl/personas/${event.persona}"),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          emit(AttendanceError(
              "No se pudo eliminar (${response.statusCode})"));
          return;
        }

        // Refrescar lista
        add(FetchAttendanceEvent());

      } on TimeoutException {
        emit(const AttendanceError("Tiempo de espera agotado"));
      } on SocketException {
        emit(const AttendanceError("No hay conexión"));
      } catch (e) {
        emit(AttendanceError("Error: $e"));
      }
    });

    // ===============================
    // ACTUALIZAR ASISTENCIAS
    // ===============================
    on<UpdateAttendanceEvent>((event, emit) async {
      emit(AttendanceLoading());

      try {
        final response = await http
            .put(
              Uri.parse("$baseUrl/asistencias/${event.persona}"),
              headers: {"Content-Type": "application/json"},
              body: json.encode({
                "fechas": event.fechas,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          emit(AttendanceError(
              "Error al actualizar (${response.statusCode})"));
          return;
        }

        // Refrescar lista
        add(FetchAttendanceEvent());

      } on TimeoutException {
        emit(const AttendanceError("Tiempo de espera agotado"));
      } on SocketException {
        emit(const AttendanceError("Servidor no disponible"));
      } catch (e) {
        emit(AttendanceError("Error: $e"));
      }
    });
  }
}
