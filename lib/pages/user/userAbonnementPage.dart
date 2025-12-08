
// screens/abonnement_screen.dart
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../services/abonnement_service.dart';
import '../../services/utils/abonnement_utils.dart';


class AbonnementScreen extends StatefulWidget {
  @override
  _AbonnementScreenState createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen> {
  final AbonnementService _abonnementService = AbonnementService();
  int _dureeSelectionnee = 1;
  bool _isLoading = false;
  bool _showPlanDetails = false;

  // Offres disponibles avec réductions
  final List<Map<String, dynamic>> _offres = [
    {'mois': 1, 'prixBase': 200, 'reduction': 0, 'economie': 0},
    {'mois': 2, 'prixBase': 400, 'reduction': 0, 'economie': 0},
    {'mois': 3, 'prixBase': 600, 'reduction': 100, 'economie': 100},
    {'mois': 4, 'prixBase': 800, 'reduction': 100, 'economie': 100},
    {'mois': 6, 'prixBase': 1200, 'reduction': 200, 'economie': 200},
    {'mois': 12, 'prixBase': 2400, 'reduction': 500, 'economie': 500},
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider?>(context);
    final user = authProvider!.loginUserData!;
    final abonnement = user?.abonnement;
    final isPremium = abonnement?.estPremium == true;
    final joursRestants = AbonnementUtils.getDaysRemaining(abonnement);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // AppBar personnalisée
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Afrolook Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF416C), Color(0xFFFDB813)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Contenu principal
          SliverList(
            delegate: SliverChildListDelegate([
              // Section: État actuel
              _buildCurrentStatusSection(abonnement, isPremium, joursRestants),

              SizedBox(height: 20),

              // Section: Pourquoi Premium
              _buildWhyPremiumSection(),

              SizedBox(height: 20),

              // Si pas premium: Section choix de durée
              if (!isPremium) _buildDurationSelectionSection(),

              // Si pas premium: Section prix
              if (!isPremium) _buildPricingSection(),

              // Si pas premium: Section paiement
              if (!isPremium) _buildPaymentSection(user!),

              // Si premium: Section renouvellement
              if (isPremium) _buildRenewalSection(user!, abonnement!),

              // Section informations
              _buildInfoSection(),

              SizedBox(height: 30),
            ]),
          ),
        ],
      ),
    );
  }

  // Section 1: État actuel de l'abonnement
  Widget _buildCurrentStatusSection(
      AfrolookAbonnement? abonnement,
      bool isPremium,
      int joursRestants
      ) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium ? Color(0xFFFDB813) : Colors.grey[800]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.workspace_premium : Icons.person_outline,
                color: isPremium ? Color(0xFFFDB813) : Colors.grey,
                size: 30,
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'ABONNÉ PREMIUM' : 'ABONNÉ GRATUIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      isPremium
                          ? joursRestants > 0
                          ? 'Valable encore $joursRestants jours'
                          : 'Valide aujourd\'hui'
                          : 'Accès aux fonctionnalités de base',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFDB813), Color(0xFFFF416C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          if (isPremium && abonnement != null)
            Column(
              children: [
                SizedBox(height: 15),
                Divider(color: Colors.grey[800]),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Début:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${abonnement.dateDebut.day}/${abonnement.dateDebut.month}/${abonnement.dateDebut.year}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fin:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${abonnement.dateFin.day}/${abonnement.dateFin.month}/${abonnement.dateFin.year}',
                      style: TextStyle(
                        color: AbonnementUtils.isExpiringSoon(abonnement)
                            ? Colors.orange
                            : Colors.white,
                        fontWeight: AbonnementUtils.isExpiringSoon(abonnement)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Montant payé:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${abonnement.montantPaye.toInt()} FCFA',
                      style: TextStyle(
                        color: Color(0xFFFDB813),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Section 2: Pourquoi passer à Premium
  Widget _buildWhyPremiumSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 15),
            child: Text(
              'Pourquoi passer à Premium ?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Avantages en grille
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildAdvantageCard(
                icon: Icons.public,
                title: 'Afrique entière',
                subtitle: 'Visibilité élargie',
                color: Colors.orange,
              ),

              _buildAdvantageCard(
                icon: Icons.live_tv,
                title: 'Live HD',
                subtitle: 'Qualité optimale',
                color: Color(0xFFFF416C),
              ),
              _buildAdvantageCard(
                icon: Icons.speed,
                title: '500ms',
                subtitle: 'Latence réduite',
                color: Color(0xFFFDB813),
              ),
              _buildAdvantageCard(
                icon: Icons.photo_library,
                title: '+ Photos',
                subtitle: 'Multiples par look',
                color: Colors.blue,
              ),
              _buildAdvantageCard(
                icon: Icons.access_time,
                title: '0 restriction',
                subtitle: 'Postez librement',
                color: Colors.green,
              ),
              _buildAdvantageCard(
                icon: Icons.emoji_events,
                title: 'Challenges',
                subtitle: 'Illimités',
                color: Colors.purple,
              ),
              _buildAdvantageCard(
                icon: Icons.verified,
                title: 'Badge',
                subtitle: 'Exclusif Premium',
                color: Color(0xFFFDB813),
              ),
            ],
          ),

          SizedBox(height: 15),

          // Bouton pour voir tous les détails
          GestureDetector(
            onTap: () => setState(() => _showPlanDetails = !_showPlanDetails),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showPlanDetails
                        ? 'MASQUER LES DÉTAILS'
                        : 'VOIR TOUS LES AVANTAGES',
                    style: TextStyle(
                      color: Color(0xFFFDB813),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    _showPlanDetails ? Icons.expand_less : Icons.expand_more,
                    color: Color(0xFFFDB813),
                  ),
                ],
              ),
            ),
          ),

          // Détails supplémentaires
          if (_showPlanDetails)
            Padding(
              padding: EdgeInsets.only(top: 15),
              child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      '✅ Vos posts visibles partout en Afrique (vs pays seulement)',
                      Colors.orange,
                    ),

                    _buildDetailItem(
                      '✅ Live en qualité HD (vs Standard)',
                      Colors.green,
                    ),
                    _buildDetailItem(
                      '✅ Latence 500ms (vs 2000ms)',
                      Colors.blue,
                    ),
                    _buildDetailItem(
                      '✅ Jusqu\'à 3 photos par look (vs 1)',
                      Colors.purple,
                    ),
                    _buildDetailItem(
                      '✅ Pas de restriction 60min après post',
                      Colors.orange,
                    ),
                    _buildDetailItem(
                      '✅ Participation illimitée aux challenges',
                      Color(0xFFFDB813),
                    ),
                    _buildDetailItem(
                      '✅ Partage de textes plus longs',
                      Color(0xFFFF416C),
                    ),
                    _buildDetailItem(
                      '✅ Accès aux événements sponsors',
                      Colors.teal,
                    ),
                    _buildDetailItem(
                      '✅ Badge Premium exclusif',
                      Color(0xFFFDB813),
                    ),
                    _buildDetailItem(
                      '✅ Support prioritaire',
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Section 3: Sélection de durée (seulement si pas premium)
  Widget _buildDurationSelectionSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisissez votre forfait',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Plus longue durée = plus d\'économies',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 15),

          // Sélecteur de durée en ligne
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _offres.map((offre) {
                final duree = offre['mois'];
                final prixFinal = offre['prixBase'] - offre['reduction'];
                final estSelectionne = _dureeSelectionnee == duree;
                final prixParMois = (prixFinal / duree).toInt();
                final economie = offre['economie'];

                return GestureDetector(
                  onTap: () => setState(() => _dureeSelectionnee = duree),
                  child: Container(
                    width: 130,
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: estSelectionne
                          ? LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFDB813)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      color: estSelectionne ? null : Colors.grey[900],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: estSelectionne
                            ? Color(0xFFFDB813)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: estSelectionne
                          ? [
                        BoxShadow(
                          color: Color(0xFFFF416C).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$duree mois',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (estSelectionne)
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          '$prixParMois F/mois',
                          style: TextStyle(
                            color: estSelectionne
                                ? Colors.white
                                : Color(0xFFFDB813),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '$prixFinal F',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (economie > 0)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'Économisez $economie F',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Section 4: Détails du prix
  Widget _buildPricingSection() {
    final offreSelectionnee = _offres.firstWhere(
          (offre) => offre['mois'] == _dureeSelectionnee,
    );
    final prixBase = offreSelectionnee['prixBase'];
    final reduction = offreSelectionnee['reduction'];
    final prixFinal = prixBase - reduction;
    final prixParMois = (prixFinal / _dureeSelectionnee).toInt();

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Durée:',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                '$_dureeSelectionnee mois',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (reduction > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix de base:',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  '$prixBase F',
                  style: TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Réduction:',
                  style: TextStyle(color: Colors.green),
                ),
                Text(
                  '-$reduction F',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
          Divider(color: Colors.grey[800]),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total à payer:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                '$prixFinal F',
                style: TextStyle(
                  color: Color(0xFFFDB813),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Soit $prixParMois F/mois',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section 5: Paiement
  Widget _buildPaymentSection(UserData user) {
    final offreSelectionnee = _offres.firstWhere(
          (offre) => offre['mois'] == _dureeSelectionnee,
    );
    final prixFinal = offreSelectionnee['prixBase'] - offreSelectionnee['reduction'];
    final soldePrincipal = user.votre_solde_principal ?? 0;
    final soldeInsuffisant = soldePrincipal < prixFinal;
    final montantManquant = prixFinal - soldePrincipal;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Info solde
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: soldeInsuffisant ? Colors.orange : Color(0xFFFDB813),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde principal',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${soldePrincipal.toInt()} FCFA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (soldeInsuffisant)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      '-${montantManquant.toInt()} F',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Bouton de paiement
          _isLoading
              ? CircularProgressIndicator(color: Color(0xFFFDB813))
              : Column(
            children: [
              if (soldeInsuffisant)
                Container(
                  margin: EdgeInsets.only(bottom: 15),
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solde insuffisant',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Il vous manque ${montantManquant.toInt()} F',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen(),));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFDB813),
                          foregroundColor: Colors.black,
                        ),
                        child: Text('Recharger'),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: soldeInsuffisant
                    ? null
                    : () => _souscrireAbonnement(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF416C),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'DEVENIR PREMIUM MAINTENANT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Section 6: Renouvellement (seulement si premium)
  Widget _buildRenewalSection(UserData user, AfrolookAbonnement abonnement) {
    final joursRestants = abonnement.joursRestants;
    final expireBientot = abonnement.expireBientot;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expireBientot ? Colors.orange : Color(0xFFFDB813),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (expireBientot)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Votre abonnement expire dans $joursRestants jours',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            'Renouveler votre abonnement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Vous pouvez renouveler dès maintenant pour éviter toute interruption',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],

            ),
          ),
          SizedBox(height: 20),

          // Bouton pour voir les offres (qui redirigerait vers la section choix)
          ElevatedButton(
            onPressed: () {
              // Faire défiler vers la section choix
              // Ou permettre de choisir une nouvelle durée
              _showRenewalOptions(user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFFFDB813),
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Color(0xFFFDB813), width: 2),
              ),
            ),
            child: Text(
              'VOIR LES OPTIONS DE RENOUVELLEMENT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Section 7: Informations
  Widget _buildInfoSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Color(0xFFFDB813)),
              SizedBox(width: 10),
              Text(
                'Informations importantes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildInfoItem(
            '💡',
            'Votre abonnement soutient directement le développement d\'Afrolook',
          ),
          SizedBox(height: 10),
          _buildInfoItem(
            '🔄',
            'Renouvellement automatique désactivé - Vous contrôlez votre abonnement',
          ),
          SizedBox(height: 10),
          _buildInfoItem(
            '⏰',
            'À l\'expiration, retour automatique à l\'abonnement gratuit',
          ),
          SizedBox(height: 10),
          _buildInfoItem(
            '🙏',
            'Merci de soutenir notre réseau social africain !',
          ),
        ],
      ),
    );
  }

  // Widgets auxiliaires
  Widget _buildAdvantageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[800]!),
      ),
      padding: EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String text, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2),
            child: Text(
              text.split(' ')[0], // Emoji
              style: TextStyle(fontSize: 16),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text.substring(text.indexOf(' ') + 1),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // Méthodes
  Future<void> _souscrireAbonnement(UserData user) async {
    setState(() => _isLoading = true);

    try {
      final result = await _abonnementService.souscrirePremium(
        dureeMois: _dureeSelectionnee,
        user: user, context: context,
      );

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.toString());
    }
  }
  void _showRenewalOptions(UserData user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true, // Important !
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8, // Le bottomsheet occupe 80% de l'écran
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Renouveler votre abonnement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Choisissez une nouvelle durée pour votre abonnement Premium',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),

                // 🔥 Le bloc scrollable
                Expanded(
                  child: ListView(
                    children: [
                      ..._offres.map((offre) {
                        final duree = offre['mois'];
                        final prixFinal = offre['prixBase'] - offre['reduction'];

                        return ListTile(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _dureeSelectionnee = duree;
                            });
                          },
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFFDB813).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$duree mois',
                              style: TextStyle(
                                color: Color(0xFFFDB813),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            '$prixFinal FCFA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Soit ${(prixFinal / duree).toInt()} F/mois',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                        );
                      }).toList(),

                      SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'ANNULER',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenewalOptions2(UserData user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Renouveler votre abonnement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Choisissez une nouvelle durée pour votre abonnement Premium',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),

              // Options de renouvellement simplifiées
              ..._offres.map((offre) {
                final duree = offre['mois'];
                final prixFinal = offre['prixBase'] - offre['reduction'];

                return ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _dureeSelectionnee = duree;
                      // Faire défiler vers la section paiement
                    });
                  },
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFDB813).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$duree mois',
                      style: TextStyle(
                        color: Color(0xFFFDB813),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '$prixFinal FCFA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Soit ${(prixFinal / duree).toInt()} F/mois',
                    style: TextStyle(color: Colors.grey),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                );
              }).toList(),

              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'ANNULER',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Color(0xFFFDB813), width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFDB813), Color(0xFFFF416C)],
                ),
              ),
              child: Icon(Icons.workspace_premium,
                  color: Colors.white,
                  size: 50),
            ),
            SizedBox(height: 20),
            Text(
              'FÉLICITATIONS !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Vous êtes maintenant membre Afrolook Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFFFDB813)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Badge Premium activé',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Profitez de tous vos avantages',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Retour à l'écran précédent
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF416C),
                minimumSize: Size(150, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'SUPER !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Erreur',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFFFDB813))),
          ),
        ],
      ),
    );
  }
}