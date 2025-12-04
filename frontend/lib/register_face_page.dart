import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class RegisterFacePage extends StatefulWidget {
  const RegisterFacePage({super.key});

  @override
  RegisterFacePageState createState() => RegisterFacePageState();
}

class RegisterFacePageState extends State<RegisterFacePage> {
  late CameraController _controller;
  bool cameraReady = false;
  bool isCapturing = false;
  String nombre = "";
  int fotosTomadas = 0;

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

  Future<void> enviarFotoAlServidor(html.File imagen) async {
    var formData = html.FormData();
    formData.append('nombre', nombre);
    formData.appendBlob('imagen', imagen, 'foto.png');

    var request = html.HttpRequest();
    request.open('POST', 'http://127.0.0.1:8000/registrar_foto');
    request.send(formData);

    request.onLoadEnd.listen((event) {
      if (request.status != 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error enviando una foto al servidor")),
        );
      }
    });
  }

  Future<void> capturarYEnviar() async {
    if (!cameraReady || nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un nombre primero")),
      );
      return;
    }

    final foto = await _controller.takePicture();

    // Convertir JPEG → PNG rápido usando Web Blob
    final bytes = await foto.readAsBytes();
    final pngFile = html.File([bytes], 'foto.png', {'type': 'image/png'});

    if (!mounted) return;

    // Actualizar contador
    setState(() {
      fotosTomadas++;
    });

    // Enviar inmediatamente al servidor 🚀
    enviarFotoAlServidor(pngFile);
  }

  Future<void> capturarMultiplesFotos() async {
    if (isCapturing) return;

    if (!mounted) return;
    setState(() => isCapturing = true);

    while (fotosTomadas < 300) {
      await capturarYEnviar();

      // Disminuir retraso → MÁS RÁPIDO
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
    }

    if (!mounted) return;

    setState(() => isCapturing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Todas las fotos enviadas al servidor")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Rostro")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Nombre de la persona",
              ),
              onChanged: (v) => nombre = v,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: cameraReady
                ? CameraPreview(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 20),

          Text(
            "Fotos tomadas: $fotosTomadas / 300",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          if (isCapturing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "📸 Capturando fotos...",
                style: TextStyle(fontSize: 18, color: Colors.amber),
              ),
            ),

          ElevatedButton(
            onPressed: isCapturing ? null : capturarMultiplesFotos,
            child: isCapturing
                ? const Text("Capturando…")
                : const Text("Registrar 300 fotos"),
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
