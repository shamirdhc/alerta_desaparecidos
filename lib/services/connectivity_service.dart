import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static const List<String> _testHosts = [
    'google.com',
    'firebase.google.com',
    'identitytoolkit.googleapis.com',
  ];

  static Future<bool> hasInternetConnection() async {
    if (kIsWeb) {
      // En entorno Web el navegador gestiona la red nativamente
      return true;
    }
    try {
      for (String host in _testHosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 5));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> canReachFirebaseServices() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final firebaseHosts = [
        'identitytoolkit.googleapis.com',
        'firebaseappcheck.googleapis.com',
        'www.googleapis.com',
      ];

      for (String host in firebaseHosts) {
        try {
          final result = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 3));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> waitForConnection({int maxRetries = 5}) async {
    if (kIsWeb) return;
    int retries = 0;
    while (retries < maxRetries) {
      if (await hasInternetConnection()) {
        return;
      }
      retries++;
      await Future.delayed(Duration(seconds: retries * 2));
    }
    throw Exception('No se pudo establecer conexión a internet');
  }
}