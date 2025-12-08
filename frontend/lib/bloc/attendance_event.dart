import 'package:equatable/equatable.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar asistencias del día actual
class LoadTodayAttendance extends AttendanceEvent {}

/// Cargar asistencias de una fecha específica
class LoadAttendanceByDate extends AttendanceEvent {
  final String fecha;

  const LoadAttendanceByDate(this.fecha);

  @override
  List<Object?> get props => [fecha];
}

/// Cargar asistencias por rango de fechas
class LoadAttendanceByRange extends AttendanceEvent {
  final String fechaInicio;
  final String fechaFin;

  const LoadAttendanceByRange(this.fechaInicio, this.fechaFin);

  @override
  List<Object?> get props => [fechaInicio, fechaFin];
}

/// Cargar historial de un estudiante
class LoadStudentHistory extends AttendanceEvent {
  final String nombre;

  const LoadStudentHistory(this.nombre);

  @override
  List<Object?> get props => [nombre];
}

/// Cargar lista de estudiantes
class LoadStudentsList extends AttendanceEvent {}

/// Exportar a Excel
class ExportToExcel extends AttendanceEvent {
  final String? fechaInicio;
  final String? fechaFin;

  const ExportToExcel({this.fechaInicio, this.fechaFin});

  @override
  List<Object?> get props => [fechaInicio, fechaFin];
}
