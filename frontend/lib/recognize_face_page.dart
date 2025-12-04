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

  final String serverUrl = kIsWeb
      ? "http://127.0.0.1:8000/reconocer"
      : "http://10.0.2.2:8000/reconocer"; // Android usa localhost diferente

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    captureTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras!.isNotEmpty) {
        controller = CameraController(cameras!.first, ResolutionPreset.medium);
        await controller!.initialize();
        setState(() {});

        // Captura automática cada 5 segundos
        captureTimer = Timer.periodic(
            const Duration(seconds: 5), (_) => captureAndRecognize());
      } else {
        setState(() => recognizedName = "No se encontró cámara.");
      }
    } catch (e) {
      setState(() => recognizedName = "Error al iniciar cámara: $e");
    }
  }

  Future<void> captureAndRecognize() async {
    if (controller == null || !controller!.value.isInitialized || isProcessing) return;

    setState(() => isProcessing = true);

    try {
      XFile file = await controller!.takePicture();

      Uint8List imageBytes = await file.readAsBytes();
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      var request = http.MultipartRequest("POST", Uri.parse(serverUrl));
      request.files.add(
        http.MultipartFile.fromBytes(
          "imagen",
          imageBytes,
          filename: fileName,
          contentType: MediaType("image", "jpeg"),
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        var data = json.decode(respStr);

        setState(() {
          recognizedName = data["nombre"] ?? "Desconocido";
        });
      } else {
        setState(() {
          recognizedName = "No identificado";
        });
      }
    } catch (e) {
      setState(() => recognizedName = "Error: $e");
    }

    setState(() => isProcessing = false);
  }

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
      body: Stack(
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
    );
  }
}
