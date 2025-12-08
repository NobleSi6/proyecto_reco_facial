import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/attendance_service.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceService attendanceService;

  AttendanceBloc({required this.attendanceService})
      : super(AttendanceInitial()) {
    on<LoadTodayAttendance>(_onLoadTodayAttendance);
    on<LoadAttendanceByDate>(_onLoadAttendanceByDate);
    on<LoadAttendanceByRange>(_onLoadAttendanceByRange);
    on<LoadStudentHistory>(_onLoadStudentHistory);
    on<LoadStudentsList>(_onLoadStudentsList);
    on<ExportToExcel>(_onExportToExcel);
  }

  Future<void> _onLoadTodayAttendance(
    LoadTodayAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final response = await attendanceService.getAttendanceToday();
      emit(AttendanceLoaded(
        asistencias: response.asistencias,
        fecha: response.fecha,
        total: response.total,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onLoadAttendanceByDate(
    LoadAttendanceByDate event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final response = await attendanceService.getAttendanceByDate(event.fecha);
      emit(AttendanceLoaded(
        asistencias: response.asistencias,
        fecha: response.fecha,
        total: response.total,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onLoadAttendanceByRange(
    LoadAttendanceByRange event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final response = await attendanceService.getAttendanceByRange(
        event.fechaInicio,
        event.fechaFin,
      );
      emit(AttendanceLoaded(
        asistencias: response.asistencias,
        fecha: '${event.fechaInicio} - ${event.fechaFin}',
        total: response.total,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onLoadStudentHistory(
    LoadStudentHistory event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final historial = await attendanceService.getStudentHistory(event.nombre);
      emit(StudentHistoryLoaded(
        nombre: event.nombre,
        historial: historial,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onLoadStudentsList(
    LoadStudentsList event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(AttendanceLoading());
    try {
      final response = await attendanceService.getAllStudents();
      emit(StudentsListLoaded(
        estudiantes: response.estudiantes,
        total: response.total,
      ));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<void> _onExportToExcel(
    ExportToExcel event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      final url = attendanceService.getExcelDownloadUrl(
        fechaInicio: event.fechaInicio,
        fechaFin: event.fechaFin,
      );
      emit(ExcelReady(url));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }
}
