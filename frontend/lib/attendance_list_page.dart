import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'bloc/attendance_bloc.dart';
import 'bloc/attendance_event.dart';
import 'bloc/attendance_state.dart';

class AttendanceListPage extends StatefulWidget {
  const AttendanceListPage({super.key});

  @override
  State<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  final DateFormat _isoFormat = DateFormat("yyyy-MM-dd");
  final DateFormat _legacyFormat =
      DateFormat("EEE MMM d HH:mm:ss yyyy", "en_US");

  // ===============================
  // PARSEO SEGURO DE FECHAS
  // ===============================
  DateTime? _parseFecha(String raw) {
    final clean = raw.replaceFirst("Asistencia: ", "").trim();

    try {
      return DateTime.parse(clean);
    } catch (_) {
      try {
        return _legacyFormat.parse(clean);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AttendanceBloc>().add(const FetchAttendanceEvent());
  }

  // ===============================
  // VER CALENDARIO (LECTURA)
  // ===============================
  void _verCalendario(BuildContext context, List<String> fechas) {
    final Set<DateTime> dias =
        fechas.map(_parseFecha).whereType<DateTime>().toSet();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Días asistidos"),
        content: SizedBox(
          width: double.maxFinite,
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: DateTime.now(),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                final asistio = dias.any((d) => isSameDay(d, day));

                if (asistio) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          )
        ],
      ),
    );
  }

  // ===============================
  // EDITAR NOMBRE
  // ===============================
  void _editarNombre(BuildContext context, String nombreActual) {
    final controller = TextEditingController(text: nombreActual);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar nombre"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nombre"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AttendanceBloc>().add(
                    UpdatePersonNameEvent(
                      oldName: nombreActual,
                      newName: controller.text.trim(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ===============================
  // EDITAR ASISTENCIAS
  // ===============================
  void _editarAsistencias(
    BuildContext parentContext,
    String persona,
    List<String> fechas,
  ) {
    final Set<DateTime> seleccionadas =
        fechas.map(_parseFecha).whereType<DateTime>().toSet();

    showDialog(
      context: parentContext,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Editar asistencias"),
          content: SizedBox(
            width: double.maxFinite,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: DateTime.now(),
              selectedDayPredicate: (day) =>
                  seleccionadas.any((d) => isSameDay(d, day)),
              onDaySelected: (day, _) {
                setDialogState(() {
                  if (seleccionadas.any((d) => isSameDay(d, day))) {
                    seleccionadas.removeWhere((d) => isSameDay(d, day));
                  } else {
                    seleccionadas.add(day);
                  }
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                parentContext.read<AttendanceBloc>().add(
                      UpdateAttendanceEvent(
                        persona: persona,
                        fechas: seleccionadas
                            .map((d) => _isoFormat.format(d))
                            .toList(),
                      ),
                    );
                Navigator.pop(parentContext);
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // ELIMINAR PERSONA
  // ===============================
  void _eliminarPersona(BuildContext context, String persona) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar persona"),
        content: const Text("¿Seguro que deseas eliminar este registro?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AttendanceBloc>().add(
                    DeletePersonEvent(persona: persona),
                  );
              Navigator.pop(context);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Asistencias"),
        centerTitle: false,
        backgroundColor: const Color.fromARGB(0, 25, 45, 95),
      ),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (context, state) {
          if (state is AttendanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AttendanceError) {
            return Center(child: Text(state.message));
          }

          if (state is AttendanceLoaded) {
            final data = state.asistencias;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Nro.")),
                  DataColumn(label: Text("Persona")),
                  DataColumn(label: Text("Calendario")),
                  DataColumn(label: Text("Asistencias")),
                  DataColumn(label: Text("Acciones")),
                ],
                rows: data.asMap().entries.map<DataRow>((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final persona = item["persona"] as String;
                  final fechas =
                      (item["fechas"] as List<dynamic>).cast<String>();

                  return DataRow(cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(persona)),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: fechas.isEmpty
                            ? null
                            : () => _verCalendario(context, fechas),
                      ),
                    ),
                    DataCell(Chip(label: Text(fechas.length.toString()))),
                    DataCell(
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "editar") {
                            _editarNombre(context, persona);
                          } else if (value == "asistencia") {
                            _editarAsistencias(context, persona, fechas);
                          } else if (value == "eliminar") {
                            _eliminarPersona(context, persona);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: "editar",
                            child: Text("Editar nombre"),
                          ),
                          PopupMenuItem(
                            value: "asistencia",
                            child: Text("Editar asistencias"),
                          ),
                          PopupMenuItem(
                            value: "eliminar",
                            child: Text("Eliminar"),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}
