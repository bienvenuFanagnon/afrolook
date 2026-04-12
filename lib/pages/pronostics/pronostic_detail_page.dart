// pages/pronostics/pronostic_detail_page.dart

import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/services/postService/feed_interaction_service.dart';
import 'package:afrotok/services/pronostic_payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_data.dart';
import '../../services/utils/abonnement_utils.dart';
import '../pub/native_ad_widget.dart';
import '../pub/rewarded_interstitial_ad_widget.dart';
import '../userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';

class PronosticDetailPage extends StatefulWidget {
  final String postId;
  final Post? post;

  const PronosticDetailPage({
    Key? key,
    required this.postId,
    this.post,
  }) : super(key: key);

  @override
  State<PronosticDetailPage> createState() => _PronosticDetailPageState();
}

class _PronosticDetailPageState extends State<PronosticDetailPage> with SingleTickerProviderStateMixin {
  // Providers
  late PronosticProvider _pronosticProvider;
  late UserAuthProvider _authProvider;
  late UserProvider _userProvider;
  late PostProvider _postProvider;
  late PronosticPaymentService _paymentService;

  // Futures pour le chargement initial
  late Future<Pronostic?> _pronosticFuture;
  late Future<Post?> _postFuture;

  // Streams pour les mises à jour en temps réel
  Stream<DocumentSnapshot>? _pronosticStream;
  Stream<DocumentSnapshot>? _postStream;

  // États locaux pour les actions utilisateur
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  bool _isSharing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // États pour la participation
  int _scoreA = 0;
  int _scoreB = 0;
  bool _isParticipating = false;
  String? _participationError;

  // Gestion de l'affichage de la description
  bool _isExpanded = false;

  // SharedPreferences pour les vues
  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';

  // Pour la pub interstitielle
  final GlobalKey<InterstitialAdWidgetState> _interstitialAdKey = GlobalKey();
  bool _adShown = false;

