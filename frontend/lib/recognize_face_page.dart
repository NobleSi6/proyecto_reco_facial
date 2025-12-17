// lib/recognize_face_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'config/api_config.dart'; // ← Importa la configuración

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

  // Personas
  List<String> personasRegistradas = [];
  Map<String, String> estadoPersonas = {};

  @override
  void initState() {
    super.initState();
    ApiConfig.printConfig(); // Debug
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
  //   Cargar personas
  // ========================
  Future<void> cargarPersonas() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.personasUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (!mounted) return;

        setState(() {
          personasRegistradas = List<String>.from(data["personas"] ?? []);

          for (var persona in personasRegistradas) {
            estadoPersonas.putIfAbsent(persona, () => "Ausente");
          }
        });
      } else {
        _showSnack("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _showSnack("Error al cargar personas: $e");
    }
  }

  // ========================
  //   Inicializar cámara
  // ========================
  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras == null || cameras!.isEmpty) {
        setState(() => recognizedName = "No se encontró cámara");
        return;
      }

      // Usa cámara frontal si existe
      final cameraIndex = cameras!.length > 1 ? 1 : 0;

      controller = CameraController(
        cameras![cameraIndex],
        ResolutionPreset.medium,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() {});

      captureTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => captureAndRecognize(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => recognizedName = "Error al iniciar cámara: $e");
      }
    }
  }

  // ========================
  //   Captura y reconocimiento
  // ========================
  Future<void> captureAndRecognize() async {
    if (controller == null || !controller!.value.isInitialized || isProcessing)
      return;

    setState(() => isProcessing = true);

    try {
      final XFile file = await controller!.takePicture();
      final Uint8List imageBytes = await file.readAsBytes();

      final request = http.MultipartRequest(
        "POST",
        Uri.parse(ApiConfig.reconocerUrl),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "imagen",
          imageBytes,
          filename: "${DateTime.now().millisecondsSinceEpoch}.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);

        final nombre = data["nombre"] ?? "Desconocido";

        if (!mounted) return;

        setState(() {
          recognizedName = nombre;

          if (personasRegistradas.contains(nombre) && nombre != "Desconocido") {
            estadoPersonas[nombre] = "Presente";
          }
        });
      } else {
        if (mounted) {
          setState(() => recognizedName = "No identificado");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => recognizedName = "Error: $e");
      }
    }

    if (mounted) {
      setState(() => isProcessing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

          // 📋 Panel lateral
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    color: const Color.fromARGB(255, 48, 44, 92),
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
                              final persona = personasRegistradas[index];
                              final estado =
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
