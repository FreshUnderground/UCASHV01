#!/usr/bin/env dart
// Simple script to test server connectivity

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🧪 Testing Server Connectivity');
  print('============================');
  
  final baseUrl = 'https://mahanaim.investee-group.com/server/api/sync';
  final pingUrl = '$baseUrl/ping.php';
  
  print('🌐 Testing URL: $pingUrl');
  
  try {
    // Test basic connectivity
    final result = await InternetAddress.lookup('localhost');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print('✅ Localhost is reachable');
    }
  } catch (e) {
    print('❌ Localhost is not reachable: $e');
  }
  
  try {
    // Test HTTP request
    print('📡 Sending HTTP request...');
    final response = await http.get(Uri.parse(pingUrl)).timeout(Duration(seconds: 10));
    
    print('📊 Response Status: ${response.statusCode}');
    print('📄 Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('✅ Server is accessible!');
    } else {
      print('⚠️ Server returned status ${response.statusCode}');
    }
  } catch (e) {
    print('❌ HTTP request failed: $e');
    
    if (e.toString().contains('XMLHttpRequest error')) {
      print('💡 This usually means the server is not running or there\'s a CORS issue');
      print('💡 Make sure Laragon is running with Apache and MySQL');
    } else if (e.toString().contains('SocketException')) {
      print('💡 This usually means the server is not accessible at the specified URL');
      print('💡 Check that the server is running and the URL is correct');
    }
  }
  
  print('\n📋 Troubleshooting Tips:');
  print('1. Make sure Laragon is running with Apache and MySQL');
  print('2. Check that port 80 is not blocked by another application');
  print('3. Verify the URL in your browser: $pingUrl');
  print('4. Check the server logs in Laragon');
}