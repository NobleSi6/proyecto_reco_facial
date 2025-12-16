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
    _controller = CameraController(cameras.length > 1 ? cameras[1] : cameras[0], ResolutionPreset.medium);

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

    request.onLoadEnd.listen((_) {
      if (request.status != 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error enviando una foto al servidor")),
        );
      }
    });
  }

  Future<void> capturarYEnviar() async {
    if (!cameraReady || nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un nombre primero")),
      );
      return;
    }

    final foto = await _controller.takePicture();
    final bytes = await foto.readAsBytes();
    final pngFile = html.File([bytes], 'foto.png', {'type': 'image/png'});

    setState(() => fotosTomadas++);

    enviarFotoAlServidor(pngFile);
  }

  Future<void> capturarMultiplesFotos() async {
    if (isCapturing) return;

    setState(() => isCapturing = true);

    while (fotosTomadas < 300 && isCapturing) {
      await capturarYEnviar();
      await Future.delayed(const Duration(milliseconds: 300));
    }

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
      appBar: AppBar(
        title: const Text("Registrar Rostro"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          /// 🔹 Campo nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              enabled: !isCapturing,
              decoration: InputDecoration(
                labelText: "Nombre de la persona",
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => nombre = v,
            ),
          ),

          const SizedBox(height: 16),

          /// 📸 Cámara
          Expanded(
            child: cameraReady
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CameraPreview(_controller),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 16),

          /// 📊 Contador
          Text(
            "Fotos tomadas: $fotosTomadas / 300",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          if (isCapturing)
            const Text(
              "📸 Capturando fotos...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 12),

          /// 🔘 Botones
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera),
                onPressed: isCapturing ? null : capturarMultiplesFotos,
                label: Text(isCapturing ? "Capturando…" : "Registrar 300 fotos"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              if (isCapturing) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  onPressed: detenerCaptura,
                  label: const Text("Detener"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
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
