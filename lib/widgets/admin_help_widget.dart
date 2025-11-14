import 'package:flutter/material.dart';

class AdminHelpWidget extends StatelessWidget {
  const AdminHelpWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Guide Administrateur UCASH',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Section Gestion des Agents
            _buildSection(
              icon: Icons.people,
              iconColor: Colors.blue,
              title: 'GESTION DES AGENTS',
              description: 'Créer et gérer les agents de vos shops',
              steps: [
                '1. Cliquez sur l\'onglet "Agents" dans le menu de gauche',
                '2. Cliquez sur le bouton "Nouvel Agent" (rouge, en haut à droite)',
                '3. Remplissez le formulaire :',
                '   • Nom d\'utilisateur (unique)',
                '   • Mot de passe (minimum 6 caractères)',
                '   • Sélectionnez le shop à assigner',
                '4. Cliquez sur "Créer" pour finaliser',
              ],
              features: [
                '✅ Création d\'agents avec identifiants uniques',
                '✅ Assignation automatique à un shop',
                '✅ Gestion des statuts (actif/inactif)',
                '✅ Modification et suppression d\'agents',
                '✅ Statistiques en temps réel',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section Gestion des Shops
            _buildSection(
              icon: Icons.store,
              iconColor: Colors.green,
              title: 'GESTION DES SHOPS',
              description: 'Créer et gérer vos points de service',
              steps: [
                '1. Cliquez sur l\'onglet "Shops" dans le menu',
                '2. Cliquez sur "Nouveau Shop"',
                '3. Remplissez les informations :',
                '   • Désignation du shop',
                '   • Localisation',
                '   • Capitaux initiaux par type de caisse',
                '4. Validez la création',
              ],
              features: [
                '🏪 Création de shops avec capitaux spécifiques',
                '💰 Gestion des capitaux par mode de paiement',
                '📍 Localisation géographique',
                '📊 Suivi des performances par shop',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section Taux et Commissions
            _buildSection(
              icon: Icons.currency_exchange,
              iconColor: Colors.orange,
              title: 'TAUX & COMMISSIONS',
              description: 'Configurer les taux de change et commissions',
              steps: [
                '1. Accédez à l\'onglet "Taux & Commissions"',
                '2. Gérez les taux de change par devise',
                '3. Configurez les commissions :',
                '   • SORTANT : 3.5% (vers l\'étranger)',
                '   • ENTRANT : 0% GRATUIT (vers RDC)',
                '4. Utilisez les données réelles du marché',
              ],
              features: [
                '💱 Taux de change réels du marché congolais',
                '💸 Commissions configurables',
                '🌍 Types : National, International',
                '📈 Calculs automatiques en temps réel',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Note importante
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'ORDRE DE CRÉATION RECOMMANDÉ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1️⃣ Créez d\'abord vos SHOPS (obligatoire)\n'
                    '2️⃣ Configurez les TAUX & COMMISSIONS\n'
                    '3️⃣ Créez ensuite vos AGENTS (assignés aux shops)\n'
                    '4️⃣ Les agents pourront créer des CLIENTS\n'
                    '5️⃣ Les opérations peuvent alors commencer',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Accès rapide
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      const Text(
                        'ACCÈS RAPIDE - CRÉER UN AGENT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🎯 Menu de gauche → "Agents" → Bouton "Nouvel Agent" (rouge)\n'
                    '📋 Formulaire simple : Username + Password + Shop\n'
                    '✅ Validation automatique et création instantanée',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> steps,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: iconColor.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Étapes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Étapes :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...steps.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        step,
                        style: TextStyle(
                          fontSize: 13,
                          color: iconColor.withOpacity(0.9),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Fonctionnalités
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fonctionnalités :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          color: iconColor.withOpacity(0.9),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
