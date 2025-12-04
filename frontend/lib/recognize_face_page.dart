import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class RecognizeFacePage extends StatefulWidget {
  const RecognizeFacePage({super.key});

  @override
  RecognizeFacePageState createState() => RecognizeFacePageState();
}

class RecognizeFacePageState extends State<RecognizeFacePage> {
  late CameraController _controller;
  bool cameraReady = false;
  bool isRecognizing = false;
  String resultadoReconocimiento = "";

  @override
  void initState() {
    super.initState();
    iniciarCamara();
  }

  Future<void> iniciarCamara() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras[1], ResolutionPreset.medium);

    await _controller.initialize();

    if (!mounted) return;
    setState(() => cameraReady = true);
  }

  Future<void> reconocerRostro() async {
    if (!cameraReady || isRecognizing) return;

    if (!mounted) return;
    setState(() {
      isRecognizing = true;
      resultadoReconocimiento = "Analizando...";
    });

    try {
      // Capturar foto
      final foto = await _controller.takePicture();
      final bytes = await foto.readAsBytes();
      final imageFile = html.File([bytes], 'rostro.png', {'type': 'image/png'});

      // Preparar FormData
      var formData = html.FormData();
      formData.appendBlob('imagen', imageFile, 'rostro.png');

      // Enviar al servidor
      var request = html.HttpRequest();
      request.open('POST', 'http://127.0.0.1:8000/reconocer_rostro');

      request.onLoadEnd.listen((event) {
        if (!mounted) return;

        if (request.status == 200) {
          try {
            final response = jsonDecode(request.responseText!);

            setState(() {
              if (response['nombre'] != null &&
                  response['nombre'] != "Desconocido") {
                resultadoReconocimiento =
                    "✅ Persona reconocida:\n${response['nombre']}";
              } else if (response['nombre'] == "Desconocido") {
                resultadoReconocimiento = "❌ Persona no reconocida";
              } else if (response['error'] != null) {
                resultadoReconocimiento = "⚠️ ${response['error']}";
              } else {
                resultadoReconocimiento =
                    "⚠️ Respuesta inesperada del servidor";
              }
              isRecognizing = false;
            });
          } catch (e) {
            setState(() {
              resultadoReconocimiento = "⚠️ Error procesando respuesta";
              isRecognizing = false;
            });
          }
        } else {
          setState(() {
            resultadoReconocimiento = "⚠️ Error de conexión con el servidor";
            isRecognizing = false;
          });
        }
      });

      request.send(formData);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        resultadoReconocimiento = "⚠️ Error al capturar imagen";
        isRecognizing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reconocer Rostro")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Expanded(
            child: cameraReady
                ? CameraPreview(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 20),

          if (resultadoReconocimiento.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultadoReconocimiento.contains("✅")
                    ? Colors.green.shade50
                    : resultadoReconocimiento.contains("❌")
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: resultadoReconocimiento.contains("✅")
                      ? Colors.green
                      : resultadoReconocimiento.contains("❌")
                      ? Colors.red
                      : Colors.orange,
                  width: 2,
                ),
              ),
              child: Text(
                resultadoReconocimiento,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: isRecognizing ? null : reconocerRostro,
            icon: isRecognizing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.face),
            label: Text(isRecognizing ? "Reconociendo..." : "Reconocer Rostro"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
