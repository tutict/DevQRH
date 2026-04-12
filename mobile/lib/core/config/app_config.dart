import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  static const _envBaseUrl = String.fromEnvironment('DEVQRH_API_BASE_URL');

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
