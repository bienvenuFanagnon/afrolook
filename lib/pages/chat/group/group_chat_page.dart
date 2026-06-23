import 'dart:io';
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
import '../../../services/utils/group_permission_utils.dart';
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

  bool _isFrozen = false;
  bool _isSending = false;
  bool _isPaymentProcessing = false;
  bool _showEmojiPicker = false;
  bool _isMuted = false;
  bool _isReadOnly = false;
  bool _sendHidden = false; // mode message invisible (Gold owner uniquement)
  String _myRole = 'member';
  Map<String, dynamic> _myPermissions = {};
  Map<String, dynamic> _groupData = {};
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;
  final Map<String, Map<String, dynamic>> _senderBadgeCache = {};

  // Reponse
  Map<String, dynamic>? _replyingToMsg;

  // Throttle anti-spam (500ms entre chaque message)
  int _lastSentAt = 0;
  static const int _throttleMs = 500;

  // ── Permissions calculées ─────────────────────────────────────────────────
  bool get _isAdminOrOwner => _myRole == 'owner' || _myRole == 'admin';

  bool get _userCanWrite => GroupPermissionUtils.canWrite(
        groupData: _groupData,
        userId: _auth.loginUserData.id ?? '',
        userRole: _myRole,
      );

  bool get _userCanShare => GroupPermissionUtils.canShare(
        groupData: _groupData,
        userId: _auth.loginUserData.id ?? '',
        userRole: _myRole,
      );

  bool get _hiddenMsgsEnabled =>
      GroupPermissionUtils.hiddenMessagesEnabled(_groupData);

  bool get _canSendHidden =>
      _myRole == 'owner' && _hiddenMsgsEnabled && !_isFrozen;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
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
          _isReadOnly = data['is_read_only'] == true;
          _isMuted = mutedGroups.contains(widget.groupId);
          _myRole = role;
          _myPermissions = perms;
        });
      }
      await _checkOwnerPremium(data);
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
      if (abonnementJson != null) {
        final ab = AfrolookAbonnement.fromJson(abonnementJson);
        // Premium OU Gold permettent de garder un groupe actif
        isStillActive = ab.estPremium;
      }

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
        setState(() {
          _messages = msgs;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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
    if (!_isMember(myId)) return;

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
      final otherMembers = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id != myId)
          .toList();
      final groupUpdate = <String, dynamic>{
        'last_message': text,
        'last_message_at': now,
        'updated_at': now,
      };
      for (final id in otherMembers) {
        groupUpdate['unread_counts.$id'] = FieldValue.increment(1);
      }
      await _firestore.collection('GroupChats').doc(widget.groupId).update(groupUpdate);

      await _sendGroupNotification(text);
    } catch (_) {
    } finally {
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
    if (!_isMember(myId)) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isSending = true);
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final file = File(picked.path);
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = _firestore.collection('GroupMessages').doc().id;

      final ref = FirebaseStorage.instance
          .ref()
          .child('group_images/${widget.groupId}/$msgId.jpg');
      await ref.putFile(file);
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

      final otherMembersImg = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id != myId)
          .toList();
      final groupUpdateImg = <String, dynamic>{
        'last_message': 'Photo',
        'last_message_at': now,
        'updated_at': now,
      };
      for (final id in otherMembersImg) {
        groupUpdateImg['unread_counts.$id'] = FieldValue.increment(1);
      }
      await _firestore.collection('GroupChats').doc(widget.groupId).update(groupUpdateImg);

      await _sendGroupNotification('Photo');
    } catch (_) {
    } finally {
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

  // ─── NOTIFICATIONS ONESIGNAL ─────────────────────────────────────────────────

  Future<void> _sendGroupNotification(String msgContent) async {
    try {
      final myId = _auth.loginUserData.id!;
      final memberIds = (_groupData['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id != myId)
          .toList();

      if (memberIds.isEmpty) return;

      final groupName = _groupData['name'] as String? ?? widget.groupName;
      final senderPseudo = _auth.loginUserData.pseudo ?? '';
      final notifMsg = '@$senderPseudo dans $groupName: $msgContent';

      // Batch par chunks de 30 (limite Firestore whereIn)
      for (var i = 0; i < memberIds.length; i += 30) {
        final chunk = memberIds.sublist(i, min(i + 30, memberIds.length));
        final snap = await _firestore
            .collection('Users')
            .where('id', whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final mutedGroups = (data['muted_groups'] as List<dynamic>? ?? []).cast<String>();
          if (mutedGroups.contains(widget.groupId)) continue;
          final oneSignalId = data['oneIgnalUserid'] as String?;
          if (oneSignalId != null && oneSignalId.length > 5) {
            await _auth.sendNotification(
              userIds: [oneSignalId],
              smallImage: _auth.loginUserData.imageUrl ?? '',
              send_user_id: myId,
              recever_user_id: data['id'] as String? ?? '',
              message: notifMsg,
              type_notif: NotificationType.MESSAGE.name,
              post_id: '',
              post_type: '',
              chat_id: widget.groupId,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _markMessagesRead() async {
    try {
      final myId = _auth.loginUserData.id!;
      final now = DateTime.now().millisecondsSinceEpoch;
      await Future.wait([
        _firestore
            .collection('GroupChats')
            .doc(widget.groupId)
            .collection('reads')
            .doc(myId)
            .set({'user_id': myId, 'last_read_at': now}),
        _firestore
            .collection('GroupChats')
            .doc(widget.groupId)
            .update({'unread_counts.$myId': 0}),
      ]);
    } catch (_) {}
  }

  Future<void> _showMessageReaders(Map<String, dynamic> msg) async {
    final msgTime = msg['create_at_time_spam'] as int? ?? 0;
    final myId = _auth.loginUserData.id!;
    try {
      final snap = await _firestore
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('reads')
          .get();
      final readers = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String? ?? '';
        if (userId == myId) continue;
        final lastRead = data['last_read_at'] as int? ?? 0;
        if (lastRead >= msgTime) {
          final userDoc = await _firestore.collection('Users').doc(userId).get();
          final userData = userDoc.data() ?? {};
          if (userData['incognitoMode'] == true) continue;
          readers.add(userData);
        }
      }
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    readers.isEmpty ? 'Personne n\'a encore lu ce message' : '${readers.length} lu par',
                    style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                ...readers.map((u) {
                  final pseudo = u['pseudo'] as String? ?? '';
                  final img = u['imageUrl'] as String? ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _colors.surfaceVariant,
                      backgroundImage: img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                      child: img.isEmpty ? Icon(Icons.person, size: 16, color: _colors.textSecondary) : null,
                    ),
                    title: Text('@$pseudo', style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
              if (canDelete && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg);
                  },
                ),
              const SizedBox(height: 8),
            ],
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

  String _formatTime(int tsMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final myId = _auth.loginUserData.id!;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isFrozen) _buildFrozenBanner(),
          if (!_isFrozen && _isReadOnly) _buildReadOnlyBanner(),
          if (!_isFrozen && !_isReadOnly && !_userCanWrite) _buildNoWritePermissionBanner(),
          Expanded(
            child: _isLoadingMessages
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
          ),
          if (_userCanWrite) _buildInputBar(),
          if (!_userCanWrite) _buildBlockedInputPlaceholder(),
        ],
      ),
    );
  }

  // ─── APPBAR ──────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    final imageUrl = _groupData['image_url'] as String? ?? widget.groupImageUrl;
    final memberCount = _groupData['member_count'] as int?;

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
                  Text(
                    _groupData['name'] as String? ?? widget.groupName,
                    style: TextStyle(
                        color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
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
      color: _colors.primary.withOpacity(0.08),
      child: Row(
        children: [
          Icon(Icons.edit_off_rounded, color: _colors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lecture seule — seuls les admins peuvent écrire',
              style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
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
      color: Colors.red.withOpacity(0.08),
      child: const Row(
        children: [
          Icon(Icons.block_rounded, color: Colors.red, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Écriture désactivée par le propriétaire du groupe',
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedInputPlaceholder() {
    String reason;
    IconData icon;
    Color color;

    if (_isFrozen) {
      reason = 'Groupe gelé — propriétaire plus Gold';
      icon = Icons.lock_outline_rounded;
      color = Colors.orange;
    } else if (_isReadOnly && !_isAdminOrOwner) {
      reason = 'Groupe en lecture seule';
      icon = Icons.edit_off_rounded;
      color = _colors.textSecondary;
    } else {
      reason = 'Écriture non autorisée dans ce groupe';
      icon = Icons.block_rounded;
      color = Colors.red;
    }

    final r = _writeBlockReason();
    return GestureDetector(
      onTap: () => _showRestrictionModal(
        title: r.title,
        message: r.message,
        icon: r.icon,
        color: r.color,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _colors.surface,
          border: Border(top: BorderSide(color: _colors.border.withOpacity(0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(r.icon, color: r.color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(reason, style: TextStyle(color: r.color, fontSize: 13)),
            ),
            Icon(Icons.info_outline_rounded, color: r.color.withOpacity(0.6), size: 15),
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

    return GestureDetector(
      onLongPress: isDeleted ? null : () => _showMessageOptions(msg, isMe),
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 60 : 8,
          right: isMe ? 8 : 60,
          top: 3,
          bottom: 3,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
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
              child: Container(
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
              ),
            ),
          ],
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
            // Miniature
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
                // Image
                GestureDetector(
                  onTap: _userCanShare ? _sendImageMessage : () => _showShareBlockedSnackbar(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    child: Icon(Icons.image_rounded,
                        color: _userCanShare ? _colors.primary : _colors.textSecondary.withOpacity(0.4),
                        size: 24),
                  ),
                ),
                // Emoji
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                      if (_showEmojiPicker) {
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
                        if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
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
