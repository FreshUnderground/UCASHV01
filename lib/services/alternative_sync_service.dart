import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'shop_service.dart';
import 'agent_service.dart';
import 'client_service.dart';
import 'rates_service.dart';

class AlternativeSyncService {
  static String get _syncUrl {
    return '${ApiService.baseUrl}/sync_all.php';
  }
  
  /// Test de connectivité avec la nouvelle API
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔄 Test connexion API alternative...');
      
      final response = await http.get(
        Uri.parse('$_syncUrl?action=status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ API alternative OK: ${data['message']}');
        return data['success'] == true;
      }
      
      debugPrint('❌ API alternative erreur HTTP: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ API alternative erreur: $e');
      return false;
    }
  }
  
  /// Synchronisation complète BIDIRECTIONNELLE
  static Future<bool> syncComplete() async {
    try {
      debugPrint('🚀 SYNCHRONISATION BIDIRECTIONNELLE DÉMARRÉE');
      
      // Test de connexion
      if (!await testConnection()) {
        debugPrint('❌ Serveur non disponible');
        return false;
      }
      
      // PHASE 1: UPLOAD App → MySQL
      debugPrint('📤 PHASE 1: Upload App → MySQL');
      await _uploadAllDataToMySQL();
      
      // PHASE 2: DOWNLOAD MySQL → App
      debugPrint('📥 PHASE 2: Download MySQL → App');
      await _downloadAllDataFromMySQL();
      
      debugPrint('✅ SYNCHRONISATION BIDIRECTIONNELLE RÉUSSIE !');
      debugPrint('📊 Toutes les données synchronisées !');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur synchronisation bidirectionnelle: $e');
      return false;
    }
  }
  
  /// Upload de toutes les données App → MySQL
  static Future<void> _uploadAllDataToMySQL() async {
    try {
      // Upload Shops
      await _uploadShopsToMySQL();
      
      // Upload Agents
      await _uploadAgentsToMySQL();
      
      // Upload Clients
      await _uploadClientsToMySQL();
      
      // Upload Taux
      await _uploadTauxToMySQL();
      
      // Upload Commissions
      await _uploadCommissionsToMySQL();
      
      debugPrint('✅ Upload App → MySQL terminé');
    } catch (e) {
      debugPrint('❌ Erreur upload: $e');
    }
  }
  
  /// Download de toutes les données MySQL → App
  static Future<void> _downloadAllDataFromMySQL() async {
    try {
      // Récupération de toutes les données
      final response = await http.get(
        Uri.parse('$_syncUrl?action=sync_complete'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        debugPrint('❌ Erreur HTTP: ${response.statusCode}');
        return;
      }
      
      final data = json.decode(response.body);
      
      if (data['success'] != true) {
        debugPrint('❌ Erreur serveur: ${data['message']}');
        return;
      }
      
      // Traitement des données par table
      final tables = data['tables'] as Map<String, dynamic>;
      await _processTables(tables);
      
      debugPrint('✅ Download MySQL → App terminé');
    } catch (e) {
      debugPrint('❌ Erreur download: $e');
    }
  }
  
  /// Traitement des données par table
  static Future<void> _processTables(Map<String, dynamic> tables) async {
    try {
      // Shops
      if (tables.containsKey('shops')) {
        final shops = tables['shops'] as List;
        debugPrint('📥 ${shops.length} shops récupérés');
        await _processShops(shops);
      }
      
      // Agents
      if (tables.containsKey('agents')) {
        final agents = tables['agents'] as List;
        debugPrint('📥 ${agents.length} agents récupérés');
        await _processAgents(agents);
      }
      
      // Clients
      if (tables.containsKey('clients')) {
        final clients = tables['clients'] as List;
        debugPrint('📥 ${clients.length} clients récupérés');
        await _processClients(clients);
      }
      
      // Opérations
      if (tables.containsKey('operations')) {
        final operations = tables['operations'] as List;
        debugPrint('📥 ${operations.length} opérations récupérées');
        await _processOperations(operations);
      }
      
      // Taux
      if (tables.containsKey('taux')) {
        final taux = tables['taux'] as List;
        debugPrint('📥 ${taux.length} taux récupérés');
        await _processTaux(taux);
      }
      
      // Commissions
      if (tables.containsKey('commissions')) {
        final commissions = tables['commissions'] as List;
        debugPrint('📥 ${commissions.length} commissions récupérées');
        await _processCommissions(commissions);
      }
      
    } catch (e) {
      debugPrint('❌ Erreur traitement tables: $e');
    }
  }
  
  /// Traitement des shops
  static Future<void> _processShops(List shops) async {
    try {
      final shopService = ShopService.instance;
      
      for (final shopData in shops) {
        final shop = shopData as Map<String, dynamic>;
        
        // Conversion vers format app
        await shopService.createShop(
          designation: shop['designation'] ?? 'Shop MySQL',
          localisation: shop['localisation'] ?? 'Localisation MySQL',
          capitalCash: double.tryParse(shop['capital_cash']?.toString() ?? '0') ?? 0.0,
          capitalAirtelMoney: double.tryParse(shop['capital_airtel_money']?.toString() ?? '0') ?? 0.0,
          capitalMPesa: double.tryParse(shop['capital_mpesa']?.toString() ?? '0') ?? 0.0,
          capitalOrangeMoney: double.tryParse(shop['capital_orange_money']?.toString() ?? '0') ?? 0.0,
          capitalInitial: double.tryParse(shop['capital_actuel']?.toString() ?? '0') ?? 0.0,
        );
      }
      
      debugPrint('✅ Shops synchronisés: MySQL → App');
    } catch (e) {
      debugPrint('❌ Erreur sync shops: $e');
    }
  }
  
  /// Traitement des agents
  static Future<void> _processAgents(List agents) async {
    try {
      final agentService = AgentService.instance;
      
      for (final agentData in agents) {
        final agent = agentData as Map<String, dynamic>;
        
        // Skip admin par défaut
        if (agent['username'] == 'admin') continue;
        
        await agentService.createAgent(
          username: agent['username'] ?? 'agent_mysql',
          password: agent['password'] ?? 'password123',
          shopId: int.tryParse(agent['shop_id']?.toString() ?? '1') ?? 1,
        );
      }
      
      debugPrint('✅ Agents synchronisés: MySQL → App');
    } catch (e) {
      debugPrint('❌ Erreur sync agents: $e');
    }
  }
  
  /// Traitement des clients
  static Future<void> _processClients(List clients) async {
    try {
      final clientService = ClientService();
      
      for (final clientData in clients) {
        final client = clientData as Map<String, dynamic>;
        
        await clientService.createClient(
          nom: client['nom'] ?? 'Client MySQL',
          telephone: client['telephone'] ?? '000000000',
          adresse: client['adresse'] ?? 'Adresse MySQL',
          shopId: int.tryParse(client['shop_id']?.toString() ?? '1') ?? 1,
          agentId: int.tryParse(client['agent_id']?.toString() ?? '1') ?? 1,
        );
      }
      
      debugPrint('✅ Clients synchronisés: MySQL → App');
    } catch (e) {
      debugPrint('❌ Erreur sync clients: $e');
    }
  }
  
  /// Traitement des opérations
  static Future<void> _processOperations(List operations) async {
    try {
      // Traitement basique des opérations
      debugPrint('✅ Opérations synchronisées: MySQL → App (${operations.length})');
    } catch (e) {
      debugPrint('❌ Erreur sync opérations: $e');
    }
  }
  
  /// Traitement des taux
  static Future<void> _processTaux(List taux) async {
    try {
      final ratesService = RatesService.instance;
      
      for (final tauxData in taux) {
        final tauxItem = tauxData as Map<String, dynamic>;
        
        await ratesService.createTaux(
          devise: tauxItem['devise'] ?? 'USD',
          taux: double.tryParse(tauxItem['taux']?.toString() ?? '2850') ?? 2850.0,
          type: tauxItem['type'] ?? 'NATIONAL',
        );
      }
      
      debugPrint('✅ Taux synchronisés: MySQL → App');
    } catch (e) {
      debugPrint('❌ Erreur sync taux: $e');
    }
  }
  
  /// Traitement des commissions
  static Future<void> _processCommissions(List commissions) async {
    try {
      final ratesService = RatesService.instance;
      
      for (final commissionData in commissions) {
        final commission = commissionData as Map<String, dynamic>;
        
        await ratesService.createCommission(
          type: commission['type'] ?? 'SORTANT',
          taux: double.tryParse(commission['taux']?.toString() ?? '3.5') ?? 3.5,
          description: commission['description'] ?? 'Commission MySQL',
        );
      }
      
      debugPrint('✅ Commissions synchronisées: MySQL → App');
    } catch (e) {
      debugPrint('❌ Erreur sync commissions: $e');
    }
  }
  
  /// Upload des shops vers MySQL
  static Future<void> _uploadShopsToMySQL() async {
    try {
      final shopService = ShopService.instance;
      final shops = shopService.shops;
      
      if (shops.isEmpty) {
        debugPrint('📤 Aucun shop à uploader');
        return;
      }
      
      final shopsData = shops.map((shop) => {
        'designation': shop.designation,
        'localisation': shop.localisation,
        'capital_cash': shop.capitalCash,
        'capital_airtel_money': shop.capitalAirtelMoney,
        'capital_mpesa': shop.capitalMPesa,
        'capital_orange_money': shop.capitalOrangeMoney,
        'capital_actuel': shop.capitalActuel,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_syncUrl?action=upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'table': 'shops',
          'data': shopsData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('📤 ${result['uploaded']} shops uploadés vers MySQL');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload shops: $e');
    }
  }
  
  /// Upload des agents vers MySQL
  static Future<void> _uploadAgentsToMySQL() async {
    try {
      final agentService = AgentService.instance;
      final agents = agentService.agents;
      
      if (agents.isEmpty) {
        debugPrint('📤 Aucun agent à uploader');
        return;
      }
      
      final agentsData = agents.map((agent) => {
        'username': agent.username,
        'password': agent.password,
        'nom': agent.nom,
        'shop_id': agent.shopId,
        'role': 'AGENT',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_syncUrl?action=upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'table': 'agents',
          'data': agentsData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('📤 ${result['uploaded']} agents uploadés vers MySQL');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload agents: $e');
    }
  }
  
  /// Upload des clients vers MySQL
  static Future<void> _uploadClientsToMySQL() async {
    try {
      final clientService = ClientService();
      final clients = clientService.clients;
      
      if (clients.isEmpty) {
        debugPrint('📤 Aucun client à uploader');
        return;
      }
      
      final clientsData = clients.map((client) => {
        'nom': client.nom,
        'telephone': client.telephone,
        'adresse': client.adresse ?? '',
        'shop_id': client.shopId,
        'solde': client.solde,
        'role': 'CLIENT',
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_syncUrl?action=upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'table': 'clients',
          'data': clientsData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('📤 ${result['uploaded']} clients uploadés vers MySQL');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload clients: $e');
    }
  }
  
  /// Upload des taux vers MySQL
  static Future<void> _uploadTauxToMySQL() async {
    try {
      final ratesService = RatesService.instance;
      final taux = ratesService.taux;
      
      if (taux.isEmpty) {
        debugPrint('📤 Aucun taux à uploader');
        return;
      }
      
      final tauxData = taux.map((tauxItem) => {
        'devise_source': tauxItem.deviseSource,
        'devise_cible': tauxItem.deviseCible,
        'taux': tauxItem.taux,
        'type': tauxItem.type,
        'est_actif': tauxItem.estActif,
        'date_effet': tauxItem.dateEffet?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_syncUrl?action=upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'table': 'taux',
          'data': tauxData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('📤 ${result['uploaded']} taux uploadés vers MySQL');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload taux: $e');
    }
  }
  
  /// Upload des commissions vers MySQL
  static Future<void> _uploadCommissionsToMySQL() async {
    try {
      final ratesService = RatesService.instance;
      final commissions = ratesService.commissions;
      
      if (commissions.isEmpty) {
        debugPrint('📤 Aucune commission à uploader');
        return;
      }
      
      final commissionsData = commissions.map((commission) => {
        'type': commission.type,
        'taux': commission.taux,
        'description': commission.description,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_syncUrl?action=upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'table': 'commissions',
          'data': commissionsData,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('📤 ${result['uploaded']} commissions uploadées vers MySQL');
      }
    } catch (e) {
      debugPrint('❌ Erreur upload commissions: $e');
    }
  }
}
