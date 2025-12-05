import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RecognizeFacePage extends StatefulWidget {
  const RecognizeFacePage({super.key});

  @override
  RecognizeFacePageState createState() => RecognizeFacePageState();
}

class RecognizeFacePageState extends State<RecognizeFacePage> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  String recognizedName = "Esperando...";
  Timer? captureTimer;
  bool isProcessing = false;

  // Lista de personas registradas
  List<String> personasRegistradas = [];

  // Mapa para guardar estado de presencia
  Map<String, String> estadoPersonas = {};

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU COMPUTADORA
  static const String BASE_URL = "http://192.168.1.10:8000";

  @override
  void initState() {
    super.initState();
    initCamera();
    cargarPersonas();
  }

  @override
  void dispose() {
    captureTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  // ========================
  //   Cargar lista personas
  // ========================
  Future<void> cargarPersonas() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/personas'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          personasRegistradas = List<String>.from(data["personas"] ?? []);

          // Todas empiezan ausentes, excepto las ya marcadas
          for (var persona in personasRegistradas) {
            estadoPersonas.putIfAbsent(persona, () => "Ausente");
          }
        });
      }
    } catch (e) {
      print("❌ Error al cargar personas: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al cargar personas: $e")));
      }
    }
  }

  // ========================
  //   Inicializar cámara
  // ========================
  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras!.isNotEmpty) {
        // Usar cámara frontal si está disponible (índice 1), sino usar la primera
        final cameraIndex = cameras!.length > 1 ? 1 : 0;
        controller = CameraController(
          cameras![cameraIndex],
          ResolutionPreset.medium,
        );
        await controller!.initialize();

        if (!mounted) return;

        setState(() {});

        // Iniciar captura automática cada 5 segundos
        captureTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => captureAndRecognize(),
        );
      } else {
        setState(() => recognizedName = "No se encontró cámara.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => recognizedName = "Error al iniciar cámara: $e");
      }
    }
  }

  // ========================
  //   Capturar y reconocer
  // ========================
  Future<void> captureAndRecognize() async {
    if (controller == null || !controller!.value.isInitialized || isProcessing)
      return;

    setState(() => isProcessing = true);

    try {
      XFile file = await controller!.takePicture();
      Uint8List imageBytes = await file.readAsBytes();

      var request = http.MultipartRequest(
        "POST",
        Uri.parse('$BASE_URL/reconocer'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          "imagen",
          imageBytes,
          filename: "${DateTime.now().millisecondsSinceEpoch}.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      var response = await request.send().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        var data = json.decode(body);
        String nombreReconocido = data["nombre"] ?? "Desconocido";

        if (!mounted) return;

        setState(() {
          recognizedName = nombreReconocido;

          // 🔥 SOLO MARCA PRESENTE AL RECONOCIDO
          // NO CAMBIA EL ESTADO DE LOS DEMÁS
          if (personasRegistradas.contains(nombreReconocido) &&
              nombreReconocido != "Desconocido") {
            estadoPersonas[nombreReconocido] = "Presente";
          }
        });
      } else {
        if (mounted) {
          setState(() => recognizedName = "No identificado");
        }
      }
    } catch (e) {
      print("❌ Error en reconocimiento: $e");
      if (mounted) {
        setState(() => recognizedName = "Error: $e");
      }
    }

    if (mounted) {
      setState(() => isProcessing = false);
    }
  }

  // ========================
  //           UI
  // ========================
  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text("Reconocer Rostro")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Reconocer Rostro")),
      body: Row(
        children: [
          // 📸 Cámara
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                CameraPreview(controller!),
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isProcessing ? "Procesando..." : recognizedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📋 Lista personas + estado
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color.fromARGB(255, 48, 44, 92),
                    width: double.infinity,
                    child: const Text(
                      "Personas Registradas",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: cargarPersonas,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      "Actualizar",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: personasRegistradas.isEmpty
                        ? const Center(
                            child: Text(
                              "No hay personas registradas",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: personasRegistradas.length,
                            itemBuilder: (context, index) {
                              String persona = personasRegistradas[index];
                              String estado =
                                  estadoPersonas[persona] ?? "Ausente";

                              return ListTile(
                                leading: Icon(
                                  Icons.person,
                                  color: estado == "Presente"
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(
                                  persona,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: Text(
                                  estado,
                                  style: TextStyle(
                                    color: estado == "Presente"
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
