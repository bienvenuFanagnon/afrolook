import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/livesServices.dart';
import '../user/userAbonnementPage.dart';
import 'livePage.dart';
import 'livesAgora.dart';

class CreateLivePage extends StatefulWidget {
  @override
  _CreateLivePageState createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<CreateLivePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Contrôleurs pour live payant
  final TextEditingController _participationFeeController = TextEditingController(text: '100');
  final TextEditingController _freeTrialController = TextEditingController(text: '1');

  // Variables pour les paramètres
  bool _isPaidLive = false;
  String _audioBehavior = 'reduce';
  int _audioReductionPercent = 50;
  bool _blurVideoAfterTrial = true;
  bool _showPaymentModalAfterTrial = true;
  bool _useHDQuality = false;
  bool _useLowLatency = false;

  // Variables pour le contrôle
  bool _isCreating = false;
  Timer? _creationTimer;

  // Variables pour les restrictions
  Map<String, dynamic> _liveRestrictions = {};
  bool _canCreateLive = true;
  String _restrictionMessage = '';
  int _remainingLives = 5;
  LiveService _liveService = LiveService();

  // Variables pour la comparaison Gratuit vs Premium
  bool _showComparison = false;

  @override
  void initState() {
    super.initState();
    _loadLiveRestrictions();
  }

  @override
  void dispose() {
    _creationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLiveRestrictions() async {
    try {
      final restrictions = await _liveService.getLiveRestrictions();
      setState(() {
        _liveRestrictions = restrictions;
        _canCreateLive = restrictions['canCreate'] ?? true;
        _remainingLives = restrictions['remainingLives'] ?? 5;

        // Message d'information
        if (restrictions['isAdmin'] == true) {
          _restrictionMessage = 'Mode Admin : Pas de restrictions';
        } else if (restrictions['isPremium'] == true) {
          _restrictionMessage = 'Mode Premium : Toutes fonctionnalités débloquées';
        } else {
          _restrictionMessage = 'Mode Gratuit : ${_remainingLives} lives restants ce mois';
        }
      });
    } catch (e) {
      print('Erreur chargement restrictions: $e');
    }
  }

  Widget _buildRestrictionsHeader() {
    final isPremium = _liveRestrictions['isPremium'] == true;
    final isAdmin = _liveRestrictions['isAdmin'] == true;
    final remainingLives = _liveRestrictions['remainingLives'] ?? 5;
    final totalLives = _liveRestrictions['totalLivesThisMonth'] ?? 0;
    final maxLives = _liveRestrictions['maxLives'] ?? 5;

    Color headerColor;
    IconData headerIcon;
    String headerText;

    if (isAdmin) {
      headerColor = Colors.green;
      headerIcon = Icons.admin_panel_settings;
      headerText = 'Mode Admin';
    } else if (isPremium) {
      headerColor = Color(0xFFFDB813);
      headerIcon = Icons.workspace_premium;
      headerText = 'Mode Premium';
    } else {
      headerColor = Colors.grey;
      headerIcon = Icons.lock;
      headerText = 'Mode Gratuit';
    }

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: headerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: headerColor, size: 20),
              SizedBox(width: 10),
              Text(
                headerText,
                style: TextStyle(
                  color: headerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              if (!isAdmin && !isPremium)
                ElevatedButton(
                  onPressed: () {
                    _showPremiumComparison();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFDB813),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'PASSER À PREMIUM',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.live_tv, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                isAdmin
                    ? 'Lives illimités • Qualité HD • 500ms'
                    : isPremium
                    ? 'Lives illimités • Qualité HD • 500ms'
                    : 'Lives restants: $remainingLives/$maxLives • SD • 2s',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (!isAdmin && !isPremium && remainingLives <= 2)
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 14, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      remainingLives == 0
                          ? 'Vous avez atteint votre limite de lives ce mois.'
                          : 'Il vous reste seulement $remainingLives live(s) ce mois.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualityComparisonSection() {
    final isPremium = _liveRestrictions['isPremium'] == true;
    final isAdmin = _liveRestrictions['isAdmin'] == true;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Text(
                  'Choisissez votre expérience de live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Option Gratuit
            _buildExperienceOption(
              title: 'Gratuit',
              subtitle: 'Expérience de base',
              icon: Icons.lock,
              color: Colors.grey,
              isSelected: !_useHDQuality && !_useLowLatency,
              onTap: () {
                if (isAdmin || isPremium) {
                  setState(() {
                    _useHDQuality = false;
                    _useLowLatency = false;
                  });
                } else {
                  // Pour les non-premium, c'est la seule option
                  _useHDQuality = false;
                  _useLowLatency = false;
                  setState(() {});
                }
              },
              features: [
                '✅ 5 lives par mois',
                '✅ Qualité SD (480p)',
                '✅ Latence 2 secondes',
                '❌ Pas de HD',
                '❌ Pas de faible latence',
              ],
            ),

            SizedBox(height: 12),

            // Option Premium
            _buildExperienceOption(
              title: 'Premium',
              subtitle: 'Expérience optimale',
              icon: Icons.workspace_premium,
              color: Color(0xFFFDB813),
              isSelected: _useHDQuality || _useLowLatency,
              onTap: () {
                if (isAdmin || isPremium) {
                  setState(() {
                    _useHDQuality = true;
                    _useLowLatency = true;
                  });
                } else {
                  _showPremiumModal(
                    title: 'Expérience Premium',
                    message: 'L\'expérience Premium est réservée aux abonnés.\nProfitez d\'une qualité HD et d\'une latence réduite pour des lives parfaits.',
                  );
                }
              },
              features: [
                '✅ Lives illimités',
                '✅ Qualité HD (720p)',
                '✅ Latence 500ms',
                '✅ Réactions en temps réel',
                '✅ Expérience fluide',
              ],
              premiumOnly: true,
            ),

            SizedBox(height: 16),

            // Bouton pour voir la comparaison détaillée
            GestureDetector(
              onTap: () {
                setState(() {
                  _showComparison = !_showComparison;
                });
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFF9A825)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showComparison ? Icons.expand_less : Icons.expand_more,
                      color: Color(0xFFF9A825),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _showComparison ? 'MASQUER LES DÉTAILS' : 'VOIR LA COMPARAISON DÉTAILLÉE',
                      style: TextStyle(
                        color: Color(0xFFF9A825),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Comparaison détaillée
            if (_showComparison)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildComparisonRow(
                        feature: 'Nombre de lives',
                        freeValue: '5/mois',
                        premiumValue: 'Illimités',
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: 'Qualité vidéo',
                        freeValue: 'SD (480p)',
                        premiumValue: 'HD (720p)',
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: 'Latence',
                        freeValue: '2000ms',
                        premiumValue: '500ms',
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: 'Fluidité',
                        freeValue: 'Standard',
                        premiumValue: 'Optimale',
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: 'Interactions',
                        freeValue: 'Délai visible',
                        premiumValue: 'Temps réel',
                        premiumBetter: true,
                      ),
                      SizedBox(height: 12),
                      if (!isAdmin && !isPremium)
                        ElevatedButton(
                          onPressed: () {
                            _showPremiumModal(
                              title: 'Améliorez votre expérience',
                              message: 'Passez à Premium pour profiter de tous les avantages et offrez la meilleure expérience à votre audience.',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFDB813),
                            foregroundColor: Colors.black,
                            minimumSize: Size(double.infinity, 40),
                          ),
                          child: Text(
                            'DÉBLOQUER L\'EXPÉRIENCE PREMIUM',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required List<String> features,
    bool premiumOnly = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[800],
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (premiumOnly)
                            Container(
                              margin: EdgeInsets.only(left: 8),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFFDB813).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Color(0xFFFDB813)),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Color(0xFFFDB813),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 24),
              ],
            ),
            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features.map((feature) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        feature.startsWith('✅') ? Icons.check : Icons.close,
                        color: feature.startsWith('✅') ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature.substring(2),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow({
    required String feature,
    required String freeValue,
    required String premiumValue,
    required bool premiumBetter,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                freeValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: premiumBetter ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: premiumBetter ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                premiumValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumComparison() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFDB813)),
            SizedBox(width: 10),
            Text(
              'Gratuit vs Premium',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gratuit
              _buildPlanCard(
                title: 'Gratuit',
                color: Colors.grey,
                features: [
                  '5 lives par mois',
                  'Qualité SD (480p)',
                  'Latence 2 secondes',
                  'Interactions limitées',
                  'Expérience standard',
                ],
                price: '0 FCFA',
                isPremium: false,
              ),

              SizedBox(height: 16),

              // Premium
              _buildPlanCard(
                title: 'Premium',
                color: Color(0xFFFDB813),
                features: [
                  'Lives illimités',
                  'Qualité HD (720p)',
                  'Latence 500ms',
                  'Interactions en temps réel',
                  'Expérience optimale',
                ],
                price: '200 FCFA/mois',
                isPremium: true,
              ),

              SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFDB813)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFDB813)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Économisez jusqu\'à 500 FCFA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Réduction sur les abonnements longs (3, 6, 12 mois)',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'PAS MAINTENANT',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigation vers la page d'abonnement
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AbonnementScreen(),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFDB813),
              foregroundColor: Colors.black,
            ),
            child: Text('VOIR LES OFFRES'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required Color color,
    required List<String> features,
    required String price,
    required bool isPremium,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPremium ? Icons.workspace_premium : Icons.lock,
                    color: color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Column(
              children: features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      feature,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumModal({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFDB813)),
            SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFDB813)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Color(0xFFFDB813)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Afrolook Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Lives illimités • HD • 500ms • Pas de restriction',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'PAS MAINTENANT',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigation vers la page d'abonnement
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AbonnementScreen(),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFDB813),
              foregroundColor: Colors.black,
            ),
            child: Text('VOIR L\'ABONNEMENT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un live', style: TextStyle(color: Color(0xFFF9A825))),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),

                // Header restrictions
                _buildRestrictionsHeader(),

                SizedBox(height: 20),

                // Titre
                _buildTitleField(),

                SizedBox(height: 20),

                // Comparaison Gratuit vs Premium
                _buildQualityComparisonSection(),

                SizedBox(height: 20),

                // Type de live
                _buildLiveTypeSection(),

                if (_isPaidLive) ..._buildPaidLiveOptions(),

                SizedBox(height: 30),

                // Bouton de création
                _buildCreateButton(),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Titre du live',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: 'Donnez un titre à votre live...',
        hintStyle: TextStyle(color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(Icons.title, color: Color(0xFFF9A825)),
        filled: true,
        fillColor: Colors.grey[900],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un titre';
        }
        if (value.length > 100) {
          return 'Titre trop long (max 100 caractères)';
        }
        return null;
      },
    );
  }

  Widget _buildLiveTypeSection() {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Text(
                  'Type de live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLiveTypeOption(
                    title: 'Gratuit',
                    subtitle: 'Tout le monde peut regarder',
                    icon: Icons.people,
                    isSelected: !_isPaidLive,
                    onTap: () => setState(() => _isPaidLive = false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildLiveTypeOption(
                    title: 'Payant',
                    subtitle: 'Spectateurs payent pour regarder',
                    icon: Icons.attach_money,
                    isSelected: _isPaidLive,
                    onTap: () => setState(() => _isPaidLive = true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFF9A825).withOpacity(0.2) : Colors.grey[800],
          border: Border.all(
            color: isSelected ? Color(0xFFF9A825) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? Color(0xFFF9A825) : Colors.grey),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPaidLiveOptions() {
    return [
      SizedBox(height: 20),
      _buildParticipationFeeField(),
      SizedBox(height: 20),
      _buildFreeTrialField(),
      SizedBox(height: 20),
      _buildAudioBehaviorSection(),
      SizedBox(height: 20),
      _buildVisualRestrictionsSection(),
    ];
  }

  Widget _buildParticipationFeeField() {
    return TextFormField(
      controller: _participationFeeController,
      style: TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Prix de participation (FCFA)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: '100',
        hintStyle: TextStyle(color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(Icons.money, color: Color(0xFFF9A825)),
        filled: true,
        fillColor: Colors.grey[900],
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return 'Veuillez entrer un prix';
        }
        if (_isPaidLive) {
          final price = double.tryParse(value!);
          if (price == null) {
            return 'Prix invalide';
          }
          if (price < 10) {
            return 'Minimum 10 FCFA';
          }
          if (price > 100000) {
            return 'Maximum 100 000 FCFA';
          }
        }
        return null;
      },
    );
  }

  Widget _buildFreeTrialField() {
    return TextFormField(
      controller: _freeTrialController,
      style: TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Temps d\'essai gratuit (minutes)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: '1',
        hintStyle: TextStyle(color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(Icons.timer, color: Color(0xFFF9A825)),
        filled: true,
        fillColor: Colors.grey[900],
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return 'Veuillez entrer une durée';
        }
        if (_isPaidLive) {
          final minutes = int.tryParse(value!);
          if (minutes == null) {
            return 'Durée invalide';
          }
          if (minutes < 1) {
            return 'Minimum 1 minute';
          }
          if (minutes > 60) {
            return 'Maximum 60 minutes';
          }
        }
        return null;
      },
    );
  }

  Widget _buildAudioBehaviorSection() {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up, color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Text(
                  'Comportement du son après l\'essai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildAudioOption(
              value: 'mute',
              title: '🔇 Son coupé',
              subtitle: 'Le spectateur ne peut plus entendre',
              icon: Icons.volume_off,
            ),
            _buildAudioOption(
              value: 'reduce',
              title: '🎵 Son réduit',
              subtitle: 'Le son est baissé mais audible',
              icon: Icons.volume_down,
            ),
            _buildAudioOption(
              value: 'keep',
              title: '🔊 Son normal',
              subtitle: 'Le son reste inchangé',
              icon: Icons.volume_up,
            ),
            if (_audioBehavior == 'reduce') ...[
              SizedBox(height: 16),
              Text(
                'Réduction du son: $_audioReductionPercent%',
                style: TextStyle(color: Colors.white70),
              ),
              Slider(
                value: _audioReductionPercent.toDouble(),
                min: 10,
                max: 90,
                divisions: 8,
                label: '$_audioReductionPercent%',
                onChanged: (value) {
                  setState(() {
                    _audioReductionPercent = value.round();
                  });
                },
                activeColor: Color(0xFFF9A825),
                inactiveColor: Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon, color: Color(0xFFF9A825)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white)),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      value: value,
      groupValue: _audioBehavior,
      onChanged: (newValue) {
        setState(() {
          _audioBehavior = newValue!;
        });
      },
      activeColor: Color(0xFFF9A825),
    );
  }

  Widget _buildVisualRestrictionsSection() {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.remove_red_eye, color: Color(0xFFF9A825), size: 20),
                SizedBox(width: 8),
                Text(
                  'Restrictions visuelles après l\'essai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text(
                'Flouter la vidéo',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Rendre le flux vidéo flou',
                style: TextStyle(color: Colors.white70),
              ),
              value: _blurVideoAfterTrial,
              onChanged: (value) {
                setState(() {
                  _blurVideoAfterTrial = value;
                });
              },
              activeColor: Color(0xFFF9A825),
            ),
            SwitchListTile(
              title: Text(
                'Afficher le modal de paiement',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Montrer automatiquement la demande de paiement',
                style: TextStyle(color: Colors.white70),
              ),
              value: _showPaymentModalAfterTrial,
              onChanged: (value) {
                setState(() {
                  _showPaymentModalAfterTrial = value;
                });
              },
              activeColor: Color(0xFFF9A825),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final isAdmin = _liveRestrictions['isAdmin'] == true;
    final isPremium = _liveRestrictions['isPremium'] == true;
    final remainingLives = _liveRestrictions['remainingLives'] ?? 0;
    final canCreate = isAdmin || isPremium || remainingLives > 0;
    final actualQuality = _useHDQuality && (_liveRestrictions['canChooseHD'] == true || isAdmin) ? 'HD' : 'SD';
    final actualLatency = _useLowLatency && (_liveRestrictions['canChooseLowLatency'] == true || isAdmin) ? 500 : 2000;

    return Column(
      children: [
        // Résumé de la configuration
        Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFF9A825)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Résumé de votre live',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.title, color: Color(0xFFF9A825), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleController.text.isNotEmpty ? _titleController.text : 'Aucun titre',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.video_settings, color: Color(0xFFF9A825), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Qualité: $actualQuality',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.speed, color: Color(0xFFF9A825), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Latence: ${actualLatency}ms',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.monetization_on, color: Color(0xFFF9A825), size: 16),
                  SizedBox(width: 8),
                  Text(
                    _isPaidLive ? 'Live payant • ${_participationFeeController.text}FCFA' : 'Live gratuit',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (!isAdmin && !isPremium && actualQuality == 'SD')
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Color(0xFFFDB813), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Passez à Premium pour améliorer la qualité',
                          style: TextStyle(
                            color: Color(0xFFFDB813),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        if (!canCreate && !isAdmin && !isPremium)
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      'Limite de lives atteinte',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Vous avez utilisé vos 5 lives gratuits ce mois.\nPassez à Premium pour des lives illimités.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AbonnementScreen(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFDB813),
                    foregroundColor: Colors.black,
                    minimumSize: Size(double.infinity, 40),
                  ),
                  child: Text(
                    'PASSER À PREMIUM',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        ElevatedButton(
          onPressed: _isCreating || !canCreate ? null : _createLive,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4),
            child: _isCreating
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Création en cours...',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text(
                  'DÉMARRER LE LIVE',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCreating || !canCreate
                ? Colors.grey[700]
                : Color(0xFFF9A825),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createLive() async {
    if (_isCreating) {
      print('⚠️ Tentative bloquée : création déjà en cours');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      print('❌ Validation du formulaire échouée');
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print('❌ Utilisateur non authentifié');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous devez être connecté pour créer un live'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier les restrictions
    final checkResult = await _liveService.canCreateLive();
    if (!checkResult['canCreate'] && _liveRestrictions['isAdmin'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(checkResult['message']),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    _creationTimer = Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _isCreating = false);
        print('🔓 Verrouillage automatique libéré après 10 secondes');
      }
    });

    try {
      // Vérifier si l'utilisateur a déjà un live actif
      final activeLiveQuery = await _firestore
          .collection('lives')
          .where('hostId', isEqualTo: user.uid)
          .where('isLive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeLiveQuery.docs.isNotEmpty) {
        final existingLiveId = activeLiveQuery.docs.first.id;
        final liveData = activeLiveQuery.docs.first.data();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous avez déjà un live en cours'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: existingLiveId,
              isHost: true,
              hostName: liveData['hostName'] ?? 'Hôte',
              hostImage: liveData['hostImage'] ?? '',
              isInvited: false,
              postLive: PostLive.fromMap(liveData),
            ),
          ),
        );
        return;
      }

      // Créer le nouveau live
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final String liveId = _firestore.collection('lives').doc().id;
      final isAdmin = _liveRestrictions['isAdmin'] == true;
      // Création du live
      final PostLive newLive = PostLive(
        liveId: liveId,
        hostId: user.uid,
        hostName: authProvider.loginUserData.pseudo! ?? 'Utilisateur',
        hostImage: authProvider.loginUserData.imageUrl! ?? 'https://via.placeholder.com/150',
        title: _titleController.text.trim(),
        startTime: DateTime.now(),
        liveDurationMinutes: isAdmin?60:30,
        // Paramètres live payant
        isPaidLive: _isPaidLive,
        participationFee: _isPaidLive ? double.parse(_participationFeeController.text) : 0.0,
        freeTrialMinutes: _isPaidLive ? int.parse(_freeTrialController.text) : 0,

        // Comportement après essai
        audioBehaviorAfterTrial: _audioBehavior,
        audioReductionPercent: _audioReductionPercent,
        blurVideoAfterTrial: _blurVideoAfterTrial,
        showPaymentModalAfterTrial: _showPaymentModalAfterTrial,
      );

      // Sauvegarder dans Firestore
      await _firestore.collection('lives').doc(liveId).set(newLive.toMap());

      // Calculer la qualité selon les choix et restrictions
      final actualQuality = _useHDQuality && (_liveRestrictions['canChooseHD'] == true || _liveRestrictions['isAdmin'] == true) ? 'HD' : 'SD';
      final actualLatency = _useLowLatency && (_liveRestrictions['canChooseLowLatency'] == true || _liveRestrictions['isAdmin'] == true) ? 500 : 2000;

      print("✅ Live créé avec succès: $liveId - Qualité: $actualQuality - Latence: ${actualLatency}ms");

      // Incrémenter le compteur de lives (sauf pour admin)
      if (_liveRestrictions['isAdmin'] != true) {
        await _liveService.incrementLiveCount();
      }

      // Envoyer les notifications
      _sendNotifications(authProvider, newLive);

      // Navigation vers le live
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LivePage(
            liveId: liveId,
            isHost: true,
            hostName: newLive.hostName!,
            hostImage: newLive.hostImage!,
            isInvited: false,
            postLive: newLive,
          ),
        ),
      );

    } catch (e) {
      print("❌ Erreur création live: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du live: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      _creationTimer?.cancel();
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _sendNotifications(UserAuthProvider authProvider, PostLive newLive) async {
    try {
      authProvider.getAllUsersOneSignaUserId().then((userIds) async {
        if (userIds.isNotEmpty) {
          await authProvider.sendNotification(
            userIds: userIds,
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: "",
            message: "🚀 @${authProvider.loginUserData.pseudo!} vient de lancer un live : ${newLive.title}",
            type_notif: NotificationType.CHRONIQUE.name,
            post_id: newLive.liveId ?? "id",
            post_type: PostDataType.TEXT.name,
            chat_id: '',
          );
          print("📨 Notifications envoyées à ${userIds.length} utilisateurs");
        }
      });
    } catch (e) {
      print("⚠️ Erreur envoi notifications: $e");
    }
  }
}


// // models/live_models.dart
// import 'dart:async';
// import 'dart:math';
// import 'package:afrotok/pages/component/consoleWidget.dart';
// import 'package:afrotok/pages/component/showUserDetails.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// import '../../models/model_data.dart';
// import '../paiement/newDepot.dart';
// import 'create_live_page.dart';
// import 'livePage.dart';
// import 'livesAgora.dart';
// // pages/live/create_live_page.dart
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import '../../models/model_data.dart';
// import '../../providers/authProvider.dart';
// import 'livePage.dart';
//
// class CreateLivePage extends StatefulWidget {
//   @override
//   _CreateLivePageState createState() => _CreateLivePageState();
// }
//
// class _CreateLivePageState extends State<CreateLivePage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final TextEditingController _titleController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//
//   // NOUVEAUX CONTROLLERS POUR LIVE PAYANT
//   final TextEditingController _participationFeeController = TextEditingController(text: '100');
//   final TextEditingController _freeTrialController = TextEditingController(text: '1');
//
//   // VARIABLES POUR LES PARAMÈTRES
//   bool _isPaidLive = false;
//   String _audioBehavior = 'reduce';
//   int _audioReductionPercent = 50;
//   bool _blurVideoAfterTrial = true;
//   bool _showPaymentModalAfterTrial = true;
//
//   // ⭐⭐ NOUVELLE VARIABLE POUR SÉCURISATION ⭐⭐
//   bool _isCreating = false;
//   Timer? _creationTimer;
//
//   @override
//   void dispose() {
//     // Nettoyer le timer si la page est fermée
//     _creationTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = context.watch<UserAuthProvider>();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Créer un live', style: TextStyle(color: Color(0xFFF9A825))),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               SizedBox(height: 20),
//               _buildTitleField(),
//               SizedBox(height: 20),
//               _buildLiveTypeSection(),
//               if (_isPaidLive) ..._buildPaidLiveOptions(),
//               SizedBox(height: 30),
//               _buildCreateButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTitleField() {
//     return TextFormField(
//       controller: _titleController,
//       style: TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: 'Titre du live',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Veuillez entrer un titre';
//         }
//         if (value.length > 100) {
//           return 'Titre trop long (max 100 caractères)';
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildLiveTypeSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Type de live',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildLiveTypeOption(
//                     title: 'Gratuit',
//                     subtitle: 'Tout le monde peut regarder',
//                     isSelected: !_isPaidLive,
//                     onTap: () => setState(() => _isPaidLive = false),
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: _buildLiveTypeOption(
//                     title: 'Payant',
//                     subtitle: 'Spectateurs payent pour regarder',
//                     isSelected: _isPaidLive,
//                     onTap: () => setState(() => _isPaidLive = true),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLiveTypeOption({
//     required String title,
//     required String subtitle,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFFF9A825).withOpacity(0.2) : Colors.grey[800],
//           border: Border.all(
//             color: isSelected ? Color(0xFFF9A825) : Colors.transparent,
//             width: 2,
//           ),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               subtitle,
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   List<Widget> _buildPaidLiveOptions() {
//     return [
//       SizedBox(height: 20),
//       _buildParticipationFeeField(),
//       SizedBox(height: 20),
//       _buildFreeTrialField(),
//       SizedBox(height: 20),
//       _buildAudioBehaviorSection(),
//       SizedBox(height: 20),
//       _buildVisualRestrictionsSection(),
//     ];
//   }
//
//   Widget _buildParticipationFeeField() {
//     return TextFormField(
//       controller: _participationFeeController,
//       style: TextStyle(color: Colors.white),
//       keyboardType: TextInputType.number,
//       decoration: InputDecoration(
//         labelText: 'Prix de participation (FCFA)',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//         prefixText: 'FCFA ',
//         prefixStyle: TextStyle(color: Colors.white70),
//       ),
//       validator: (value) {
//         if (_isPaidLive && (value == null || value.isEmpty)) {
//           return 'Veuillez entrer un prix';
//         }
//         if (_isPaidLive) {
//           final price = double.tryParse(value!);
//           if (price == null) {
//             return 'Prix invalide';
//           }
//           if (price < 10) {
//             return 'Minimum 10 FCFA';
//           }
//           if (price > 100000) {
//             return 'Maximum 100 000 FCFA';
//           }
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildFreeTrialField() {
//     return TextFormField(
//       controller: _freeTrialController,
//       style: TextStyle(color: Colors.white),
//       keyboardType: TextInputType.number,
//       decoration: InputDecoration(
//         labelText: 'Temps d\'essai gratuit (minutes)',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//         suffixText: 'min',
//         suffixStyle: TextStyle(color: Colors.white70),
//       ),
//       validator: (value) {
//         if (_isPaidLive && (value == null || value.isEmpty)) {
//           return 'Veuillez entrer une durée';
//         }
//         if (_isPaidLive) {
//           final minutes = int.tryParse(value!);
//           if (minutes == null) {
//             return 'Durée invalide';
//           }
//           if (minutes < 1) {
//             return 'Minimum 1 minute';
//           }
//           if (minutes > 60) {
//             return 'Maximum 60 minutes';
//           }
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildAudioBehaviorSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Comportement du son après l\'essai',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             _buildAudioOption(
//               value: 'mute',
//               title: '🔇 Son coupé',
//               subtitle: 'Le spectateur ne peut plus entendre',
//             ),
//             _buildAudioOption(
//               value: 'reduce',
//               title: '🎵 Son réduit',
//               subtitle: 'Le son est baissé mais audible',
//             ),
//             _buildAudioOption(
//               value: 'keep',
//               title: '🔊 Son normal',
//               subtitle: 'Le son reste inchangé',
//             ),
//             if (_audioBehavior == 'reduce') ...[
//               SizedBox(height: 16),
//               Text(
//                 'Réduction du son: $_audioReductionPercent%',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               Slider(
//                 value: _audioReductionPercent.toDouble(),
//                 min: 10,
//                 max: 90,
//                 divisions: 8,
//                 label: '$_audioReductionPercent%',
//                 onChanged: (value) {
//                   setState(() {
//                     _audioReductionPercent = value.round();
//                   });
//                 },
//                 activeColor: Color(0xFFF9A825),
//                 inactiveColor: Colors.grey,
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAudioOption({
//     required String value,
//     required String title,
//     required String subtitle,
//   }) {
//     return RadioListTile<String>(
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: TextStyle(color: Colors.white)),
//           SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: TextStyle(color: Colors.white70, fontSize: 12),
//           ),
//         ],
//       ),
//       value: value,
//       groupValue: _audioBehavior,
//       onChanged: (newValue) {
//         setState(() {
//           _audioBehavior = newValue!;
//         });
//       },
//       activeColor: Color(0xFFF9A825),
//     );
//   }
//
//   Widget _buildVisualRestrictionsSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Restrictions visuelles après l\'essai',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             SwitchListTile(
//               title: Text(
//                 'Flouter la vidéo',
//                 style: TextStyle(color: Colors.white),
//               ),
//               subtitle: Text(
//                 'Rendre le flux vidéo flou',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               value: _blurVideoAfterTrial,
//               onChanged: (value) {
//                 setState(() {
//                   _blurVideoAfterTrial = value;
//                 });
//               },
//               activeColor: Color(0xFFF9A825),
//             ),
//             SwitchListTile(
//               title: Text(
//                 'Afficher le modal de paiement',
//                 style: TextStyle(color: Colors.white),
//               ),
//               subtitle: Text(
//                 'Montrer automatiquement la demande de paiement',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               value: _showPaymentModalAfterTrial,
//               onChanged: (value) {
//                 setState(() {
//                   _showPaymentModalAfterTrial = value;
//                 });
//               },
//               activeColor: Color(0xFFF9A825),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ⭐⭐ BOUTON CRÉATION AVEC SÉCURISATION ⭐⭐
//   Widget _buildCreateButton() {
//     return ElevatedButton(
//       onPressed: _isCreating ? null : _createLive,
//       child: _isCreating
//           ? Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SizedBox(
//             width: 20,
//             height: 20,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: Colors.black,
//             ),
//           ),
//           SizedBox(width: 12),
//           Text(
//             'Création en cours...',
//             style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//           ),
//         ],
//       )
//           : Text(
//         'Démarrer le live',
//         style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//       ),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: _isCreating ? Colors.grey[700] : Color(0xFFF9A825),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }
//
//   // ⭐⭐ MÉTHODE DE CRÉATION SÉCURISÉE ⭐⭐
//   Future<void> _createLive() async {
//     // 1. VÉRIFICATION PRÉLIMINAIRE
//     if (_isCreating) {
//       print('⚠️ Tentative bloquée : création déjà en cours');
//       return;
//     }
//
//     if (!_formKey.currentState!.validate()) {
//       print('❌ Validation du formulaire échouée');
//       return;
//     }
//
//     final User? user = _auth.currentUser;
//     if (user == null) {
//       print('❌ Utilisateur non authentifié');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Vous devez être connecté pour créer un live'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
//
//     // 2. ACTIVER LE VERROUILLAGE
//     setState(() => _isCreating = true);
//
//     // Timer de sécurité : déverrouille automatiquement après 10 secondes
//     _creationTimer = Timer(Duration(seconds: 10), () {
//       if (mounted) {
//         setState(() => _isCreating = false);
//         print('🔓 Verrouillage automatique libéré après 10 secondes');
//       }
//     });
//
//     try {
//       // 3. VÉRIFIER SI L'UTILISATEUR A DÉJÀ UN LIVE ACTIF
//       final activeLiveQuery = await _firestore
//           .collection('lives')
//           .where('hostId', isEqualTo: user.uid)
//           .where('isLive', isEqualTo: true)
//           .limit(1)
//           .get();
//
//       if (activeLiveQuery.docs.isNotEmpty) {
//         // L'utilisateur a déjà un live actif
//         print('❌ Utilisateur a déjà un live actif: ${activeLiveQuery.docs.first.id}');
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Vous avez déjà un live en cours. Terminez-le avant d\'en créer un nouveau.'),
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 4),
//           ),
//         );
//
//         // Navigation vers le live existant
//         final existingLiveId = activeLiveQuery.docs.first.id;
//         final liveData = activeLiveQuery.docs.first.data();
//
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => LivePage(
//               liveId: existingLiveId,
//               isHost: true,
//               hostName: liveData['hostName'] ?? 'Hôte',
//               hostImage: liveData['hostImage'] ?? '',
//               isInvited: false,
//               postLive: PostLive.fromMap(liveData),
//             ),
//           ),
//         );
//         return;
//       }
//
//       // 4. CRÉER LE NOUVEAU LIVE
//       final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//       final String liveId = _firestore.collection('lives').doc().id;
//
//       // Création du live avec tous les paramètres
//       final PostLive newLive = PostLive(
//         liveId: liveId,
//         hostId: user.uid,
//         hostName: authProvider.loginUserData.pseudo! ?? 'Utilisateur',
//         hostImage: authProvider.loginUserData.imageUrl! ?? 'https://via.placeholder.com/150',
//         title: _titleController.text.trim(),
//         startTime: DateTime.now(),
//
//         // Paramètres live payant
//         isPaidLive: _isPaidLive,
//         participationFee: _isPaidLive ? double.parse(_participationFeeController.text) : 0.0,
//         freeTrialMinutes: _isPaidLive ? int.parse(_freeTrialController.text) : 0,
//
//         // Comportement après essai
//         audioBehaviorAfterTrial: _audioBehavior,
//         audioReductionPercent: _audioReductionPercent,
//         blurVideoAfterTrial: _blurVideoAfterTrial,
//         showPaymentModalAfterTrial: _showPaymentModalAfterTrial,
//       );
//
//       // 5. SAUVEGARDE DANS FIRESTORE
//       await _firestore.collection('lives').doc(liveId).set(newLive.toMap());
//       print("✅ Live créé avec succès: $liveId");
//
//       // 6. ENVOYER LES NOTIFICATIONS (en arrière-plan)
//       _sendNotifications(authProvider, newLive);
//
//       // 7. NAVIGATION VERS LE LIVE
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => LivePage(
//             liveId: liveId,
//             isHost: true,
//             hostName: newLive.hostName!,
//             hostImage: newLive.hostImage!,
//             isInvited: false,
//             postLive: newLive,
//           ),
//         ),
//       );
//
//     } catch (e) {
//       print("❌ Erreur création live: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Erreur lors de la création du live: ${e.toString()}'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 4),
//         ),
//       );
//     } finally {
//       // 8. DÉSACTIVER LE VERROUILLAGE QUOI QU'IL ARRIVE
//       _creationTimer?.cancel();
//       if (mounted) {
//         setState(() => _isCreating = false);
//       }
//     }
//   }
//
//   // ⭐⭐ MÉTHODE POUR ENVOYER LES NOTIFICATIONS (ASYNCHRONE)
//   Future<void> _sendNotifications(UserAuthProvider authProvider, PostLive newLive) async {
//     try {
//       // Cette partie s'exécute en arrière-plan, ne bloque pas l'interface
//       authProvider.getAllUsersOneSignaUserId().then((userIds) async {
//         if (userIds.isNotEmpty) {
//           await authProvider.sendNotification(
//             userIds: userIds,
//             smallImage: authProvider.loginUserData.imageUrl!,
//             send_user_id: authProvider.loginUserData.id!,
//             recever_user_id: "",
//             message: "🚀 @${authProvider.loginUserData.pseudo!} vient tout juste de lancer un live 🎬✨ ! : ${newLive.title}",
//             type_notif: NotificationType.CHRONIQUE.name,
//             post_id: newLive.liveId ?? "id",
//             post_type: PostDataType.TEXT.name,
//             chat_id: '',
//           );
//           print("📨 Notifications envoyées à ${userIds.length} utilisateurs");
//         }
//       });
//     } catch (e) {
//       print("⚠️ Erreur envoi notifications: $e");
//       // Ne pas bloquer la création du live si les notifications échouent
//     }
//   }
// }
//
//
