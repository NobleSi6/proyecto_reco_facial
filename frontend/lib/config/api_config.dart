import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    } else {
      return "http://10.0.2.2:8000"; // emulador
      // return "http://192.168.1.35:8000"; // celular físico
    }
  }
}
