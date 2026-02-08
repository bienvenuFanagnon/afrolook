import 'package:flutter/material.dart';

class MarketingExplanationPage extends StatelessWidget {
  const MarketingExplanationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Comment ça marche ?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec chiffre impressionnant
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB71C1C), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '🚀 GAGNEZ JUSQU\'À',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '50 000+ FCFA',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Déjà gagnés par nos utilisateurs actifs !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Introduction
            _buildSectionTitle('✨ Votre Rêve Commence Ici'),
            SizedBox(height: 12),
            Text(
              'Transformez vos relations en revenus stables avec le système de marketing Afrolook ! '
                  'Notre communauté a déjà généré plus de 50 000 FCFA de commissions pour nos membres actifs.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            SizedBox(height: 24),

            // Étape 1 - Parrainage
            _buildStepCard(
              stepNumber: 1,
              title: '👑 Trouvez un Parrain',
              description: 'Commencez par ajouter un parrain avec un code valide. '
                  'Votre parrain vous guide et bénéficie de vos succès.',
              icon: Icons.group_add,
              color: Colors.red,
            ),
            SizedBox(height: 16),

            // Étape 2 - Activation
            _buildStepCard(
              stepNumber: 2,
              title: '🚀 Activez Votre Compte',
              description: 'Pour seulement 4 500 FCFA, activez votre compte marketing pour 3 mois. '
                  'Votre parrain reçoit immédiatement 50% (2 250 FCFA) !',
              icon: Icons.rocket_launch,
              color: Colors.orange,
            ),
            SizedBox(height: 16),

            // Étape 3 - Réseau
            _buildStepCard(
              stepNumber: 3,
              title: '📱 Développez Votre Réseau',
              description: 'Partagez votre code de parrainage avec vos amis, '
                  'famille et followers sur les réseaux sociaux.',
              icon: Icons.share,
              color: Colors.green,
            ),
            SizedBox(height: 16),

            // Étape 4 - Commissions
            _buildStepCard(
              stepNumber: 4,
              title: '💰 Gagnez des Commissions',
              description: 'Recevez 50% du montant d\'activation (2 250 FCFA) '
                  'pour chaque filleul qui active son compte marketing !',
              icon: Icons.monetization_on,
              color: Colors.amber,
            ),
            SizedBox(height: 24),

            // Avantages
            _buildSectionTitle('🎁 Vos Avantages Exclusifs'),
            SizedBox(height: 12),
            _buildBenefitItem('✅ Commission de 50% sur chaque activation'),
            _buildBenefitItem('✅ Commission sur chaque renouvellement'),
            _buildBenefitItem('✅ Partage illimité d\'images'),
            _buildBenefitItem('✅ Publicités ciblées'),
            _buildBenefitItem('✅ Lives gratuits et monétisés'),
            _buildBenefitItem('✅ Accès à toutes les fonctionnalités premium'),
            SizedBox(height: 24),

            // Système de Renouvellement
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.autorenew, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text(
                        '🔄 REVENUS RÉCURRENTS',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'La magie continue ! Chaque fois que vos filleuls renouvellent leur abonnement '
                        '(tous les 3 mois), vous recevez à nouveau 50% de commission !',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Exemple : Avec 10 filleuls actifs, vous gagnez 22 500 FCFA tous les 3 mois !',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Tableau des Gains
            _buildSectionTitle('📈 Votre Potentiel de Gains'),
            SizedBox(height: 12),
            _buildEarningsTable(),
            SizedBox(height: 24),

            // Témoignage
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.purple, size: 24),
                      SizedBox(width: 12),
                      Text(
                        '💬 TEMOIGNAGE',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '"Grâce au système Afrolook, j\'ai généré 32 000 FCFA en seulement 2 mois ! '
                        'Mes filleuls continuent de renouveler, c\'est un revenu passif incroyable."',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '- Marie D., Utilisatrice depuis 6 mois',
                    style: TextStyle(
                      color: Colors.purple.shade300,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Calculatrice de Gains
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Colors.red.shade900],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧮 CALCULEZ VOS FUTURS GAINS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '10 filleuls × 2 250 FCFA = 22 500 FCFA\n'
                        '20 filleuls × 2 250 FCFA = 45 000 FCFA\n'
                        '50 filleuls × 2 250 FCFA = 112 500 FCFA',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Et ceci tous les 3 mois avec les renouvellements !',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // CTA Final
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFA000), Color(0xFFB71C1C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.celebration, color: Colors.white, size: 40),
                  SizedBox(height: 16),
                  Text(
                    '🚀 PRÊT À COMMENCER ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Rejoignez les centaines d\'utilisateurs qui transforment déjà '
                        'leurs réseaux en revenus stables avec Afrolook !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'COMMENCER MAINTENANT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // En-tête du tableau
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Nombre de Filleuls',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Gains / Activation',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Gains / An',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Lignes du tableau
          _buildTableRow('5 filleuls', '11 250 FCFA', '45 000 FCFA'),
          _buildTableRow('10 filleuls', '22 500 FCFA', '90 000 FCFA'),
          _buildTableRow('20 filleuls', '45 000 FCFA', '180 000 FCFA'),
          _buildTableRow('50 filleuls', '112 500 FCFA', '450 000 FCFA'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String filleuls, String activation, String annuel) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              filleuls,
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              activation,
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              annuel,
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}