  // Pour éviter de déclencher plusieurs fois le lancement automatique du match
  bool _matchStarted = false;

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221);
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _paymentService = PronosticPaymentService();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Initialiser les futures pour le chargement initial
    _pronosticFuture = _loadPronostic();
    _postFuture = _loadPost();

    // Initialiser les streams pour les mises à jour
    _initStreams();

    // Incrémenter les vues une fois
    _initPrefsAndViews();
  }

  Future<void> _initPrefsAndViews() async {
    _prefs = await SharedPreferences.getInstance();
    await _incrementViews();
  }

  Future<Pronostic?> _loadPronostic() async {
    try {
      final pronostic = await _pronosticProvider.getPronosticByPostId(widget.postId);
      if (pronostic != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartMatch(pronostic));
      }
      return pronostic;
    } catch (e) {
      print('Erreur chargement pronostic: $e');
      return null;
    }
  }

  Future<Post?> _loadPost() async {
    if (widget.post != null) return widget.post;
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .get();
      if (postDoc.exists) {
        return Post.fromJson(postDoc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Erreur chargement post: $e');
    }
    return null;
  }

  void _initStreams() {
    // Stream du pronostic : filtre les snapshots vides
    _pronosticStream = FirebaseFirestore.instance
        .collection('Pronostics')
        .where('postId', isEqualTo: widget.postId)
        .snapshots()
        .where((snapshot) => snapshot.docs.isNotEmpty)
        .map((snapshot) => snapshot.docs.first);

    // Stream du post
    _postStream = FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postId)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // Gestion des vues
  // ---------------------------------------------------------------------------
  Future<void> _incrementViews() async {
    if (_authProvider.loginUserData.id == null) return;

    final currentUserId = _authProvider.loginUserData.id!;
    String viewKey = '${_lastViewDatePrefix}${currentUserId}_${widget.postId}';
    String? lastViewDateStr = _prefs.getString(viewKey);

    if (lastViewDateStr != null) {
      DateTime lastViewDate = DateTime.parse(lastViewDateStr);
      if (DateTime.now().difference(lastViewDate).inDays < 2) return;
    }

    await _prefs.setString(viewKey, DateTime.now().toIso8601String());

    await FirebaseFirestore.instance
        .collection('Posts')
        .doc(widget.postId)
        .update({
      'vues': FieldValue.increment(1),
      'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      'popularity': FieldValue.increment(2),
    });
  }

  // ---------------------------------------------------------------------------
  // Vérification et déclenchement automatique du match
  // ---------------------------------------------------------------------------
  Future<void> _checkAndStartMatch(Pronostic pronostic) async {
    if (_matchStarted) return;
    if (pronostic.statut != PronosticStatut.OUVERT) return;
    if (pronostic.dateDebutMatch == null) return;

    if (DateTime.now().isAfter(pronostic.dateDebutMatch!)) {
      _matchStarted = true;
      await _startMatch(pronostic);
    }
  }

  Future<void> _startMatch(Pronostic pronostic) async {
    final docRef = FirebaseFirestore.instance.collection('Pronostics').doc(pronostic.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final currentStatut = snapshot.get('statut');
      if (currentStatut == PronosticStatut.OUVERT.name) {
        transaction.update(docRef, {
          'statut': PronosticStatut.EN_COURS.name,
          'dateDebutMatch': DateTime.now().microsecondsSinceEpoch,
        });
      }
    });

    final participantsIds = pronostic.toutesParticipations.map((p) => p.userId).toList();
    if (participantsIds.isNotEmpty) {
      final message = '⚽ Le match ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom} a commencé ! Les pronostics sont maintenant fermés.';
      await _authProvider.sendPushToSpecificUsers(
        userIds: participantsIds,
        sender: _authProvider.loginUserData,
        message: message,
        typeNotif: NotificationType.POST.name,
        postId: pronostic.postId,
        postType: 'PRONOSTIC',
        chatId: '',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🏁 Le match a commencé !'), backgroundColor: Colors.orange),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Actions sur le post
  // ---------------------------------------------------------------------------
  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;

    final userId = _authProvider.loginUserData.id!;
    final postId = widget.postId;

    setState(() => _isProcessingFavorite = true);

    try {
      if (_isFavorite) {
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
          'popularity': FieldValue.increment(-2),
        });
        await FirebaseFirestore.instance.collection('Users').doc(userId).update({
          'favoritePostsIds': FieldValue.arrayRemove([postId]),
        });
      } else {
        await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
          'popularity': FieldValue.increment(2),
        });
        await FirebaseFirestore.instance.collection('Users').doc(userId).update({
          'favoritePostsIds': FieldValue.arrayUnion([postId]),
        });
        addPointsForAction(UserAction.favorite);
      }

      setState(() => _isFavorite = !_isFavorite);
      _animationController.forward().then((_) => _animationController.reverse());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '✅ Post ajouté aux favoris' : '🗑️ Post retiré des favoris'),
          backgroundColor: _isFavorite ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur toggle favori: $e');
    } finally {
      setState(() => _isProcessingFavorite = false);
    }
  }

  Future<void> _handleLike() async {
    final userId = _authProvider.loginUserData.id!;
    await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
      'popularity': FieldValue.increment(3),
    });

    final postSnapshot = await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).get();
    final post = Post.fromJson(postSnapshot.data()!);
    FeedInteractionService.onPostLoved(post, userId);
    addPointsForAction(UserAction.like);
    addPointsForOtherUserAction(post.user_id!, UserAction.autre);

    _animationController.forward().then((_) => _animationController.reverse());
  }

  Future<void> _handleShare() async {
    setState(() => _isSharing = true);
    try {
      final postSnapshot = await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).get();
      final post = Post.fromJson(postSnapshot.data()!);

      final shareImageUrl = post.images?.isNotEmpty == true ? post.images!.first : '';

      final AppLinkService appLinkService = AppLinkService();
      await appLinkService.shareContent(
        type: AppLinkType.post,
        id: widget.postId,
        message: post.description ?? 'Pronostic',
        mediaUrl: shareImageUrl,
      );

      await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([_authProvider.loginUserData.id!]),
      });

      addPointsForAction(UserAction.partagePost);
      addPointsForOtherUserAction(post.user_id!, UserAction.autre);
    } catch (e) {
      print('Erreur partage: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Participation
  // ---------------------------------------------------------------------------
  void _incrementScoreA() => setState(() { _scoreA++; _participationError = null; });
  void _decrementScoreA() => setState(() { if (_scoreA > 0) _scoreA--; _participationError = null; });
  void _incrementScoreB() => setState(() { _scoreB++; _participationError = null; });
  void _decrementScoreB() => setState(() { if (_scoreB > 0) _scoreB--; _participationError = null; });

  Future<void> _validerParticipation(Pronostic pronostic) async {
    setState(() {
      _isParticipating = true;
      _participationError = null;
    });

    try {
      final userId = _authProvider.loginUserData.id!;

      var verification = await _pronosticProvider.verifierParticipation(
        pronosticId: pronostic.id,
        userId: userId,
        scoreA: _scoreA,
        scoreB: _scoreB,
      );

      if (!verification['peutParticiper']) {
        setState(() {
          _participationError = verification['raison'];
          _isParticipating = false;
        });
        return;
      }

      if (pronostic.typeAcces == 'PAYANT') {
        bool confirm = await _showPaymentConfirmation(pronostic, userId);
        if (!confirm) {
          setState(() => _isParticipating = false);
          return;
        }

        bool paiementReussi = await _paymentService.debiterUtilisateur(
          userId: userId,
          montant: pronostic.prixParticipation,
          raison: 'Participation au pronostic: ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}',
          postId: pronostic.postId,
          pronosticId: pronostic.id,
        );

        if (!paiementReussi) {
          setState(() {
            _participationError = 'Échec du paiement. Solde insuffisant ?';
            _isParticipating = false;
          });
          return;
        }
      }

      final participation = ParticipationPronostic(
        userId: userId,
        userPseudo: _authProvider.loginUserData.pseudo ?? 'Utilisateur',
        userImageUrl: _authProvider.loginUserData.imageUrl ?? '',
        scoreEquipeA: _scoreA,
        scoreEquipeB: _scoreB,
        montantPaye: pronostic.typeAcces == 'PAYANT' ? pronostic.prixParticipation : 0,
        dateParticipation: DateTime.now(),
      );

      var result = await _pronosticProvider.ajouterParticipation(
        pronosticId: pronostic.id,
        participation: participation,
      );

      if (result['success']) {
        String message = "🔥 Je viens de participer aux pronostics sur AfroLook ! ⚽\n"
            "📌 ${pronostic.equipeA.nom} 🆚 ${pronostic.equipeB.nom}\n"
            "🔥 Mon pronostic : $_scoreA - $_scoreB\n"
            "💰 Plus de 55 000 FCFA à gagner !\n"
            "⏳ Match en approche… participe vite avant le coup d’envoi !\n"
            "👉 Et toi, quel est ton score ? 🚀";
        _authProvider.sendPushNotificationToUsersPronostic(
          sender: _authProvider.loginUserData,
          message: message,
          typeNotif: NotificationType.POST.name,
          postId: widget.postId,
          postType: 'PRONOSTIC',
          chatId: '',
          smallImage: _authProvider.loginUserData.imageUrl,
          isChannel: false,
        );

        final isPremium = _isUserPremium();
        if (!isPremium && !_adShown) {
          _adShown = true;
          _interstitialAdKey.currentState?.showAd();
          // Ne rien faire de plus – la page restera ouverte,
          // la pub s'affichera, et le callback la fermera.
        } else {
          // Utilisateur premium ou déjà montré
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Pronostic enregistré !'), backgroundColor: Colors.green),
            );
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.pop(context);
            });
          }
        }
      } else {
        setState(() {
          _participationError = result['message'];
          _isParticipating = false;
        });
      }
    } catch (e) {
      setState(() {
        _participationError = 'Erreur: $e';
        _isParticipating = false;
      });
    }
  }

  Future<bool> _showPaymentConfirmation(Pronostic pronostic, String userId) async {
    double solde = await _paymentService.getSoldeUtilisateur(userId);
    bool soldeSuffisant = solde >= pronostic.prixParticipation;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Iconsax.money, color: _secondaryColor),
            const SizedBox(width: 10),
            const Text('Confirmation de paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vous allez payer ${pronostic.prixParticipation.toStringAsFixed(0)} FCFA pour participer.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Votre solde', '${solde.toStringAsFixed(0)} FCFA', soldeSuffisant ? Colors.green : Colors.red),
                  const Divider(color: Colors.grey, height: 16),
                  _buildInfoRow('Nouveau solde', '${(solde - pronostic.prixParticipation).toStringAsFixed(0)} FCFA', Colors.white),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black),
            child: const Text('CONFIRMER LE PAIEMENT'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  bool _isUserPremium() {
    final abonnement = _authProvider.loginUserData.abonnement;
    if (abonnement == null) return false;
    return AbonnementUtils.isPremiumActive(abonnement);
  }

  bool _aDejaParticipe(Pronostic pronostic, String userId) {
    return pronostic.toutesParticipations.any((p) => p.userId == userId);
  }

  ParticipationPronostic? _getMaParticipation(Pronostic pronostic, String userId) {
    try {
      return pronostic.toutesParticipations.firstWhere((p) => p.userId == userId);
    } catch (e) {
      return null;
    }
  }

  bool _estGagnant(Pronostic pronostic, String userId) {
    return pronostic.gagnantsIds.contains(userId);
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy à HH:mm').format(date);
  String formatNumber(int number) => number >= 1000 ? '${(number / 1000).toStringAsFixed(1)}k' : number.toString();

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _hintColor)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets UI
  // ---------------------------------------------------------------------------
  Widget _buildTeamsCard(Pronostic pronostic) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildTeamLogo(pronostic.equipeA.urlLogo, size: 70),
                const SizedBox(height: 12),
                Text(pronostic.equipeA.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                if (pronostic.scoreFinalEquipeA != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('${pronostic.scoreFinalEquipeA}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(30)),
            child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTeamLogo(pronostic.equipeB.urlLogo, size: 70),
                const SizedBox(height: 12),
                Text(pronostic.equipeB.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                if (pronostic.scoreFinalEquipeB != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('${pronostic.scoreFinalEquipeB}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String url, {double size = 50}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: _primaryColor, width: 2),
      ),
      child: url.isNotEmpty && url != 'https://via.placeholder.com/150'
          ? ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(MaterialIcons.sports_soccer, color: _hintColor)),
      )
          : Icon(MaterialIcons.sports_soccer, color: _hintColor),
    );
  }

  Widget _buildStatusCard(Pronostic pronostic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatutColor(pronostic.statut).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatutColor(pronostic.statut)),
                ),
                child: Row(
                  children: [
                    Icon(Iconsax.info_circle, size: 16, color: _getStatutColor(pronostic.statut)),
                    const SizedBox(width: 4),
                    Text(_getStatutText(pronostic.statut), style: TextStyle(color: _getStatutColor(pronostic.statut), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const Spacer(),
              if (pronostic.typeAcces == 'PAYANT')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _secondaryColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.money, size: 14, color: _secondaryColor),
                      const SizedBox(width: 4),
                      Text('${pronostic.prixParticipation.toStringAsFixed(0)} FCFA', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(icon: Iconsax.people, value: '${pronostic.nombreParticipants}', label: 'Participants', color: Colors.blue),
              _buildInfoItem(icon: Iconsax.money, value: '${pronostic.cagnotte.toStringAsFixed(0)} F', label: 'Cagnotte', color: _secondaryColor),
              _buildInfoItem(icon: Iconsax.chart, value: '${pronostic.nombrePronosticsUniques}', label: 'Scores', color: Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          if (pronostic.dateDebutMatch != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.calendar, size: 14, color: _hintColor),
                const SizedBox(width: 4),
                Text('Match le ${_formatDate(pronostic.dateDebutMatch!)}', style: TextStyle(color: _hintColor, fontSize: 12)),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.clock, size: 14, color: _hintColor),
              const SizedBox(width: 4),
              Text('Publié le ${_formatDate(pronostic.dateCreation)}', style: TextStyle(color: _hintColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String value, required String label, required Color color}) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: _hintColor, fontSize: 10)),
      ],
    );
  }

  Color _getStatutColor(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT: return Colors.green;
      case PronosticStatut.EN_COURS: return Colors.orange;
      case PronosticStatut.TERMINE: return Colors.blue;
      case PronosticStatut.GAINS_DISTRIBUES: return Colors.purple;
    }
  }

  String _getStatutText(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT: return '🔓 Pronostic ouvert';
      case PronosticStatut.EN_COURS: return '⚽ Match en cours';
      case PronosticStatut.TERMINE: return '✅ Match terminé';
      case PronosticStatut.GAINS_DISTRIBUES: return '💰 Gains distribués';
    }
  }

  Widget _buildStatsRow(Post post) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(icon: Icons.remove_red_eye, count: post.vues ?? 0, label: 'Vues'),
          GestureDetector(onTap: _handleLike, child: _buildStatItem(icon: Icons.favorite, count: post.loves ?? 0, label: 'Likes', isLiked: post.users_love_id?.contains(_authProvider.loginUserData.id) ?? false)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostComments(post: post))),
            child: _buildStatItem(icon: Icons.comment, count: post.comments ?? 0, label: 'Comments'),
          ),
          GestureDetector(onTap: _toggleFavorite, child: _buildStatItem(icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border, count: post.favoritesCount ?? 0, label: 'Favoris', isLiked: _isFavorite)),
          _isSharing
              ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
              : GestureDetector(onTap: _handleShare, child: _buildStatItem(icon: Icons.share, count: post.partage ?? 0, label: 'Partages')),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required int count, required String label, bool isLiked = false}) {
    Color iconColor;
    if (icon == Icons.bookmark || icon == Icons.bookmark_border) iconColor = isLiked ? _secondaryColor : Colors.yellow;
    else if (icon == Icons.favorite) iconColor = isLiked ? Colors.red : Colors.yellow;
    else iconColor = Colors.yellow;

    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 5),
        Text(formatNumber(count), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  Widget _buildMyParticipationCard(ParticipationPronostic participation, bool estGagnant, Pronostic pronostic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estGagnant ? _secondaryColor : Colors.blue, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(estGagnant ? Iconsax.cup : Iconsax.tick_circle, color: estGagnant ? _secondaryColor : Colors.blue),
              const SizedBox(width: 8),
              Text(estGagnant ? '🎉 FÉLICITATIONS ! VOUS AVEZ GAGNÉ !' : 'VOTRE PRONOSTIC', style: TextStyle(color: estGagnant ? _secondaryColor : Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(30), border: Border.all(color: estGagnant ? _secondaryColor : Colors.blue)),
              child: Text('${participation.scoreEquipeA} - ${participation.scoreEquipeB}', style: TextStyle(color: estGagnant ? _secondaryColor : Colors.blue, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
          ),
          if (pronostic.scoreFinalEquipeA != null && pronostic.scoreFinalEquipeB != null && !estGagnant)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Score final: ${pronostic.scoreFinalEquipeA} - ${pronostic.scoreFinalEquipeB}', style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildGainCard(double gain) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: _secondaryColor)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _secondaryColor, shape: BoxShape.circle), child: const Icon(Iconsax.money, color: Colors.black)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VOS GAINS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${gain.toStringAsFixed(0)} FCFA', style: TextStyle(color: _secondaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Ont été crédités sur votre solde', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(Post post) {
    if (post.description == null || post.description!.isEmpty) return const SizedBox();
    final text = post.description!;
    final isLong = text.split(' ').length > 50;
    final displayed = _isExpanded ? text : (text.split(' ').take(50).join(' ') + (isLong ? '...' : ''));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayed, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_isExpanded ? 'Voir moins' : 'Voir plus', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipationForm(Pronostic pronostic) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('Faites votre pronostic', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTeamLogo(pronostic.equipeA.urlLogo, size: 50),
                    const SizedBox(height: 8),
                    Text(pronostic.equipeA.nom, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _participationError != null ? Colors.red : Colors.grey[800]!)),
                      child: Row(
                        children: [
                          IconButton(onPressed: _decrementScoreA, icon: Icon(Icons.remove, color: _secondaryColor)),
                          Expanded(child: Text('$_scoreA', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          IconButton(onPressed: _incrementScoreA, icon: Icon(Icons.add, color: _secondaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.white, fontSize: 24))),
              Expanded(
                child: Column(
                  children: [
                    _buildTeamLogo(pronostic.equipeB.urlLogo, size: 50),
                    const SizedBox(height: 8),
                    Text(pronostic.equipeB.nom, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _participationError != null ? Colors.red : Colors.grey[800]!)),
                      child: Row(
                        children: [
                          IconButton(onPressed: _decrementScoreB, icon: Icon(Icons.remove, color: _secondaryColor)),
                          Expanded(child: Text('$_scoreB', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          IconButton(onPressed: _incrementScoreB, icon: Icon(Icons.add, color: _secondaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_participationError != null) ...[
            const SizedBox(height: 8),
            Text(_participationError!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FutureBuilder<int>(
            future: _getNombreParticipantsPourScore(pronostic, _scoreA, _scoreB),
            builder: (context, snapshot) {
              int participants = snapshot.data ?? 0;
              bool isQuotaOk = participants < pronostic.quotaMaxParScore;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Participants pour ce score:', style: TextStyle(color: _hintColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isQuotaOk ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('$participants/${pronostic.quotaMaxParScore}', style: TextStyle(color: isQuotaOk ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isParticipating ? null : () => _validerParticipation(pronostic),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: _isParticipating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(pronostic.typeAcces == 'PAYANT' ? 'PAYER ${pronostic.prixParticipation.toStringAsFixed(0)} FCFA ET VALIDER' : 'VALIDER MON PRONOSTIC',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          if (pronostic.typeAcces == 'PAYANT') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Iconsax.info_circle, color: _secondaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Le montant sera débité de votre solde principal', style: TextStyle(color: _hintColor, fontSize: 12))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<int> _getNombreParticipantsPourScore(Pronostic pronostic, int scoreA, int scoreB) async {
    String key = '$scoreA-$scoreB';
    return pronostic.participationsParScore[key]?.length ?? 0;
  }

  Widget _buildClosedMessage(Pronostic pronostic) {
    String message;
    if (pronostic.statut == PronosticStatut.EN_COURS) message = 'Le match a commencé, les pronostics sont fermés.';
    else if (pronostic.statut == PronosticStatut.TERMINE) message = 'Le match est terminé. Consultez les résultats.';
    else if (pronostic.statut == PronosticStatut.GAINS_DISTRIBUES) message = 'Les gains ont été distribués.';
    else message = 'Ce pronostic n\'est plus disponible.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Iconsax.lock, size: 50, color: _hintColor),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: _hintColor, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Pronostic pronostic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition des scores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ...pronostic.participationsParScore.entries.map((entry) {
            String score = entry.key;
            int count = entry.value.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 60, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(score, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  const SizedBox(width: 12),
                  Expanded(child: LinearProgressIndicator(value: count / pronostic.quotaMaxParScore, backgroundColor: Colors.grey[800], valueColor: AlwaysStoppedAnimation<Color>(count >= pronostic.quotaMaxParScore ? Colors.red : _primaryColor))),
                  const SizedBox(width: 8),
                  Text('$count/${pronostic.quotaMaxParScore}', style: TextStyle(color: _hintColor, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          if (pronostic.participationsParScore.isEmpty) Center(child: Text('Aucun pronostic pour le moment', style: TextStyle(color: _hintColor))),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(Pronostic pronostic) {
    if (pronostic.toutesParticipations.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Participants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${pronostic.toutesParticipations.length} personne(s)', style: TextStyle(color: _hintColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pronostic.toutesParticipations.length,
              itemBuilder: (context, index) {
                final p = pronostic.toutesParticipations[index];
                final estGagnant = pronostic.gagnantsIds.contains(p.userId);
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: estGagnant ? _secondaryColor : Colors.transparent, width: 2),
                                image: p.userImageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(p.userImageUrl), fit: BoxFit.cover) : null),
                            child: p.userImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                          ),
                          if (estGagnant) Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFFFFD600), shape: BoxShape.circle), child: const Icon(Iconsax.cup, size: 12, color: Colors.black))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${p.scoreEquipeA}-${p.scoreEquipeB}', style: TextStyle(color: estGagnant ? _secondaryColor : _hintColor, fontSize: 10, fontWeight: estGagnant ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build principal
  // ---------------------------------------------------------------------------
  Widget _buildAdBanner({required String key}) {
    // return SizedBox.shrink();
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: MrecAdWidget(
        key: ValueKey(key),
        // templateType: TemplateType.small, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
        },
      ),
      //
      //   // child: BannerAdWidget(
      //   //   onAdLoaded: () {
      //   //     print('✅ Bannière Afrolook chargée: $key');
      //   //   },
      //   // ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: _secondaryColor), onPressed: () => Navigator.pop(context)),
        title: const Text('Détail du pronostic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Text('Afrolook', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)))],
      ),
      body: Stack(
        children: [
          FutureBuilder<Pronostic?>(
            future: _pronosticFuture,
            builder: (context, pronosticSnapshot) {
              if (pronosticSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingWidget());
              }
              if (pronosticSnapshot.hasError || pronosticSnapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.warning_2, size: 60, color: _primaryColor),
                      const SizedBox(height: 16),
                      Text('Pronostic non trouvé', style: TextStyle(color: _textColor)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                );
              }

              final pronostic = pronosticSnapshot.data!;

              // Stream pour les mises à jour en temps réel du pronostic
              return StreamBuilder<DocumentSnapshot>(
                stream: _pronosticStream,
                builder: (context, pronosticUpdateSnapshot) {
                  final currentPronostic = pronosticUpdateSnapshot.hasData && pronosticUpdateSnapshot.data != null
                      ? Pronostic.fromJson(pronosticUpdateSnapshot.data!.data() as Map<String, dynamic>)
                      : pronostic;

                  WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartMatch(currentPronostic));

                  return FutureBuilder<Post?>(
                    future: _postFuture,
                    builder: (context, postSnapshot) {
                      if (postSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: LoadingWidget());
                      }
                      if (postSnapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.warning_2, size: 60, color: _primaryColor),
                              const SizedBox(height: 16),
                              Text('Erreur chargement post', style: TextStyle(color: _textColor)),
                            ],
                          ),
                        );
                      }

                      Post? initialPost = postSnapshot.data;
                      if (initialPost == null && widget.post != null) initialPost = widget.post;

                      return StreamBuilder<DocumentSnapshot>(
                        stream: _postStream,
                        builder: (context, postUpdateSnapshot) {
                          Post? currentPost = initialPost;
                          if (postUpdateSnapshot.hasData && postUpdateSnapshot.data != null) {
                            currentPost = Post.fromJson(postUpdateSnapshot.data!.data() as Map<String, dynamic>);
                            if (currentPost != null && mounted && _isFavorite != (currentPost.users_favorite_id?.contains(_authProvider.loginUserData.id) ?? false)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() => _isFavorite = currentPost!.users_favorite_id?.contains(_authProvider.loginUserData.id) ?? false);
                              });
                            }
                          }

                          final userId = _authProvider.loginUserData.id!;

                          return RefreshIndicator(
                            onRefresh: () async {},
                            color: _secondaryColor,
                            backgroundColor: _cardColor,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildAdBanner(key: 'ad_native_pronos'),
                                  const SizedBox(height: 8),

                                  _buildTeamsCard(currentPronostic),
                                  const SizedBox(height: 8),
                                  _buildStatusCard(currentPronostic),
                                  const SizedBox(height: 8),
                                  if (currentPost != null) _buildDescription(currentPost),
                                  if (currentPost != null) _buildStatsRow(currentPost),
                                  const Divider(color: Colors.grey, height: 32),

                                  if (_aDejaParticipe(currentPronostic, userId))
                                    _buildMyParticipationCard(_getMaParticipation(currentPronostic, userId)!, _estGagnant(currentPronostic, userId), currentPronostic),

                                  if (_aDejaParticipe(currentPronostic, userId) && _estGagnant(currentPronostic, userId) && currentPronostic.gainParGagnant != null)
                                    _buildGainCard(currentPronostic.gainParGagnant!),

                                  const SizedBox(height: 8),

                                  if (currentPronostic.estOuvert && !_aDejaParticipe(currentPronostic, userId))
                                    _buildParticipationForm(currentPronostic)
                                  else if (!currentPronostic.estOuvert && !_aDejaParticipe(currentPronostic, userId))
                                    _buildClosedMessage(currentPronostic),

                                  const SizedBox(height: 8),
                                  _buildStatsCard(currentPronostic),
                                  const SizedBox(height: 8),
                                  _buildParticipantsList(currentPronostic),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          InterstitialAdWidget(
            key: _interstitialAdKey,
            onAdDismissed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Merci d\'avoir regardé la publicité !'), backgroundColor: Colors.green),
                );
                // Fermer la page après un court délai pour laisser voir le snackbar
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) Navigator.pop(context);
                });
              }
            },
          ),        ],
      ),
    );
  }
}

// // pages/pronostics/pronostic_detail_page.dart
//
// import 'package:afrotok/pages/postComments.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:afrotok/providers/pronostic_provider.dart';
// import 'package:afrotok/providers/userProvider.dart';
// import 'package:afrotok/services/linkService.dart';
// import 'package:afrotok/services/postService/feed_interaction_service.dart';
// import 'package:afrotok/services/pronostic_payment_service.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../models/model_data.dart';
// import '../userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';
//
// class PronosticDetailPage extends StatefulWidget {
//   final String postId;
//   final Post? post;
//
//   const PronosticDetailPage({
//     Key? key,
//     required this.postId,
//     this.post,
//   }) : super(key: key);
//
//   @override
//   State<PronosticDetailPage> createState() => _PronosticDetailPageState();
// }
//
// class _PronosticDetailPageState extends State<PronosticDetailPage> with SingleTickerProviderStateMixin {
//   late PronosticProvider _pronosticProvider;
//   late UserAuthProvider _authProvider;
//   late UserProvider _userProvider;
//   late PostProvider _postProvider;
//   late PronosticPaymentService _paymentService;
//
//   // Données
//   Pronostic? _pronostic;
//   Post? _post;
//   bool _isLoading = true;
//   String? _errorMessage;
//
//   // États pour la description
//   bool _isExpanded = false;
//
//   // États pour la participation
//   int _scoreA = 0;
//   int _scoreB = 0;
//   bool _isParticipating = false;
//   String? _participationError;
//
//   // Stats du post
//   bool _isFavorite = false;
//   bool _isProcessingFavorite = false;
//   bool _isSharing = false;
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//
//   // SharedPreferences pour les vues
//   late SharedPreferences _prefs;
//   final String _lastViewDatePrefix = 'last_view_date_';
//
//   // Couleurs
//   final Color _primaryColor = const Color(0xFFE21221); // Rouge
//   final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
//   final Color _backgroundColor = const Color(0xFF121212); // Noir
//   final Color _cardColor = const Color(0xFF1E1E1E);
//   final Color _textColor = Colors.white;
//   final Color _hintColor = Colors.grey[400]!;
//
//   @override
//   void initState() {
//     super.initState();
//     _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
//     _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _userProvider = Provider.of<UserProvider>(context, listen: false);
//     _postProvider = Provider.of<PostProvider>(context, listen: false);
//     _paymentService = PronosticPaymentService();
//
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 300),
//     );
//     _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );
//
//     _initData();
//   }
//
//   Future<void> _initData() async {
//     _prefs = await SharedPreferences.getInstance();
//     await _loadData();
//     await _checkIfFavorite();
//     await _incrementViews();
//   }
//
//   Future<void> _loadData() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       // Charger le pronostic
//       final pronostic = await _pronosticProvider.getPronosticByPostId(widget.postId);
//
//       if (pronostic == null) {
//         setState(() {
//           _errorMessage = 'Pronostic non trouvé';
//           _isLoading = false;
//         });
//         return;
//       }
//
//       // Charger le post
//       Post? post;
//       if (widget.post != null) {
//         post = widget.post;
//       } else {
//         final postDoc = await FirebaseFirestore.instance
//             .collection('Posts')
//             .doc(widget.postId)
//             .get();
//
//         if (postDoc.exists) {
//           post = Post.fromJson(postDoc.data() as Map<String, dynamic>);
//         }
//       }
//
//       setState(() {
//         _pronostic = pronostic;
//         _post = post;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Erreur: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _refreshData() async {
//     await _loadData();
//     await _checkIfFavorite();
//   }
//
//   Future<void> _checkIfFavorite() async {
//     if (_post == null || _authProvider.loginUserData.id == null) return;
//
//     try {
//       final postDoc = await FirebaseFirestore.instance
//           .collection('Posts')
//           .doc(widget.postId)
//           .get();
//
//       if (postDoc.exists) {
//         final data = postDoc.data() as Map<String, dynamic>;
//         final favorites = List<String>.from(data['users_favorite_id'] ?? []);
//         setState(() {
//           _isFavorite = favorites.contains(_authProvider.loginUserData.id);
//           if (_post != null) {
//             _post!.favoritesCount = data['favorites_count'] ?? 0;
//             _post!.users_favorite_id = favorites;
//           }
//         });
//       }
//     } catch (e) {
//       print('Erreur vérification favoris: $e');
//     }
//   }
//
//   Future<void> _incrementViews() async {
//     if (_authProvider.loginUserData.id == null || _post == null) return;
//
//     final currentUserId = _authProvider.loginUserData.id!;
//
//     _post!.users_vue_id ??= [];
//
//     String viewKey = '${_lastViewDatePrefix}${currentUserId}_${widget.postId}';
//     String? lastViewDateStr = _prefs.getString(viewKey);
//
//     if (lastViewDateStr != null) {
//       DateTime lastViewDate = DateTime.parse(lastViewDateStr);
//       DateTime now = DateTime.now();
//       int difference = now.difference(lastViewDate).inDays;
//
//       if (difference < 2) {
//         if (!_post!.users_vue_id!.contains(currentUserId)) {
//           setState(() {
//             _post!.users_vue_id!.add(currentUserId);
//           });
//         }
//         return;
//       }
//     }
//
//     await _prefs.setString(viewKey, DateTime.now().toIso8601String());
//
//     setState(() {
//       _post!.vues = (_post!.vues ?? 0) + 1;
//       if (!_post!.users_vue_id!.contains(currentUserId)) {
//         _post!.users_vue_id!.add(currentUserId);
//       }
//     });
//
//     await FirebaseFirestore.instance
//         .collection('Posts')
//         .doc(widget.postId)
//         .update({
//       'vues': FieldValue.increment(1),
//       'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       'popularity': FieldValue.increment(2),
//     });
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   // ========== FORMATAGE ==========
//   String _formatDate(DateTime date) {
//     return DateFormat('dd/MM/yyyy à HH:mm').format(date);
//   }
//
//   String formaterDateTime(DateTime dateTime) {
//     final now = DateTime.now();
//     final difference = now.difference(dateTime);
//
//     if (difference.inDays < 1) {
//       if (difference.inHours < 1) {
//         if (difference.inMinutes < 1) {
//           return "il y a quelques secondes";
//         } else {
//           return "il y a ${difference.inMinutes} min";
//         }
//       } else {
//         return "il y a ${difference.inHours} h";
//       }
//     } else if (difference.inDays < 7) {
//       return "il y a ${difference.inDays} j";
//     } else {
//       return DateFormat('dd/MM/yy').format(dateTime);
//     }
//   }
//
//   String formatNumber(int number) {
//     if (number >= 1000) {
//       double nombre = number / 1000;
//       return nombre.toStringAsFixed(1) + 'k';
//     } else {
//       return number.toString();
//     }
//   }
//
//   bool isIn(List<String>? users_id, String userIdToCheck) {
//     if (users_id == null) return false;
//     return users_id.any((item) => item == userIdToCheck);
//   }
//
//   // ========== STATUTS PRONOSTIC ==========
//   Color _getStatutColor(PronosticStatut statut) {
//     switch (statut) {
//       case PronosticStatut.OUVERT:
//         return Colors.green;
//       case PronosticStatut.EN_COURS:
//         return Colors.orange;
//       case PronosticStatut.TERMINE:
//         return Colors.blue;
//       case PronosticStatut.GAINS_DISTRIBUES:
//         return Colors.purple;
//     }
//   }
//
//   String _getStatutText(PronosticStatut statut) {
//     switch (statut) {
//       case PronosticStatut.OUVERT:
//         return '🔓 Pronostic ouvert';
//       case PronosticStatut.EN_COURS:
//         return '⚽ Match en cours';
//       case PronosticStatut.TERMINE:
//         return '✅ Match terminé';
//       case PronosticStatut.GAINS_DISTRIBUES:
//         return '💰 Gains distribués';
//     }
//   }
//
//   bool _aDejaParticipe(Pronostic pronostic, String userId) {
//     return pronostic.toutesParticipations.any((p) => p.userId == userId);
//   }
//
//   ParticipationPronostic? _getMaParticipation(Pronostic pronostic, String userId) {
//     try {
//       return pronostic.toutesParticipations.firstWhere((p) => p.userId == userId);
//     } catch (e) {
//       return null;
//     }
//   }
//
//   bool _estGagnant(Pronostic pronostic, String userId) {
//     return pronostic.gagnantsIds.contains(userId);
//   }
//
//   // ========== ACTIONS SUR LE POST ==========
//   Future<void> _toggleFavorite() async {
//     if (_isProcessingFavorite || _post == null) return;
//
//     final userId = _authProvider.loginUserData.id!;
//     final postId = widget.postId;
//
//     setState(() {
//       _isProcessingFavorite = true;
//     });
//
//     try {
//       if (_isFavorite) {
//         await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
//           'users_favorite_id': FieldValue.arrayRemove([userId]),
//           'favorites_count': FieldValue.increment(-1),
//           'popularity': FieldValue.increment(-2),
//         });
//
//         await FirebaseFirestore.instance.collection('Users').doc(userId).update({
//           'favoritePostsIds': FieldValue.arrayRemove([postId]),
//         });
//
//         setState(() {
//           _isFavorite = false;
//           if (_post != null) {
//             _post!.favoritesCount = (_post!.favoritesCount ?? 0) - 1;
//             _post!.users_favorite_id?.remove(userId);
//           }
//         });
//       } else {
//         await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
//           'users_favorite_id': FieldValue.arrayUnion([userId]),
//           'favorites_count': FieldValue.increment(1),
//           'popularity': FieldValue.increment(2),
//         });
//
//         await FirebaseFirestore.instance.collection('Users').doc(userId).update({
//           'favoritePostsIds': FieldValue.arrayUnion([postId]),
//         });
//
//         setState(() {
//           _isFavorite = true;
//           if (_post != null) {
//             _post!.favoritesCount = (_post!.favoritesCount ?? 0) + 1;
//             _post!.users_favorite_id ??= [];
//             _post!.users_favorite_id!.add(userId);
//           }
//         });
//
//         addPointsForAction(UserAction.favorite);
//       }
//
//       _animationController.forward().then((_) => _animationController.reverse());
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             _isFavorite ? '✅ Post ajouté aux favoris' : '🗑️ Post retiré des favoris',
//             style: const TextStyle(color: Colors.white),
//           ),
//           backgroundColor: _isFavorite ? Colors.green : Colors.grey,
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     } catch (e) {
//       print('Erreur toggle favori: $e');
//     } finally {
//       setState(() {
//         _isProcessingFavorite = false;
//       });
//     }
//   }
//
//   Future<void> _handleLike() async {
//     if (_post == null) return;
//
//     try {
//       if (!isIn(_post!.users_love_id, _authProvider.loginUserData.id!)) {
//         setState(() {
//           _post!.loves = (_post!.loves ?? 0) + 1;
//           _post!.users_love_id ??= [];
//           _post!.users_love_id!.add(_authProvider.loginUserData.id!);
//         });
//
//         await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
//           'loves': FieldValue.increment(1),
//           'users_love_id': FieldValue.arrayUnion([_authProvider.loginUserData.id]),
//           'popularity': FieldValue.increment(3),
//         });
//
//         FeedInteractionService.onPostLoved(_post!, _authProvider.loginUserData.id!);
//
//         addPointsForAction(UserAction.like);
//         addPointsForOtherUserAction(_post!.user_id!, UserAction.autre);
//
//         _animationController.forward().then((_) => _animationController.reverse());
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('+ de points ajoutés à votre compte'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e) {
//       print("Erreur like: $e");
//     }
//   }
//
//   Future<void> _handleShare() async {
//     if (_post == null) return;
//
//     setState(() {
//       _isSharing = true;
//     });
//
//     try {
//       final AppLinkService _appLinkService = AppLinkService();
//       String shareImageUrl = (_post!.images?.isNotEmpty ?? false)
//           ? _post!.images!.first
//           : "";
//
//       await _appLinkService.shareContent(
//         type: AppLinkType.post,
//         id: widget.postId,
//         message: _post!.description ?? "Pronostic",
//         mediaUrl: shareImageUrl,
//       );
//
//       setState(() {
//         _post!.partage = (_post!.partage ?? 0) + 1;
//         _post!.users_partage_id ??= [];
//         _post!.users_partage_id!.add(_authProvider.loginUserData.id!);
//       });
//
//       await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
//         'partage': FieldValue.increment(1),
//         'users_partage_id': FieldValue.arrayUnion([_authProvider.loginUserData.id]),
//       });
//
//       if (!isIn(_post!.users_partage_id, _authProvider.loginUserData.id!)) {
//         addPointsForAction(UserAction.partagePost);
//         addPointsForOtherUserAction(_post!.user_id!, UserAction.autre);
//       }
//     } catch (e) {
//       print("Erreur partage: $e");
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isSharing = false;
//         });
//       }
//     }
//   }
//
//   // ========== PARTICIPATION ==========
//   Future<int> _getNombreParticipantsPourScore(Pronostic pronostic, int scoreA, int scoreB) async {
//     String key = '$scoreA-$scoreB';
//     return pronostic.participationsParScore[key]?.length ?? 0;
//   }
//
//   void _incrementScoreA() {
//     setState(() {
//       _scoreA++;
//       _participationError = null;
//     });
//   }
//
//   void _decrementScoreA() {
//     setState(() {
//       if (_scoreA > 0) _scoreA--;
//       _participationError = null;
//     });
//   }
//
//   void _incrementScoreB() {
//     setState(() {
//       _scoreB++;
//       _participationError = null;
//     });
//   }
//
//   void _decrementScoreB() {
//     setState(() {
//       if (_scoreB > 0) _scoreB--;
//       _participationError = null;
//     });
//   }
//
//   Future<void> _validerParticipation(Pronostic pronostic) async {
//     setState(() {
//       _isParticipating = true;
//       _participationError = null;
//     });
//
//     try {
//       final userId = _authProvider.loginUserData.id!;
//
//       var verification = await _pronosticProvider.verifierParticipation(
//         pronosticId: pronostic.id,
//         userId: userId,
//         scoreA: _scoreA,
//         scoreB: _scoreB,
//       );
//
//       if (!verification['peutParticiper']) {
//         setState(() {
//           _participationError = verification['raison'];
//           _isParticipating = false;
//         });
//         return;
//       }
//
//       if (pronostic.typeAcces == 'PAYANT') {
//         bool? confirm = await showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: _cardColor,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             title: Row(
//               children: [
//                 Icon(Iconsax.money, color: _secondaryColor),
//                 const SizedBox(width: 10),
//                 const Text(
//                   'Confirmation de paiement',
//                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Vous allez payer ${pronostic.prixParticipation.toStringAsFixed(0)} FCFA pour participer à ce pronostic.',
//                   style: const TextStyle(color: Colors.grey),
//                 ),
//                 const SizedBox(height: 16),
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: _backgroundColor,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: FutureBuilder<double>(
//                     future: _paymentService.getSoldeUtilisateur(userId),
//                     builder: (context, snapshot) {
//                       double solde = snapshot.data ?? 0;
//                       bool soldeSuffisant = solde >= pronostic.prixParticipation;
//
//                       return Column(
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text('Votre solde:', style: TextStyle(color: Colors.white)),
//                               Text(
//                                 '${solde.toStringAsFixed(0)} FCFA',
//                                 style: TextStyle(
//                                   color: soldeSuffisant ? Colors.green : Colors.red,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const Divider(color: Colors.grey),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text('Nouveau solde:', style: TextStyle(color: Colors.white)),
//                               Text(
//                                 '${(solde - pronostic.prixParticipation).toStringAsFixed(0)} FCFA',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: Text('ANNULER', style: TextStyle(color: _hintColor)),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _secondaryColor,
//                   foregroundColor: Colors.black,
//                 ),
//                 child: const Text('CONFIRMER LE PAIEMENT'),
//               ),
//             ],
//           ),
//         );
//
//         if (confirm != true) {
//           setState(() => _isParticipating = false);
//           return;
//         }
//
//         bool paiementReussi = await _paymentService.debiterUtilisateur(
//           userId: userId,
//           montant: pronostic.prixParticipation,
//           raison: 'Participation au pronostic: ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}',
//           postId: pronostic.postId,
//           pronosticId: pronostic.id,
//         );
//
//         if (!paiementReussi) {
//           setState(() {
//             _participationError = 'Échec du paiement. Solde insuffisant ?';
//             _isParticipating = false;
//           });
//           return;
//         }
//       }
//       String message = "🔥 Je viens de participer aux pronostics sur AfroLook ! ⚽\n"
//           "📌 ${pronostic.equipeA.nom} 🆚 ${pronostic.equipeB.nom}\n"
//           "🔥 Mon pronostic : ${_scoreA} - ${_scoreB}\n"
//           "💰 Plus de 55 000 FCFA à gagner !\n"
//           "⏳ Match en approche… participe vite avant le coup d’envoi !\n"
//           "👉 Et toi, quel est ton score ? 🚀";
//       var participation = ParticipationPronostic(
//         userId: userId,
//         userPseudo: _authProvider.loginUserData.pseudo ?? 'Utilisateur',
//         userImageUrl: _authProvider.loginUserData.imageUrl ?? '',
//         scoreEquipeA: _scoreA,
//         scoreEquipeB: _scoreB,
//         montantPaye: pronostic.typeAcces == 'PAYANT' ? pronostic.prixParticipation : 0,
//         dateParticipation: DateTime.now(),
//       );
//
//       var result = await _pronosticProvider.ajouterParticipation(
//         pronosticId: pronostic.id,
//         participation: participation,
//       );
//
//       if (result['success']) {
//
//          _authProvider.sendPushNotificationToUsersPronostic(
//           sender: _authProvider.loginUserData,
//           message: message,
//           typeNotif: NotificationType.POST.name,
//           postId: widget.postId,
//           postType: 'PRONOSTIC',
//           chatId: '',
//           smallImage: _authProvider.loginUserData.imageUrl,
//           isChannel: false,
//         );
//
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('✅ ${result['message']}'),
//               backgroundColor: Colors.green,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         }
//         await _refreshData(); // Recharger les données
//         setState(() {
//           _isParticipating = false;
//           _scoreA = 0;
//           _scoreB = 0;
//         });
//       } else {
//         setState(() {
//           _participationError = result['message'];
//           _isParticipating = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _participationError = 'Erreur: $e';
//         _isParticipating = false;
//       });
//     }
//   }
//
//   // ========== WIDGETS ==========
//   Widget _buildTeamsCard(Pronostic pronostic) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Column(
//                   children: [
//                     _buildTeamLogo(pronostic.equipeA.urlLogo, size: 70),
//                     const SizedBox(height: 12),
//                     Text(
//                       pronostic.equipeA.nom,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     if (pronostic.scoreFinalEquipeA != null)
//                       Container(
//                         margin: const EdgeInsets.only(top: 8),
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         decoration: BoxDecoration(
//                           color: _primaryColor,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           '${pronostic.scoreFinalEquipeA}',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//
//               Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 10),
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: _primaryColor,
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 child: const Text(
//                   'VS',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 18,
//                   ),
//                 ),
//               ),
//
//               Expanded(
//                 child: Column(
//                   children: [
//                     _buildTeamLogo(pronostic.equipeB.urlLogo, size: 70),
//                     const SizedBox(height: 12),
//                     Text(
//                       pronostic.equipeB.nom,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     if (pronostic.scoreFinalEquipeB != null)
//                       Container(
//                         margin: const EdgeInsets.only(top: 8),
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         decoration: BoxDecoration(
//                           color: _primaryColor,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           '${pronostic.scoreFinalEquipeB}',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTeamLogo(String url, {double size = 50}) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(size / 2),
//         border: Border.all(color: _primaryColor, width: 2),
//       ),
//       child: url.isNotEmpty && url != 'https://via.placeholder.com/150'
//           ? ClipRRect(
//         borderRadius: BorderRadius.circular(size / 2),
//         child: Image.network(
//           url,
//           fit: BoxFit.cover,
//           errorBuilder: (context, error, stackTrace) {
//             return Icon(MaterialIcons.sports_soccer, color: _hintColor, size: size * 0.5);
//           },
//         ),
//       )
//           : Icon(MaterialIcons.sports_soccer, color: _hintColor, size: size * 0.5),
//     );
//   }
//
//   Widget _buildStatusCard(Pronostic pronostic) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: _getStatutColor(pronostic.statut).withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: _getStatutColor(pronostic.statut)),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Iconsax.info_circle,
//                       size: 16,
//                       color: _getStatutColor(pronostic.statut),
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       _getStatutText(pronostic.statut),
//                       style: TextStyle(
//                         color: _getStatutColor(pronostic.statut),
//                         fontWeight: FontWeight.bold,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const Spacer(),
//               if (pronostic.typeAcces == 'PAYANT')
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: _secondaryColor.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: _secondaryColor),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Iconsax.money, size: 14, color: _secondaryColor),
//                       const SizedBox(width: 4),
//                       Text(
//                         '${pronostic.prixParticipation.toStringAsFixed(0)} FCFA',
//                         style: TextStyle(
//                           color: _secondaryColor,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//
//           const SizedBox(height: 16),
//
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildInfoItem(
//                 icon: Iconsax.people,
//                 value: '${pronostic.nombreParticipants}',
//                 label: 'Participants',
//                 color: Colors.blue,
//               ),
//               _buildInfoItem(
//                 icon: Iconsax.money,
//                 value: '${pronostic.cagnotte.toStringAsFixed(0)} F',
//                 label: 'Cagnotte',
//                 color: _secondaryColor,
//               ),
//               _buildInfoItem(
//                 icon: Iconsax.chart,
//                 value: '${pronostic.nombrePronosticsUniques}',
//                 label: 'Scores',
//                 color: Colors.green,
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 12),
//
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Iconsax.clock, size: 14, color: _hintColor),
//               const SizedBox(width: 4),
//               Text(
//                 'Publié le ${_formatDate(pronostic.dateCreation)}',
//                 style: TextStyle(color: _hintColor, fontSize: 12),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoItem({
//     required IconData icon,
//     required String value,
//     required String label,
//     required Color color,
//   }) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Icon(icon, color: color, size: 20),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             color: _textColor,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(color: _hintColor, fontSize: 10),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildStatsRow(Post post) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildStatItem(
//             icon: Icons.remove_red_eye,
//             count: post.vues ?? 0,
//             label: 'Vues',
//           ),
//           GestureDetector(
//             onTap: _handleLike,
//             child: _buildStatItem(
//               icon: Icons.favorite,
//               count: post.loves ?? 0,
//               label: 'Likes',
//               isLiked: isIn(post.users_love_id, _authProvider.loginUserData.id!),
//             ),
//           ),
//           GestureDetector(
//             onTap: () {
//               FirebaseFirestore.instance.collection('Posts').doc(widget.postId).update({
//                 'popularity': FieldValue.increment(1),
//               });
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => PostComments(post: post),
//                 ),
//               ).then((_) => _refreshData());
//             },
//             child: _buildStatItem(
//               icon: Icons.comment,
//               count: post.comments ?? 0,
//               label: 'Comments',
//             ),
//           ),
//           GestureDetector(
//             onTap: _toggleFavorite,
//             child: _buildStatItem(
//               icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
//               count: post.favoritesCount ?? 0,
//               label: 'Favoris',
//               isLiked: _isFavorite,
//             ),
//           ),
//           _isSharing
//               ? const SizedBox(
//             width: 40,
//             height: 40,
//             child: Padding(
//               padding: EdgeInsets.all(8.0),
//               child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD600)),
//             ),
//           )
//               : GestureDetector(
//             onTap: _handleShare,
//             child: _buildStatItem(
//               icon: Icons.share,
//               count: post.partage ?? 0,
//               label: 'Partages',
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatItem({
//     required IconData icon,
//     required int count,
//     required String label,
//     bool isLiked = false,
//   }) {
//     Color iconColor;
//     if (icon == Icons.bookmark || icon == Icons.bookmark_border) {
//       iconColor = isLiked ? _secondaryColor : Colors.yellow;
//     } else if (icon == Icons.favorite || icon == Icons.favorite_border) {
//       iconColor = isLiked ? Colors.red : Colors.yellow;
//     } else {
//       iconColor = Colors.yellow;
//     }
//
//     return Column(
//       children: [
//         Icon(
//           icon,
//           color: iconColor,
//           size: 20,
//         ),
//         const SizedBox(height: 5),
//         Text(
//           formatNumber(count),
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 12,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey[400],
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildMyParticipationCard(ParticipationPronostic participation, bool estGagnant, Pronostic pronostic) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: estGagnant ? _secondaryColor : Colors.blue,
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(
//                 estGagnant ? Iconsax.cup : Iconsax.tick_circle,
//                 color: estGagnant ? _secondaryColor : Colors.blue,
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 estGagnant ? '🎉 FÉLICITATIONS ! VOUS AVEZ GAGNÉ !' : 'VOTRE PRONOSTIC',
//                 style: TextStyle(
//                   color: estGagnant ? _secondaryColor : Colors.blue,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: _backgroundColor,
//                   borderRadius: BorderRadius.circular(30),
//                   border: Border.all(color: estGagnant ? _secondaryColor : Colors.blue),
//                 ),
//                 child: Text(
//                   '${participation.scoreEquipeA} - ${participation.scoreEquipeB}',
//                   style: TextStyle(
//                     color: estGagnant ? _secondaryColor : Colors.blue,
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           if (pronostic.scoreFinalEquipeA != null && pronostic.scoreFinalEquipeB != null && !estGagnant)
//             Padding(
//               padding: const EdgeInsets.only(top: 8),
//               child: Center(
//                 child: Text(
//                   'Score final: ${pronostic.scoreFinalEquipeA} - ${pronostic.scoreFinalEquipeB}',
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildGainCard(double gain) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _secondaryColor.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _secondaryColor),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: _secondaryColor,
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Iconsax.money, color: Colors.black),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'VOS GAINS',
//                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   '${gain.toStringAsFixed(0)} FCFA',
//                   style: TextStyle(
//                     color: _secondaryColor,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const Text(
//                   'Ont été crédités sur votre solde',
//                   style: TextStyle(color: Colors.grey, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDescription(Post? post) {
//     if (post == null || post.description == null || post.description!.isEmpty) {
//       return const SizedBox();
//     }
//
//     final text = post.description!;
//     final words = text.split(' ');
//     final isLong = words.length > 50;
//     final displayedText = _isExpanded ? text : words.take(50).join(' ') + (isLong ? '...' : '');
//
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             displayedText,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               height: 1.4,
//             ),
//           ),
//           if (isLong)
//             GestureDetector(
//               onTap: () {
//                 setState(() {
//                   _isExpanded = !_isExpanded;
//                 });
//               },
//               child: Padding(
//                 padding: const EdgeInsets.only(top: 4),
//                 child: Text(
//                   _isExpanded ? "Voir moins" : "Voir plus",
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: _secondaryColor,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildParticipationForm(Pronostic pronostic) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Faites votre pronostic',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//
//           Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   children: [
//                     _buildTeamLogo(pronostic.equipeA.urlLogo, size: 50),
//                     const SizedBox(height: 8),
//                     Text(
//                       pronostic.equipeA.nom,
//                       style: const TextStyle(color: Colors.white, fontSize: 12),
//                       textAlign: TextAlign.center,
//                       maxLines: 2,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             height: 50,
//                             decoration: BoxDecoration(
//                               color: _backgroundColor,
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(
//                                 color: _participationError != null ? Colors.red : Colors.grey[800]!,
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 IconButton(
//                                   onPressed: _decrementScoreA,
//                                   icon: Icon(Icons.remove, color: _secondaryColor),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     '$_scoreA',
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ),
//                                 IconButton(
//                                   onPressed: _incrementScoreA,
//                                   icon: Icon(Icons.add, color: _secondaryColor),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//
//               const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 8),
//                 child: Text(
//                   '-',
//                   style: TextStyle(color: Colors.white, fontSize: 24),
//                 ),
//               ),
//
//               Expanded(
//                 child: Column(
//                   children: [
//                     _buildTeamLogo(pronostic.equipeB.urlLogo, size: 50),
//                     const SizedBox(height: 8),
//                     Text(
//                       pronostic.equipeB.nom,
//                       style: const TextStyle(color: Colors.white, fontSize: 12),
//                       textAlign: TextAlign.center,
//                       maxLines: 2,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             height: 50,
//                             decoration: BoxDecoration(
//                               color: _backgroundColor,
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(
//                                 color: _participationError != null ? Colors.red : Colors.grey[800]!,
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 IconButton(
//                                   onPressed: _decrementScoreB,
//                                   icon: Icon(Icons.remove, color: _secondaryColor),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     '$_scoreB',
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ),
//                                 IconButton(
//                                   onPressed: _incrementScoreB,
//                                   icon: Icon(Icons.add, color: _secondaryColor),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//
//           if (_participationError != null) ...[
//             const SizedBox(height: 8),
//             Text(
//               _participationError!,
//               style: const TextStyle(color: Colors.red, fontSize: 12),
//               textAlign: TextAlign.center,
//             ),
//           ],
//
//           const SizedBox(height: 16),
//
//           FutureBuilder<int>(
//             future: _getNombreParticipantsPourScore(pronostic, _scoreA, _scoreB),
//             builder: (context, snapshot) {
//               int participants = snapshot.data ?? 0;
//               bool isQuotaOk = participants < pronostic.quotaMaxParScore;
//
//               return Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: _backgroundColor,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Participants pour ce score:',
//                       style: TextStyle(color: _hintColor),
//                     ),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: isQuotaOk ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         '$participants/${pronostic.quotaMaxParScore}',
//                         style: TextStyle(
//                           color: isQuotaOk ? Colors.green : Colors.red,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//
//           const SizedBox(height: 20),
//
//           SizedBox(
//             width: double.infinity,
//             height: 55,
//             child: ElevatedButton(
//               onPressed: _isParticipating ? null : () => _validerParticipation(pronostic),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _primaryColor,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//               ),
//               child: _isParticipating
//                   ? const CircularProgressIndicator(color: Colors.white)
//                   : Text(
//                 pronostic.typeAcces == 'PAYANT'
//                     ? 'PAYER ${pronostic.prixParticipation.toStringAsFixed(0)} FCFA ET VALIDER'
//                     : 'VALIDER MON PRONOSTIC',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ),
//
//           if (pronostic.typeAcces == 'PAYANT') ...[
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _backgroundColor,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Iconsax.info_circle, color: _secondaryColor, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Le montant sera débité de votre solde principal',
//                       style: TextStyle(color: _hintColor, fontSize: 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildClosedMessage(Pronostic pronostic) {
//     String message;
//     if (pronostic.statut == PronosticStatut.EN_COURS) {
//       message = 'Le match a commencé, les pronostics sont fermés.';
//     } else if (pronostic.statut == PronosticStatut.TERMINE) {
//       message = 'Le match est terminé. Consultez les résultats.';
//     } else if (pronostic.statut == PronosticStatut.GAINS_DISTRIBUES) {
//       message = 'Les gains ont été distribués.';
//     } else {
//       message = 'Ce pronostic n\'est plus disponible.';
//     }
//
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         children: [
//           Icon(Iconsax.lock, size: 50, color: _hintColor),
//           const SizedBox(height: 16),
//           Text(
//             message,
//             style: TextStyle(color: _hintColor, fontSize: 14),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatsCard(Pronostic pronostic) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Répartition des scores',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
//           ),
//           const SizedBox(height: 16),
//
//           ...pronostic.participationsParScore.entries.map((entry) {
//             String score = entry.key;
//             int count = entry.value.length;
//
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 8),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 60,
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: _backgroundColor,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       score,
//                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         LinearProgressIndicator(
//                           value: count / pronostic.quotaMaxParScore,
//                           backgroundColor: Colors.grey[800],
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                             count >= pronostic.quotaMaxParScore ? Colors.red : _primaryColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     '$count/${pronostic.quotaMaxParScore}',
//                     style: TextStyle(color: _hintColor, fontSize: 12),
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//
//           if (pronostic.participationsParScore.isEmpty)
//             Center(
//               child: Text(
//                 'Aucun pronostic pour le moment',
//                 style: TextStyle(color: _hintColor),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildParticipantsList(Pronostic pronostic) {
//     if (pronostic.toutesParticipations.isEmpty) {
//       return const SizedBox();
//     }
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Text(
//                 'Participants',
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               const Spacer(),
//               Text(
//                 '${pronostic.toutesParticipations.length} personne(s)',
//                 style: TextStyle(color: _hintColor, fontSize: 12),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           SizedBox(
//             height: 80,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: pronostic.toutesParticipations.length,
//               itemBuilder: (context, index) {
//                 final participation = pronostic.toutesParticipations[index];
//                 final estGagnant = pronostic.gagnantsIds.contains(participation.userId);
//
//                 return Container(
//                   width: 60,
//                   margin: const EdgeInsets.only(right: 12),
//                   child: Column(
//                     children: [
//                       Stack(
//                         children: [
//                           Container(
//                             width: 50,
//                             height: 50,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               border: Border.all(
//                                 color: estGagnant ? _secondaryColor : Colors.transparent,
//                                 width: 2,
//                               ),
//                               image: participation.userImageUrl.isNotEmpty
//                                   ? DecorationImage(
//                                 image: NetworkImage(participation.userImageUrl),
//                                 fit: BoxFit.cover,
//                               )
//                                   : null,
//                             ),
//                             child: participation.userImageUrl.isEmpty
//                                 ? const Icon(Icons.person, color: Colors.grey)
//                                 : null,
//                           ),
//                           if (estGagnant)
//                             Positioned(
//                               bottom: 0,
//                               right: 0,
//                               child: Container(
//                                 padding: const EdgeInsets.all(2),
//                                 decoration: const BoxDecoration(
//                                   color: Color(0xFFFFD600),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: const Icon(Iconsax.cup, size: 12, color: Colors.black),
//                               ),
//                             ),
//                         ],
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         '${participation.scoreEquipeA}-${participation.scoreEquipeB}',
//                         style: TextStyle(
//                           color: estGagnant ? _secondaryColor : _hintColor,
//                           fontSize: 10,
//                           fontWeight: estGagnant ? FontWeight.bold : FontWeight.normal,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _backgroundColor,
//       appBar: AppBar(
//         backgroundColor: _cardColor,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: _secondaryColor),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Détail du pronostic',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//         actions: const [
//           Padding(
//             padding: EdgeInsets.only(right: 16),
//             child: Text(
//               'Afrolook',
//               style: TextStyle(
//                 color: Colors.green,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: LoadingWidget())
//           : _errorMessage != null
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Iconsax.warning_2, size: 60, color: _primaryColor),
//             const SizedBox(height: 16),
//             Text(
//               _errorMessage!,
//               style: TextStyle(color: _textColor),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _refreshData,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _primaryColor,
//               ),
//               child: const Text('RÉESSAYER'),
//             ),
//           ],
//         ),
//       )
//           : _pronostic == null
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Iconsax.chart, size: 80, color: _hintColor),
//             const SizedBox(height: 16),
//             Text(
//               'Pronostic non trouvé',
//               style: TextStyle(color: _hintColor, fontSize: 16),
//             ),
//           ],
//         ),
//       )
//           : RefreshIndicator(
//         onRefresh: _refreshData,
//         color: _secondaryColor,
//         backgroundColor: _cardColor,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               _buildTeamsCard(_pronostic!),
//               const SizedBox(height: 16),
//
//               _buildStatusCard(_pronostic!),
//               const SizedBox(height: 16),
//
//               if (_post != null) _buildDescription(_post),
//               if (_post != null) _buildStatsRow(_post!),
//
//               const Divider(color: Colors.grey, height: 32),
//
//               // Participation de l'utilisateur
//               if (_aDejaParticipe(_pronostic!, _authProvider.loginUserData.id!))
//                 _buildMyParticipationCard(
//                   _getMaParticipation(_pronostic!, _authProvider.loginUserData.id!)!,
//                   _estGagnant(_pronostic!, _authProvider.loginUserData.id!),
//                   _pronostic!,
//                 ),
//
//               if (_aDejaParticipe(_pronostic!, _authProvider.loginUserData.id!) &&
//                   _estGagnant(_pronostic!, _authProvider.loginUserData.id!) &&
//                   _pronostic!.gainParGagnant != null)
//                 _buildGainCard(_pronostic!.gainParGagnant!),
//
//               const SizedBox(height: 16),
//
//               // Formulaire de participation
//               if (_pronostic!.estOuvert && !_aDejaParticipe(_pronostic!, _authProvider.loginUserData.id!))
//                 _buildParticipationForm(_pronostic!)
//               else if (!_pronostic!.estOuvert && !_aDejaParticipe(_pronostic!, _authProvider.loginUserData.id!))
//                 _buildClosedMessage(_pronostic!),
//
//               const SizedBox(height: 16),
//
//               _buildStatsCard(_pronostic!),
//               const SizedBox(height: 16),
//
//               _buildParticipantsList(_pronostic!),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }