// lib/config/api_config.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  // 🔧 CAMBIA ESTA IP POR LA IP DE TU COMPUTADORA
  static const String _serverIp = "192.168.1.7"; // ← Tu IP aquí
  static const String _serverPort = "8000";

  /// Retorna la URL base según la plataforma
  static String get baseUrl {
    if (kIsWeb) {
      // Web: usa localhost
      return "http://127.0.0.1:$_serverPort";
    } else if (Platform.isAndroid) {
      // Android Emulador: usa 10.0.2.2
      // Android Real: usa la IP de tu computadora
      // Para detectar si es emulador, usa la IP real por defecto
      return "http://$_serverIp:$_serverPort";
    } else if (Platform.isIOS) {
      // iOS: usa la IP de tu computadora
      return "http://$_serverIp:$_serverPort";
    } else {
      // Fallback para otras plataformas
      return "http://$_serverIp:$_serverPort";
    }
  }

  // URLs específicas
  static String get reconocerUrl => "$baseUrl/reconocer";
  static String get personasUrl => "$baseUrl/personas";
  static String get registrarFotoUrl => "$baseUrl/registrar_foto";
  static String get asistenciasUrl => "$baseUrl/asistencias";

  /// Para debugging
  static void printConfig() {
    print("🌐 API Config:");
    print("   Base URL: $baseUrl");
    print("   Platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}");
  }
}
