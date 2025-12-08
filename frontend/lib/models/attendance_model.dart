class AttendanceRecord {
  final String nombre;
  final String? codigo;
  final String fecha;
  final String hora;
  final String estado;

  AttendanceRecord({
    required this.nombre,
    this.codigo,
    required this.fecha,
    required this.hora,
    this.estado = 'presente',
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      nombre: json['nombre'] ?? 'Sin nombre',
      codigo: json['codigo'],
      fecha: json['fecha'] ?? '',
      hora: json['hora'] ?? '',
      estado: json['estado'] ?? 'presente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'codigo': codigo,
      'fecha': fecha,
      'hora': hora,
      'estado': estado,
    };
  }
}

class Student {
  final int id;
  final String nombre;
  final String? codigo;
  final int totalAsistencias;
  final String? ultimaAsistencia;

  Student({
    required this.id,
    required this.nombre,
    this.codigo,
    required this.totalAsistencias,
    this.ultimaAsistencia,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Sin nombre',
      codigo: json['codigo'],
      totalAsistencias: json['total_asistencias'] ?? 0,
      ultimaAsistencia: json['ultima_asistencia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'total_asistencias': totalAsistencias,
      'ultima_asistencia': ultimaAsistencia,
    };
  }
}

class AttendanceResponse {
  final String fecha;
  final int total;
  final List<AttendanceRecord> asistencias;

  AttendanceResponse({
    required this.fecha,
    required this.total,
    required this.asistencias,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      fecha: json['fecha'] ?? '',
      total: json['total'] ?? 0,
      asistencias: (json['asistencias'] as List?)
              ?.map((item) => AttendanceRecord.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class StudentsResponse {
  final int total;
  final List<Student> estudiantes;

  StudentsResponse({
    required this.total,
    required this.estudiantes,
  });

  factory StudentsResponse.fromJson(Map<String, dynamic> json) {
    return StudentsResponse(
      total: json['total'] ?? 0,
      estudiantes: (json['estudiantes'] as List?)
              ?.map((item) => Student.fromJson(item))
              .toList() ??
          [],
    );
  }
}
