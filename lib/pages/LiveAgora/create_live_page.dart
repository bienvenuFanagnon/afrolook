import 'package:afrotok/l10n/tr.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/api_identity.dart';
import '../../services/media_shrink.dart';
import 'package:afrotok/services/account_gate.dart';
import '../../utils/platform_guard.dart';
import 'dart:async';
import 'dart:io';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // uniquement l'état en direct du live (spectateurs, commentaires), qui reste sur Firebase
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/lives_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:afrotok/services/api/live_shop_api.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/api/shop_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/livesServices.dart';
import '../user/userAbonnementPage.dart';
import 'livePage.dart';
import 'package:afrotok/services/api/live_display.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'livesAgora.dart';

class CreateLivePage extends StatefulWidget {
  /// [initialShopping] : démarre sur « Vente en direct » ; [articleIds] : articles de la boutique à épingler dès le début du live (depuis la page de la boutique).
  const CreateLivePage({super.key, this.initialShopping = false, this.articleIds = const []});

  final bool initialShopping;
  final List<String> articleIds;

  @override
  _CreateLivePageState createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<CreateLivePage> {
  // Thème clair ou sombre de l'application (comme les autres pages)
  AppColors get _c => AppColors.of(context);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _coverUploadId;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Contrôleurs pour live payant
  final TextEditingController _participationFeeController = TextEditingController(text: '250');
  final TextEditingController _freeTrialController = TextEditingController(text: '1');

  // Variables pour les paramètres
  bool _isPaidLive = false;
  late bool _isShoppingLive = widget.initialShopping;   // vente en direct (Live Shopping)
  bool _audioRoom = false;                              // salon audio : pas de vidéo, billet le moins cher
  int _marketStalls = 6;
  int _marketRent = 300;
  int _marketMinutes = 15;
  String _game = '';                                    // duel ou défi à plusieurs (jeux de live), vide pour une discussion ou une vente
  String _audioBehavior = 'reduce';
  int _audioReductionPercent = 50;
  bool _blurVideoAfterTrial = true;
  bool _showPaymentModalAfterTrial = true;
  bool _useHDQuality = false;
  bool _useLowLatency = false;

  // Image de couverture
  File? _coverImageFile;
  String? _coverImageUrl;
  bool _isUploadingCover = false;

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

  // Aperçu de la caméra, produits à épingler, options repliées (page refaite le 06/11/2026)
  CameraController? _cam;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  bool _camReady = false;
  List<ArticleData> _myArticles = [];
  final List<String> _pickedArticles = [];
  bool _showOptions = false;

  // Minutes d'Agora : tant qu'il reste du gratuit, tout est gratuit ; ensuite les spectateurs prennent un billet et l'hôte paie ses frais de diffusion
  Map<String, dynamic>? _minutes;
  bool _offerEntry = false;
  int _ticketExtra = 0;
  int _ticketTrial = 1;
  bool _allowStage = true;
  LiveDisplay _liveDisplay = LiveDisplay.essential;
  bool get _ticketMode => _minutes?['mode'] == 'ticket';

  @override
  void initState() {
    super.initState();
    // Compte bloqué pour inactivité (20 jours sans publication) : déblocage en pièces avant de continuer
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await AccountGate.ensureCanPublish(context) && mounted) Navigator.of(context).maybePop();
    });
    _loadLiveRestrictions();
    _loadMinutes();
    _pickedArticles.addAll(widget.articleIds);
    _initPreview();
    if (_isShoppingLive) _loadArticles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkActiveLive());
  }

  Future<void> _loadMinutes() async {
    try {
      final m = await LivesApi.minutes();
      if (mounted) setState(() => _minutes = m);
    } catch (_) {}
  }

  int _num(String k, [int d = 0]) => (_minutes?[k] as num?)?.toInt() ?? d;

  /// Un seul live actif par hôte : dès l'ouverture de la page, proposer de reprendre
  /// le live en cours ou de le terminer pour en créer un nouveau.
  Future<void> _checkActiveLive() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final page = await LivesApi.list(status: 'live', hostId: (ApiIdentity.myId ?? user.uid), limit: 1);
      if (page.items.isEmpty || !mounted) return;
      final apiLive = page.items.first;
      final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
      final liveId = '${apiLive['id']}';
      final title = (apiLive['title'] as String?)?.trim();

      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(tr('Tu as déjà un live en cours')),
          content: Text(
            (title != null && title.isNotEmpty ? '« $title » est toujours en direct. ' : tr('Un de tes lives est toujours en direct. ')) +
                tr('Un seul live à la fois est possible : reprends-le, ou termine-le pour en créer un nouveau.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'fermer'), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'terminer'), child: Text(tr('Terminer ce live'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'reprendre'), child: const Text('Reprendre')),
          ],
        ),
      );
      if (!mounted) return;

      if (choice == 'reprendre') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: liveId,
              isHost: true,
              hostName: me.pseudo ?? tr('Hôte'),
              hostImage: me.imageUrl ?? '',
              isInvited: false,
              postLive: postLiveFromApi(apiLive, hostName: me.pseudo ?? '', hostImage: me.imageUrl ?? ''),
            ),
          ),
        );
      } else if (choice == 'terminer') {
        await LivesApi.end(liveId);
        try {
          await _firestore.collection('lives').doc(liveId).update({'isLive': false, 'endTime': DateTime.now()});
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Live terminé : tu peux en créer un nouveau.'))),
          );
        }
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      printVm('Vérification live actif : $e');
    }
  }

  @override
  void dispose() {
    _creationTimer?.cancel();
    _cam?.dispose();
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
          _restrictionMessage = tr('Mode Admin : Pas de restrictions');
        } else if (restrictions['isPremium'] == true) {
          _restrictionMessage = tr('Mode Premium : Toutes fonctionnalités débloquées');
        } else {
          _restrictionMessage = 'Mode Gratuit : ${_remainingLives} lives restants ce mois';
        }
      });
    } catch (e) {
      printVm('Erreur chargement restrictions: $e');
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
      headerColor = _c.textSecondary;
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
                    tr('PASSER À PREMIUM'),
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
              Icon(Icons.live_tv, size: 16, color: _c.textSecondary),
              SizedBox(width: 8),
              Text(
                isAdmin
                    ? tr('Lives illimités • Qualité HD • 500ms')
                    : isPremium
                    ? tr('Lives illimités • Qualité HD • 500ms')
                    : 'Lives restants: $remainingLives/$maxLives • SD • 2s',
                style: TextStyle(
                  color: _c.textSecondary,
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
                          ? tr('Vous avez atteint votre limite de lives ce mois.')
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
      color: _c.surface,
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
                  tr('Choisissez votre expérience de live'),
                  style: TextStyle(
                    color: _c.textPrimary,
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
              subtitle: tr('Expérience de base'),
              icon: Icons.lock,
              color: _c.textSecondary,
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
                tr('✅ Qualité SD (480p)'),
                '✅ Latence 2 secondes',
                tr('❌ Pas de HD'),
                tr('❌ Pas de faible latence'),
              ],
            ),

            SizedBox(height: 12),

            // Option Premium
            _buildExperienceOption(
              title: 'Premium',
              subtitle: tr('Expérience optimale'),
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
                    title: tr('Expérience Premium'),
                    message: tr('L\'expérience Premium est réservée aux abonnés.\nProfitez d\'une qualité HD et d\'une latence réduite pour des lives parfaits.'),
                  );
                }
              },
              features: [
                tr('✅ Lives illimités'),
                tr('✅ Qualité HD (720p)'),
                '✅ Latence 500ms',
                tr('✅ Réactions en temps réel'),
                tr('✅ Expérience fluide'),
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
                  color: _c.surfaceVariant,
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
                      _showComparison ? tr('MASQUER LES DÉTAILS') : tr('VOIR LA COMPARAISON DÉTAILLÉE'),
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
                    color: _c.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildComparisonRow(
                        feature: tr('Nombre de lives'),
                        freeValue: '5/mois',
                        premiumValue: tr('Illimités'),
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: tr('Qualité vidéo'),
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
                        feature: tr('Fluidité'),
                        freeValue: 'Standard',
                        premiumValue: 'Optimale',
                        premiumBetter: true,
                      ),
                      _buildComparisonRow(
                        feature: 'Interactions',
                        freeValue: tr('Délai visible'),
                        premiumValue: tr('Temps réel'),
                        premiumBetter: true,
                      ),
                      SizedBox(height: 12),
                      if (!isAdmin && !isPremium)
                        ElevatedButton(
                          onPressed: () {
                            _showPremiumModal(
                              title: tr('Améliorez votre expérience'),
                              message: tr('Passez à Premium pour profiter de tous les avantages et offrez la meilleure expérience à votre audience.'),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFDB813),
                            foregroundColor: Colors.black,
                            minimumSize: Size(double.infinity, 40),
                          ),
                          child: Text(
                            tr('DÉBLOQUER L\'EXPÉRIENCE PREMIUM'),
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
          color: isSelected ? color.withOpacity(0.2) : _c.surfaceVariant,
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
                              color: _c.textPrimary,
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
                          color: _c.textSecondary,
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
                            color: _c.textSecondary,
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
        border: Border(bottom: BorderSide(color: _c.surfaceVariant!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                color: _c.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                freeValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _c.textPrimary,
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
                  color: _c.textPrimary,
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
        backgroundColor: _c.surface,
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
                color: _c.textPrimary,
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
                color: _c.textSecondary,
                features: [
                  '5 lives par mois',
                  tr('Qualité SD (480p)'),
                  'Latence 2 secondes',
                  tr('Interactions limitées'),
                  tr('Expérience standard'),
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
                  tr('Lives illimités'),
                  tr('Qualité HD (720p)'),
                  'Latence 500ms',
                  tr('Interactions en temps réel'),
                  tr('Expérience optimale'),
                ],
                price: tr('500 pièces/mois'),
                isPremium: true,
              ),

              SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _c.surfaceVariant,
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
                            tr('Économisez jusqu\'à 1 250 pièces'),
                            style: TextStyle(
                              color: _c.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            tr('Réduction sur les abonnements longs (3, 6, 12 mois)'),
                            style: TextStyle(
                              color: _c.textSecondary,
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
              tr('PAS MAINTENANT'),
              style: TextStyle(color: _c.textSecondary),
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
            child: Text(tr('VOIR LES OFFRES')),
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
                    color: _c.textPrimary,
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
                        color: _c.textSecondary,
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
                color: _c.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: _c.textPrimary,
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
        backgroundColor: _c.surface,
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
                color: _c.textPrimary,
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
              style: TextStyle(color: _c.textSecondary),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _c.surfaceVariant,
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
                            color: _c.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          tr('Lives illimités • HD • 500ms • Pas de restriction'),
                          style: TextStyle(
                            color: _c.textSecondary,
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
              tr('PAS MAINTENANT'),
              style: TextStyle(color: _c.textSecondary),
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

  // ── Aperçu de la caméra ────────────────────────────────────────────────────
  Future<void> _initPreview() async {
    try {
      if (_cams.isEmpty) _cams = await availableCameras();
      if (_cams.isEmpty) return;
      final want = _cams.indexWhere((c) => c.lensDirection == (_camIndex == 0 ? CameraLensDirection.front : CameraLensDirection.back));
      final desc = _cams[want >= 0 ? want : 0];
      final old = _cam;
      final ctl = CameraController(desc, ResolutionPreset.medium, enableAudio: false);
      await ctl.initialize();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _cam = ctl;
        _camReady = true;
      });
      await old?.dispose();
    } catch (_) {
      if (mounted) setState(() => _camReady = false);
    }
  }

  Future<void> _flipCamera() async {
    setState(() {
      _camIndex = _camIndex == 0 ? 1 : 0;
      _camReady = false;
    });
    await _initPreview();
  }

  Future<void> _stopPreview() async {
    final c = _cam;
    _cam = null;
    _camReady = false;
    await c?.dispose();
  }

  Future<void> _loadArticles() async {
    if (_myArticles.isNotEmpty) return;
    try {
      final id = ApiIdentity.myId;
      if (id == null) return;
      final mine = await ShopApi.articles(ownerId: id, limit: 50);
      if (mounted) setState(() => _myArticles = mine.items.where((a) => a.id != null).toList());
    } catch (_) {}
  }

  bool get _canCreate {
    final isAdmin = _liveRestrictions['isAdmin'] == true;
    final isPremium = _liveRestrictions['isPremium'] == true;
    final remaining = _liveRestrictions['remainingLives'] ?? 0;
    return isAdmin || isPremium || remaining > 0;
  }

  static const Color _gold = Color(0xFFFFC400);

  Widget _buildPreviewCard() {
    final front = _camIndex == 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Colors.black),
          if (_camReady && _cam != null && _cam!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: _cam!.value.previewSize?.height ?? 1, height: _cam!.value.previewSize?.width ?? 1, child: CameraPreview(_cam!)),
            )
          else
            const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
              child: Text(front ? tr('Aperçu · caméra avant') : tr('Aperçu · caméra arrière'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: _flipCamera,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.45), border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _modeCard({required String title, required String subtitle, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? _gold.withOpacity(0.14) : _c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _gold : _c.border, width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: selected ? _c.accentText : _c.textSecondary),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, size: 18, color: _c.accentText),
            ]),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: _c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: _c.textSecondary, fontSize: 12, height: 1.3)),
          ]),
        ),
      ),
    );
  }

  Widget _buildModeCards() {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _modeCard(
          title: tr('Discussion'),
          subtitle: tr('Parle, échange, reçois des cadeaux'),
          icon: Icons.forum_outlined,
          selected: !_isShoppingLive && _game.isEmpty && !_audioRoom,
          onTap: () => setState(() {
            _isShoppingLive = false;
            _game = '';
            _audioRoom = false;
          }),
        ),
        const SizedBox(width: 10),
        _modeCard(
          title: tr('Vente en direct'),
          subtitle: tr('Vends les articles de ta boutique'),
          icon: Icons.shopping_bag_outlined,
          selected: _isShoppingLive,
          onTap: () {
            setState(() {
              _isShoppingLive = true;
              _game = '';
              _audioRoom = false;
            });
            _loadArticles();
          },
        ),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _modeCard(
          title: '${tr('Marché en direct')} · ${tr('Nouveau')}',
          subtitle: tr('Des vendeurs louent un étal chez toi'),
          icon: Icons.storefront_outlined,
          selected: _game == 'market',
          onTap: () => setState(() {
            _isShoppingLive = false;
            _game = 'market';
            _audioRoom = false;
            _allowStage = true;
          }),
        ),
        const SizedBox(width: 10),
        _modeCard(
          title: '${tr('Salon audio')} · ${tr('Nouveau')}',
          subtitle: tr('Que des voix, billet le moins cher'),
          icon: Icons.mic_none_rounded,
          selected: _audioRoom,
          onTap: () => setState(() {
            _isShoppingLive = false;
            _game = '';
            _audioRoom = true;
            _allowStage = true;
          }),
        ),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _modeCard(
          title: '${tr('Duel')} · ${tr('Nouveau')}',
          subtitle: tr('1 contre 1, les cadeaux décident'),
          icon: Icons.sports_mma_outlined,
          selected: _game == 'duel',
          onTap: () => setState(() {
            _isShoppingLive = false;
            _audioRoom = false;
            _game = 'duel';
            _allowStage = true;
          }),
        ),
        const SizedBox(width: 10),
        _modeCard(
          title: '${tr('Défi à plusieurs')} · ${tr('Nouveau')}',
          subtitle: tr('Le premier à l\'objectif gagne'),
          icon: Icons.groups_outlined,
          selected: _game == 'challenge',
          onTap: () => setState(() {
            _isShoppingLive = false;
            _audioRoom = false;
            _game = 'challenge';
            _allowStage = true;
          }),
        ),
      ]),
    ]);
  }

  Widget _buildProductStrip() {
    final n = _pickedArticles.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_myArticles.isEmpty ? tr('Produits à épingler') : tr('Produits à épingler ({a} sur {b})', {'a': '$n', 'b': '${_myArticles.length}'}), style: TextStyle(color: _c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (_myArticles.isEmpty)
        Text(tr('Ajoute des articles à ta boutique pour les vendre en direct. Tu pourras aussi les épingler pendant le live.'), style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.4))
      else
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _myArticles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = _myArticles[i];
              final picked = _pickedArticles.contains(a.id);
              final img = (a.images != null && a.images!.isNotEmpty) ? a.images!.first : '';
              return GestureDetector(
                onTap: () => setState(() => picked ? _pickedArticles.remove(a.id) : _pickedArticles.add(a.id!)),
                child: SizedBox(
                  width: 76,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 76,
                          height: 76,
                          color: _c.surfaceVariant,
                          child: img.isEmpty ? Icon(Icons.image_outlined, color: _c.textSecondary) : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: _c.textSecondary)),
                        ),
                      ),
                      if (picked)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(width: 20, height: 20, decoration: BoxDecoration(color: _c.success, shape: BoxShape.circle), child: const Icon(Icons.check, size: 14, color: Colors.white)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(a.titre ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('${a.prix ?? 0} F', style: TextStyle(color: _c.textSecondary, fontSize: 10.5)),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }

  Widget _buildFreePaidSegment() {
    Widget seg(String label, bool on, VoidCallback tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: on ? _c.surface : Colors.transparent, borderRadius: BorderRadius.circular(99), boxShadow: on ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 1))] : null),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(color: on ? _c.textPrimary : _c.textSecondary, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _c.surfaceVariant, borderRadius: BorderRadius.circular(99)),
      child: Row(children: [
        seg(tr('Gratuit'), !_isPaidLive, () => setState(() => _isPaidLive = false)),
        seg(tr('Payant'), _isPaidLive, () => setState(() => _isPaidLive = true)),
      ]),
    );
  }

  /// Carte d'information : vert (live gratuit) ou orange (minutes gratuites du mois épuisées : billets et frais de diffusion).
  Widget _buildMinutesCard() {
    if (_minutes == null) return const SizedBox.shrink();
    if (!_ticketMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFE6F4EB), border: Border.all(color: const Color(0xFFBFE3CB)), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFF158246), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Live gratuit'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F5E32))),
              const SizedBox(height: 1),
              Text(tr('Les minutes gratuites du mois couvrent ce live. Tu ne paies rien, et tes spectateurs non plus.'), style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF2F4A3A))),
            ]),
          ),
        ]),
      );
    }
    final t = (_minutes!['ticket_coins'] as Map?) ?? const {};
    Widget pr(String a, String b, {bool dashed = false}) => Container(
          padding: EdgeInsets.only(top: dashed ? 6 : 3, bottom: 3),
          margin: EdgeInsets.only(top: dashed ? 3 : 0),
          decoration: dashed ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFFFD2A8)))) : null,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(a, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
            Text(b, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.black87)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF1E3), border: Border.all(color: const Color(0xFFFFD2A8)), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFFF7A1A), shape: BoxShape.circle), child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF121212), size: 16)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Les minutes gratuites du mois sont épuisées'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF8A4300))),
              const SizedBox(height: 1),
              Text(tr('Tes spectateurs prennent un billet de {m} minutes. Toi, tu paies tes frais de diffusion.', {'m': '${_num('ticket_minutes', 15)}'}), style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF5C3A1D))),
            ]),
          ),
        ]),
        const SizedBox(height: 7),
        const Divider(height: 1, color: Color(0xFFFFD2A8)),
        const SizedBox(height: 6),
        pr(tr('Discussion ou vente, en vidéo'), tr('{n} pièces', {'n': '${t['video'] ?? 50}'})),
        pr(tr('Avec invités ou duel en vidéo'), tr('{n} pièces', {'n': '${t['stage'] ?? 110}'})),
        pr(tr('Audio seul'), tr('{n} pièces', {'n': '${t['audio'] ?? 13}'})),
        pr(tr('Tes frais de diffusion (hôte)'), tr('{n} pièces · {m} min', {'n': '${_num('host_fee_coins', 50)}', 'm': '${_num('ticket_minutes', 15)}'}), dashed: true),
        pr(tr('Par invité en vidéo, sans place payante'), tr('+{n} pièces · {m} min', {'n': '${_num('stage_guest_fee_coins', 50)}', 'm': '${_num('ticket_minutes', 15)}'})),
      ]),
    );
  }

  Widget _stepper(String minus, String plus, String value, VoidCallback? onMinus, VoidCallback? onPlus) {
    Widget b(String label, String aria, VoidCallback? tap) => GestureDetector(
          onTap: tap,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _c.surface, border: Border.all(color: _c.border)),
            child: Text(label, style: TextStyle(color: tap == null ? _c.textSecondary.withOpacity(.4) : _c.textPrimary, fontSize: 15)),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      b('−', minus, onMinus),
      SizedBox(width: 40, child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: _c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
      b('+', plus, onPlus),
    ]);
  }

  Widget _row(String title, String? sub, Widget trailing, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: _c.border))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub, style: TextStyle(color: _c.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          trailing,
        ]),
      );

  Widget _sw(bool v, ValueChanged<bool>? on) => Switch(value: v, onChanged: on, activeColor: Colors.white, activeTrackColor: const Color(0xFF158246));

  /// Coût par minute d'une entrée offerte à 50 spectateurs (billet vidéo ÷ durée du billet).
  int _offerCostPerMinute() {
    final video = (((_minutes?['ticket_coins'] as Map?)?['video']) as num?)?.toInt() ?? 50;
    return (50 * video / _num('ticket_minutes', 15)).round();
  }

  /// Lignes d'options de la maquette : essai, entrée offerte, supplément (mode billet), puis qualité HD, faible latence, scène et affichage.
  Widget _buildLiveRows() {
    final isAdmin = _liveRestrictions['isAdmin'] == true;
    final canHd = _liveRestrictions['canChooseHD'] == true || isAdmin;
    final canLow = _liveRestrictions['canChooseLowLatency'] == true || isAdmin;
    final ticket = _ticketMode && !isAdmin;
    final rows = <Widget>[
      if (_game == 'market') ...[
        _row(tr('Nombre d\'étals'), tr('Un vendeur passe à la fois, chacun son tour'), _stepper('Moins', 'Plus', '$_marketStalls', _marketStalls > 1 ? () => setState(() => _marketStalls--) : null, _marketStalls < 10 ? () => setState(() => _marketStalls++) : null)),
        _row(tr('Loyer d\'un étal'), tr('Payé en pièces par le vendeur à son tour, il te revient (partage habituel des cadeaux)'), _stepper('Moins', 'Plus', '$_marketRent', _marketRent > 0 ? () => setState(() => _marketRent = (_marketRent - 50).clamp(0, 5000)) : null, _marketRent < 5000 ? () => setState(() => _marketRent = (_marketRent + 50).clamp(0, 5000)) : null)),
        _row(tr('Durée d\'un tour'), tr('Commission de vente : 10 % (déjà en place)'), _stepper('Moins', 'Plus', tr('{n} min', {'n': '$_marketMinutes'}), _marketMinutes > 5 ? () => setState(() => _marketMinutes -= 5) : null, _marketMinutes < 30 ? () => setState(() => _marketMinutes += 5) : null)),
      ],
      if (ticket) ...[
        _row(tr('Temps d\'essai gratuit'), tr('Avant le billet. Les minutes d\'essai sont à ta charge (environ {c} pièces par spectateur et par minute)', {'c': '${_num('trial_cost_per_minute', 3)}'}),
            _stepper('Moins', 'Plus', tr('{n} min', {'n': '$_ticketTrial'}), _ticketTrial > 0 ? () => setState(() => _ticketTrial--) : null, _ticketTrial < _num('trial_max_minutes', 3) ? () => setState(() => _ticketTrial++) : null)),
        _row(tr('Offrir l\'entrée à mes spectateurs'), tr('Je paie les billets à leur place (environ {n} pièces par minute pour 50 spectateurs)', {'n': '${_offerCostPerMinute()}'}),
            _sw(_offerEntry, (v) => setState(() {
                  _offerEntry = v;
                  if (v) _ticketExtra = 0;
                }))),
        if (!_offerEntry)
          _row(tr('Supplément pour moi'), tr('S\'ajoute au billet, il me revient'),
              _stepper('Moins', 'Plus', _ticketExtra == 0 ? '0' : '+$_ticketExtra', _ticketExtra > 0 ? () => setState(() => _ticketExtra = (_ticketExtra - 10).clamp(0, 200)) : null, _ticketExtra < 200 ? () => setState(() => _ticketExtra = (_ticketExtra + 10).clamp(0, 200)) : null)),
      ],
      _row(tr('Qualité HD (720p)'), canHd ? null : tr('Réservée à Gold'), _sw(_useHDQuality && canHd, canHd ? (v) => setState(() => _useHDQuality = v) : null)),
      _row(tr('Faible latence'), tr('Réactions plus rapides'), _sw(_useLowLatency && canLow, canLow ? (v) => setState(() => _useLowLatency = v) : null)),
      _row(tr('Inviter sur scène'), tr('Le prix du billet passe à {n} si tes invités sont en vidéo', {'n': '${((_minutes?['ticket_coins'] as Map?)?['stage'] ?? 110)}'}), _sw(_allowStage, (v) => setState(() => _allowStage = v))),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickDisplay,
        child: _row(tr('Affichage des compteurs'), tr('Ce que voient tes spectateurs'),
            Text('${tr(LiveDisplay.label(_liveDisplay.preset))} ›', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF158246))),
            last: true),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(color: _c.surface, border: Border.all(color: _c.border), borderRadius: BorderRadius.circular(14)),
      child: Column(children: rows),
    );
  }

  /// Choix du préréglage d'affichage (Essentiel par défaut) ; le réglage fin se fait pendant le live, dans « Menu ».
  Future<void> _pickDisplay() async {
    final p = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _c.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(tr('Affichage des compteurs'), style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
          for (final k in LiveDisplay.presets)
            ListTile(
              title: Text(tr(LiveDisplay.label(k)), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
              trailing: _liveDisplay.preset == k ? const Icon(Icons.check_rounded, color: Color(0xFF158246)) : null,
              onTap: () => Navigator.pop(ctx, k),
            ),
        ]),
      ),
    );
    if (p != null && mounted) setState(() => _liveDisplay = LiveDisplay.byName(p));
  }

  Widget _buildOptionsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showOptions = !_showOptions),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _c.border))),
          child: Row(children: [
            Text(tr('Options'), style: TextStyle(color: _c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(tr('Couverture'), style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
            Icon(_showOptions ? Icons.expand_less_rounded : Icons.chevron_right_rounded, color: _c.textSecondary),
          ]),
        ),
      ),
      if (_showOptions) ...[
        _buildCoverImagePicker(),
      ],
    ]);
  }

  Widget _buildGoButton() {
    final disabled = _isCreating || !_canCreate;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!_canCreate)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen())),
            child: Text(tr('Tu as utilisé tes lives gratuits de ce mois. Passe à Gold pour des lives illimités.'), textAlign: TextAlign.center, style: TextStyle(color: _c.accentText, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: disabled ? null : _createLive,
          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF3A2C00), disabledBackgroundColor: _c.border, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
          child: _isCreating
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3A2C00)))
              : Text(_ticketMode && _liveRestrictions['isAdmin'] != true ? tr('Passer en direct avec billet') : tr('Passer en direct'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _c.textPrimary), onPressed: () => Navigator.maybePop(context)),
        title: Text(tr('Lancer un live'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _formKey,
        child: Stack(children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 130 + MediaQuery.of(context).padding.bottom),
            children: [
              _buildPreviewCard(),
              const SizedBox(height: 14),
              _buildModeCards(),
              if (_isShoppingLive) ...[const SizedBox(height: 14), _buildProductStrip()],
              const SizedBox(height: 14),
              _buildTitleField(),
              const SizedBox(height: 14),
              _buildFreePaidSegment(),
              if (_isPaidLive) ..._buildPaidLiveOptions(),
              const SizedBox(height: 12),
              _buildMinutesCard(),
              const SizedBox(height: 12),
              _buildLiveRows(),
              const SizedBox(height: 10),
              _buildOptionsSection(),
            ],
          ),
          Positioned(left: 16, right: 16, bottom: 12 + MediaQuery.of(context).padding.bottom, child: _buildGoButton()),
        ]),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: _c.textPrimary),
      decoration: InputDecoration(
        labelText: tr('Titre du live'),
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: tr('Donnez un titre à votre live...'),
        hintStyle: TextStyle(color: _c.textSecondary),
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
        fillColor: _c.surface,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return tr('Veuillez entrer un titre');
        }
        if (value.length > 100) {
          return tr('Titre trop long (max 100 caractères)');
        }
        return null;
      },
    );
  }

  /// Format du live : discussion (comme avant) ou vente en direct (produits de la boutique épinglés, achat en 1 clic avec séquestre).
  Widget _buildFormatSection() {
    return Card(
      color: _c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.live_tv_rounded, color: Color(0xFFF9A825), size: 20),
              const SizedBox(width: 8),
              Text(tr('Format du live'), style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _buildLiveTypeOption(
                  title: 'Discussion',
                  subtitle: tr('Parle, échange, reçois des cadeaux'),
                  icon: Icons.forum_rounded,
                  isSelected: !_isShoppingLive,
                  onTap: () => setState(() => _isShoppingLive = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLiveTypeOption(
                  title: 'Vente en direct',
                  subtitle: tr('Vends les articles de ta boutique'),
                  icon: Icons.shopping_bag_rounded,
                  isSelected: _isShoppingLive,
                  onTap: () => setState(() => _isShoppingLive = true),
                ),
              ),
            ]),
            if (_isShoppingLive) ...[
              const SizedBox(height: 10),
              Text(
                tr("Pendant le live, tu épingles un article de ta boutique : les spectateurs l'achètent en un clic ou négocient le prix. Leur argent est protégé jusqu'à la réception, puis il t'est versé (10 % de commission) : ça rassure les acheteurs. Il faut avoir une boutique avec au moins un article."),
                style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTypeSection() {
    return Card(
      color: _c.surface,
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
                  tr('Type de live'),
                  style: TextStyle(
                    color: _c.textPrimary,
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
                    subtitle: tr('Tout le monde peut regarder'),
                    icon: Icons.people,
                    isSelected: !_isPaidLive,
                    onTap: () => setState(() => _isPaidLive = false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildLiveTypeOption(
                    title: 'Payant',
                    subtitle: tr('Spectateurs payent pour regarder'),
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
          color: isSelected ? Color(0xFFF9A825).withOpacity(0.2) : _c.surfaceVariant,
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
                Icon(icon, color: isSelected ? Color(0xFFF9A825) : _c.textSecondary),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: _c.textSecondary,
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
      style: TextStyle(color: _c.textPrimary),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: tr("Prix d'entrée du live privé (pièces)"),
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: '250',
        suffixText: tr('pièces'),
        helperText: kIsAppleStore ? null : tr('1 FCFA = 2,5 pièces'),
        hintStyle: TextStyle(color: _c.textSecondary),
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
        fillColor: _c.surface,
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return tr('Veuillez entrer un prix');
        }
        if (_isPaidLive) {
          final price = double.tryParse(value!);
          if (price == null) {
            return 'Prix invalide';
          }
          if (price < 25) {
            return tr('Minimum 25 pièces');
          }
          if (price > 250000) {
            return tr('Maximum 250 000 pièces');
          }
        }
        return null;
      },
    );
  }

  Widget _buildFreeTrialField() {
    return TextFormField(
      controller: _freeTrialController,
      style: TextStyle(color: _c.textPrimary),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Temps d\'essai gratuit (minutes)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        hintText: '1',
        hintStyle: TextStyle(color: _c.textSecondary),
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
        fillColor: _c.surface,
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return tr('Veuillez entrer une durée');
        }
        if (_isPaidLive) {
          final minutes = int.tryParse(value!);
          if (minutes == null) {
            return tr('Durée invalide');
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
      color: _c.surface,
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
                  tr('Comportement du son après l\'essai'),
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildAudioOption(
              value: 'mute',
              title: tr('🔇 Son coupé'),
              subtitle: tr('Le spectateur ne peut plus entendre'),
              icon: Icons.volume_off,
            ),
            _buildAudioOption(
              value: 'reduce',
              title: tr('🎵 Son réduit'),
              subtitle: tr('Le son est baissé mais audible'),
              icon: Icons.volume_down,
            ),
            _buildAudioOption(
              value: 'keep',
              title: '🔊 Son normal',
              subtitle: tr('Le son reste inchangé'),
              icon: Icons.volume_up,
            ),
            if (_audioBehavior == 'reduce') ...[
              SizedBox(height: 16),
              Text(
                'Réduction du son: $_audioReductionPercent%',
                style: TextStyle(color: _c.textSecondary),
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
                inactiveColor: _c.textSecondary,
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
                Text(title, style: TextStyle(color: _c.textPrimary)),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: _c.textSecondary, fontSize: 12),
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
      color: _c.surface,
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
                  tr('Restrictions visuelles après l\'essai'),
                  style: TextStyle(
                    color: _c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text(
                tr('Flouter la vidéo'),
                style: TextStyle(color: _c.textPrimary),
              ),
              subtitle: Text(
                tr('Rendre le flux vidéo flou'),
                style: TextStyle(color: _c.textSecondary),
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
                tr('Afficher le modal de paiement'),
                style: TextStyle(color: _c.textPrimary),
              ),
              subtitle: Text(
                tr('Montrer automatiquement la demande de paiement'),
                style: TextStyle(color: _c.textSecondary),
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
            color: _c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFF9A825)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Résumé de votre live'),
                style: TextStyle(
                  color: _c.textPrimary,
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
                        color: _c.textSecondary,
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
                      color: _c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.speed, color: Color(0xFFF9A825), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Latence: ${actualLatency}ms',
                    style: TextStyle(
                      color: _c.textSecondary,
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
                    _isPaidLive ? 'Live privé • ${_participationFeeController.text} pièces' : 'Live gratuit',
                    style: TextStyle(
                      color: _c.textSecondary,
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
                          tr('Passez à Premium pour améliorer la qualité'),
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
                      tr('Limite de lives atteinte'),
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  tr('Vous avez utilisé vos 5 lives gratuits ce mois.\nPassez à Premium pour des lives illimités.'),
                  style: TextStyle(color: _c.textSecondary),
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
                    tr('PASSER À PREMIUM'),
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
                  tr('Création en cours...'),
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
                  tr('DÉMARRER LE LIVE'),
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCreating || !canCreate
                ? _c.border
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

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _coverImageFile = File(picked.path);
      _coverImageUrl = null;
    });
    setState(() => _isUploadingCover = true);
    try {
      final shrunk = await MediaShrink.file(_coverImageFile!);
      _coverUploadId = await ChatApi.uploadImage(await shrunk.readAsBytes());
    } catch (_) {} finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Widget _buildCoverImagePicker() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _c.border),
          image: _coverImageFile != null
              ? DecorationImage(image: FileImage(_coverImageFile!), fit: BoxFit.cover)
              : null,
        ),
        child: _coverImageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: _c.textSecondary, size: 36),
                  const SizedBox(height: 8),
                  Text(tr('Ajouter une image de couverture'),
                      style: TextStyle(color: _c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(tr('Optionnel — visible dans la liste des lives'),
                      style: TextStyle(color: _c.border, fontSize: 11)),
                ],
              )
            : Stack(
                children: [
                  if (_isUploadingCover)
                    Center(child: CircularProgressIndicator(color: _c.textSecondary)),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() { _coverImageFile = null; _coverImageUrl = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  if (_coverImageUrl != null)
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(tr('Uploadée'), style: TextStyle(color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _createLive() async {
    if (_isCreating) {
      printVm('⚠️ Tentative bloquée : création déjà en cours');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      printVm('❌ Validation du formulaire échouée');
      return;
    }

    // Verrou posé tout de suite (avant tout await) : les taps multiples ne créent qu'un seul live
    setState(() => _isCreating = true);
    var created = false;
    try {
    final User? user = _auth.currentUser;
    if (user == null) {
      printVm('❌ Utilisateur non authentifié');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Vous devez être connecté pour créer un live')),
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

    try {
      // Un seul live actif par hôte : l'API termine l'ancien en démarrant un nouveau, on prévient quand même la personne
      final already = await LivesApi.list(status: 'live', hostId: (ApiIdentity.myId ?? user.uid), limit: 1);
      if (already.items.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Votre live précédent a été terminé pour démarrer celui-ci')), backgroundColor: Colors.orange, duration: Duration(seconds: 3)),
        );
      }

      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final isAdmin = _liveRestrictions['isAdmin'] == true;
      final fee = _isPaidLive ? (double.tryParse(_participationFeeController.text) ?? 0).round() : 0;
      // Le serveur plafonne la durée (30 min, 60 min pour l'équipe) et garde l'accès payant ; l'état en direct est ensuite recopié sur Firebase
      final apiLive = await LivesApi.start(
        title: _titleController.text.trim(),
        coverUploadId: _coverUploadId,
        durationMinutes: isAdmin ? 60 : 30,
        isPaid: _isPaidLive && fee > 0,
        feeCoins: fee,
        freeTrialMinutes: _ticketMode ? _ticketTrial : (_isPaidLive ? (int.tryParse(_freeTrialController.text) ?? 0) : 0),
        typeSession: _isShoppingLive ? 'shopping' : (_game.isNotEmpty ? _game : 'talk'),
        offerEntry: _offerEntry,
        audioOnly: _audioRoom,
        ticketExtraCoins: _offerEntry ? 0 : _ticketExtra,
        options: {
          'stage': _allowStage,
          'display': _liveDisplay.toJson(),
          if (_game == 'market') 'market': {'stalls': _marketStalls, 'rent_coins': _marketRent, 'minutes': _marketMinutes},
          'audioBehaviorAfterTrial': _audioBehavior,
          'audioReductionPercent': _audioReductionPercent,
          'blurVideoAfterTrial': _blurVideoAfterTrial,
          'showPaymentModalAfterTrial': _showPaymentModalAfterTrial,
        },
      );
      // Vente en direct lancée depuis la boutique : les articles choisis sont épinglés tout de suite (le premier choisi s'affiche en premier)
      if (_isShoppingLive && _pickedArticles.isNotEmpty) {
        try {
          for (final id in _pickedArticles.reversed) {
            await LiveShopApi.enableSelling(id);
            await LiveShopApi.pin('${apiLive['id']}', id);
          }
        } catch (e) {
          printVm('⚠️ Épinglage des articles impossible, à refaire depuis le live : $e');
        }
      }
      final String liveId = '${apiLive['id']}';
      // Gratuit du mois épuisé : l'hôte paie d'abord ses frais de diffusion (sinon le live s'arrête tout seul au bout de 2 minutes)
      if (apiLive['ticket_mode'] == true) {
        final fee = _num('host_fee_coins', 50);
        final paid = fee <= 0 || await CoinCheckout.pay(context, kind: 'live_host_fee', refId: liveId, coins: fee, label: context.tr('Frais de diffusion'));
        if (!paid) {
          try {
            await LivesApi.end(liveId);
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Live annulé : les frais de diffusion n\'ont pas été payés.'))));
          }
          return;
        }
      }
      final PostLive newLive = postLiveFromApi(
        apiLive,
        hostName: authProvider.loginUserData.pseudo ?? 'Utilisateur',
        hostImage: authProvider.loginUserData.imageUrl ?? '',
      );

      // État en direct (spectateurs, pause, texte épinglé, commentaires) : reste sur Firebase, avec le même identifiant que dans l'API
      await _firestore.collection('lives').doc(liveId).set({...newLive.toMap(), 'display': _liveDisplay.toJson()});

      // Calculer la qualité selon les choix et restrictions
      final actualQuality = _useHDQuality && (_liveRestrictions['canChooseHD'] == true || _liveRestrictions['isAdmin'] == true) ? 'HD' : 'SD';
      final actualLatency = _useLowLatency && (_liveRestrictions['canChooseLowLatency'] == true || _liveRestrictions['isAdmin'] == true) ? 500 : 2000;

      printVm("✅ Live créé avec succès: $liveId - Qualité: $actualQuality - Latence: ${actualLatency}ms");

      // Incrémenter le compteur de lives (sauf pour admin)
      if (_liveRestrictions['isAdmin'] != true) {
        await _liveService.incrementLiveCount();
      }

      // Les notifications aux abonnés sont envoyées par le serveur

      // Navigation vers le live (le verrou reste posé jusqu'à la fermeture de la page)
      created = true;
      await _stopPreview();
      if (!mounted) return;
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
      printVm("❌ Erreur création live: $e");
      // Quota mensuel gratuit atteint (appliqué par le serveur) : message clair, pas d'erreur technique
      if (e is ApiException && e.code == 'monthly_limit') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Tu as utilisé tes lives gratuits de ce mois. Passe à Gold pour des lives illimités.')), backgroundColor: Colors.orange, duration: const Duration(seconds: 5)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du live: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
    } finally {
      // Libéré seulement en cas d'échec ou d'abandon, jamais sur un délai
      if (!created && mounted) {
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
            type_notif: NotificationType.LIVE.name,
            post_id: newLive.liveId ?? "id",
            post_type: PostDataType.TEXT.name,
            chat_id: '',
          );
          printVm("📨 Notifications envoyées à ${userIds.length} utilisateurs");
        }
      });
    } catch (e) {
      printVm("⚠️ Erreur envoi notifications: $e");
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
//       printVm('⚠️ Tentative bloquée : création déjà en cours');
//       return;
//     }
//
//     if (!_formKey.currentState!.validate()) {
//       printVm('❌ Validation du formulaire échouée');
//       return;
//     }
//
//     final User? user = _auth.currentUser;
//     if (user == null) {
//       printVm('❌ Utilisateur non authentifié');
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
//         printVm('🔓 Verrouillage automatique libéré après 10 secondes');
//       }
//     });
//
//     try {
//       // 3. VÉRIFIER SI L'UTILISATEUR A DÉJÀ UN LIVE ACTIF
//       final activeLiveQuery = await _firestore
//           .collection('lives')
//           .where('hostId', isEqualTo: (ApiIdentity.myId ?? user.uid))
//           .where('isLive', isEqualTo: true)
//           .limit(1)
//           .get();
//
//       if (activeLiveQuery.docs.isNotEmpty) {
//         // L'utilisateur a déjà un live actif
//         printVm('❌ Utilisateur a déjà un live actif: ${activeLiveQuery.docs.first.id}');
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
//         hostId: (ApiIdentity.myId ?? user.uid),
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
//       printVm("✅ Live créé avec succès: $liveId");
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
//       printVm("❌ Erreur création live: $e");
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
//           printVm("📨 Notifications envoyées à ${userIds.length} utilisateurs");
//         }
//       });
//     } catch (e) {
//       printVm("⚠️ Erreur envoi notifications: $e");
//       // Ne pas bloquer la création du live si les notifications échouent
//     }
//   }
// }
//
//
