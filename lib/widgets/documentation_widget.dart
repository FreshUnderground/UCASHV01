import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import '../services/documentation_service.dart';
import '../services/auth_service.dart';

class DocumentationWidget extends StatefulWidget {
  const DocumentationWidget({super.key});

  @override
  State<DocumentationWidget> createState() => _DocumentationWidgetState();
}

class _DocumentationWidgetState extends State<DocumentationWidget> {
  String _searchQuery = '';
  String? _selectedSectionId;
  String _selectedLanguage = 'fr'; // Default to French
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userRole = authService.currentUser?.role ?? 'CLIENT';
        final locale = Localizations.localeOf(context);
        final systemLanguage = locale.languageCode == 'en' ? 'en' : 'fr';
        // Use selected language if set, otherwise fall back to system language
        final language =
            _selectedLanguage.isNotEmpty ? _selectedLanguage : systemLanguage;
        final sections = DocumentationService.searchSections(
            _searchQuery, userRole, language);

        return Scaffold(
          appBar: AppBar(
            title: Text(language == 'en'
                ? 'UCASH Documentation'
                : 'Documentation UCASH'),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Language selector
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: DropdownButton<String>(
                  value: language,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.language, color: Colors.white),
                  underline: Container(),
                  onChanged: (String? newLanguage) {
                    if (newLanguage != null) {
                      setState(() {
                        _selectedLanguage = newLanguage;
                        // Reset selected section when language changes
                        _selectedSectionId = null;
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: 'fr',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇫🇷', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Français',
                              style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'en',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇺🇸', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('English',
                              style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              // Sidebar avec liste des sections
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: [
                    // Barre de recherche
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: language == 'en'
                              ? 'Search documentation...'
                              : 'Rechercher dans la documentation...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),

                    // Indicateur de rôle
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoleIcon(userRole),
                            size: 16,
                            color: const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getRoleDisplayName(userRole),
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Liste des sections
                    Expanded(
                      child: ListView.builder(
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          final isSelected = _selectedSectionId == section.id;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            child: ListTile(
                              leading: Icon(
                                _getIconData(section.icon),
                                color: isSelected
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey[600],
                              ),
                              title: Text(
                                section.title,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                section.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: isSelected,
                              selectedTileColor:
                                  const Color(0xFFDC2626).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedSectionId = section.id;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu principal
              Expanded(
                child: _selectedSectionId == null
                    ? _buildWelcomeScreen(userRole)
                    : _buildDocumentationContent(_selectedSectionId!),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeScreen(String userRole) {
    final locale = Localizations.localeOf(context);
    final systemLanguage = locale.languageCode == 'en' ? 'en' : 'fr';
    final language =
        _selectedLanguage.isNotEmpty ? _selectedLanguage : systemLanguage;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getRoleIcon(userRole),
            size: 80,
            color: const Color(0xFFDC2626).withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            language == 'en'
                ? 'Welcome to UCASH Documentation'
                : 'Bienvenue dans la Documentation UCASH',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            language == 'en'
                ? 'Specialized documentation for ${_getRoleDisplayName(userRole, language)}'
                : 'Documentation spécialisée pour ${_getRoleDisplayName(userRole, language)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  language == 'en'
                      ? 'How to use this documentation'
                      : 'Comment utiliser cette documentation',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  language == 'en'
                      ? '• Select a section from the left menu\n'
                          '• Use the search bar to find quickly\n'
                          '• Each section contains detailed guides\n'
                          '• Information is adapted to your role\n'
                          '• Use the language selector to switch between French and English'
                      : '• Sélectionnez une section dans le menu de gauche\n'
                          '• Utilisez la barre de recherche pour trouver rapidement\n'
                          '• Chaque section contient des guides détaillés\n'
                          '• Les informations sont adaptées à votre rôle\n'
                          '• Utilisez le sélecteur de langue pour basculer entre français et anglais',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentationContent(String sectionId) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'en' ? 'en' : 'fr';
    final content =
        DocumentationService.getContentForSection(sectionId, language);

    if (content == null) {
      return const Center(
        child: Text('Contenu non disponible'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre principal
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Sections de contenu
          ...content.sections.map((section) => _buildContentSection(section)),
        ],
      ),
    );
  }

  Widget _buildContentSection(DocumentationSubSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de la section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contenu de la section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _buildFormattedContent(section.content),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Titres avec **
      if (line.startsWith('**') && line.endsWith('**')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              line.substring(2, line.length - 2),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        );
      }
      // Listes avec •
      else if (line.startsWith('•')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Listes numérotées
      else if (RegExp(r'^\d+\.').hasMatch(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
      // Emojis avec texte
      else if (line.contains('✅') ||
          line.contains('🔒') ||
          line.contains('📸') ||
          line.contains('💰') ||
          line.contains('🌍') ||
          line.contains('🏪') ||
          line.contains('👤') ||
          line.contains('1️⃣') ||
          line.contains('2️⃣') ||
          line.contains('3️⃣') ||
          line.contains('4️⃣') ||
          line.contains('5️⃣')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
      // Texte normal
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'ADMIN':
        return Icons.admin_panel_settings;
      case 'AGENT':
        return Icons.person_outline;
      case 'CLIENT':
        return Icons.account_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getRoleDisplayName(String role, [String language = 'fr']) {
    switch (role) {
      case 'ADMIN':
        return language == 'en' ? 'Administrator' : 'Administrateur';
      case 'AGENT':
        return language == 'en' ? 'Agent' : 'Agent';
      case 'CLIENT':
        return language == 'en' ? 'Client' : 'Client';
      default:
        return language == 'en' ? 'User' : 'Utilisateur';
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings;
      case 'store':
        return Icons.store;
      case 'people':
        return Icons.people;
      case 'badge':
        return Icons.badge;
      case 'currency_exchange':
        return Icons.currency_exchange;
      case 'analytics':
        return Icons.analytics;
      case 'verified':
        return Icons.verified;
      case 'dashboard':
        return Icons.dashboard;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'phone_android':
        return Icons.phone_android;
      case 'check_circle':
        return Icons.check_circle;
      case 'assessment':
        return Icons.assessment;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'account_balance':
        return Icons.account_balance;
      case 'person':
        return Icons.person;
      case 'account_circle':
        return Icons.account_circle;
      case 'history':
        return Icons.history;
      case 'request_quote':
        return Icons.request_quote;
      default:
        return Icons.help_outline;
    }
  }
}
