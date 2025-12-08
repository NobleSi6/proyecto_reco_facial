import 'package:equatable/equatable.dart';
import '../models/attendance_model.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial
class AttendanceInitial extends AttendanceState {}

/// Cargando datos
class AttendanceLoading extends AttendanceState {}

/// Asistencias cargadas exitosamente
class AttendanceLoaded extends AttendanceState {
  final List<AttendanceRecord> asistencias;
  final String fecha;
  final int total;

  const AttendanceLoaded({
    required this.asistencias,
    required this.fecha,
    required this.total,
  });

  @override
  List<Object?> get props => [asistencias, fecha, total];
}

/// Historial de estudiante cargado
class StudentHistoryLoaded extends AttendanceState {
  final String nombre;
  final List<AttendanceRecord> historial;

  const StudentHistoryLoaded({
    required this.nombre,
    required this.historial,
  });

  @override
  List<Object?> get props => [nombre, historial];
}

/// Lista de estudiantes cargada
class StudentsListLoaded extends AttendanceState {
  final List<Student> estudiantes;
  final int total;

  const StudentsListLoaded({
    required this.estudiantes,
    required this.total,
  });

  @override
  List<Object?> get props => [estudiantes, total];
}

/// Excel listo para descargar
class ExcelReady extends AttendanceState {
  final String downloadUrl;

  const ExcelReady(this.downloadUrl);

  @override
  List<Object?> get props => [downloadUrl];
}

/// Error
class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
