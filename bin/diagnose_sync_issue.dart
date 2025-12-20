#!/usr/bin/env dart
// Comprehensive diagnostic script for sync issues

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🧪 Comprehensive Sync Issue Diagnosis');
  print('====================================');
  
  // Test 1: Basic connectivity to localhost
  print('\n🔍 Test 1: Basic localhost connectivity');
  try {
    final result = await InternetAddress.lookup('localhost');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print('✅ Localhost is reachable');
    } else {
      print('❌ Localhost is not reachable');
      return;
    }
  } catch (e) {
    print('❌ Localhost is not reachable: $e');
    return;
  }
  
  // Test 2: HTTP server connectivity
  print('\n🔍 Test 2: HTTP server connectivity');
  final urlsToTest = [
    'http://localhost',
    'https://mahanaimeservice.investee-group.com',
    'https://mahanaimeservice.investee-group.com/server',
    'https://mahanaimeservice.investee-group.com/server/api',
    'https://mahanaimeservice.investee-group.com/server/api/sync',
    'https://mahanaimeservice.investee-group.com/server/api/sync/ping.php',
  ];
  
  for (String url in urlsToTest) {
    try {
      print('📡 Testing $url...');
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
      print('📊 Status: ${response.statusCode} - ${response.body.substring(0, 50)}...');
    } catch (e) {
      print('❌ Error: $e');
    }
  }
  
  // Test 3: Specific sync endpoints
  print('\n🔍 Test 3: Specific sync endpoints');
  final syncEndpoints = [
    'https://mahanaimeservice.investee-group.com/server/api/sync/ping.php',
    'https://mahanaimeservice.investee-group.com/server/api/sync/operations/changes.php?limit=1',
  ];
  
  for (String url in syncEndpoints) {
    try {
      print('📡 Testing $url...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }
      ).timeout(Duration(seconds: 10));
      print('📊 Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');
    } catch (e) {
      print('❌ Error: $e');
    }
  }
  
  // Test 4: POST request to upload endpoint
  print('\n🔍 Test 4: POST request to upload endpoint');
  final uploadUrl = 'https://mahanaimeservice.investee-group.com/server/api/sync/operations/upload.php';
  try {
    print('📡 Testing POST to $uploadUrl...');
    final response = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: '{"test": "data"}'
    ).timeout(Duration(seconds: 10));
    print('📊 Status: ${response.statusCode}');
    print('📄 Body: ${response.body}');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n📋 Summary:');
  print('If all tests fail, check:');
  print('1. Laragon is running with Apache and MySQL');
  print('2. Port 80 is not blocked by another application');
  print('3. Windows Firewall is not blocking the connection');
  print('4. The server files are in the correct location');
}