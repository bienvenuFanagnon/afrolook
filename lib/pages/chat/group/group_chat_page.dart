import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/utils/country_list.dart';
import '../../../services/utils/group_permission_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../widgets/smart_video_player.dart';
import '../../../services/media_cache_service.dart';
import '../../../widgets/user_badge_widget.dart';
import '../../../theme/app_colors.dart';
import '../../component/showUserDetails.dart';
import '../../afroshop/marketPlace/acceuil/produit_details.dart';
import '../../contenuPayant/contentDetails.dart';
import '../../postDetails.dart';
import '../../post_video_format_tel_details.dart';
import '../../LiveAgora/livesAgora.dart';
import '../../LiveAgora/livePage.dart';
import '../../LiveAgora/live_ended_page.dart';
import 'group_info_page.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupImageUrl;

  const GroupChatPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
  }) : super(key: key);

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  late AppColors _colors;
  late UserAuthProvider _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _initialScrollDone = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMsgIds = {};
  bool _isFrozen = false;
  bool _isSending = false;
  bool _isPaymentProcessing = false;
  bool _isJoiningGroup = false;
  bool _isAppAdmin = false;
  bool _isBlocked = false;
  bool _showEmojiPicker = false;
  bool _showAttachMenu = false;
  bool _isMuted = false;
  bool _isReadOnly = false;
  bool _sendHidden = false;
  bool _showScrollBtn = false;
  bool _ownerIsGold = false;
  int _seenByPage = 10;
  String _myRole = 'member';
  Map<String, dynamic> _myPermissions = {};
  Map<String, dynamic> _groupData = {};
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;
  bool _permissionsLoaded = false;
  final Map<String, Map<String, dynamic>> _senderBadgeCache = {};

  // Reponse
  Map<String, dynamic>? _replyingToMsg;

  // Throttle anti-spam (500ms entre chaque message)
  int _lastSentAt = 0;
  static const int _throttleMs = 500;

  // ── Permissions calculées ─────────────────────────────────────────────────
  bool get _isAdminOrOwner => _myRole == 'owner' || _myRole == 'admin';

  // ADM de l'app : tous les droits sans restriction (même groupe bloqué/gelé)
  bool get _userCanWrite =>
      _isAppAdmin ||
      (!_isBlocked && !_isFrozen &&
          GroupPermissionUtils.canWrite(
            groupData: _groupData,
            userId: _auth.loginUserData.id ?? '',
            userRole: _myRole,
          ));

  bool get _userCanShare =>
      _isAppAdmin ||
      (!_isBlocked &&
          GroupPermissionUtils.canShare(
            groupData: _groupData,
            userId: _auth.loginUserData.id ?? '',
            userRole: _myRole,
          ));

  bool get _hiddenMsgsEnabled =>
      GroupPermissionUtils.hiddenMessagesEnabled(_groupData);

  bool get _canSendHidden =>
      _myRole == 'owner' && _hiddenMsgsEnabled && !_isFrozen;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _scrollController.addListener(_onScrollBtn);
    _loadGroup();
    _subscribeMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── CHARGEMENT ──────────────────────────────────────────────────────────────

  Future<void> _loadGroup() async {
    try {
      final myId = _auth.loginUserData.id!;
      final isAppAdmin = _auth.loginUserData.role == 'ADM';
      final groupDoc = await _firestore.collection('GroupChats').doc(widget.groupId).get();
      final data = groupDoc.data() ?? {};
      final userDoc = await _firestore.collection('Users').doc(myId).get();
      final mutedGroups = (userDoc.data()?['muted_groups'] as List<dynamic>? ?? []).cast<String>();
      final memberDoc = await _firestore
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('members')
          .doc(myId)
          .get();
      final role = memberDoc.data()?['role'] as String? ?? 'member';
      final perms = (memberDoc.data()?['permissions'] as Map<String, dynamic>?) ?? {};
      if (mounted) {
        setState(() {
          _groupData = data;
          _isFrozen = data['is_frozen'] == true;
          _isBlocked = data['is_blocked'] == true;
          _isReadOnly = data['is_read_only'] == true;
          _isMuted = mutedGroups.contains(widget.groupId);
          _isAppAdmin = isAppAdmin;
          _myRole = role;
          _myPermissions = perms;
          _permissionsLoaded = true;
        });
      }
      await _checkOwnerPremium(data);

      // Vérifier l'adhésion pour les groupes gratuits (sauf ADM)
      if (mounted && !isAppAdmin) {
        final ownerId = data['owner_id'] as String?;
        final isPrivate = data['is_private'] == true;
        final price = (data['subscription_price'] as num?)?.toDouble() ?? 0.0;
        if (myId != ownerId && !_isMember(myId)) {
          if (!isPrivate || price <= 0) {
            _showJoinGroupModal();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    final myId = _auth.loginUserData.id!;
    final newMuted = !_isMuted;
    try {
      await _firestore.collection('Users').doc(myId).update({
        'muted_groups': newMuted
            ? FieldValue.arrayUnion([widget.groupId])
            : FieldValue.arrayRemove([widget.groupId]),
      });
      if (mounted) setState(() => _isMuted = newMuted);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newMuted
            ? 'Notifications désactivées pour ce groupe'
            : 'Notifications réactivées'),
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {}
  }

  Future<void> _checkOwnerPremium(Map<String, dynamic> data) async {
    final ownerId = data['owner_id'] as String?;
    if (ownerId == null) return;
    try {
      final ownerDoc = await _firestore.collection('Users').doc(ownerId).get();
      final ownerData = ownerDoc.data() ?? {};
      final abonnementJson = ownerData['abonnement'] as Map<String, dynamic>?;

      bool isStillActive = false;
      bool ownerGold = ownerData['role'] == 'ADM'; // admin = Gold à vie
      if (abonnementJson != null) {
        final ab = AfrolookAbonnement.fromJson(abonnementJson);
        // Premium OU Gold permettent de garder un groupe actif
        isStillActive = ab.estPremium;
        if (ab.estGold) ownerGold = true;
      }
      if (mounted) setState(() => _ownerIsGold = ownerGold);

      final isFrozenNow = _groupData['is_frozen'] == true;
      if (!isStillActive && !isFrozenNow) {
        await _firestore.collection('GroupChats').doc(widget.groupId).update({'is_frozen': true});
        if (mounted) setState(() => _isFrozen = true);
      } else if (isStillActive && isFrozenNow) {
        await _firestore.collection('GroupChats').doc(widget.groupId).update({'is_frozen': false});
        if (mounted) setState(() => _isFrozen = false);
      }

      // Vérifier l'abonnement payant si groupe privé
      if (mounted) await _checkPaidSubscription(data);
    } catch (_) {}
  }

  /// Pour les groupes privés payants : vérifie si l'utilisateur est abonné.
  /// Si expiré ou absent → dialog de renouvellement (pas d'expulsion automatique).
  Future<void> _checkPaidSubscription(Map<String, dynamic> data) async {
    final isPrivate = data['is_private'] == true;
    if (!isPrivate) return;

    final myId = _auth.loginUserData.id!;
    final ownerId = data['owner_id'] as String?;
    if (ownerId == myId) return; // le propriétaire n'est jamais bloqué

    final price = (data['subscription_price'] as num?)?.toDouble() ?? 0.0;
    if (price <= 0) return; // groupe privé gratuit

    final paidSubs = (data['paid_subscribers'] as Map<String, dynamic>?) ?? {};
    final expiryMs = paidSubs[myId] as int?;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (expiryMs == null || expiryMs < now) {
      // Abonnement absent ou expiré — afficher dialog de renouvellement
      if (mounted) _showGroupSubscriptionDialog(data, price, expiryMs);
    }
  }

  // ── Raison de blocage en écriture ────────────────────────────────────────
  ({String title, String message, IconData icon, Color color}) _writeBlockReason() {
    final userId = _auth.loginUserData.id ?? '';

    if (_isFrozen) {
      return (
        title: 'Groupe suspendu',
        message: 'Ce groupe est temporairement gelé. Le propriétaire doit renouveler son abonnement Gold pour rouvrir les messages.',
        icon: Icons.pause_circle_outline_rounded,
        color: Colors.orange,
      );
    }
    if (_isReadOnly) {
      return (
        title: 'Mode lecture seule',
        message: 'L\'administrateur a activé le mode lecture seule. Seuls les admins et le propriétaire peuvent écrire dans ce groupe.',
        icon: Icons.edit_off_rounded,
        color: _colors.primary,
      );
    }
    // Vérifier si c'est une permission individuelle ou globale
    final allPerms = (_groupData['member_permissions'] as Map<String, dynamic>?) ?? {};
    final userPerms = allPerms[userId];
    if (userPerms is Map && userPerms['can_write'] == false) {
      return (
        title: 'Écriture bloquée',
        message: 'L\'administrateur vous a retiré le droit d\'écrire dans ce groupe. Contactez l\'administrateur pour en savoir plus.',
        icon: Icons.person_off_rounded,
        color: Colors.red,
      );
    }
    return (
      title: 'Écriture désactivée',
      message: 'L\'administrateur a désactivé l\'écriture pour tous les membres de ce groupe.',
      icon: Icons.block_rounded,
      color: Colors.red,
    );
  }

  // ── Raison de blocage en partage ──────────────────────────────────────────
  ({String title, String message, IconData icon, Color color}) _shareBlockReason() {
    final userId = _auth.loginUserData.id ?? '';

    if (_isFrozen) {
      return (
        title: 'Groupe suspendu',
        message: 'Ce groupe est temporairement gelé. Le partage de contenus est désactivé jusqu\'au renouvellement du propriétaire.',
        icon: Icons.pause_circle_outline_rounded,
        color: Colors.orange,
      );
    }
    final allPerms = (_groupData['member_permissions'] as Map<String, dynamic>?) ?? {};
    final userPerms = allPerms[userId];
    if (userPerms is Map && userPerms['can_share'] == false) {
      return (
        title: 'Partage bloqué',
        message: 'L\'administrateur vous a retiré le droit de partager des contenus dans ce groupe.',
        icon: Icons.person_off_rounded,
        color: Colors.red,
      );
    }
    return (
      title: 'Partage désactivé',
      message: 'L\'administrateur a désactivé le partage de contenus (posts, produits, lives) pour tous les membres de ce groupe.',
      icon: Icons.share_rounded,
      color: Colors.red,
    );
  }

  // ── Modal rejoindre un groupe gratuit ────────────────────────────────────
  void _showJoinGroupModal() {
    final groupName = _groupData['name'] as String? ?? widget.groupName;
    final imageUrl = _groupData['image_url'] as String? ?? widget.groupImageUrl;
    final memberCount = (_groupData['member_count'] as int?) ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _colors.primary.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: _colors.surfaceVariant,
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(imageUrl)
                      : null,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 32)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  groupName,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$memberCount membre${memberCount > 1 ? 's' : ''}',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vous n\'êtes pas encore membre de ce groupe. Rejoignez-le pour lire et envoyer des messages.',
                  style: TextStyle(
                    color: _colors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Retour',
                          style: TextStyle(
                              color: _colors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isJoiningGroup
                            ? null
                            : () async {
                                setDialogState(() => _isJoiningGroup = true);
                                await _joinGroup();
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isJoiningGroup
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Rejoindre',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinGroup() async {
    final myId = _auth.loginUserData.id!;
    try {
      await _firestore
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('members')
          .doc(myId)
          .set({
        'user_id': myId,
        'pseudo': _auth.loginUserData.pseudo ?? '',
        'image_url': _auth.loginUserData.imageUrl ?? '',
        'role': 'member',
        'joined_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _firestore.collection('GroupChats').doc(widget.groupId).update({
        'member_ids': FieldValue.arrayUnion([myId]),
        'member_count': FieldValue.increment(1),
      });
      // Mettre à jour l'état local pour éviter un rechargement complet
      if (mounted) {
        setState(() {
          _isJoiningGroup = false;
          _myRole = 'member';
          final ids = List<dynamic>.from(
              (_groupData['member_ids'] as List<dynamic>?) ?? []);
          if (!ids.contains(myId)) {
            ids.add(myId);
            _groupData['member_ids'] = ids;
          }
          _groupData['member_count'] =
              ((_groupData['member_count'] as int?) ?? 0) + 1;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isJoiningGroup = false);
    }
  }

  // ── Modal d'explication de restriction ───────────────────────────────────
  void _showRestrictionModal({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: _colors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: color.withOpacity(0.10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Compris',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareBlockedSnackbar() {
    final r = _shareBlockReason();
    _showRestrictionModal(title: r.title, message: r.message, icon: r.icon, color: r.color);
  }

  void _showGroupSubscriptionDialog(
    Map<String, dynamic> groupData,
    double price,
    int? previousExpiryMs,
  ) {
    final groupName = groupData['name'] as String? ?? widget.groupName;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFFFFD700)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                previousExpiryMs != null ? 'Renouveler l\'accès' : 'Groupe privé',
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              previousExpiryMs != null
                  ? 'Votre accès à "$groupName" a expiré.'
                  : 'L\'accès à "$groupName" est payant.',
              style: TextStyle(color: _colors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Prix : ${price.toStringAsFixed(0)} FCFA / mois',
              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Abonnez-vous pour accéder au groupe.',
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // quitter le groupe
            },
            child: Text('Quitter', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: _isPaymentProcessing ? null : () => _payGroupSubscription(groupData, price),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('S\'abonner', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _payGroupSubscription(Map<String, dynamic> groupData, double price) async {
    // Verrou anti-double-paiement
    if (_isPaymentProcessing) return;
    if (mounted) setState(() => _isPaymentProcessing = true);

    Navigator.pop(context); // fermer le dialog

    final myId = _auth.loginUserData.id!;
    final myUser = _auth.loginUserData;
    final solde = myUser.votre_solde_principal ?? 0.0;

    if (solde < price) {
      if (mounted) {
        setState(() => _isPaymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solde insuffisant. Manque ${(price - solde).toStringAsFixed(0)} FCFA'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final ownerId = groupData['owner_id'] as String?;
      final ownerShare = price * 0.70;
      final appShare = price * 0.30;
      final now = DateTime.now();
      final expiryMs = now.add(const Duration(days: 30)).millisecondsSinceEpoch;

      // Débiter l'utilisateur
      await _firestore.collection('Users').doc(myId).update({
        'votre_solde_principal': FieldValue.increment(-price),
      });

      // 70% au propriétaire du groupe
      if (ownerId != null) {
        await _firestore.collection('Users').doc(ownerId).update({
          'votre_solde_principal': FieldValue.increment(ownerShare),
        });
      }

      // 30% à l'app
      if (_auth.appDefaultData.id != null) {
        await _firestore.collection('AppData').doc(_auth.appDefaultData.id).update({
          'solde_gain': FieldValue.increment(appShare),
        });
      }

      // Mettre à jour paid_subscribers
      await _firestore.collection('GroupChats').doc(widget.groupId).update({
        'paid_subscribers.$myId': expiryMs,
      });

      // Ajouter comme membre si pas encore dans le groupe (cas arrivée via lien avant paiement)
      final memberIds = (_groupData['member_ids'] as List<dynamic>? ?? []).cast<String>();
      if (!memberIds.contains(myId)) {
        final myPseudo = _auth.loginUserData.pseudo ?? '';
        final myImageUrl = _auth.loginUserData.imageUrl ?? '';
        await _firestore.collection('GroupChats').doc(widget.groupId).collection('members').doc(myId).set({
          'user_id': myId,
          'pseudo': myPseudo,
          'image_url': myImageUrl,
          'role': 'member',
          'joined_at': now.millisecondsSinceEpoch,
        });
        await _firestore.collection('GroupChats').doc(widget.groupId).update({
          'member_ids': FieldValue.arrayUnion([myId]),
          'member_count': FieldValue.increment(1),
        });
      }

      // Transaction
      final ref = _firestore.collection('TransactionSoldes').doc();
      await ref.set({
        'id': ref.id,
        'user_id': myId,
        'type': 'DEPENSE',
        'statut': 'VALIDER',
        'description': 'Abonnement groupe "${groupData['name']}" - 1 mois',
        'montant': price,
        'montant_total': price,
        'methode_paiement': 'SOLDE',
        'sous_type': 'ABONNEMENT_GROUPE',
        'group_id': widget.groupId,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'reference': 'GRP_${now.millisecondsSinceEpoch}',
      });

      if (mounted) {
        setState(() => _isPaymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès accordé pour 30 jours !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaymentProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _subscribeMessages() {
    _firestore
        .collection('GroupMessages')
        .where('group_id', isEqualTo: widget.groupId)
        .orderBy('create_at_time_spam', descending: false)
        .limit(150)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        final myId = _auth.loginUserData.id ?? '';
        final msgs = snap.docs
            .map((d) => d.data())
            .where((d) => d['is_valide'] == true || d['is_deleted'] == true)
            // Filtrer les messages invisibles — visibles seulement par l'expéditeur
            .where((d) => GroupPermissionUtils.isMessageVisibleTo(d, myId))
            .toList();
        final isFirst = !_initialScrollDone;
        setState(() {
          _messages = msgs;
          _isLoadingMessages = false;
          _initialScrollDone = true;
        });
        if (isFirst) {
          _scrollToBottomInitial();
        } else {
          _scrollToBottomIfNearEnd();
        }
        _markMessagesRead();
        // Charger les badges des expéditeurs
        final senderIds = msgs
            .map((m) => m['send_by'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _loadBadgesFor(senderIds);
      }
    });
  }

  // Premier chargement : double postFrame pour attendre le layout complet
  void _scrollToBottomInitial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  // Nouveau message : scroll auto seulement si déjà en bas (< 150px de la fin)
  void _scrollToBottomIfNearEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final nearEnd = pos.maxScrollExtent - pos.pixels < 150;
      if (nearEnd) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onScrollBtn() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 200;
    if (atBottom == _showScrollBtn) {
      setState(() => _showScrollBtn = !atBottom);
    }
  }

  // Bouton AppBar : force le scroll en bas
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ─── ENVOI ───────────────────────────────────────────────────────────────────

  bool get _canSend {
    return DateTime.now().millisecondsSinceEpoch - _lastSentAt > _throttleMs;
  }

  bool _isMember(String myId) {
    final ids = (_groupData['member_ids'] as List<dynamic>? ?? []).cast<String>();
    return ids.contains(myId);
  }

  bool _hasPermission(String right) {
    if (_isAdminOrOwner) return true;
    return _myPermissions[right] == true;
  }

  Future<void> _showSenderProfile(String userId) async {
    if (userId.isEmpty) return;
    try {
      final doc = await _firestore.collection('Users').doc(userId).get();
      if (!doc.exists || !mounted) return;
      final user = UserData.fromJson(doc.data()!);
      final size = MediaQuery.of(context).size;
      showUserDetailsModalDialog(user, size.width, size.height, context);
    } catch (_) {}
  }

  void _loadBadgesFor(Set<String> userIds) {
    final toLoad = userIds.where((id) => !_senderBadgeCache.containsKey(id)).toList();
    if (toLoad.isEmpty) return;
    for (var i = 0; i < toLoad.length; i += 10) {
      final chunk = toLoad.sublist(i, i + 10 > toLoad.length ? toLoad.length : i + 10);
      _firestore
          .collection('Users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get()
          .then((snap) {
        if (!mounted) return;
        setState(() {
          for (final doc in snap.docs) {
            final d = doc.data();
            _senderBadgeCache[doc.id] = {
              'isVerify': d['isVerify'] == true,
              'officialBadge': d['officialBadge'] == true,
              'officialAccountType': d['officialAccountType'],
              'isPremium': d['abonnement']?['estPremium'] == true,
            };
          }
        });
      }).catchError((_) {});
    }
  }

  Widget _buildUserBadge(String userId) {
    final cache = _senderBadgeCache[userId];
    if (cache == null) return const SizedBox.shrink();
    return UserBadgeWidget(
      isVerified: cache['isVerify'] == true,
      officialBadge: cache['officialBadge'] == true,
      officialAccountType: cache['officialAccountType'] as String?,
      isPremiumOverride: cache['isPremium'] == true,
      size: 12,
    );
  }

  Future<void> _sendTextMessage() async {
    if (_isSending || !_canSend) return;
    if (!_userCanWrite) {
      final r = _writeBlockReason();
      _showRestrictionModal(title: r.title, message: r.message, icon: r.icon, color: r.color);
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myId = _auth.loginUserData.id!;
    if (!_isAppAdmin && !_isMember(myId)) return;

    setState(() => _isSending = true);
    _textController.clear();
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;

    final replySnapshot = _replyingToMsg;
    if (mounted) setState(() => _replyingToMsg = null);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = _firestore.collection('GroupMessages').doc().id;

      final msgData = <String, dynamic>{
        'id': msgId,
        'group_id': widget.groupId,
        'send_by': myId,
        'sender_pseudo': _auth.loginUserData.pseudo ?? '',
        'sender_image': _auth.loginUserData.imageUrl ?? '',
        'message': text,
        'message_type': 'text',
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'is_hidden': _sendHidden, // message invisible (Gold owner)
        'create_at_time_spam': now,
        'message_state': 'NONLU',
      };

      if (replySnapshot != null) {
        msgData['reply_to_id'] = replySnapshot['id'] ?? '';
        msgData['reply_to_message'] = replySnapshot['is_deleted'] == true
            ? 'Message supprime'
            : (replySnapshot['message'] as String? ?? '');
        msgData['reply_to_pseudo'] = replySnapshot['sender_pseudo'] ?? '';
        msgData['reply_to_type'] = replySnapshot['message_type'] ?? 'text';
      }

      await _firestore.collection('GroupMessages').doc(msgId).set(msgData);

      // Message visible dans le chat — libérer l'UI immédiatement
      if (mounted) setState(() => _isSending = false);

      // Mises à jour en arrière-plan (non bloquantes pour l'UI)
      final otherMembers = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id.isNotEmpty && id != myId)
          .toList();

      _firestore.collection('GroupChats').doc(widget.groupId).update({
        'last_message': text,
        'last_message_at': now,
        'updated_at': now,
      }).catchError((e) => debugPrint('[GroupChatPage] last_message update failed: $e'));

      _updateUnreadCounts(otherMembers);

    } catch (e) {
      debugPrint('[GroupChatPage] _sendTextMessage error: $e');
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImageMessage() async {
    if (!_canSend) return;
    if (!_userCanWrite) {
      final r = _writeBlockReason();
      _showRestrictionModal(title: r.title, message: r.message, icon: r.icon, color: r.color);
      return;
    }
    final myId = _auth.loginUserData.id!;
    if (!_isAppAdmin && !_isMember(myId)) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isSending = true);
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final bytes = await picked.readAsBytes();
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = _firestore.collection('GroupMessages').doc().id;

      final ref = FirebaseStorage.instance
          .ref()
          .child('group_images/${widget.groupId}/$msgId.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await _firestore.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': widget.groupId,
        'send_by': myId,
        'sender_pseudo': _auth.loginUserData.pseudo ?? '',
        'sender_image': _auth.loginUserData.imageUrl ?? '',
        'message': url,
        'message_type': 'image',
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'NONLU',
      });

      // Photo visible — libérer l'UI immédiatement
      if (mounted) setState(() => _isSending = false);

      final otherMembersImg = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id.isNotEmpty && id != myId)
          .toList();

      _firestore.collection('GroupChats').doc(widget.groupId).update({
        'last_message': 'Photo',
        'last_message_at': now,
        'updated_at': now,
      }).catchError((e) => debugPrint('[GroupChatPage] last_message (image) failed: $e'));

      _updateUnreadCounts(otherMembersImg);

    } catch (e) {
      debugPrint('[GroupChatPage] _sendImageMessage error: $e');
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMultiImageMessage() async {
    if (!_canSend) return;
    if (!_userCanWrite) {
      final r = _writeBlockReason();
      _showRestrictionModal(title: r.title, message: r.message, icon: r.icon, color: r.color);
      return;
    }
    final myId = _auth.loginUserData.id!;
    if (!_isAppAdmin && !_isMember(myId)) return;

    if (!_ownerIsGold) {
      _showRestrictionModal(
        title: 'Fonctionnalité Gold',
        message: 'L\'envoi de plusieurs images est réservé aux groupes dont le propriétaire a le plan Gold.',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFFFD700),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 75, limit: 5);
    if (pickedList.isEmpty) return;
    final limited = pickedList.take(5).toList();

    setState(() => _isSending = true);
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = _firestore.collection('GroupMessages').doc().id;

      // Upload en parallèle
      final urls = await Future.wait(
        limited.asMap().entries.map((e) async {
          final bytes = await e.value.readAsBytes();
          final ref = FirebaseStorage.instance
              .ref()
              .child('group_images/${widget.groupId}/${msgId}_${e.key}.jpg');
          await ref.putData(bytes);
          return await ref.getDownloadURL();
        }),
      );

      await _firestore.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': widget.groupId,
        'send_by': myId,
        'sender_pseudo': _auth.loginUserData.pseudo ?? '',
        'sender_image': _auth.loginUserData.imageUrl ?? '',
        'message': urls.first,
        'image_urls': urls,
        'message_type': 'multi_image',
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'NONLU',
      });

      if (mounted) setState(() => _isSending = false);

      final otherMembers = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id.isNotEmpty && id != myId)
          .toList();

      _firestore.collection('GroupChats').doc(widget.groupId).update({
        'last_message': '📷 ${urls.length} photo(s)',
        'last_message_at': now,
        'updated_at': now,
      }).catchError((e) => debugPrint('[GroupChatPage] last_message (multi_image) update failed: $e'));

      _updateUnreadCounts(otherMembers);
    } catch (e) {
      debugPrint('[GroupChatPage] _sendMultiImageMessage error: $e');
      if (mounted) setState(() => _isSending = false);
    }
  }

  static const int _maxVideoBytes = 30 * 1024 * 1024;       // 30 Mo par vidéo
  static const int _maxDailyVideoBytes = 150 * 1024 * 1024; // 150 Mo par jour

  Future<void> _sendVideoMessage() async {
    if (!_canSend) return;
    if (!_userCanWrite) {
      final r = _writeBlockReason();
      _showRestrictionModal(title: r.title, message: r.message, icon: r.icon, color: r.color);
      return;
    }
    final myId = _auth.loginUserData.id!;
    if (!_isAppAdmin && !_isMember(myId)) return;

    // ── Vérification Gold du propriétaire ───────────────────────────────────
    if (!_ownerIsGold) {
      _showRestrictionModal(
        title: 'Fonctionnalité Gold',
        message: 'L\'envoi de vidéos est réservé aux groupes dont le propriétaire a le plan Gold.',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFFFD700),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final sizeBytes = bytes.length;

    // ── Vérification taille unitaire (30 Mo) ───────────────────────────────
    if (sizeBytes > _maxVideoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vidéo trop lourde — maximum 30 Mo par vidéo'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // ── Vérification quota journalier (150 Mo) ─────────────────────────────
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final rawStats = _groupData['video_daily_stats'] as Map<String, dynamic>?;
    final statsDate = rawStats?['date'] as String? ?? '';
    final usedBytes =
        statsDate == todayStr ? (rawStats?['bytes'] as int? ?? 0) : 0;

    if (usedBytes + sizeBytes > _maxDailyVideoBytes) {
      final usedMo = (usedBytes / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) {
        _showRestrictionModal(
          title: 'Limite journalière atteinte',
          message:
              'Ce groupe a atteint sa limite de 150 Mo de vidéos pour aujourd\'hui.\n'
              'Déjà utilisé : $usedMo Mo / 150 Mo.\n'
              'Revenez demain pour envoyer de nouvelles vidéos.',
          icon: Icons.data_usage_rounded,
          color: Colors.orange,
        );
      }
      return;
    }

    setState(() => _isSending = true);
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = _firestore.collection('GroupMessages').doc().id;

      final ref = FirebaseStorage.instance
          .ref()
          .child('group_videos/${widget.groupId}/$msgId.mp4');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await _firestore.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': widget.groupId,
        'send_by': myId,
        'sender_pseudo': _auth.loginUserData.pseudo ?? '',
        'sender_image': _auth.loginUserData.imageUrl ?? '',
        'message': url,
        'message_type': 'video',
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'NONLU',
      });

      if (mounted) setState(() => _isSending = false);

      final otherMembers = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id.isNotEmpty && id != myId)
          .toList();

      _firestore.collection('GroupChats').doc(widget.groupId).update({
        'last_message': 'Vidéo',
        'last_message_at': now,
        'updated_at': now,
        'video_daily_stats': {
          'date': todayStr,
          'bytes': usedBytes + sizeBytes,
        },
      }).then((_) {
        if (mounted) {
          setState(() {
            _groupData['video_daily_stats'] = {
              'date': todayStr,
              'bytes': usedBytes + sizeBytes,
            };
          });
        }
      }).catchError((e) => debugPrint('[GroupChatPage] last_message (video) update failed: $e'));

      _updateUnreadCounts(otherMembers);
    } catch (e) {
      debugPrint('[GroupChatPage] _sendVideoMessage error: $e');
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final confirmed = await _showConfirmDialog(
      'Supprimer ce message',
      'Ce message sera marque comme supprime pour tous les membres.',
    );
    if (!confirmed) return;

    try {
      await _firestore.collection('GroupMessages').doc(msg['id']).update({
        'is_valide': true,
        'is_deleted': true,
        'message': 'Message supprime',
      });

      // Mettre a jour last_message si c'est le dernier
      final lastMsg = _groupData['last_message'] as String?;
      if (lastMsg == msg['message']) {
        await _firestore.collection('GroupChats').doc(widget.groupId).update({
          'last_message': 'Message supprime',
        });
      }
    } catch (_) {}
  }

  void _toggleMessageSelection(String msgId) {
    if (msgId.isEmpty) return;
    setState(() {
      if (_selectedMsgIds.contains(msgId)) {
        _selectedMsgIds.remove(msgId);
        if (_selectedMsgIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMsgIds.add(msgId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMsgIds.clear();
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMsgIds.isEmpty) return;
    final count = _selectedMsgIds.length;
    final confirmed = await _showConfirmDialog(
      'Suppression définitive',
      'Supprimer définitivement $count message${count > 1 ? 's' : ''} ?\nAucune trace pour les membres.',
    );
    if (!confirmed) return;

    try {
      final ids = List<String>.from(_selectedMsgIds);
      // Firestore batch : max 500 ops, on découpe si besoin
      for (int i = 0; i < ids.length; i += 400) {
        final chunk = ids.sublist(i, (i + 400).clamp(0, ids.length));
        final batch = _firestore.batch();
        for (final id in chunk) {
          batch.delete(_firestore.collection('GroupMessages').doc(id));
        }
        await batch.commit();
      }
      _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _permanentDeleteMessage(Map<String, dynamic> msg) async {
    final confirmed = await _showConfirmDialog(
      'Suppression définitive',
      'Ce message sera effacé définitivement pour tous les membres, sans aucune trace.',
    );
    if (!confirmed) return;

    final msgId = msg['id'] as String?;
    if (msgId == null) return;

    try {
      await _firestore.collection('GroupMessages').doc(msgId).delete();

      // Mettre à jour last_message si c'était le dernier
      final lastMsg = _groupData['last_message'] as String?;
      if (lastMsg == msg['message']) {
        await _firestore.collection('GroupChats').doc(widget.groupId).update({
          'last_message': '',
        });
      }
    } catch (_) {}
  }

  // ─── UNREAD COUNTS (chunked pour groupes avec 500+ membres) ──────────────────

  void _updateUnreadCounts(List<String> memberIds) {
    if (memberIds.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(i, min(i + chunkSize, memberIds.length));
      final unreadUpdate = <String, dynamic>{};
      for (final id in chunk) {
        unreadUpdate['unread_counts.$id'] = FieldValue.increment(1);
      }
      _firestore.collection('GroupChats').doc(widget.groupId).update(unreadUpdate)
          .catchError((e) => debugPrint('[GroupChatPage] unread_counts update failed: $e | chunk[$i..${i + chunk.length - 1}]'));
    }
  }

  Future<void> _markMessagesRead() async {
    final myId = _auth.loginUserData.id!;
    // Ne pas créer de faux receipts pour les admins non-membres
    if (_isAppAdmin && !_isMember(myId)) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await Future.wait([
        _firestore
            .collection('GroupChats')
            .doc(widget.groupId)
            .collection('reads')
            .doc(myId)
            .set({
          'user_id': myId,
          'pseudo': _auth.loginUserData.pseudo ?? '',
          'image_url': _auth.loginUserData.imageUrl ?? '',
          'last_read_at': now,
        }),
        _firestore
            .collection('GroupChats')
            .doc(widget.groupId)
            .update({'unread_counts.$myId': 0}),
      ]);
    } catch (_) {}
  }

  Future<void> _showMessageReaders(Map<String, dynamic> msg) async {
    if (!_ownerIsGold && !_isAppAdmin) {
      _showRestrictionModal(
        title: 'Fonctionnalité Gold',
        message: 'La liste des membres ayant lu un message est réservée aux groupes Gold.',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFFFD700),
      );
      return;
    }

    final msgTime = msg['create_at_time_spam'] as int? ?? 0;
    final myId = _auth.loginUserData.id!;

    try {
      final snap = await _firestore
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('reads')
          .get();

      final allReaders = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String? ?? '';
        if (userId == myId) continue;
        final lastRead = data['last_read_at'] as int? ?? 0;
        if (lastRead >= msgTime) {
          allReaders.add(data);
        }
      }

      if (!mounted) return;
      setState(() => _seenByPage = 10);

      showResponsiveBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final visible = allReaders.take(_seenByPage).toList();
            final hasMore = allReaders.length > _seenByPage;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: _colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colors.border.withOpacity(0.3)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: _colors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_rounded, color: _colors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            allReaders.isEmpty
                                ? 'Personne n\'a encore lu ce message'
                                : 'Vu par ${allReaders.length} membre${allReaders.length > 1 ? 's' : ''}',
                            style: TextStyle(
                                color: _colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    if (allReaders.isNotEmpty)
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          children: [
                            ...visible.map((u) {
                              final pseudo = u['pseudo'] as String? ?? '';
                              final img = u['image_url'] as String? ?? '';
                              final readAt = u['last_read_at'] as int? ?? 0;
                              final timeStr = readAt > 0
                                  ? () {
                                      final d = DateTime.fromMillisecondsSinceEpoch(readAt);
                                      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                                    }()
                                  : '';
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _colors.surfaceVariant,
                                  backgroundImage:
                                      img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                                  child: img.isEmpty
                                      ? Icon(Icons.person, size: 16, color: _colors.textSecondary)
                                      : null,
                                ),
                                title: Text('@$pseudo',
                                    style: TextStyle(
                                        color: _colors.textPrimary, fontSize: 14)),
                                trailing: timeStr.isNotEmpty
                                    ? Text(timeStr,
                                        style: TextStyle(
                                            color: _colors.textSecondary, fontSize: 12))
                                    : null,
                              );
                            }),
                            if (hasMore)
                              TextButton(
                                onPressed: () {
                                  setState(() => _seenByPage += 10);
                                  setSheetState(() {});
                                },
                                child: Text(
                                  'Voir plus (${allReaders.length - _seenByPage} restants)',
                                  style: TextStyle(color: _colors.primary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (_) {}
  }

  Future<void> _toggleGroupBlock() async {
    final action = _isBlocked ? 'Débloquer' : 'Bloquer';
    final desc = _isBlocked
        ? 'Les membres pourront à nouveau envoyer des messages.'
        : 'Plus aucun membre ne pourra envoyer de messages dans ce groupe.';
    final confirm = await _showConfirmDialog('$action le groupe', desc);
    if (!confirm) return;
    try {
      final newBlocked = !_isBlocked;
      await _firestore
          .collection('GroupChats')
          .doc(widget.groupId)
          .update({'is_blocked': newBlocked});
      if (mounted) setState(() => _isBlocked = newBlocked);
    } catch (_) {}
  }

  // ─── UI HELPERS ──────────────────────────────────────────────────────────────

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700)),
            content: Text(message, style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    final isDeleted = msg['is_deleted'] == true;
    final canDelete = isMe || _hasPermission('can_delete_others');
    final msgId = msg['id'] as String? ?? '';
    final myId = _auth.loginUserData.id ?? '';
    final sendBy = msg['send_by'] as String? ?? '';
    final isSender = sendBy == myId;
    final isOwner = _myRole == 'owner';
    final canManageVisibility = isSender || (isOwner && _hiddenMsgsEnabled);
    final isHidden = msg['is_hidden'] == true;
    final visibleTo = (msg['visible_to'] as List<dynamic>?)?.cast<String>();
    final hasVisibleTo = visibleTo != null && visibleTo.isNotEmpty;
    final isRestricted = isHidden || hasVisibleTo;

    HapticFeedback.mediumImpact();

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _colors.border.withOpacity(0.3)),
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
              ),
              if (!isDeleted) ...[
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: _colors.primary),
                  title: Text('Repondre', style: TextStyle(color: _colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _replyingToMsg = msg);
                    _focusNode.requestFocus();
                    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: _colors.textSecondary),
                  title: Text('Copier', style: TextStyle(color: _colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final text = msg['message'] as String? ?? '';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Message copie'),
                        backgroundColor: _colors.primary,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),

                // ── Gestion de la visibilité ──────────────────────────────
                if (canManageVisibility) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Masquer / Rendre visible à tous
                  ListTile(
                    leading: Icon(
                      isRestricted ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.purple,
                    ),
                    title: Text(
                      isRestricted ? 'Rendre visible à tous' : 'Masquer le message',
                      style: const TextStyle(color: Colors.purple),
                    ),
                    subtitle: isRestricted
                        ? const Text('Tous les membres pourront le voir', style: TextStyle(fontSize: 12))
                        : const Text('Visible seulement par vous', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleMessageHidden(msg, makeVisible: isRestricted);
                    },
                  ),

                  // Choisir les destinataires (Gold — allow_hidden_msgs)
                  if (_hiddenMsgsEnabled)
                    ListTile(
                      leading: const Icon(Icons.group_rounded, color: Colors.purple),
                      title: const Text('Choisir qui peut voir', style: TextStyle(color: Colors.purple)),
                      subtitle: hasVisibleTo
                          ? Text('${visibleTo!.length} membre${visibleTo.length > 1 ? 's' : ''} sélectionné${visibleTo.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12))
                          : const Text('Restreindre à certains membres', style: TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showVisibilityPickerDialog(msg);
                      },
                    ),
                ],
              ],
              // ── Ciblage par pays (groupes officiels, admin/owner) ──────────
              if (_isAdminOrOwner && _groupData['is_official'] == true && !isDeleted) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.public_rounded, color: Color(0xFF185FA5)),
                  title: const Text('Cibler par pays', style: TextStyle(color: Color(0xFF185FA5))),
                  subtitle: Builder(builder: (_) {
                    final vc = (msg['visible_countries'] as List<dynamic>?)?.cast<String>();
                    if (vc == null || vc.isEmpty || vc.contains('ALL')) {
                      return const Text('Visible dans tous les pays', style: TextStyle(fontSize: 12));
                    }
                    return Text('${vc.length} pays ciblé${vc.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12));
                  }),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCountryTargetingSheet(msg);
                  },
                ),
              ],

              if (!isDeleted && (_isAdminOrOwner || _isAppAdmin)) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                Builder(builder: (_) {
                  final canSee = _ownerIsGold || _isAppAdmin;
                  return ListTile(
                    leading: canSee
                        ? Icon(Icons.visibility_rounded, color: _colors.primary)
                        : const Icon(Icons.lock_rounded, color: Colors.amber),
                    title: Text('Vu par',
                        style: TextStyle(
                          color: canSee ? _colors.textPrimary : _colors.textSecondary,
                        )),
                    subtitle: canSee
                        ? null
                        : const Text(
                            'Réservé aux groupes Gold ou aux admins de l\'app',
                            style: TextStyle(fontSize: 11, color: Colors.amber),
                          ),
                    trailing: canSee
                        ? null
                        : const Icon(Icons.workspace_premium_rounded,
                            color: Colors.amber, size: 18),
                    onTap: canSee
                        ? () {
                            Navigator.pop(ctx);
                            _showMessageReaders(msg);
                          }
                        : null,
                  );
                }),
              ],
              if (canDelete && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg);
                  },
                ),
              if (_isAppAdmin) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.checklist_rounded, color: _colors.primary),
                  title: Text('Sélection multiple', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sélectionner plusieurs messages à supprimer', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isSelectionMode = true;
                      if (msgId.isNotEmpty) _selectedMsgIds.add(msgId);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Supprimer définitivement', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Aucune trace — admin seulement', style: TextStyle(fontSize: 11, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _permanentDeleteMessage(msg);
                  },
                ),
              ],
              const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMessageHidden(Map<String, dynamic> msg, {required bool makeVisible}) async {
    final msgId = msg['id'] as String?;
    if (msgId == null) return;
    try {
      if (makeVisible) {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'is_hidden': false,
          'visible_to': FieldValue.delete(),
        });
      } else {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'is_hidden': true,
          'visible_to': FieldValue.delete(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showVisibilityPickerDialog(Map<String, dynamic> msg) {
    final msgId = msg['id'] as String?;
    if (msgId == null) return;

    final sendBy = msg['send_by'] as String? ?? '';
    final currentVisibleTo = ((msg['visible_to'] as List<dynamic>?)?.cast<String>() ?? []).toSet();
    final selected = <String>{...currentVisibleTo};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Choisir les destinataires', style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Visible par l\'expéditeur et les membres cochés.',
                style: TextStyle(color: _colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          content: FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('GroupChats')
                .doc(widget.groupId)
                .collection('members')
                .get(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final members = (snap.data?.docs ?? [])
                  .map((d) => d.data() as Map<String, dynamic>)
                  .where((m) => (m['user_id'] as String? ?? '') != sendBy)
                  .toList();

              if (members.isEmpty) {
                return Text('Aucun autre membre dans ce groupe.', style: TextStyle(color: _colors.textSecondary));
              }

              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final uid = m['user_id'] as String? ?? '';
                    final pseudo = m['pseudo'] as String? ?? uid;
                    final imageUrl = m['image_url'] as String? ?? '';
                    final isSelected = selected.contains(uid);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.purple,
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) selected.add(uid);
                          else selected.remove(uid);
                        });
                      },
                      title: Text(pseudo, style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
                      secondary: CircleAvatar(
                        radius: 16,
                        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        backgroundColor: _colors.surfaceVariant,
                        child: imageUrl.isEmpty ? Icon(Icons.person, size: 16, color: _colors.textSecondary) : null,
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
            ),
            if (currentVisibleTo.isNotEmpty)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _setMessageVisibleTo(msgId, []);
                },
                child: const Text('Visible pour tous', style: TextStyle(color: Colors.orange)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _setMessageVisibleTo(msgId, selected.toList());
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMessageVisibleTo(String msgId, List<String> visibleTo) async {
    try {
      if (visibleTo.isEmpty) {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'visible_to': FieldValue.delete(),
          'is_hidden': false,
        });
      } else {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'visible_to': visibleTo,
          'is_hidden': false,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Ciblage par pays ──────────────────────────────────────────────────────

  void _showCountryTargetingSheet(Map<String, dynamic> msg) {
    final msgId = msg['id'] as String?;
    if (msgId == null) return;

    final current = ((msg['visible_countries'] as List<dynamic>?)?.cast<String>() ?? []).toSet();
    // Si 'ALL' est dans la liste, on considère qu'il n'y a pas de ciblage
    final initialSelected = current.contains('ALL') ? <String>{} : Set<String>.from(current);
    final selected = <String>{...initialSelected};
    final searchCtrl = TextEditingController();
    final countries = kCountries.where((c) => c['code'] != 'ALL').toList();

    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? countries
              : countries
                  .where((c) =>
                      (c['name']!).toLowerCase().contains(query) ||
                      (c['code']!).toLowerCase().contains(query))
                  .toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            decoration: BoxDecoration(
              color: _colors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _colors.border, borderRadius: BorderRadius.circular(2)),
                ),

                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded, color: Color(0xFF185FA5), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cibler par pays',
                          style: TextStyle(
                              color: _colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ),
                      if (selected.isNotEmpty)
                        Chip(
                          label: Text('${selected.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: const Color(0xFF185FA5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Option "Tous les pays"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: InkWell(
                    onTap: () {
                      setModal(() => selected.clear());
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected.isEmpty
                            ? const Color(0xFF185FA5).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected.isEmpty
                              ? const Color(0xFF185FA5).withOpacity(0.4)
                              : _colors.border.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🌍', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tous les pays',
                              style: TextStyle(
                                color: selected.isEmpty
                                    ? const Color(0xFF185FA5)
                                    : _colors.textPrimary,
                                fontWeight: selected.isEmpty
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selected.isEmpty)
                            const Icon(Icons.check_rounded,
                                color: Color(0xFF185FA5), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (v) => setModal(() {}),
                    style: TextStyle(color: _colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un pays...',
                      hintStyle: TextStyle(color: _colors.textSecondary.withOpacity(0.6), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: _colors.textSecondary, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _colors.border.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _colors.border.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _colors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Liste des pays
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final code = c['code']!;
                      final name = c['name']!;
                      final flag = c['flag']!;
                      final isSelected = selected.contains(code);
                      return InkWell(
                        onTap: () => setModal(() {
                          if (isSelected) {
                            selected.remove(code);
                          } else {
                            selected.add(code);
                          }
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        color: _colors.textPrimary,
                                        fontSize: 14)),
                              ),
                              if (isSelected)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF185FA5),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 13),
                                )
                              else
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _colors.border.withOpacity(0.4))),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Boutons
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _colors.textSecondary,
                            side: BorderSide(color: _colors.border.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final countries = selected.isEmpty
                                ? ['ALL']
                                : selected.toList();
                            await _setMessageVisibleCountries(msgId, countries);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185FA5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            selected.isEmpty ? 'Tous les pays' : 'Confirmer (${selected.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setMessageVisibleCountries(String msgId, List<String> countries) async {
    try {
      if (countries.isEmpty || countries.contains('ALL')) {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'visible_countries': FieldValue.delete(),
        });
      } else {
        await _firestore.collection('GroupMessages').doc(msgId).update({
          'visible_countries': countries,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(int tsMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final myId = _auth.loginUserData.id!;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) _exitSelectionMode();
      },
      child: Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: Column(
        children: [
          if (_permissionsLoaded) ...[
            if (_isBlocked) _buildBlockedBanner(),
            if (!_isBlocked && _isFrozen) _buildFrozenBanner(),
            if (!_isBlocked && !_isFrozen && _isReadOnly) _buildReadOnlyBanner(),
            if (!_isBlocked && !_isFrozen && !_isReadOnly && !_userCanWrite && !_isAppAdmin)
              _buildNoWritePermissionBanner(),
            if (_isAppAdmin) _buildAdminBanner(),
          ],
          Expanded(
            child: Stack(
              children: [
                _isLoadingMessages
                    ? Center(child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2))
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (_, index) {
                              final msg = _messages[index];
                              final isMe = msg['send_by'] == myId;
                              return _buildMessageBubble(msg, isMe);
                            },
                          ),
                if (_showScrollBtn)
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_permissionsLoaded) ...[
            if (_userCanWrite) _buildInputBar(),
            if (!_userCanWrite) _buildBlockedInputPlaceholder(),
          ],
        ],
        ),
      ),
      ),  // Scaffold
    );    // PopScope
  }

  // ─── APPBAR ──────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    // ── Mode sélection multiple (admin) ──────────────────────────────────────
    if (_isSelectionMode && _isAppAdmin) {
      final count = _selectedMsgIds.length;
      return AppBar(
        backgroundColor: _colors.primary.withOpacity(0.12),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _colors.textPrimary),
          onPressed: _exitSelectionMode,
          tooltip: 'Annuler la sélection',
        ),
        title: Text(
          count == 0
              ? 'Sélectionner des messages'
              : '$count message${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          if (count > 0)
            IconButton(
              tooltip: 'Supprimer définitivement',
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 26),
              onPressed: _deleteSelectedMessages,
            ),
          const SizedBox(width: 4),
        ],
      );
    }

    final imageUrl = _groupData['image_url'] as String? ?? widget.groupImageUrl;
    final memberCount = _groupData['member_count'] as int?;
    final isOfficial = _groupData['is_official'] == true;

    return AppBar(
      backgroundColor: _colors.background,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.primary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupInfoPage(groupId: widget.groupId, groupName: widget.groupName),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _colors.surfaceVariant,
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(imageUrl)
                      : null,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 18)
                      : null,
                ),
                if (_isFrozen)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _groupData['name'] as String? ?? widget.groupName,
                          style: TextStyle(
                              color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOfficial) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
                      ],
                    ],
                  ),
                  Text(
                    memberCount != null ? '$memberCount membres' : 'Groupe',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isAppAdmin)
          IconButton(
            tooltip: _isBlocked ? 'Débloquer le groupe' : 'Bloquer le groupe',
            icon: Icon(
              _isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
              color: _isBlocked ? Colors.green : Colors.red,
              size: 22,
            ),
            onPressed: _toggleGroupBlock,
          ),
        if (!_isAppAdmin)
          IconButton(
            tooltip: _isMuted ? 'Réactiver les notifications' : 'Désactiver les notifications',
            icon: Icon(
              _isMuted ? Icons.notifications_off_outlined : Icons.notifications_none_rounded,
              color: _isMuted ? _colors.textSecondary : _colors.primary,
              size: 22,
            ),
            onPressed: _toggleMute,
          ),
        IconButton(
          icon: Icon(Icons.info_outline_rounded, color: _colors.primary, size: 22),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupInfoPage(groupId: widget.groupId, groupName: widget.groupName),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: _colors.border.withOpacity(0.3)),
      ),
    );
  }

  // ─── BANNIERES ───────────────────────────────────────────────────────────────

  Widget _buildFrozenBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withOpacity(0.12),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Groupe gelé — le propriétaire n\'est plus Gold. Lecture seule pour tous.',
              style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _colors.textSecondary.withOpacity(0.06),
      child: Row(
        children: [
          Icon(Icons.edit_off_rounded, color: _colors.textSecondary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lecture seule — seuls les admins peuvent écrire',
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWritePermissionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _colors.textSecondary.withOpacity(0.06),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: _colors.textSecondary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Écriture désactivée par le propriétaire du groupe',
              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.deepPurple.withOpacity(0.10),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Mode administrateur Afrolook — lecture seule',
              style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: Colors.red, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Groupe bloqué par l\'administration — aucun message ne peut être envoyé.',
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedInputPlaceholder() {
    if (_isAppAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _colors.surface,
          border: Border(top: BorderSide(color: _colors.border.withOpacity(0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple, size: 15),
            const SizedBox(width: 8),
            const Text(
              'Mode administrateur — lecture seule',
              style: TextStyle(color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _colors.surface,
          border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 15),
            SizedBox(width: 8),
            Text(
              'Groupe bloqué par l\'administration',
              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final String reason;

    if (_isFrozen) {
      reason = 'Groupe gelé — propriétaire plus Gold';
    } else if (_isReadOnly && !_isAdminOrOwner) {
      reason = 'Groupe en lecture seule';
    } else {
      reason = 'Écriture non autorisée dans ce groupe';
    }

    final r = _writeBlockReason();
    final displayColor = _isFrozen ? Colors.orange : _colors.textSecondary;
    return GestureDetector(
      onTap: () => _showRestrictionModal(
        title: r.title,
        message: r.message,
        icon: r.icon,
        color: r.color,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _colors.surface,
          border: Border(top: BorderSide(color: _colors.border.withOpacity(0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(r.icon, color: displayColor, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(reason, style: TextStyle(color: displayColor, fontSize: 12)),
            ),
            Icon(Icons.info_outline_rounded, color: displayColor.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _colors.surfaceVariant, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 32, color: _colors.textSecondary),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucun message',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Soyez le premier a ecrire !',
            style: TextStyle(color: _colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── BULLE MESSAGE ───────────────────────────────────────────────────────────

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final isSystem = msg['send_by'] == 'system';
    final isDeleted = msg['is_deleted'] == true;

    if (isSystem) return _buildSystemMessage(msg);

    // ── Filtrage ciblage pays ─────────────────────────────────────────────────
    // Applicable uniquement dans les groupes officiels, pour les membres (non admin)
    if (!isDeleted && _groupData['is_official'] == true && !_isAdminOrOwner) {
      final vc = (msg['visible_countries'] as List<dynamic>?)?.cast<String>();
      if (vc != null && vc.isNotEmpty && !vc.contains('ALL')) {
        final myCountry = (_auth.loginUserData.countryData as Map<String, dynamic>?)?['countryCode'] as String?;
        if (myCountry == null || !vc.contains(myCountry)) {
          return const SizedBox.shrink();
        }
      }
    }

    final visibleCountries = !isDeleted && _groupData['is_official'] == true && _isAdminOrOwner
        ? (msg['visible_countries'] as List<dynamic>?)?.cast<String>()
        : null;
    final hasCountryTarget = visibleCountries != null &&
        visibleCountries.isNotEmpty &&
        !visibleCountries.contains('ALL');

    final text = isDeleted ? 'Message supprime' : (msg['message'] as String? ?? '');
    final type = isDeleted ? 'text' : (msg['message_type'] as String? ?? 'text');
    final pseudo = msg['sender_pseudo'] as String? ?? '';
    final senderImage = msg['sender_image'] as String? ?? '';
    final ts = msg['create_at_time_spam'] as int? ?? 0;
    final timeStr = _formatTime(ts);
    final isRestricted = !isDeleted && GroupPermissionUtils.isMessageRestricted(msg);
    final hasVisibleTo = !isDeleted && (msg['visible_to'] as List<dynamic>?)?.isNotEmpty == true;

    final replyId = msg['reply_to_id'] as String?;
    final replyMsg = msg['reply_to_message'] as String?;
    final replyPseudo = msg['reply_to_pseudo'] as String?;
    final replyType = msg['reply_to_type'] as String?;
    final hasReply = replyId != null && replyId.isNotEmpty;

    final rawReactions = msg['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) => MapEntry(k, List<String>.from(v as List? ?? [])));
    final hasReactions = reactions.values.any((list) => list.isNotEmpty);
    final msgId = msg['id'] as String? ?? '';

    final isSelected = _isSelectionMode && _selectedMsgIds.contains(msgId);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (_isSelectionMode && _isAppAdmin)
          ? () => _toggleMessageSelection(msgId)
          : null,
      onLongPress: _isSelectionMode
          ? () => _toggleMessageSelection(msgId)
          : (isDeleted && !_isAppAdmin)
              ? null
              : () => _showMessageOptions(msg, isMe),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? _colors.primary.withOpacity(0.15) : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(
            left: (_isSelectionMode && _isAppAdmin) ? 4 : (isMe ? 60 : 8),
            right: isMe ? 8 : 60,
            top: 3,
            bottom: hasReactions ? 6 : 3,
          ),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
            // Checkbox sélection (admin, mode sélection)
            if (_isSelectionMode && _isAppAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleMessageSelection(msgId),
                    activeColor: _colors.primary,
                    shape: const CircleBorder(),
                    side: BorderSide(color: _colors.border, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (!isMe && !(_isSelectionMode && _isAppAdmin)) ...[
              GestureDetector(
                onTap: () => _showSenderProfile(msg['send_by'] as String? ?? ''),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _colors.surfaceVariant,
                      backgroundImage:
                          senderImage.isNotEmpty ? CachedNetworkImageProvider(senderImage) : null,
                      child: senderImage.isEmpty
                          ? Icon(Icons.person, size: 14, color: _colors.textSecondary)
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: _buildUserBadge(msg['send_by'] as String? ?? ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Bulle + bouton réaction côte à côte
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isMe && !isDeleted) ...[
                        _buildAddReactionButton(msgId, reactions),
                        const SizedBox(width: 4),
                      ],
                      Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? _colors.primary
                      : (isDeleted ? _colors.surfaceVariant : _colors.surface),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: (isMe || isDeleted)
                      ? null
                      : Border.all(color: _colors.border.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Pseudo (pour les autres)
                    if (!isMe && !isDeleted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '@$pseudo',
                          style: TextStyle(
                              color: _colors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),

                    // Bloc reponse cite
                    if (hasReply) _buildReplyPreview(replyPseudo, replyMsg, replyType, isMe),

                    // Contenu
                    if (isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_rounded,
                              size: 13,
                              color: isMe ? Colors.white54 : _colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Message supprime',
                            style: TextStyle(
                              color: isMe ? Colors.white54 : _colors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else if (type == 'image')
                      GestureDetector(
                        onTap: () => _openImage(text),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: text,
                            width: 200,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 200,
                              height: 140,
                              color: _colors.surfaceVariant,
                              child: Icon(Icons.image_rounded,
                                  color: _colors.textSecondary, size: 32),
                            ),
                          ),
                        ),
                      )
                    else if (type == 'multi_image')
                      _buildMultiImageGrid(msg, isMe)
                    else if (type == 'video')
                      _buildVideoCard(text, isMe)
                    else if (type == 'post')
                      _buildSharedPostCard(msg, isMe)
                    else if (type == 'link_share')
                      _buildLinkShareCard(msg, isMe)
                    else if (_groupData['allow_external_links'] == true)
                      Linkify(
                        onOpen: (link) async {
                          final uri = Uri.tryParse(link.url);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        text: text,
                        style: TextStyle(
                          color: isMe ? Colors.white : _colors.textPrimary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        linkStyle: TextStyle(
                          color: isMe ? Colors.white70 : _colors.info,
                          decoration: TextDecoration.underline,
                        ),
                        options: const LinkifyOptions(humanize: false),
                      )
                    else
                      Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : _colors.textPrimary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),

                    // Heure + vues (messages envoyés par moi)
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: isMe && !isDeleted ? () => _showMessageReaders(msg) : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Indicateur visibilité restreinte
                          if (isRestricted) ...[
                            Icon(
                              hasVisibleTo ? Icons.group_rounded : Icons.visibility_off_rounded,
                              size: 11,
                              color: isMe ? Colors.purple.shade200 : Colors.purple,
                            ),
                            const SizedBox(width: 4),
                          ],
                          // Indicateur ciblage pays (visible admin/owner uniquement)
                          if (hasCountryTarget) ...[
                            const Icon(Icons.public_rounded,
                                size: 11, color: Color(0xFF185FA5)),
                            const SizedBox(width: 2),
                            Text(
                              visibleCountries.take(2).map(countryFlag).join(''),
                              style: const TextStyle(fontSize: 9),
                            ),
                            if (visibleCountries.length > 2)
                              Text(
                                '+${visibleCountries.length - 2}',
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xFF185FA5)),
                              ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: isMe ? Colors.white54 : _colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          if (isMe && !isDeleted) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.done_all_rounded,
                                size: 12,
                                color: Colors.white54),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
              if (!isMe && !isDeleted) ...[
                const SizedBox(width: 4),
                _buildAddReactionButton(msgId, reactions),
              ],
            ],
          ),
          // Pilules de réactions
          if (hasReactions)
            _buildReactionsBar(msgId, reactions, isMe),
        ],
      ),
            ),
          ],
        ),
      ),
    ),  // AnimatedContainer
    );
  }

  Widget _buildAddReactionButton(String msgId, Map<String, List<String>> reactions) {
    return GestureDetector(
      onTap: () => _showReactionPicker(msgId, reactions),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colors.surface,
          border: Border.all(color: _colors.border.withOpacity(0.4)),
        ),
        child: Center(
          child: Text('+', style: TextStyle(
            fontSize: 14, color: _colors.textSecondary, height: 1,
          )),
        ),
      ),
    );
  }

  Widget _buildReactionsBar(String msgId, Map<String, List<String>> reactions, bool isMe) {
    final myId = _auth.loginUserData.id ?? '';
    final sorted = reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: sorted.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final mine = users.contains(myId);
          return GestureDetector(
            onTap: () => _toggleReaction(msgId, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: mine
                    ? _colors.primary.withOpacity(0.12)
                    : _colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: mine
                      ? _colors.primary.withOpacity(0.4)
                      : _colors.border.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text(
                    '${users.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mine ? _colors.primary : _colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _toggleReaction(String msgId, String emoji) async {
    if (msgId.isEmpty) return;
    final myId = _auth.loginUserData.id ?? '';
    if (myId.isEmpty) return;
    final msgRef = FirebaseFirestore.instance.collection('GroupMessages').doc(msgId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final doc = await tx.get(msgRef);
      final raw = doc.data()?['reactions'] as Map<String, dynamic>? ?? {};
      final reactions = raw.map((k, v) =>
          MapEntry(k, List<String>.from(v as List? ?? [])));

      for (final e in reactions.keys.where((e) => e != emoji)) {
        reactions[e]!.remove(myId);
      }

      final target = reactions[emoji] ?? <String>[];
      if (target.contains(myId)) {
        target.remove(myId);
      } else {
        target.add(myId);
      }
      reactions[emoji] = target;
      reactions.removeWhere((_, v) => v.isEmpty);

      tx.update(msgRef, {'reactions': reactions});
    });
  }

  void _showReactionPicker(String msgId, Map<String, List<String>> currentReactions) {
    final myId = _auth.loginUserData.id ?? '';

    String? myCurrentEmoji;
    for (final e in currentReactions.entries) {
      if (e.value.contains(myId)) { myCurrentEmoji = e.key; break; }
    }

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.58,
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: _colors.border, borderRadius: BorderRadius.circular(2)),
            ),

            // Titre + réaction actuelle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Réagir au message',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  if (myCurrentEmoji != null)
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _toggleReaction(msgId, myCurrentEmoji!);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _colors.primary.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(myCurrentEmoji,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 5),
                            Text('Retirer',
                                style: TextStyle(
                                    color: _colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 6 réactions rapides (style WhatsApp)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ...[
                    ('❤️', 'Aimer'),
                    ('😂', 'Rire'),
                    ('👍', 'D\'accord'),
                    ('👎', 'Non aimer'),
                    ('😮', 'Surpris'),
                    ('😢', 'Triste'),
                  ].map((pair) {
                    final emoji = pair.$1;
                    final label = pair.$2;
                    final isMine = myCurrentEmoji == emoji;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _toggleReaction(msgId, emoji);
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isMine
                                  ? _colors.primary.withOpacity(0.15)
                                  : _colors.surfaceVariant,
                              border: Border.all(
                                color: isMine
                                    ? _colors.primary.withOpacity(0.5)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: isMine ? _colors.primary : _colors.textSecondary,
                              fontWeight: isMine ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: _colors.border.withOpacity(0.3)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Tous les emojis', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),

            // Picker complet avec toutes les catégories
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) async {
                  Navigator.pop(ctx);
                  await _toggleReaction(msgId, emoji.emoji);
                },
                config: Config(
                  height: MediaQuery.of(ctx).size.height * 0.58 - 80,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 9,
                    emojiSizeMax: 26,
                    backgroundColor: _colors.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: _colors.surfaceVariant,
                    indicatorColor: _colors.primary,
                    iconColorSelected: _colors.primary,
                    iconColor: _colors.textSecondary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: _colors.surface,
                    buttonIconColor: _colors.primary,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: _colors.surfaceVariant,
                    buttonColor: _colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiImageGrid(Map<String, dynamic> msg, bool isMe) {
    final urls = (msg['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    if (urls.isEmpty) return const SizedBox.shrink();

    const double totalW = 190.0;
    const double gap = 2.0;
    final thumbW = (totalW - gap) / 2;

    if (urls.length == 1) {
      return _buildGridThumb(urls[0], totalW, totalW * 0.75);
    }
    if (urls.length == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGridThumb(urls[0], thumbW, thumbW),
          const SizedBox(width: gap),
          _buildGridThumb(urls[1], thumbW, thumbW),
        ],
      );
    }
    // 3-5 : première image pleine largeur, reste en grille 2 colonnes
    final rest = urls.skip(1).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGridThumb(urls[0], totalW, totalW * 0.55),
        const SizedBox(height: gap),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: rest.map((u) => _buildGridThumb(u, thumbW, thumbW)).toList(),
        ),
      ],
    );
  }

  Widget _buildGridThumb(String url, double w, double h) {
    return GestureDetector(
      onTap: () => _openImage(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: url,
          width: w,
          height: h,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: w,
            height: h,
            color: _colors.surfaceVariant,
            child: Icon(Icons.image_rounded,
                color: _colors.textSecondary, size: 20),
          ),
          errorWidget: (_, __, ___) => Container(
            width: w,
            height: h,
            color: _colors.surfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSharedPostCard(Map<String, dynamic> msg, bool isMe) {
    final thumbnail = msg['post_thumbnail'] as String? ?? '';
    final description = msg['message'] as String? ?? '';
    final dataType = msg['post_data_type'] as String? ?? 'IMAGE';
    final postId = msg['post_id'] as String? ?? '';

    IconData typeIcon;
    String typeLabel;
    switch (dataType) {
      case 'VIDEO':
        typeIcon = Icons.videocam_rounded;
        typeLabel = 'Video Afrolook';
        break;
      case 'AUDIO':
        typeIcon = Icons.audiotrack_rounded;
        typeLabel = 'Audio Afrolook';
        break;
      case 'TEXT':
        typeIcon = Icons.article_outlined;
        typeLabel = 'Article Afrolook';
        break;
      default:
        typeIcon = Icons.image_rounded;
        typeLabel = 'Post Afrolook';
    }

    return GestureDetector(
      onTap: postId.isEmpty ? null : () => _openSharedPost(postId, dataType: dataType),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.12)
              : _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isMe
                  ? Colors.white24
                  : _colors.border.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature / Vidéo inline pour les posts VIDEO
            if (dataType == 'VIDEO' && postId.isNotEmpty)
              _GroupChatSharedVideoWidget(postId: postId, thumbnail: thumbnail)
            else
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: thumbnail.isNotEmpty
                    ? Image.network(
                        thumbnail,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          color: _colors.surfaceVariant,
                          child: Center(
                              child: Icon(typeIcon,
                                  color: _colors.textSecondary, size: 28)),
                        ),
                      )
                    : Container(
                        height: 80,
                        color: _colors.surfaceVariant,
                        child: Center(
                            child: Icon(typeIcon,
                                color: _colors.textSecondary, size: 28)),
                      ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(typeIcon,
                          size: 12,
                          color: isMe ? Colors.white70 : _colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(
                            color:
                                isMe ? Colors.white70 : _colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description.length > 60
                          ? '${description.substring(0, 60)}...'
                          : description,
                      style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : _colors.textPrimary,
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Voir le post',
                    style: TextStyle(
                        color: isMe ? Colors.white70 : _colors.primary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkShareCard(Map<String, dynamic> msg, bool isMe) {
    final title = msg['item_title'] as String? ?? msg['message'] as String? ?? '';
    final thumbnail = msg['item_thumbnail'] as String? ?? '';
    final itemType = msg['item_type'] as String? ?? '';
    final isLive = itemType == 'live';

    IconData icon;
    String typeLabel;
    String actionLabel;
    Color typeColor;
    switch (itemType) {
      case 'live':
        icon = Icons.live_tv_rounded;
        typeLabel = '● LIVE';
        actionLabel = 'Visiter le live';
        typeColor = Colors.redAccent;
        break;
      case 'product':
        icon = Icons.shopping_bag_outlined;
        typeLabel = 'Produit';
        actionLabel = 'Voir le produit';
        typeColor = isMe ? Colors.white70 : _colors.primary;
        break;
      case 'vip':
        icon = Icons.star_rounded;
        typeLabel = 'Contenu VIP';
        actionLabel = 'Voir le contenu';
        typeColor = const Color(0xFFF9A825);
        break;
      default:
        icon = Icons.link_rounded;
        typeLabel = 'Lien partagé';
        actionLabel = 'Voir';
        typeColor = isMe ? Colors.white70 : _colors.primary;
    }

    return GestureDetector(
      onTap: () => _openSharedItem(msg),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.12) : _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isMe ? Colors.white24 : _colors.border.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: CachedNetworkImage(
                      imageUrl: thumbnail,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: 60, color: _colors.surfaceVariant,
                        child: Center(child: Icon(icon, color: _colors.textSecondary, size: 24)),
                      ),
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              )
            else if (isLive)
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.live_tv_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 5),
                      const Text('● LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          typeLabel,
                          style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title.length > 55 ? '${title.substring(0, 55)}...' : title,
                    style: TextStyle(color: isMe ? Colors.white : _colors.textPrimary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(actionLabel, style: TextStyle(color: isMe ? Colors.white60 : _colors.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSharedItem(Map<String, dynamic> msg) async {
    final itemType = msg['item_type'] as String? ?? '';
    final itemId = msg['item_id'] as String? ?? '';
    if (itemId.isEmpty || !mounted) return;

    switch (itemType) {
      case 'product':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProduitDetail(productId: itemId),
        ));
        break;
      case 'vip':
        try {
          final doc = await _firestore.collection('ContentPaie').doc(itemId).get();
          if (!doc.exists || !mounted) return;
          final content = ContentPaie.fromJson(doc.data()!);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ContentDetailScreen(content: content),
          ));
        } catch (_) {}
        break;
      case 'live':
        try {
          final doc = await _firestore.collection('lives').doc(itemId).get();
          if (!doc.exists || !mounted) return;
          final live = PostLive.fromMap(doc.data()!);
          if (live.isLive) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => LivePage(
                liveId: itemId,
                postLive: live,
                isHost: false,
                isInvited: false,
                hostName: live.hostName ?? '',
                hostImage: live.hostImage ?? '',
              ),
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveEndedPage(live: live)));
          }
        } catch (_) {}
        break;
    }
  }

  Future<void> _openSharedPost(String postId, {String dataType = 'IMAGE'}) async {
    try {
      final doc = await _firestore.collection('Posts').doc(postId).get();
      if (!doc.exists || !mounted) return;
      final post = Post.fromJson(doc.data()!);
      final type = post.dataType ?? dataType;
      if (type == 'VIDEO') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PostDetailsVideoFormatTel(initialPost: post),
        ));
      } else {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetailsPost(post: post),
        ));
      }
    } catch (_) {}
  }

  Widget _buildSystemMessage(Map<String, dynamic> msg) {
    final text = msg['message'] as String? ?? '';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: _colors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
      String? pseudo, String? message, String? type, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : _colors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pseudo != null && pseudo.isNotEmpty)
            Text(
              '@$pseudo',
              style: TextStyle(
                color: isMe ? Colors.white : _colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 2),
          if (type == 'image')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_rounded,
                    size: 13,
                    color: isMe ? Colors.white70 : _colors.textSecondary),
                const SizedBox(width: 4),
                Text('Photo',
                    style: TextStyle(
                        color: isMe ? Colors.white70 : _colors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ],
            )
          else
            Text(
              message ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.white70 : _colors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(String url, bool isMe) {
    return _GroupChatVideoPreview(url: url, isMe: isMe);
  }

  // ─── INPUT BAR ───────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banniere reponse
          if (_replyingToMsg != null) _buildReplyBanner(),

          // Indicateur message invisible actif
          if (_sendHidden)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              color: Colors.purple.withOpacity(0.12),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off_rounded, color: Colors.purple, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Message invisible — visible seulement par vous',
                    style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Barre principale
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _colors.surface,
              border: Border(top: BorderSide(color: _sendHidden
                  ? Colors.purple.withOpacity(0.4)
                  : _colors.border.withOpacity(0.3))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bouton "+" — ouvre/ferme le menu pièces jointes
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAttachMenu = !_showAttachMenu;
                      if (_showAttachMenu && _showEmojiPicker) {
                        _showEmojiPicker = false;
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    child: AnimatedRotation(
                      turns: _showAttachMenu ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(Icons.add_rounded, color: _colors.primary, size: 26),
                    ),
                  ),
                ),
                // Menu pièces jointes (image + vidéo + futurs)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _showAttachMenu
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _showAttachMenu = false);
                                _userCanShare
                                    ? _sendImageMessage()
                                    : _showShareBlockedSnackbar();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8, right: 4),
                                child: Icon(Icons.image_rounded,
                                    color: _userCanShare
                                        ? _colors.primary
                                        : _colors.textSecondary.withOpacity(0.4),
                                    size: 24),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _showAttachMenu = false);
                                _userCanShare
                                    ? _sendVideoMessage()
                                    : _showShareBlockedSnackbar();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8, right: 4),
                                child: Icon(Icons.videocam_rounded,
                                    color: _userCanShare
                                        ? _colors.primary
                                        : _colors.textSecondary.withOpacity(0.4),
                                    size: 24),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _showAttachMenu = false);
                                _userCanShare
                                    ? _sendMultiImageMessage()
                                    : _showShareBlockedSnackbar();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8, right: 6),
                                child: Icon(Icons.photo_library_rounded,
                                    color: _userCanShare
                                        ? _colors.primary
                                        : _colors.textSecondary.withOpacity(0.4),
                                    size: 24),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                // Emoji
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                      if (_showEmojiPicker) {
                        _showAttachMenu = false;
                        _focusNode.unfocus();
                      } else {
                        _focusNode.requestFocus();
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 6),
                    child: Icon(
                      _showEmojiPicker
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      color: _colors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
                // Bouton message invisible (Gold owner uniquement)
                if (_canSendHidden)
                  GestureDetector(
                    onTap: () => setState(() => _sendHidden = !_sendHidden),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 6),
                      child: Icon(
                        _sendHidden ? Icons.visibility_off_rounded : Icons.visibility_outlined,
                        color: _sendHidden ? Colors.purple : _colors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                // Champ texte
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: _colors.background,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _sendHidden
                          ? Colors.purple.withOpacity(0.5)
                          : _colors.border.withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      style: TextStyle(color: _colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _sendHidden ? '👁️ Message invisible...' : 'Message au groupe...',
                        hintStyle:
                            TextStyle(color: _sendHidden ? Colors.purple.withOpacity(0.6) : _colors.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      onTap: () {
                        if (_showEmojiPicker || _showAttachMenu) {
                          setState(() {
                            _showEmojiPicker = false;
                            _showAttachMenu = false;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton envoyer
                GestureDetector(
                  onTap: _sendTextMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _sendHidden ? Colors.purple : _colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            _sendHidden ? Icons.visibility_off_rounded : Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _textController,
                onEmojiSelected: (_, __) => setState(() {}),
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: _colors.background,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: _colors.surfaceVariant,
                    indicatorColor: _colors.primary,
                    iconColorSelected: _colors.primary,
                    iconColor: _colors.textSecondary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: _colors.background,
                    buttonIconColor: _colors.primary,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: _colors.surfaceVariant,
                    buttonColor: _colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    final reply = _replyingToMsg!;
    final isDeleted = reply['is_deleted'] == true;
    final type = reply['message_type'] as String? ?? 'text';
    final pseudo = reply['sender_pseudo'] as String? ?? '';
    final text = isDeleted
        ? 'Message supprime'
        : (type == 'image' ? 'Photo' : (reply['message'] as String? ?? ''));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _colors.primary.withOpacity(0.07),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$pseudo',
                  style: TextStyle(
                      color: _colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingToMsg = null),
            child: Icon(Icons.close_rounded, size: 18, color: _colors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Prévisualisation inline muette des vidéos dans le chat ──────────────────

class _GroupChatVideoPreview extends StatefulWidget {
  final String url;
  final bool isMe;

  const _GroupChatVideoPreview({required this.url, required this.isMe});

  @override
  State<_GroupChatVideoPreview> createState() => _GroupChatVideoPreviewState();
}

class _GroupChatVideoPreviewState extends State<_GroupChatVideoPreview> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _muted = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = await MediaCacheService.videoController(widget.url);
      _ctrl = ctrl;
      await ctrl.initialize();
      await ctrl.setVolume(0);
      ctrl.setLooping(true);
      if (mounted) {
        setState(() => _initialized = true);
        if (_visible) ctrl.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _handleVisibility(VisibilityInfo info) {
    final nowVisible = info.visibleFraction > 0.4;
    if (nowVisible == _visible) return;
    _visible = nowVisible;
    if (_initialized && _ctrl != null) {
      nowVisible ? _ctrl!.play() : _ctrl!.pause();
    }
  }

  void _openFullscreen() {
    _ctrl?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoFullscreenPage(url: widget.url)),
    ).then((_) {
      if (_visible && _initialized && _ctrl != null) _ctrl!.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return VisibilityDetector(
      key: Key('group-video-${widget.url.hashCode}'),
      onVisibilityChanged: _handleVisibility,
      child: GestureDetector(
        onTap: _openFullscreen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 220,
            color: Colors.black,
            child: _initialized && _ctrl != null
                ? Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: _ctrl!.value.aspectRatio > 0
                            ? _ctrl!.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_ctrl!),
                      ),
                      // Icône plein écran au centre
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      // Bouton muet
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _muted = !_muted);
                            _ctrl?.setVolume(_muted ? 0 : 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _muted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 130,
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.12)
                        : colors.surfaceVariant,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.videocam_rounded,
                            size: 40,
                            color: widget.isMe
                                ? Colors.white54
                                : colors.textSecondary),
                        const SizedBox.expand(
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white38),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _VideoFullscreenPage extends StatelessWidget {
  final String url;

  const _VideoFullscreenPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vidéo'),
        elevation: 0,
      ),
      body: Center(
        child: SmartVideoPlayer(
          url: url,
          autoPlay: true,
          looping: false,
          showControls: true,
        ),
      ),
    );
  }
}

// ─── Lecture inline d'un post vidéo partagé dans le chat ────────────────────

class _GroupChatSharedVideoWidget extends StatefulWidget {
  final String postId;
  final String thumbnail;

  const _GroupChatSharedVideoWidget({required this.postId, required this.thumbnail});

  @override
  State<_GroupChatSharedVideoWidget> createState() => _GroupChatSharedVideoWidgetState();
}

class _GroupChatSharedVideoWidgetState extends State<_GroupChatSharedVideoWidget> {
  String? _videoUrl;
  bool _loading = true;
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _muted = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _fetchUrl();
  }

  Future<void> _fetchUrl() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Posts').doc(widget.postId).get();
      if (!mounted) return;
      final url = doc.data()?['url_media'] as String?;
      if (url != null && url.isNotEmpty) {
        setState(() { _videoUrl = url; _loading = false; });
        _initVideo(url);
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initVideo(String url) async {
    try {
      final ctrl = await MediaCacheService.videoController(url);
      _ctrl = ctrl;
      await ctrl.initialize();
      await ctrl.setVolume(0);
      ctrl.setLooping(true);
      if (mounted) {
        setState(() => _initialized = true);
        if (_visible) ctrl.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _handleVisibility(VisibilityInfo info) {
    final nowVisible = info.visibleFraction > 0.4;
    if (nowVisible == _visible) return;
    _visible = nowVisible;
    if (_initialized && _ctrl != null) {
      nowVisible ? _ctrl!.play() : _ctrl!.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _initialized && _ctrl != null
        ? AspectRatio(
            aspectRatio: _ctrl!.value.aspectRatio > 0 ? _ctrl!.value.aspectRatio : 16 / 9,
            child: VideoPlayer(_ctrl!),
          )
        : widget.thumbnail.isNotEmpty
            ? Image.network(
                widget.thumbnail,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 130,
                  color: Colors.black12,
                  child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 28)),
                ),
              )
            : Container(
                height: 130,
                color: Colors.black26,
                child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 28)),
              );

    return VisibilityDetector(
      key: Key('shared-video-${widget.postId}'),
      onVisibilityChanged: _handleVisibility,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: Stack(
          children: [
            child,
            if (_loading)
              Positioned(
                top: 0, left: 0, right: 0, bottom: 0,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
              ),
            if (!_loading && _videoUrl != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _muted = !_muted);
                    _ctrl?.setVolume(_muted ? 0 : 1);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Navigation vers DetailsPost avec chargement depuis Firestore
class _PostNavigatorPage extends StatefulWidget {
  final Post post;
  const _PostNavigatorPage({required this.post});

  @override
  State<_PostNavigatorPage> createState() => _PostNavigatorPageState();
}

class _PostNavigatorPageState extends State<_PostNavigatorPage> {
  @override
  Widget build(BuildContext context) {
    return DetailsPost(post: widget.post);
  }
}
