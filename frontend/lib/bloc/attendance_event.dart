import 'package:equatable/equatable.dart';

/// 🔹 Evento base
abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

/// 🔄 Obtener todas las asistencias
class FetchAttendanceEvent extends AttendanceEvent {
  const FetchAttendanceEvent();
}

/// 🔁 Refrescar asistencias (alias de Fetch)
class RefreshAttendanceEvent extends AttendanceEvent {
  const RefreshAttendanceEvent();
}

/// ✏️ Editar nombre de una persona
class UpdatePersonNameEvent extends AttendanceEvent {
  final String oldName;
  final String newName;

  const UpdatePersonNameEvent({
    required this.oldName,
    required this.newName,
  });

  @override
  List<Object?> get props => [oldName, newName];
}

/// 🗑️ Eliminar persona
class DeletePersonEvent extends AttendanceEvent {
  final String persona;

  const DeletePersonEvent({
    required this.persona,
  });

  @override
  List<Object?> get props => [persona];
}

/// 📅 Actualizar asistencias
class UpdateAttendanceEvent extends AttendanceEvent {
  final String persona;
  final List<String> fechas;

  const UpdateAttendanceEvent({
    required this.persona,
    required this.fechas,
  });

  @override
  List<Object?> get props => [persona, fechas];
}
