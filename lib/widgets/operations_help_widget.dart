import 'package:flutter/material.dart';

class OperationsHelpWidget extends StatelessWidget {
  const OperationsHelpWidget({super.key});

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
                  Icons.info_outline,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
                    'Guide d\'utilisation - Opérations UCASH',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Section Dépôts
            _buildOperationSection(
              icon: Icons.add_circle,
              iconColor: Colors.green,
              title: 'DÉPÔTS',
              description: 'Ajouter de l\'argent dans le compte d\'un client',
              steps: [
                '1. Cliquez sur le bouton VERT "Dépôt"',
                '2. Sélectionnez le client dans la liste',
                '3. Saisissez le montant à déposer',
                '4. Choisissez le mode de paiement (Cash, Airtel Money, M-Pesa, Orange Money)',
                '5. Vérifiez le résumé et confirmez',
              ],
              features: [
                '✅ Aucune commission (0%)',
                '✅ Pas de capture d\'écran requise',
                '✅ Mise à jour automatique du solde client',
                '✅ Mise à jour automatique du capital shop',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section Retraits
            _buildOperationSection(
              icon: Icons.remove_circle,
              iconColor: Colors.orange,
              title: 'RETRAITS',
              description: 'Retirer de l\'argent du compte d\'un client',
              steps: [
                '1. Cliquez sur le bouton ORANGE "Retrait"',
                '2. Sélectionnez le client dans la liste',
                '3. Vérifiez le solde disponible du client',
                '4. Saisissez le montant à retirer (≤ solde disponible)',
                '5. Choisissez le mode de paiement',
                '6. Vérifiez le résumé et confirmez',
              ],
              features: [
                '✅ Aucune commission (0%)',
                '✅ Validation automatique du solde',
                '✅ Blocage si solde insuffisant',
                '✅ Mise à jour automatique des soldes',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section Transferts
            _buildOperationSection(
              icon: Icons.send,
              iconColor: const Color(0xFFDC2626),
              title: 'TRANSFERTS',
              description: 'Envoyer de l\'argent vers une destination',
              steps: [
                '1. Cliquez sur "Transfert Simple" ou "Transfert Destination"',
                '2. Ajoutez une capture d\'écran (preuve de paiement)',
                '3. Saisissez le nom de la personne à servir',
                '4. Choisissez le shop de destination (si national)',
                '5. La commission est calculée automatiquement',
              ],
              features: [
                '📸 Capture d\'écran obligatoire',
                '💰 Commission selon le type (3.5% ou gratuit)',
                '🌍 National, International Sortant/Entrant',
                '🏪 Sélection du shop de destination',
                '👤 Nom de la personne uniquement (pas de téléphone)',
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
                        'IMPORTANT - Données Réelles',
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
                    '• L\'application démarre sans données par défaut\n'
                    '• Vous devez d\'abord créer des partenaires dans l\'onglet "Partenaires"\n'
                    '• Les dépôts/retraits ne fonctionnent qu\'avec des clients existants\n'
                    '• Toutes les opérations sont réelles et mettent à jour les soldes\n'
                    '• Les commissions sont calculées selon les taux du marché congolais',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationSection({
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
              
              // Caractéristiques
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caractéristiques :',
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
