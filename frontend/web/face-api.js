import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<bool> detectarRostro(html.File foto) async {
  final reader = html.FileReader();  // Usamos FileReader para leer la imagen
  final completer = Completer<bool>();

  // Leer el archivo como ArrayBuffer
  reader.readAsArrayBuffer(foto);

  reader.onLoadEnd.listen((event) async {
    final bytes = reader.result as Uint8List;
    final blob = html.Blob([bytes]);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final image = html.ImageElement(src: objectUrl);

    image.onLoad.listen((e) async {
      // Esperamos a que face-api.js cargue y se inicialice
      await html.window.document!.createElement('script')
        ..src = 'https://cdn.jsdelivr.net/npm/face-api.js'
        ..defer = true;

      // Inicializar face-api.js (esto es necesario para cargar los modelos)
      await html.window.document!.readyState;

      // Detectar los rostros con face-api.js
      try {
        final faces = await html.window.faceapi!.detectAllFaces(image);

        // Si se detectan rostros, retornamos true, de lo contrario, false
        completer.complete(faces.isNotEmpty);
      } catch (e) {
        print("Error en la detección de rostros: $e");
        completer.complete(false);
      }
    });
  });

  return completer.future;
}
