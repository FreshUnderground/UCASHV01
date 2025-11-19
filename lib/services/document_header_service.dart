import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/document_header_model.dart';
import '../config/app_config.dart';

/// Service de gestion des en-têtes de documents avec synchronisation
class DocumentHeaderService extends ChangeNotifier {
  static const String _headerKey = 'document_header_active';
  
  DocumentHeaderModel? _currentHeader;
  bool _isLoading = false;
  String? _error;

  DocumentHeaderModel? get currentHeader => _currentHeader;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialiser et charger l'en-tête
  Future<void> initialize() async {
    await loadHeader();
  }

  /// Charger l'en-tête depuis le cache local puis synchroniser
  Future<void> loadHeader() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Charger depuis SharedPreferences
      await _loadFromLocalStorage();

      // 2. Synchroniser avec le serveur
      await syncWithServer();

    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erreur chargement en-tête: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger depuis SharedPreferences
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_headerKey);
      
      if (cachedData != null) {
        final json = jsonDecode(cachedData);
        _currentHeader = DocumentHeaderModel.fromJson(json);
        debugPrint('✅ En-tête chargé depuis stockage local');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement stockage local: $e');
    }
  }

  /// Sauvegarder dans SharedPreferences
  Future<void> _saveToLocalStorage(DocumentHeaderModel header) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_headerKey, jsonEncode(header.toJson()));
      debugPrint('✅ En-tête sauvegardé dans stockage local');
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde stockage local: $e');
    }
  }

  /// Synchroniser avec le serveur MySQL
  Future<void> syncWithServer() async {
    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      
      // Télécharger depuis le serveur
      final response = await http.get(
        Uri.parse('$baseUrl/document-headers/active'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(AppConfig.httpTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final serverHeader = DocumentHeaderModel.fromJson(data['data']);
          
          // Sauvegarder localement
          await _saveToLocalStorage(serverHeader);
          
          _currentHeader = serverHeader;
          
          debugPrint('✅ En-tête synchronisé depuis serveur');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur sync serveur: $e');
      // Continuer avec les données locales si la sync échoue
    }
  }

  /// Créer ou mettre à jour l'en-tête (depuis l'admin)
  Future<bool> saveHeader(DocumentHeaderModel header) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Sauvegarder localement d'abord
      await _saveToLocalStorage(header);
      _currentHeader = header;
      notifyListeners();

      // 2. Envoyer au serveur
      final baseUrl = await AppConfig.getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/document-headers/save'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(header.toJson()),
      ).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ En-tête sauvegardé et synchronisé');
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _error = 'Erreur serveur lors de la sauvegarde';
      return false;

    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Erreur sauvegarde en-tête: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtenir l'en-tête actif ou créer un par défaut
  DocumentHeaderModel getHeaderOrDefault() {
    return _currentHeader ?? DocumentHeaderModel(
      id: 0,
      companyName: 'UCASH',
      companySlogan: 'Merci pour votre confiance',
      address: '',
      phone: '',
      email: '',
      website: '',
      createdAt: DateTime.now(),
    );
  }

  /// Vider le cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_headerKey);
    _currentHeader = null;
    notifyListeners();
  }
}
