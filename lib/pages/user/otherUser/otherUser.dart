import 'dart:math';

import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/tiktokModel.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/pages/user/profile/profileDetail/widget/numbers_widget.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../providers/userProvider.dart';
import '../../../services/linkService.dart';
import '../../../services/chat_service.dart';
import '../../home/user_presence_widget.dart';
import '../../widgetGlobal.dart';
import '../../../widgets/interests_selector_widget.dart';
import '../userPubs/user_profile_boost_page.dart';
import '../user_following_page.dart';
import '../../suspension_screen.dart';
import '../../chat/myChat.dart';
import 'package:page_transition/page_transition.dart';

class OtherUserPage extends StatefulWidget {
  final UserData otherUser;

  const OtherUserPage({super.key, required this.otherUser});

  @override
  _OtherUserPageState createState() => _OtherUserPageState();
}

class _OtherUserPageState extends State<OtherUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  // ── Posts normaux ──────────────────────────────────────────
  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  DocumentSnapshot? _lastDocument;
  String _selectedFilter = 'all';

  // ── Publicités (isAdvertisement == true) ───────────────────
  List<Post> _adsPosts = [];
  bool _adsLoading = false;
  bool _adsLoadingMore = false;
  DocumentSnapshot? _adsLastDocument;
  Map<String, Advertisement> _adsData = {};

  // ── Onglet actif ───────────────────────────────────────────
  bool _showAds = false;

  final int _postsPerPage = 12;
  bool _isSharing = false;
  bool _abonneTap = false;
  late UserAuthProvider authProvider;

  int _profileLikes = 0;
  bool _isSendingReminder = false;
  bool _isOpeningChat = false;
  final ChatService _chatService = ChatService();

  // ── Sélection multiple ─────────────────────────────────────
  bool _isSelectionMode = false;
  Set<String> _selectedPostIds = {};
  bool _isDeletingPosts = false;

  // ── Stats d'abonnements ────────────────────────────────────
  int _followingCount = 0;
  int _canalCount = 0;

  bool get _canManagePosts =>
      authProvider.loginUserData.id == widget.otherUser.id ||
      authProvider.loginUserData.role == 'ADM';

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _profileLikes = widget.otherUser.userlikes ?? 0;
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
    _loadFollowingStats();
    _refreshUserData();
  }

  Future<void> _loadFollowingStats() async {
    if (widget.otherUser.id == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Users').doc(widget.otherUser.id).get(),
        FirebaseFirestore.instance.collection('Canaux').where('usersSuiviId', arrayContains: widget.otherUser.id).count().get(),
      ]);
      final userDoc = results[0] as DocumentSnapshot;
      final canalCount = results[1] as AggregateQuerySnapshot;
      final followingIds = (userDoc.data() as Map<String, dynamic>?)?['followingIds'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _followingCount = followingIds.length;
          _canalCount = canalCount.count ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendReminderEmail() async {
    if (_isSendingReminder) return;

    setState(() => _isSendingReminder = true);

    try {
      // Récupérer les données utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.otherUser.id)
          .get();

      if (!userDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }

      final data = userDoc.data()!;
      final lastTimeActive = data['last_time_active'] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final daysInactive = ((now - lastTimeActive) / (24 * 60 * 60 * 1000)).floor();

      // Compter les nouveaux likes (7 derniers jours)
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .get();

      int newLikesCount = 0;
      for (var postDoc in postsSnapshot.docs) {
        final post = postDoc.data();
        final postCreatedAt = post['created_at'] ?? 0;
        if (postCreatedAt > sevenDaysAgo) {
          newLikesCount += (post['loves'] as int ?? 0);
        }
      }

      // Préparer les données
      final userEmailData = {
        'userId': widget.otherUser.id,
        'userEmail': data['email'] ?? '',
        'userName': data['pseudo'] ?? 'Utilisateur',
        'pseudo': data['pseudo'] ?? 'user',
        'giftCoinsBalance': data['giftCoinsBalance'] ?? 0,
        'soldePrincipal': data['votre_solde_principal'] ?? 0,
        'totalCoinsEarned': data['totalCoinsEarnedFromLikes'] ?? 0,
        'totalLikesReceived': data['totalLikesReceived'] ?? 0,
        'totalFollowers': (data['userAbonnesIds'] as List?)?.length ?? 0,
        'daysInactive': daysInactive < 0 ? 3 : daysInactive,
        'newLikesOnMyPosts': newLikesCount,
        'newCommentsOnMyPosts': 0,
      };

      // Appeler la Cloud Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendInactiveUserReminder')
          .call({
        'userId': widget.otherUser.id,
        'userData': userEmailData,
      });

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Email envoyé à ${userEmailData['userEmail']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data['message'] ?? 'Erreur lors de l\'envoi'),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingReminder = false);
      }
    }
  }

  void _showConfirmReminderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.email, color: Colors.orange),
            SizedBox(width: 10),
            Text('Envoyer un rappel', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Envoyer un email personnalisé à @${widget.otherUser.pseudo} ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendReminderEmail();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Envoyer'),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleAbonnement() async {
    if (_abonneTap) return; // Éviter les doubles clics

    setState(() => _abonneTap = true);

    try {
      if (_isAbonne) {
        // Se désabonner
        await _desabonner(widget.otherUser);
      } else {
        // S'abonner
        await authProvider.abonner(widget.otherUser, context);
      }

      // Rafraîchir les données du profil
      await _refreshUserData();

    } catch (e) {
      printVm('Erreur lors de l\'opération: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Erreur lors de l\'opération',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _abonneTap = false);
      }
    }
  }

  Future<void> _desabonner(UserData userToUnfollow) async {
    try {
      final currentUserId = authProvider.loginUserData.id!;

      // Vérifier si l'utilisateur est bien abonné
      if (!_isAbonne) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous n\'êtes pas abonné à ce compte'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Mise à jour dans Firestore
      await Future.wait([
        // Doc du créateur : -1 abonné
        FirebaseFirestore.instance
            .collection('Users')
            .doc(userToUnfollow.id)
            .update({
          'userAbonnesIds': FieldValue.arrayRemove([currentUserId]),
          'abonnes': FieldValue.increment(-1),
        }),
        // Doc de l'utilisateur courant : retirer du following
        FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUserId)
            .update({
          'followingIds': FieldValue.arrayRemove([userToUnfollow.id!]),
        }),
      ]);

      // Supprimer la relation d'abonnement si elle existe
      final querySnapshot = await FirebaseFirestore.instance
          .collection('UserAbonnes')
          .where('compteUserId', isEqualTo: currentUserId)
          .where('abonneUserId', isEqualTo: userToUnfollow.id)
          .limit(1)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      // Mise à jour locale
      authProvider.loginUserData.userAbonnes?.removeWhere(
              (abonne) => abonne.abonneUserId == userToUnfollow.id
      );
      authProvider.loginUserData.followingIds?.remove(userToUnfollow.id);

      userToUnfollow.userAbonnesIds?.remove(currentUserId);
      userToUnfollow.abonnes = (userToUnfollow.abonnes ?? 1) - 1;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous ne suivez plus @${userToUnfollow.pseudo}',
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      printVm("Erreur lors du désabonnement : $e");
      throw e; // Relancer l'erreur pour la gestion dans _toggleAbonnement
    }
  }

  Future<void> _refreshUserData() async {
    if (widget.otherUser.id == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.otherUser.id)
          .get();

      if (docSnapshot.exists && mounted) {
        final updatedUser = UserData.fromJson(docSnapshot.data()!);
        setState(() {
          widget.otherUser.userAbonnesIds = updatedUser.userAbonnesIds;
          widget.otherUser.abonnes = updatedUser.abonnes;
          widget.otherUser.followingIds = updatedUser.followingIds;
          widget.otherUser.pointContribution = updatedUser.pointContribution;
          widget.otherUser.codeParrainage = updatedUser.codeParrainage;
          widget.otherUser.usersParrainer = updatedUser.usersParrainer;
          widget.otherUser.usersParrainerActifs = updatedUser.usersParrainerActifs;
          widget.otherUser.userlikes = updatedUser.userlikes;
          _profileLikes = updatedUser.userlikes ?? _profileLikes;
        });
      }
    } catch (e) {
      printVm('Erreur refresh user data: $e');
    }
  }
  Future<void> _shareProfile() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final appLinkService = AppLinkService();

      // Message court et accrocheur
      String shareMessage =
          "🚀 @${widget.otherUser.pseudo} sur Afrolook !: "
          "👥 ${widget.otherUser.userAbonnesIds?.length ?? 0} followers, "
          "❤️ ${_profileLikes  ?? 0} likes.\n "
          "💰 Dès 100 vues, tu es rémunéré (+25 000 FCFA/mois)!\n"
          "🎁 Cliquez sur mon lien et utiliser MON CODE à l'inscription: ${widget.otherUser.codeParrainage}\n"
          "📱 Afrolook - Le réseau social qui paie ton talent";

      await appLinkService.shareProfil(
        type: AppLinkType.profil,
        id: widget.otherUser.id!,
        message: shareMessage,
        mediaUrl: widget.otherUser.imageUrl ?? '',
      );

    } catch (e) {
      printVm('Erreur partage profil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  bool get _isAbonne {
    final currentUserId = authProvider.loginUserData.id;
    return widget.otherUser.userAbonnesIds?.contains(currentUserId) ?? false;
  }

  Future<void> _openDirectChat() async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    try {
      final tempChat = Chat(
        id: 'temp_${widget.otherUser.id}',
        senderId: authProvider.loginUserData.id,
        receiverId: widget.otherUser.id,
        chatFriend: widget.otherUser,
        receiver: widget.otherUser,
        type: ChatType.USER.name,
      );
      final resultChat = await _chatService.createOrGetChat(
        chat: tempChat,
        currentUserId: authProvider.loginUserData.id!,
      );
      if (!mounted) return;
      Navigator.push(context, PageTransition(
        type: PageTransitionType.fade,
        child: MyChat(title: 'Message', chat: resultChat),
      ));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  void _showSuspendDialog() {
    final colors = AppColors.of(context);
    final reasonCtrl = TextEditingController();
    int? durationDays;
    bool isPermanent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: colors.surface,
          title: Row(children: [
            const Icon(Icons.block, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'Suspendre @${widget.otherUser.pseudo}',
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type de suspension
                Text('Type :', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() { isPermanent = false; durationDays = null; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isPermanent ? Colors.orange.withOpacity(0.15) : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: !isPermanent ? Colors.orange : colors.divider),
                          ),
                          child: Column(children: [
                            Icon(Icons.timer, color: !isPermanent ? Colors.orange : colors.textSecondary, size: 20),
                            const SizedBox(height: 4),
                            Text('Temporaire', style: TextStyle(fontSize: 11, color: !isPermanent ? Colors.orange : colors.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => isPermanent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isPermanent ? Colors.red.withOpacity(0.15) : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isPermanent ? Colors.red : colors.divider),
                          ),
                          child: Column(children: [
                            Icon(Icons.block, color: isPermanent ? Colors.red : colors.textSecondary, size: 20),
                            const SizedBox(height: 4),
                            Text('Définitive', style: TextStyle(fontSize: 11, color: isPermanent ? Colors.red : colors.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Durée (si temporaire)
                if (!isPermanent) ...[
                  Text('Durée :', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [1, 3, 7, 14, 30].map((d) => GestureDetector(
                      onTap: () => setS(() => durationDays = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: durationDays == d ? Colors.orange.withOpacity(0.2) : colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: durationDays == d ? Colors.orange : colors.divider),
                        ),
                        child: Text('${d}j', style: TextStyle(fontSize: 12, color: durationDays == d ? Colors.orange : colors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                ],
                // Raison
                Text('Raison (visible par l\'utilisateur) :', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ex: Violation des règles de la communauté...',
                    hintStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                if (!isPermanent && durationDays == null) return;
                Navigator.pop(ctx);
                await _applySuspension(
                  isPermanent: isPermanent,
                  durationDays: durationDays,
                  reason: reasonCtrl.text.trim(),
                );
              },
              child: const Text('Suspendre', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySuspension({
    required bool isPermanent,
    int? durationDays,
    required String reason,
  }) async {
    try {
      final data = <String, dynamic>{
        'suspensionReason': reason,
        'suspendedPermanently': isPermanent,
      };
      if (isPermanent) {
        data['suspendedUntil'] = null;
      } else {
        final until = DateTime.now().add(Duration(days: durationDays!));
        data['suspendedUntil'] = until.millisecondsSinceEpoch;
        data['suspendedPermanently'] = false;
      }
      await _firestore.collection('Users').doc(widget.otherUser.id).update(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte suspendu'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showLiftSuspensionDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Lever la suspension', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Êtes-vous sûr de vouloir lever la suspension du compte @${widget.otherUser.pseudo} ?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestore.collection('Users').doc(widget.otherUser.id).update({
                'suspendedUntil': null,
                'suspendedPermanently': false,
                'suspensionReason': null,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Suspension levée'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            child: const Text('Lever', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorScoreBadge(double score, dynamic colors) {
    final color = score >= 50
        ? const Color(0xFF4CAF50)
        : score >= 15
            ? const Color(0xFFFFD700)
            : colors.textSecondary;
    final label = score >= 50 ? 'Top créateur' : score >= 15 ? 'Créateur actif' : 'Créateur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.trending_up_rounded, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          '$label · ${score.toStringAsFixed(1)} pts',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _buildFollowButton() {
    final isOwnProfile = authProvider.loginUserData.id == widget.otherUser.id;
    if (isOwnProfile) return const SizedBox();
    final isAdmin = authProvider.loginUserData.role == 'ADM';
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    Widget followBtn;
    if (_isAbonne) {
      // Se désabonner — discret, outlined
      followBtn = OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.4), width: 1),
          foregroundColor: colors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _abonneTap ? null : _toggleAbonnement,
        child: _abonneTap
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colors.textSecondary, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 18, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(t.otherUserUnsubscribe,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textSecondary)),
              ]),
      );
    } else {
      // S'abonner — gradient attractif + animation pulse légère
      final btn = GestureDetector(
        onTap: _abonneTap ? null : _toggleAbonnement,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE21221), Color(0xFFFF5E62)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFFE21221).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: _abonneTap
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.person_add, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text("S'ABONNER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
        ),
      );
      followBtn = btn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.02, 1.02), duration: 900.ms, curve: Curves.easeInOut);
    }

    final isSuspended = widget.otherUser.suspendedPermanently == true ||
        (widget.otherUser.suspendedUntil != null &&
            DateTime.now().millisecondsSinceEpoch < widget.otherUser.suspendedUntil!);

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: isAdmin ? 2 : 1, child: followBtn),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              // Message direct admin
              Container(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.primary, width: 1),
                ),
                child: IconButton(
                  icon: _isOpeningChat
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
                      : Icon(Icons.chat_bubble_outline, color: colors.primary, size: 22),
                  onPressed: _isOpeningChat ? null : _openDirectChat,
                  tooltip: 'Message direct',
                ),
              ),
              const SizedBox(width: 8),
              // Email rappel
              Container(
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.warning, width: 1),
                ),
                child: IconButton(
                  icon: _isSendingReminder
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colors.warning, strokeWidth: 2))
                      : Icon(Icons.email, color: colors.warning, size: 22),
                  onPressed: _isSendingReminder ? null : _showConfirmReminderDialog,
                  tooltip: t.otherUserSendReminder,
                ),
              ),
            ],
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 8),
          // Bouton suspension
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isSuspended ? Colors.green : Colors.red,
                side: BorderSide(color: isSuspended ? Colors.green : Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSuspended ? _showLiftSuspensionDialog : _showSuspendDialog,
              icon: Icon(isSuspended ? Icons.lock_open : Icons.block, size: 16),
              label: Text(
                isSuspended ? 'Lever la suspension' : 'Suspendre ce compte',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShareButton() {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _isSharing ? null : _shareProfile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isSharing ? colors.surfaceVariant : colors.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: _isSharing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: colors.onPrimary, strokeWidth: 2),
              )
            : Icon(Icons.share, color: colors.onPrimary, size: 24),
      ),
    );
  }
  Widget _buildReferralCodeCompact() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.otherUserReferralCode,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.otherUser.codeParrainage}",
                style: TextStyle(
                  color: colors.supportAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.info.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group, color: colors.info, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.otherUser.usersParrainer?.length ?? 0}",
                      style: TextStyle(
                        color: colors.info,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: "${widget.otherUser.codeParrainage}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t.otherUserCodeCopied),
                      backgroundColor: colors.primary,
                    ),
                  );
                },
                child: Icon(Icons.copy, color: colors.supportAccent, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Future<void> _loadInitialPosts() async {
    try {
      setState(() => _loading = true);

      final query = _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .orderBy('created_at', descending: true)
          .limit(_postsPerPage);

      final snapshot = await query.get();

      final filteredPosts = snapshot.docs
          .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
          .where((post) =>
              (post.challenge_id == null || post.challenge_id!.isEmpty) &&
              (post.canal_id == null || post.canal_id!.isEmpty) &&
              (post.type == PostType.POST.name) &&
              post.isAdvertisement != true)
          .toList();

      setState(() {
        _posts = filteredPosts;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _loading = false;
      });
    } catch (e) {
      printVm('Erreur chargement posts: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || _lastDocument == null) return;

    try {
      setState(() => _loadingMore = true);

      var query = _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage);

      if (_selectedFilter != 'all') {
        query = query.where('dataType', isEqualTo: _selectedFilter);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        final filteredPosts = snapshot.docs
            .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
            .where((post) =>
                (post.challenge_id == null || post.challenge_id!.isEmpty) &&
                (post.canal_id == null || post.canal_id!.isEmpty) &&
                (post.type == PostType.POST.name) &&
                post.isAdvertisement != true)
            .toList();

        setState(() {
          _posts.addAll(filteredPosts);
          _lastDocument = snapshot.docs.last;
        });
      }
    } catch (e) {
      printVm('Erreur chargement plus de posts: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }


  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange) {
      if (_showAds) {
        _loadMoreAds();
      } else {
        _loadMorePosts();
      }
    }
  }

  Future<void> _applyFilter(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _loading = true;
      _posts.clear();
      _lastDocument = null;
    });
    printVm("_selectedFilter : ${_selectedFilter}");
    await _loadInitialPosts();
  }

  Future<void> _switchTab(bool showAds) async {
    if (_showAds == showAds) return;
    setState(() => _showAds = showAds);
    if (showAds && _adsPosts.isEmpty && !_adsLoading) {
      await _loadInitialAds();
    }
  }

  Future<void> _loadInitialAds() async {
    try {
      setState(() => _adsLoading = true);
      final snapshot = await _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .where('isAdvertisement', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(_postsPerPage)
          .get();

      final posts = snapshot.docs
          .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      await _fetchAdvertisements(posts);

      setState(() {
        _adsPosts = posts;
        _adsLastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _adsLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement pubs: $e');
      setState(() => _adsLoading = false);
    }
  }

  Future<void> _loadMoreAds() async {
    if (_adsLoadingMore || _adsLastDocument == null) return;
    try {
      setState(() => _adsLoadingMore = true);
      final snapshot = await _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .where('isAdvertisement', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .startAfterDocument(_adsLastDocument!)
          .limit(_postsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final newPosts = snapshot.docs
            .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
            .toList();
        await _fetchAdvertisements(newPosts);
        setState(() {
          _adsPosts.addAll(newPosts);
          _adsLastDocument = snapshot.docs.last;
        });
      }
    } catch (e) {
      printVm('Erreur chargement plus de pubs: $e');
    } finally {
      setState(() => _adsLoadingMore = false);
    }
  }

  Future<void> _fetchAdvertisements(List<Post> posts) async {
    final ids = posts
        .where((p) => p.advertisementId != null && p.advertisementId!.isNotEmpty)
        .map((p) => p.advertisementId!)
        .where((id) => !_adsData.containsKey(id))
        .toList();
    if (ids.isEmpty) return;
    for (int i = 0; i < ids.length; i += 30) {
      final batch = ids.sublist(i, min(i + 30, ids.length));
      try {
        final snap = await _firestore
            .collection('Advertisements')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          _adsData[doc.id] =
              Advertisement.fromJson({'id': doc.id, ...doc.data()});
        }
      } catch (e) {
        printVm('Erreur fetch advertisements: $e');
      }
    }
  }

  List<Post> get _filteredPosts {
    if (_selectedFilter == 'all') return _posts;
    return _posts.where((post) => post.dataType == _selectedFilter).toList();
  }

  void _navigateToPostDetails(Post post) {
    if (post.dataType == PostDataType.VIDEO.name) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoYoutubePageDetails(initialPost: post,),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DetailsPost(post: post),
      ));
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPostIds.clear();
    });
  }

  void _togglePostSelection(String postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
        if (_selectedPostIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  Future<void> _deleteSelectedPosts() async {
    if (_isDeletingPosts || _selectedPostIds.isEmpty) return;
    final count = _selectedPostIds.length;
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Supprimer $count post${count > 1 ? 's' : ''} ?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'Cette action est irréversible.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeletingPosts = true);
    final idsToDelete = Set<String>.from(_selectedPostIds);
    try {
      for (final id in idsToDelete) {
        await _firestore.collection('Posts').doc(id).delete();
      }
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.id != null && idsToDelete.contains(p.id));
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count post${count > 1 ? 's supprimés' : ' supprimé'}'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingPosts = false;
          _isSelectionMode = false;
          _selectedPostIds.clear();
        });
      }
    }
  }

  Widget _buildSelectionBar(dynamic colors) {
    final count = _selectedPostIds.length;
    final allSelected = _filteredPosts.isNotEmpty &&
        _filteredPosts.every((p) => p.id != null && _selectedPostIds.contains(p.id));
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: _exitSelectionMode,
              child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
            ),
            Expanded(
              child: Text(
                '$count sélectionné${count > 1 ? 's' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedPostIds.clear();
                  } else {
                    _selectedPostIds.addAll(
                      _filteredPosts
                          .where((p) => p.id != null)
                          .map((p) => p.id!),
                    );
                  }
                });
              },
              child: Text(
                allSelected ? 'Désélect. tout' : 'Tout sélect.',
                style: TextStyle(color: colors.primary, fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            _isDeletingPosts
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: count > 0 ? _deleteSelectedPosts : null,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Supprimer', style: TextStyle(fontSize: 13)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    if (widget.otherUser.isVerify != true) return const SizedBox();
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: colors.onPrimary, size: 12),
          const SizedBox(width: 4),
          Text(
            t.otherUserVerified,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBar(colors) : null,
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: RefreshIndicator(
        onRefresh: _loadInitialPosts,
        backgroundColor: colors.primary,
        color: colors.onPrimary,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              backgroundColor: colors.background,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.primary.withOpacity(0.3),
                        colors.background,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.primary, width: 3),
                        ),
                        child: ClipOval(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrl: widget.otherUser.imageUrl ?? '',
                                  ),
                                ),
                              );
                            },
                            child: CachedNetworkImage(
                              imageUrl: widget.otherUser.imageUrl ?? '',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colors.surfaceVariant,
                                child: Icon(Icons.person, color: colors.textSecondary),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colors.surfaceVariant,
                                child: Icon(Icons.person, color: colors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "@${widget.otherUser.pseudo!}",
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildVerificationBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      UserPresenceWidget(
                        userId: widget.otherUser.id!,
                        showTextStatus: true,
                        isChatHeader: false,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),

            // Section statistiques
            // SliverToBoxAdapter(
            //   child: Padding(
            //     padding: EdgeInsets.all(16),
            //     child: Column(
            //       children: [
            //         NumbersWidget(
            //
            //           followers: widget.otherUser.userAbonnesIds?.length ?? 0,
            //           taux: widget.otherUser.popularite!,
            //           points: widget.otherUser.pointContribution!,
            //         ),
            //         SizedBox(height: 16),
            //
            //         // Likes
            //         Container(
            //           padding:
            //               EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //           decoration: BoxDecoration(
            //             color: Colors.green.withOpacity(0.1),
            //             borderRadius: BorderRadius.circular(12),
            //             border: Border.all(color: Colors.green),
            //           ),
            //           child: Text(
            //             "${_formatNumber(widget.otherUser.userlikes!)} like(s)",
            //             style: TextStyle(
            //               color: Colors.green,
            //               fontSize: 16,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ),
            //         SizedBox(height: 16),
            //
            //         // À propos
            //         _buildAboutSection(),
            //         SizedBox(height: 16),
            //
            //         // Filtres
            //         _buildFilterSection(),
            //       ],
            //     ),
            //   ),
            // ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    NumbersWidget(
                      followers: widget.otherUser.userAbonnesIds?.length ?? 0,
                      taux: widget.otherUser.popularite!,
                      points: widget.otherUser.pointContribution!,
                    ),
                    const SizedBox(height: 10),
                    // Abonnements : créateurs + canaux suivis
                    if (_followingCount > 0 || _canalCount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_followingCount > 0)
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => UserFollowingPage(
                                  userId: widget.otherUser.id!,
                                  displayName: widget.otherUser.pseudo,
                                  initialTab: 0,
                                ),
                              )),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colors.primary.withOpacity(0.3)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.person_outline, size: 14, color: colors.primary),
                                  const SizedBox(width: 4),
                                  Text('$_followingCount créateur${_followingCount > 1 ? 's' : ''} suivi${_followingCount > 1 ? 's' : ''}',
                                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          if (_followingCount > 0 && _canalCount > 0) const SizedBox(width: 8),
                          if (_canalCount > 0)
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => UserFollowingPage(
                                  userId: widget.otherUser.id!,
                                  displayName: widget.otherUser.pseudo,
                                  initialTab: 1,
                                ),
                              )),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colors.primary.withOpacity(0.3)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.campaign_outlined, size: 14, color: colors.primary),
                                  const SizedBox(width: 4),
                                  Text('$_canalCount canal${_canalCount > 1 ? 'aux' : ''} suivi${_canalCount > 1 ? 's' : ''}',
                                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                        ],
                      ),
                    if ((widget.otherUser.creatorScore ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      _buildCreatorScoreBadge(widget.otherUser.creatorScore!, colors),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildFollowButton(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildShareButton(),
                        ),
                      ],
                    ),
                    if (authProvider.loginUserData.id == widget.otherUser.id) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserProfileBoostPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.rocket_launch_outlined, color: Colors.black),
                          label: const Text(
                            'Booster mon profil',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildReferralCodeCompact(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: colors.danger, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "${_formatNumber(widget.otherUser.userlikes ?? 0)} ${t.otherUserLikesReceived}",
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAboutSection(),
                    if ((widget.otherUser.interests ?? []).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInterestsSection(),
                    ],
                    const SizedBox(height: 16),
                    _buildFilterSection(),
                  ],
                ),
              ),
            ),
            // ── Grille : Posts ou Publicités ───────────────────────
            if (_showAds) ...[
              if (_adsLoading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colors.warning),
                      ),
                    ),
                  ),
                )
              else if (_adsPosts.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign, size: 64, color: colors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          t.otherUserNoAds,
                          style: TextStyle(color: colors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _adsPosts.length) return _buildLoadMoreIndicator();
                      return _buildAdCard(_adsPosts[index], width);
                    },
                    childCount: _adsPosts.length + (_adsLoadingMore ? 1 : 0),
                  ),
                ),
            ] else ...[
              if (_loading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                  ),
                )
              else if (_filteredPosts.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.post_add, size: 64, color: colors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'all'
                              ? t.otherUserNoPosts
                              : t.otherUserNoFilterPosts(_getFilterLabel(_selectedFilter)),
                          style: TextStyle(color: colors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _filteredPosts.length) return _buildLoadMoreIndicator();
                      return _buildPostCard(_filteredPosts[index], width);
                    },
                    childCount: _filteredPosts.length + (_loadingMore ? 1 : 0),
                  ),
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildReferralCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: [
        Row(
          spacing: 5,
          children: [
            Text(
              "Code de parrainage: ",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.yellow),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${widget.otherUser.codeParrainage}",
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: "${widget.otherUser.codeParrainage}"));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code de parrainage copié !'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Icon(Icons.copy, color: Colors.yellow, size: 16),
                  ),
                ],
              ),
            ),

          ],
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, color: Colors.blue, size: 16),
            SizedBox(width: 4),
            Text(
              "${widget.otherUser.usersParrainer!.length} parrainages",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )

      ],
    );
  }

  Widget _buildAboutSection() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                t.otherUserAbout,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.otherUser.apropos ?? t.otherUserNoDescription,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection() {
    final colors = AppColors.of(context);
    final interests = widget.otherUser.interests ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Centres d\'intérêt',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InterestsDisplayWidget(codes: interests, compact: true),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final filters = [
      {'value': 'all', 'label': t.otherUserFilterAll, 'icon': Icons.all_inclusive},
      {'value': 'IMAGE', 'label': t.otherUserFilterImages, 'icon': Icons.photo},
      {'value': 'VIDEO', 'label': t.otherUserFilterVideos, 'icon': Icons.videocam},
      {'value': 'AUDIO', 'label': t.otherUserFilterAudios, 'icon': Icons.headphones},
      {'value': 'TEXT', 'label': t.otherUserFilterTexts, 'icon': Icons.text_fields},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Onglets Posts / Publicités ──────────────────────────
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_showAds ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_view,
                            size: 16,
                            color: !_showAds ? colors.onPrimary : colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          t.otherUserTabPosts,
                          style: TextStyle(
                            color: !_showAds ? colors.onPrimary : colors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _showAds ? colors.warning : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign,
                            size: 16,
                            color: _showAds ? colors.onPrimary : colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          t.otherUserTabAds,
                          style: TextStyle(
                            color: _showAds ? colors.onPrimary : colors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Chips de filtre (uniquement onglet Posts) ───────────
        if (!_showAds) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _selectedFilter == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (_) => _applyFilter(filter['value'].toString()),
                    label: Text(
                      filter['label'].toString(),
                      style: TextStyle(
                        color: isSelected ? colors.onPrimary : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    avatar: Icon(
                      filter['icon'] as IconData,
                      color: isSelected ? colors.onPrimary : colors.primary,
                      size: 16,
                    ),
                    backgroundColor: colors.surfaceVariant,
                    selectedColor: colors.primary,
                    checkmarkColor: colors.onPrimary,
                    side: BorderSide(color: colors.primary),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostCard(Post post, double width) {
    final colors = AppColors.of(context);
    final isSelected = post.id != null && _selectedPostIds.contains(post.id);
    return GestureDetector(
      onLongPress: _canManagePosts && !_isSelectionMode
          ? () {
              setState(() {
                _isSelectionMode = true;
                if (post.id != null) _selectedPostIds.add(post.id!);
              });
            }
          : null,
      onTap: _isSelectionMode
          ? () {
              if (post.id != null) _togglePostSelection(post.id!);
            }
          : () => _navigateToPostDetails(post),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colors.surface,
          border: Border.all(
            color: isSelected ? colors.primary : colors.primary.withOpacity(0.3),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildPostContent(post),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colors.primary.withOpacity(0.2),
                  ),
                ),
              ),
            if (_isSelectionMode)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? colors.primary
                        : Colors.white.withOpacity(0.8),
                    border: Border.all(
                      color: isSelected ? colors.primary : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                      : null,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPostStat(Icons.favorite, post.loves ?? 0),
                    _buildPostStat(Icons.visibility, post.vues ?? 0),
                    _buildPostStat(Icons.comment, post.comments ?? 0),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getPostTypeIcon(post.dataType),
                        color: colors.primary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _getPostTypeLabel(post.dataType),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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



  Widget _buildAdCard(Post post, double width) {
    final colors = AppColors.of(context);
    final ad = (post.advertisementId != null && post.advertisementId!.isNotEmpty)
        ? _adsData[post.advertisementId]
        : null;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (ad?.status) {
      case 'active':
        statusColor = colors.primary;
        statusText = 'Active';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = colors.warning;
        statusText = 'Attente';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'expired':
        statusColor = colors.textSecondary;
        statusText = 'Expirée';
        statusIcon = Icons.timer_off;
        break;
      case 'rejected':
        statusColor = colors.danger;
        statusText = 'Rejetée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = colors.warning;
        statusText = 'PUB';
        statusIcon = Icons.campaign;
    }

    return GestureDetector(
      onTap: () => _navigateToPostDetails(post),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colors.surface,
          border: Border.all(
            color: ad?.status == 'active'
                ? colors.warning.withOpacity(0.6)
                : colors.border,
          ),
        ),
        child: Stack(
          children: [
            // Contenu post (image / vidéo / audio / texte)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(child: _buildPostContent(post)),
            ),

            // Bandeau bas : stats Advertisement
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xEE000000), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ligne stats si Advertisement chargé (clics réservés à l'admin)
                    if (ad != null) Builder(builder: (ctx) {
                      final isAdm = authProvider.loginUserData.role == 'ADM';
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAdStat(Icons.remove_red_eye,
                              _formatNumber(ad.views ?? 0), colors.info),
                          if (isAdm) ...[
                            _buildAdStat(Icons.ads_click,
                                _formatNumber(ad.clicks ?? 0), colors.warning),
                            _buildAdStat(
                                Icons.trending_up,
                                '${ad.ctr.toStringAsFixed(1)}%',
                                ad.ctr > 5 ? colors.primary : colors.warning),
                          ],
                        ],
                      );
                    }),
                    // Bouton d'action
                    if (ad != null &&
                        (ad.actionButtonText != null ||
                            ad.actionType != null)) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.warning.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(ad.getActionIcon(),
                                size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              ad.getActionButtonText(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Si pas encore chargé : icône like/vue/comment classiques
                    if (ad == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPostStat(Icons.favorite, post.loves ?? 0),
                          _buildPostStat(Icons.visibility, post.vues ?? 0),
                          _buildPostStat(Icons.comment, post.comments ?? 0),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Badge type contenu — haut gauche
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getPostTypeIcon(post.dataType),
                        color: colors.warning, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      _getPostTypeLabel(post.dataType),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Badge statut — haut droite
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      statusText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
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

  Widget _buildAdStat(IconData icon, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPostContent(Post post) {
    final colors = AppColors.of(context);
    if (post.dataType == PostDataType.VIDEO.name) {
      final thumb = post.thumbnail;
      if (thumb != null && thumb.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: colors.surfaceVariant),
                errorWidget: (_, __, ___) => Container(color: colors.surfaceVariant),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: colors.surfaceVariant,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ),
        ),
      );
    } else if (post.dataType == PostDataType.AUDIO.name) {
      // Priorité : thumbnail → première image → dégradé violet
      final coverUrl = (post.thumbnail != null && post.thumbnail!.isNotEmpty)
          ? post.thumbnail!
          : (post.images != null && post.images!.isNotEmpty)
              ? post.images!.first
              : null;

      if (coverUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: colors.surfaceVariant),
                errorWidget: (_, __, ___) =>
                    Container(color: colors.surfaceVariant),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headphones,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        );
      }
      // Pas de couverture → dégradé violet avec headphones centré
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A0080), Color(0xFF311B92)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headphones, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    post.description ?? 'Audio',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (post.dataType == PostDataType.IMAGE.name &&
        post.images != null &&
        post.images!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.images!.first,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: colors.surfaceVariant,
            child: Icon(Icons.photo, color: colors.primary),
          ),
          errorWidget: (context, url, error) => Container(
            color: colors.surfaceVariant,
            child: Icon(Icons.broken_image, color: colors.primary),
          ),
        ),
      );
    } else {
      return _buildTextPost(post);
    }
  }

  Widget _buildTextPost(Post post) {
    // Liste de dégradés prédéfinis (tu peux en rajouter d’autres)
    final gradients = [
      [Colors.purple, Colors.deepPurpleAccent],
      [Colors.blue, Colors.lightBlueAccent],
      [Colors.green, Colors.teal],
      [Colors.orange, Colors.deepOrangeAccent],
      [Colors.red, Colors.pinkAccent],
      [Colors.indigo, Colors.blueGrey],
    ];

    // On génère un index en fonction de l'id (pour que ce soit stable)
    int gradientIndex = 0;
    if (post.id != null) {
      gradientIndex = post.id.hashCode % gradients.length;
    } else {
      gradientIndex = Random().nextInt(gradients.length);
    }

    final chosenGradient = gradients[gradientIndex];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: chosenGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          post.description ?? 'Post texte',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          maxLines: 4, // limite comme un statut
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPostStat(IconData icon, int count) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.primary, size: 12),
        const SizedBox(width: 4),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
        ),
      ),
    );
  }

  IconData _getPostTypeIcon(String? dataType) {
    switch (dataType) {
      case 'VIDEO':
        return Icons.videocam;
      case 'IMAGE':
        return Icons.photo;
      case 'TEXT':
        return Icons.text_fields;
      case 'AUDIO':
        return Icons.headphones;
      default:
        return Icons.post_add;
    }
  }

  String _getPostTypeLabel(String? dataType) {
    switch (dataType) {
      case 'VIDEO':
        return 'VIDÉO';
      case 'IMAGE':
        return 'IMAGE';
      case 'TEXT':
        return 'TEXTE';
      case 'AUDIO':
        return 'AUDIO';
      default:
        return 'POST';
    }
  }

  String _getFilterLabel(String filter) {
    final t = AppLocalizations.of(context);
    switch (filter) {
      case 'IMAGE': return t.otherUserFilterImages;
      case 'VIDEO': return t.otherUserFilterVideos;
      case 'TEXT':  return t.otherUserFilterTexts;
      case 'AUDIO': return t.otherUserFilterAudios;
      default:      return t.otherUserFilterAll;
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toStringAsFixed(0);
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(1)}m';
    } else {
      return '${(number / 1000000000).toStringAsFixed(1)}b';
    }
  }
}
