import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bloc/attendance_bloc.dart';
import 'bloc/attendance_event.dart';
import 'bloc/attendance_state.dart';
import 'models/attendance_model.dart';
import 'services/attendance_service.dart';

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterMode = 'today'; // 'today', 'date', 'range'

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _selectDate(BuildContext context,
      {bool isStartDate = true}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (_filterMode == 'date') {
          _selectedDate = picked;
        } else if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _loadAttendance(BuildContext context) {
    if (_filterMode == 'today') {
      context.read<AttendanceBloc>().add(LoadTodayAttendance());
    } else if (_filterMode == 'date' && _selectedDate != null) {
      context.read<AttendanceBloc>().add(
            LoadAttendanceByDate(_formatDate(_selectedDate!)),
          );
    } else if (_filterMode == 'range' &&
        _startDate != null &&
        _endDate != null) {
      context.read<AttendanceBloc>().add(
            LoadAttendanceByRange(
              _formatDate(_startDate!),
              _formatDate(_endDate!),
            ),
          );
    }
  }

  void _exportToExcel(BuildContext context) {
    if (_filterMode == 'today') {
      context.read<AttendanceBloc>().add(
            ExportToExcel(
              fechaInicio: _formatDate(DateTime.now()),
            ),
          );
    } else if (_filterMode == 'date' && _selectedDate != null) {
      context.read<AttendanceBloc>().add(
            ExportToExcel(
              fechaInicio: _formatDate(_selectedDate!),
            ),
          );
    } else if (_filterMode == 'range' &&
        _startDate != null &&
        _endDate != null) {
      context.read<AttendanceBloc>().add(
            ExportToExcel(
              fechaInicio: _formatDate(_startDate!),
              fechaFin: _formatDate(_endDate!),
            ),
          );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceBloc(
        attendanceService: AttendanceService(),
      )..add(LoadTodayAttendance()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reporte de Asistencias'),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                context.read<AttendanceBloc>().add(LoadStudentsList());
              },
              tooltip: 'Ver todos los estudiantes',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterSection(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar asistencias:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'today',
                      label: Text('Hoy'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: 'date',
                      label: Text('Fecha'),
                      icon: Icon(Icons.calendar_today),
                    ),
                    ButtonSegment(
                      value: 'range',
                      label: Text('Rango'),
                      icon: Icon(Icons.date_range),
                    ),
                  ],
                  selected: {_filterMode},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _filterMode = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_filterMode == 'date') _buildDateSelector(),
          if (_filterMode == 'range') _buildRangeSelector(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadAttendance(context),
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportToExcel(context),
                  icon: const Icon(Icons.file_download),
                  label: const Text('Exportar Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return ListTile(
      title: Text(
        _selectedDate != null
            ? 'Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'
            : 'Seleccionar fecha',
      ),
      leading: const Icon(Icons.calendar_today),
      onTap: () => _selectDate(context),
      tileColor: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildRangeSelector() {
    return Column(
      children: [
        ListTile(
          title: Text(
            _startDate != null
                ? 'Desde: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'
                : 'Fecha inicio',
          ),
          leading: const Icon(Icons.calendar_today),
          onTap: () => _selectDate(context, isStartDate: true),
          tileColor: Colors.grey[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(
            _endDate != null
                ? 'Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                : 'Fecha fin',
          ),
          leading: const Icon(Icons.calendar_today),
          onTap: () => _selectDate(context, isStartDate: false),
          tileColor: Colors.grey[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        if (state is ExcelReady) {
          _launchUrl(state.downloadUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Descargando Excel...'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is AttendanceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AttendanceLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is AttendanceLoaded) {
          return _buildAttendanceTable(state);
        } else if (state is StudentsListLoaded) {
          return _buildStudentsList(state);
        } else if (state is AttendanceError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadAttendance(context),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        return const Center(
            child: Text('Selecciona un filtro y presiona Buscar'));
      },
    );
  }

  Widget _buildAttendanceTable(AttendanceLoaded state) {
    if (state.asistencias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay registros de asistencia'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.fecha,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text('Total: ${state.total}'),
                backgroundColor: Colors.green,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Código')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Hora')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: List.generate(
                  state.asistencias.length,
                  (index) {
                    final asistencia = state.asistencias[index];
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(asistencia.nombre)),
                        DataCell(Text(asistencia.codigo ?? 'N/A')),
                        DataCell(Text(asistencia.fecha)),
                        DataCell(Text(asistencia.hora)),
                        DataCell(
                          Chip(
                            label: Text(asistencia.estado),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsList(StudentsListLoaded state) {
    if (state.estudiantes.isEmpty) {
      return const Center(child: Text('No hay estudiantes registrados'));
    }

    return ListView.builder(
      itemCount: state.estudiantes.length,
      itemBuilder: (context, index) {
        final student = state.estudiantes[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(student.nombre[0].toUpperCase()),
          ),
          title: Text(student.nombre),
          subtitle: Text('Código: ${student.codigo ?? "N/A"}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${student.totalAsistencias} asistencias'),
              if (student.ultimaAsistencia != null)
                Text(
                  student.ultimaAsistencia!,
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
          onTap: () {
            context
                .read<AttendanceBloc>()
                .add(LoadStudentHistory(student.nombre));
          },
        );
      },
    );
  }
}
