// lib/register_face_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'config/api_config.dart';

class RegisterFacePage extends StatefulWidget {
  const RegisterFacePage({super.key});

  @override
  State<RegisterFacePage> createState() => _RegisterFacePageState();
}

class _RegisterFacePageState extends State<RegisterFacePage> {
  CameraController? _controller;
  bool cameraReady = false;
  bool isCapturing = false;
  String nombre = "";
  int fotosTomadas = 0;
  int fotosEnviadas = 0;

  @override
  void initState() {
    super.initState();
    ApiConfig.printConfig(); // Debug
    iniciarCamara();
  }

  Future<void> iniciarCamara() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showSnack("No se encontró cámara");
        return;
      }

      // Usa cámara frontal si existe
      final camera = cameras.length > 1 ? cameras[1] : cameras[0];

      _controller = CameraController(camera, ResolutionPreset.medium);

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => cameraReady = true);
    } catch (e) {
      _showSnack("Error iniciando cámara: $e");
    }
  }

  /// Enviar foto al servidor usando http multipart
  Future<bool> enviarFotoAlServidor(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.registrarFotoUrl),
      );

      // Agregar el nombre como campo
      request.fields['nombre'] = nombre;

      // Agregar la imagen
      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          imageBytes,
          filename: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("⚠️ Error del servidor: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Error enviando foto: $e");
      return false;
    }
  }

  Future<void> capturarYEnviar() async {
    if (!cameraReady || _controller == null || nombre.isEmpty) {
      _showSnack("Ingresa un nombre primero");
      return;
    }

    try {
      final foto = await _controller!.takePicture();
      final bytes = await foto.readAsBytes();

      setState(() => fotosTomadas++);

      // Enviar al servidor
      final enviado = await enviarFotoAlServidor(bytes);

      if (enviado) {
        setState(() => fotosEnviadas++);
      }
    } catch (e) {
      print("Error capturando foto: $e");
    }
  }

  Future<void> capturarMultiplesFotos() async {
    if (isCapturing) return;

    if (nombre.trim().isEmpty) {
      _showSnack("Por favor ingresa un nombre");
      return;
    }

    setState(() {
      isCapturing = true;
      fotosTomadas = 0;
      fotosEnviadas = 0;
    });

    while (fotosTomadas < 300 && isCapturing) {
      await capturarYEnviar();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => isCapturing = false);

    if (mounted) {
      _showSnack(
        "✅ Proceso terminado: $fotosEnviadas fotos enviadas correctamente",
      );
    }
  }

  void detenerCaptura() {
    setState(() => isCapturing = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Rostro"), centerTitle: false),
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
            child: cameraReady && _controller != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CameraPreview(_controller!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 16),

          /// 📊 Contador
          Text(
            "Fotos tomadas: $fotosTomadas / 300",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          Text(
            "Fotos enviadas: $fotosEnviadas",
            style: const TextStyle(fontSize: 16, color: Colors.green),
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
                label: Text(
                  isCapturing ? "Capturando…" : "Registrar 300 fotos",
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
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
    _controller?.dispose();
    super.dispose();
  }
}
