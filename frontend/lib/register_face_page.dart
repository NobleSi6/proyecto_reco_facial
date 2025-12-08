import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  // ⚠️ CAMBIAR ESTA IP POR LA IP DE TU COMPUTADORA
  static const String BASE_URL = "http://192.168.1.10:8000";

  @override
  void initState() {
    super.initState();
    iniciarCamara();
  }

  Future<void> iniciarCamara() async {
    final cameras = await availableCameras();
    // Usar cámara frontal (index 1) o trasera (index 0)
    final cameraIndex = cameras.length > 1 ? 1 : 0;
    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
    );

    await _controller.initialize();

    if (!mounted) return;
    setState(() => cameraReady = true);
  }

  Future<void> enviarFotoAlServidor(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$BASE_URL/registrar_foto'),
      );

      request.fields['nombre'] = nombre;
      request.files.add(await http.MultipartFile.fromPath('imagen', imagePath));

      var response = await request.send();

      if (response.statusCode != 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error enviando foto al servidor")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
    }
  }

  Future<void> capturarYEnviar() async {
    if (!cameraReady || nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un nombre primero")),
      );
      return;
    }

    try {
      final foto = await _controller.takePicture();

      if (!mounted) return;

      // Actualizar contador
      setState(() {
        fotosTomadas++;
      });

      // Enviar al servidor
      await enviarFotoAlServidor(foto.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error capturando foto: $e")));
      }
    }
  }

  Future<void> capturarMultiplesFotos() async {
    if (isCapturing) return;

    if (!mounted) return;
    setState(() => isCapturing = true);

    while (fotosTomadas < 300 && isCapturing) {
      await capturarYEnviar();

      // Pequeño delay entre capturas
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
    }

    if (!mounted) return;

    setState(() => isCapturing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Todas las fotos enviadas al servidor")),
    );
  }

  void detenerCaptura() {
    setState(() => isCapturing = false);
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
              enabled: !isCapturing,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isCapturing ? null : capturarMultiplesFotos,
                child: isCapturing
                    ? const Text("Capturando…")
                    : const Text("Registrar 300 fotos"),
              ),
              if (isCapturing) ...[
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: detenerCaptura,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Detener"),
                ),
              ],
            ],
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
