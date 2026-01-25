#!/usr/bin/env dart
// Test script for improved connectivity check

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🧪 Testing Improved Connectivity Check');
  print('====================================');

  final baseUrl = 'https://safdal.investee-group.com/server/api/sync';
  final pingUrls = [
    '$baseUrl/ping.php', // URL directe avec extension
    '$baseUrl/ping', // URL sans extension (si .htaccess)
  ];

  print('🌐 Testing URLs: $pingUrls');

  http.Response? response;
  String usedUrl = '';

  for (String url in pingUrls) {
    try {
      print('📡 Testing $url...');
      usedUrl = url;
      response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      print('📊 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      // Si la requête réussit, sortir de la boucle
      if (response.statusCode == 200) {
        print('✅ Successfully connected to $url');
        break;
      } else {
        print('⚠️ Failed to connect to $url (status ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error connecting to $url: $e');
      // Continuer avec l'URL suivante
    }
  }

  if (response == null) {
    print('❌ Failed to connect to any URL');
  } else if (response.statusCode == 200) {
    print('🎉 Connection successful!');
  } else {
    print('⚠️ Connection failed with status ${response.statusCode}');
  }
}
