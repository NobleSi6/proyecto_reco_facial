import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class RecognizeFacePage extends StatefulWidget {
  @override
  _RecognizeFacePageState createState() => _RecognizeFacePageState();
}

class _RecognizeFacePageState extends State<RecognizeFacePage> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  String recognizedName = "Esperando...";
  Timer? captureTimer;
  bool isProcessing = false;

  // Lista de personas registradas
  List<String> personasRegistradas = [];

  // Mapa para guardar estado de presencia
  Map<String, String> estadoPersonas = {};

  // URLs del servidor
  final String reconocerUrl = kIsWeb
      ? "http://127.0.0.1:8000/reconocer"
      : "http://10.0.2.2:8000/reconocer";

  final String personasUrl = kIsWeb
      ? "http://127.0.0.1:8000/personas"
      : "http://10.0.2.2:8000/personas";

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
      final response = await http.get(Uri.parse(personasUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          personasRegistradas = List<String>.from(data["personas"]);

          // Todas empiezan ausentes, excepto las ya marcadas
          for (var persona in personasRegistradas) {
            estadoPersonas.putIfAbsent(persona, () => "Ausente");
          }
        });
      }
    } catch (e) {
      print("❌ Error al cargar personas: $e");
    }
  }

  // ========================
  //   Inicializar cámara
  // ========================
  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();

      if (cameras!.isNotEmpty) {
        controller = CameraController(cameras!.first, ResolutionPreset.medium);
        await controller!.initialize();

        setState(() {});

        captureTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => captureAndRecognize(),
        );
      } else {
        setState(() => recognizedName = "No se encontró cámara.");
      }
    } catch (e) {
      setState(() => recognizedName = "Error al iniciar cámara: $e");
    }
  }

  // ========================
  //   Capturar y reconocer
  // ========================
  Future<void> captureAndRecognize() async {
    if (controller == null || !controller!.value.isInitialized || isProcessing) return;

    setState(() => isProcessing = true);

    try {
      XFile file = await controller!.takePicture();
      Uint8List imageBytes = await file.readAsBytes();

      var request = http.MultipartRequest("POST", Uri.parse(reconocerUrl));
      request.files.add(
        http.MultipartFile.fromBytes(
          "imagen",
          imageBytes,
          filename: "${DateTime.now().millisecondsSinceEpoch}.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        var data = json.decode(body);
        String nombreReconocido = data["nombre"] ?? "Desconocido";

        setState(() {
          recognizedName = nombreReconocido;

          // 🔥 SOLO MARCA PRESENTE AL RECONOCIDO
          // NO CAMBIA EL ESTADO DE LOS DEMÁS
          if (personasRegistradas.contains(nombreReconocido)) {
            estadoPersonas[nombreReconocido] = "Presente";
          }
        });
      } else {
        setState(() => recognizedName = "No identificado");
      }
    } catch (e) {
      setState(() => recognizedName = "Error: $e");
    }

    setState(() => isProcessing = false);
  }

  // ========================
  //           UI
  // ========================
  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text("Reconocer Rostro")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Reconocer Rostro")),
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
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isProcessing ? "Procesando..." : recognizedName,
                        style: TextStyle(color: Colors.white, fontSize: 22),
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
                    padding: EdgeInsets.all(12),
                    color: Color.fromARGB(255, 48, 44, 92),
                    width: double.infinity,
                    child: Text(
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
                    icon: Icon(Icons.refresh, color: Colors.white),
                    label: Text("Actualizar", style: TextStyle(color: Colors.white)),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: personasRegistradas.length,
                      itemBuilder: (context, index) {
                        String persona = personasRegistradas[index];
                        String estado = estadoPersonas[persona] ?? "Ausente";

                        return ListTile(
                          leading: Icon(
                            Icons.person,
                            color: estado == "Presente" ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            persona,
                            style: TextStyle(color: Colors.white),
                          ),
                          trailing: Text(
                            estado,
                            style: TextStyle(
                              color: estado == "Presente" ? Colors.green : Colors.red,
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
