import 'package:flutter/material.dart';

class RecognizeFacePage extends StatelessWidget {
  const RecognizeFacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reconocer Rostro")),
      body: const Center(child: Text("📷 Aquí va tu código de reconocimiento facial")),
    );
  }
}