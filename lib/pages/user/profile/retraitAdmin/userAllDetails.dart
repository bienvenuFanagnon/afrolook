// pages/admin/user_management_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:flutter/material.dart';
import '../../../admin/admin_palette.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../widgets/interests_selector_widget.dart';
import '../../../../services/chat_service.dart';
import '../../../chat/myChat.dart';
import 'package:page_transition/page_transition.dart';
import '../../mes_gains_post_page.dart';
import '../../userTransactionListe.dart';

// ── Palette admin ────────────────────────────────────────────────────────────
Color get _bg      => AdminPalette.bg;
Color get _surface => AdminPalette.surface;
Color get _card    => AdminPalette.card;
Color get _border  => AdminPalette.border;
Color get _gold    => AdminPalette.gold;
Color get _green   => AdminPalette.green;
Color get _amber   => AdminPalette.amber;
Color get _blue    => AdminPalette.blue;
Color get _red     => AdminPalette.red;
Color get _textP   => AdminPalette.textP;
Color get _textS   => AdminPalette.textS;

class UserManagementPage extends StatefulWidget {
  final String userId;
  const UserManagementPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  UserData? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _infoExpanded = false;
  bool _isSendingReminder = false;
  bool _isOpeningChat = false;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _posts = [];
  bool _postsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('Users').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        if (!mounted) return;
        setState(() { _userData = UserData.fromJson(data); _isLoading = false; });
        _loadPosts();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      printVm('Erreur chargement user: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Actions de gestion (déplacées depuis le profil public) ───────────────

  Future<void> _openDirectChat() async {
    if (_isOpeningChat || _userData == null) return;
    final admin = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    setState(() => _isOpeningChat = true);
    try {
      final tempChat = Chat(
        id: 'temp_${_userData!.id}',
        senderId: admin.id,
        receiverId: _userData!.id,
        chatFriend: _userData,
        receiver: _userData,
        type: ChatType.USER.name,
      );
      final resultChat = await _chatService.createOrGetChat(
        chat: tempChat,
        currentUserId: admin.id!,
      );
      if (!mounted) return;
      Navigator.push(context, PageTransition(
        type: PageTransitionType.fade,
        child: MyChat(title: 'Message', chat: resultChat),
      ));
    } catch (e) {
      _showSnack('Erreur: $e', _red);
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  void _showConfirmReminderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Row(children: [
          Icon(Icons.email, color: _amber),
          const SizedBox(width: 10),
          Text('Envoyer un rappel', style: TextStyle(color: _textP)),
        ]),
        content: Text(
          'Envoyer un email personnalisé à @${_userData?.pseudo ?? ''} ?',
          style: TextStyle(color: _textS),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: _textS)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendReminderEmail();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _amber),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminderEmail() async {
    if (_isSendingReminder || _userData == null) return;
    setState(() => _isSendingReminder = true);
    try {
      final userDoc = await _firestore.collection('Users').doc(widget.userId).get();
      if (!userDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }
      final data = userDoc.data()!;
      final lastTimeActive = data['last_time_active'] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final daysInactive = ((now - lastTimeActive) / (24 * 60 * 60 * 1000)).floor();

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.userId)
          .get();

      int newLikesCount = 0;
      for (var postDoc in postsSnapshot.docs) {
        final post = postDoc.data();
        final postCreatedAt = post['created_at'] ?? 0;
        if (postCreatedAt > sevenDaysAgo) {
          newLikesCount += ((post['loves'] ?? 0) as num).toInt();
        }
      }

      final userEmailData = {
        'userId': widget.userId,
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

      final result = await FirebaseFunctions.instance
          .httpsCallable('sendInactiveUserReminder')
          .call({
        'userId': widget.userId,
        'userData': userEmailData,
      });

      if (result.data['success'] == true) {
        _showSnack('Email envoyé à ${userEmailData['userEmail']}', _green);
      } else {
        _showSnack(result.data['message'] ?? 'Erreur lors de l\'envoi', _red);
      }
    } catch (e) {
      _showSnack('Erreur: $e', _red);
    } finally {
      if (mounted) setState(() => _isSendingReminder = false);
    }
  }

  void _showSuspendDialog() {
    final reasonCtrl = TextEditingController();
    int? durationDays;
    bool isPermanent = false;

    Widget typeBox(bool selected, Color c, IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? c.withOpacity(0.15) : _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? c : _border),
            ),
            child: Column(children: [
              Icon(icon, color: selected ? c : _textS, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: selected ? c : _textS)),
            ]),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _card,
          title: Row(children: [
            Icon(Icons.block, color: _red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Suspendre @${_userData?.pseudo ?? ''}',
                  style: TextStyle(color: _textP, fontSize: 15)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type :', style: TextStyle(color: _textS, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  typeBox(!isPermanent, _amber, Icons.timer, 'Temporaire',
                      () => setS(() { isPermanent = false; durationDays = null; })),
                  const SizedBox(width: 8),
                  typeBox(isPermanent, _red, Icons.block, 'Définitive',
                      () => setS(() => isPermanent = true)),
                ]),
                const SizedBox(height: 14),
                if (!isPermanent) ...[
                  Text('Durée :', style: TextStyle(color: _textS, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [1, 3, 7, 14, 30].map((d) => GestureDetector(
                      onTap: () => setS(() => durationDays = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: durationDays == d ? _amber.withOpacity(0.2) : _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: durationDays == d ? _amber : _border),
                        ),
                        child: Text('${d}j',
                            style: TextStyle(
                                fontSize: 12,
                                color: durationDays == d ? _amber : _textS,
                                fontWeight: FontWeight.w600)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                ],
                Text('Raison (visible par l\'utilisateur) :',
                    style: TextStyle(color: _textS, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: TextStyle(color: _textP, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ex: Violation des règles de la communauté...',
                    hintStyle: TextStyle(color: _textS, fontSize: 12),
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
              child: Text('Annuler', style: TextStyle(color: _textS)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _red),
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
      await _firestore.collection('Users').doc(widget.userId).update(data);
      _showSnack('Compte suspendu', _red);
      await _loadUserData();
    } catch (e) {
      _showSnack('Erreur: $e', _red);
    }
  }

  void _showLiftSuspensionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Lever la suspension', style: TextStyle(color: _textP)),
        content: Text(
          'Êtes-vous sûr de vouloir lever la suspension du compte @${_userData?.pseudo ?? ''} ?',
          style: TextStyle(color: _textS),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: _textS)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestore.collection('Users').doc(widget.userId).update({
                  'suspendedUntil': null,
                  'suspendedPermanently': false,
                  'suspensionReason': null,
                });
                _showSnack('Suspension levée', _green);
                await _loadUserData();
              } catch (e) {
                _showSnack('Erreur: $e', _red);
              }
            },
            child: const Text('Lever', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final suspended = _userData!.isSuspended;
    Widget btn(IconData icon, String label, Color c, VoidCallback? onTap, {bool busy = false}) {
      return OutlinedButton.icon(
        onPressed: busy ? null : onTap,
        icon: busy
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c))
            : Icon(icon, size: 18, color: c),
        label: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ACTIONS DE GESTION'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: suspended ? _red.withOpacity(0.5) : _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (suspended) ...[
                Text(
                  _userData!.suspendedPermanently == true
                      ? 'Compte suspendu définitivement'
                      : 'Compte suspendu jusqu\'au ${_formatDate(_userData!.suspendedUntil ?? 0)}',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                if ((_userData!.suspensionReason ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Motif : ${_userData!.suspensionReason}',
                        style: TextStyle(color: _textS, fontSize: 12)),
                  ),
                const SizedBox(height: 10),
              ],
              btn(Icons.chat_bubble_outline, 'Message direct', _blue, _openDirectChat, busy: _isOpeningChat),
              const SizedBox(height: 8),
              btn(Icons.email_outlined, 'Envoyer un rappel par e-mail', _amber,
                  _showConfirmReminderDialog, busy: _isSendingReminder),
              const SizedBox(height: 8),
              suspended
                  ? btn(Icons.lock_open_rounded, 'Lever la suspension', _green, _showLiftSuspensionDialog)
                  : btn(Icons.block_rounded, 'Suspendre ce compte', _red, _showSuspendDialog),
            ],
          ),
        ),
      ],
    );
  }

  // ── Publications ──────────────────────────────────────────────────────────

  Future<void> _loadPosts() async {
    if (mounted) setState(() => _postsLoading = true);
    List<Map<String, dynamic>> result = [];
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('Posts')
            .where('user_id', isEqualTo: widget.userId)
            .orderBy('created_at', descending: true)
            .limit(30)
            .get();
      } catch (_) {
        // Index manquant : récupération puis tri côté client
        snap = await _firestore
            .collection('Posts')
            .where('user_id', isEqualTo: widget.userId)
            .limit(200)
            .get();
      }
      result = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
      int ts(Map<String, dynamic> m) => ((m['created_at'] ?? 0) as num).toInt();
      result.sort((a, b) => ts(b).compareTo(ts(a)));
      if (result.length > 30) result = result.sublist(0, 30);
    } catch (e) {
      printVm('Erreur chargement posts: $e');
    }
    if (!mounted) return;
    setState(() {
      _posts = result;
      _postsLoading = false;
    });
  }

  Future<void> _confirmDeletePost(Map<String, dynamic> post) async {
    final id = post['id'] as String?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Supprimer ce post ?', style: TextStyle(color: _textP)),
        content: Text('Cette action est irréversible.', style: TextStyle(color: _textS)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: _textS)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _firestore.collection('Posts').doc(id).delete();
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p['id'] == id));
      _showSnack('Post supprimé', _green);
    } catch (e) {
      _showSnack('Erreur: $e', _red);
    }
  }

  Widget _buildPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PUBLICATIONS'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: _postsLoading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: _gold)),
                )
              : _posts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Aucune publication', style: TextStyle(color: _textS)),
                    )
                  : Column(
                      children: _posts.map((p) {
                        final images = p['images'];
                        final thumb = (images is List && images.isNotEmpty) ? images.first.toString() : null;
                        final desc = (p['description'] ?? '').toString().trim();
                        final created = ((p['created_at'] ?? 0) as num).toInt();
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: thumb != null
                                  ? Image.network(thumb, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.broken_image_outlined, color: _textS))
                                  : Icon(Icons.article_outlined, color: _textS),
                            ),
                          ),
                          title: Text(
                            desc.isEmpty ? '(sans texte)' : desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _textP, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${_formatDate(created)}  ·  ${p['loves'] ?? 0} likes',
                            style: TextStyle(color: _textS, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: _red),
                            onPressed: () => _confirmDeletePost(p),
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  // ── Certification ─────────────────────────────────────────────────────────

  /// Compte en cours de suppression : restauration possible pendant les 15 jours (erreur signalée au support).
  Widget _buildDeletionBanner() {
    final at = _userData!.deletionScheduledAt;
    final date = at != null ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(at)) : '?';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.delete_forever_rounded, color: _red),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Compte supprimé à la demande de l\'utilisateur',
                style: TextStyle(color: _textP, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Accès désactivé. Effacement définitif prévu le $date.',
            style: TextStyle(color: _textS, fontSize: 13)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _restoreAccount,
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: const Text('Restaurer le compte'),
          style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Future<void> _restoreAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer ce compte ?'),
        content: const Text('La personne pourra de nouveau se connecter et la suppression est annulée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('restoreDeletedAccount')
          .call({'userId': _userData!.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte restauré')));
      await _loadUserData();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Restauration impossible')));
    }
  }

  Future<void> _toggleVerification() async {
    if (_userData == null) return;
    final newValue = !(_userData!.isVerify == true);
    final pseudo = _userData!.pseudo ?? widget.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          newValue ? 'Certifier ce compte ?' : 'Retirer la certification ?',
          style: TextStyle(color: _textP, fontWeight: FontWeight.w700),
        ),
        content: Text(
          newValue
              ? 'Le compte @$pseudo sera certifié. Un badge ✓ apparaîtra sur son profil et une notification lui sera envoyée.'
              : 'Le badge de vérification du compte @$pseudo sera retiré. Une notification lui sera envoyée.',
          style: TextStyle(color: _textS, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: _textS)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? _green : _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newValue ? 'Certifier' : 'Retirer',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isUpdating = true);

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final adminId = authProvider.userId ?? '';

      // 1. Mise à jour Firestore
      await _firestore.collection('Users').doc(widget.userId).update({
        'isVerify': newValue,
        'verifiedAt': newValue ? DateTime.now().millisecondsSinceEpoch : null,
        'verifiedBy': adminId,
      });

      // 2. Notification in-app (collection Notifications)
      final notifId = _firestore.collection('Notifications').doc().id;
      final notif = NotificationData(
        id: notifId,
        titre: newValue ? '✅ Compte certifié !' : 'Certification retirée',
        media_url: _userData!.imageUrl ?? '',
        type: NotificationType.CERTIFICATION.name,
        description: newValue
            ? 'Félicitations ! Votre compte Afrolook a été certifié. Le badge de vérification ✓ est maintenant visible sur votre profil.'
            : 'La certification de votre compte a été retirée par l\'administration Afrolook.',
        users_id_view: [],
        user_id: adminId,
        receiver_id: widget.userId,
        post_id: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _firestore.collection('Notifications').doc(notifId).set(notif.toJson());

      // 3. Push notification OneSignal
      final osId = _userData!.oneIgnalUserid ?? '';
      if (osId.length > 5) {
        await authProvider.sendNotification(
          appName: 'Afrolook',
          userIds: [osId],
          smallImage: _userData!.imageUrl ?? '',
          send_user_id: adminId,
          recever_user_id: widget.userId,
          message: newValue
              ? '✅ Votre compte Afrolook a été certifié !'
              : 'La certification de votre compte a été retirée.',
          type_notif: NotificationType.CERTIFICATION.name,
          post_id: '',
          post_type: '',
          chat_id: '',
        );
      }

      setState(() {
        _userData!.isVerify = newValue;
        _isUpdating = false;
      });
      _showSnack(
        newValue ? '✅ Compte @$pseudo certifié' : 'Certification retirée pour @$pseudo',
        newValue ? _green : _amber,
      );
    } catch (e) {
      printVm('Erreur certification: $e');
      setState(() => _isUpdating = false);
      _showSnack('Erreur lors de la mise à jour', _red);
    }
  }

  // ── Opérations solde FCFA ─────────────────────────────────────────────────

  Future<void> _updateUserBalance(
    double amount, String type, String description, String raison, {
    String balanceField = 'votre_solde_principal',
  }) async {
    if (_userData == null) return;
    final adminId = Provider.of<UserAuthProvider>(context, listen: false).userId;
    setState(() => _isUpdating = true);
    try {
      final current = balanceField == 'votre_solde_depot'
          ? (_userData!.votre_solde_depot ?? 0.0)
          : (_userData!.votre_solde_principal ?? 0.0);
      final newBal = current + amount;

      await _firestore.collection('Users').doc(widget.userId).update({
        balanceField: newBal,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount.abs(),
        'type': type,
        'description': description,
        'raison': raison,
        'balance_field': balanceField,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'processed_by': adminId,
      });
      setState(() {
        if (balanceField == 'votre_solde_depot') {
          _userData!.votre_solde_depot = newBal;
        } else {
          _userData!.votre_solde_principal = newBal;
        }
      });
      _showSnack('Opération effectuée !', _green);
    } catch (e) {
      _showSnack('Erreur : $e', _red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ── Opérations pièces ─────────────────────────────────────────────────────

  /// Crédit / débit de pièces par l'admin.
  /// [depot] = true : Pièces de dépôt (non convertibles, même calcul que coin_locks.ts) ;
  /// false : Pièces gagnées (convertibles en argent).
  Future<void> _updateCoinsBalance(int amount, String raison, {required bool depot}) async {
    if (_userData == null) return;
    final adminId = Provider.of<UserAuthProvider>(context, listen: false).userId;
    final userRef = _firestore.collection('Users').doc(widget.userId);
    setState(() => _isUpdating = true);
    try {
      final updated = await _firestore.runTransaction<UserData>((tx) async {
        final snap = await tx.get(userRef);
        final u = UserData.fromJson(snap.data() ?? {});
        final balance = u.giftCoinsBalance ?? 0;
        final locked = u.lockedGiftCoins;
        final convertible = u.convertibleGiftCoins;
        if (amount < 0 && -amount > (depot ? locked : convertible)) {
          throw Exception(depot
              ? 'Pièces de dépôt insuffisantes (${depot ? locked : convertible})'
              : 'Pièces gagnées insuffisantes ($convertible)');
        }
        // Le verrou est « figé » à la valeur actuelle puis ajusté pour les pièces de dépôt.
        final newLocked = depot ? (locked + amount).clamp(0, 1 << 40) : locked;
        tx.update(userRef, {
          'giftCoinsBalance': FieldValue.increment(amount),
          'lockedCoins': newLocked,
          'lockedCoinsSpentBaseline': u.totalGiftCoinsSpent ?? 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        final label = depot ? 'pièces de dépôt' : 'pièces gagnées';
        tx.set(_firestore.collection('TransactionSoldes').doc(), {
          'user_id': _userData!.id,
          'montant': amount.abs(),
          // DEPENSE + « pieces » : montant lu en pièces dans l'historique (TxAmount)
          'type': amount > 0 ? 'GAIN_PIECES' : 'DEPENSE',
          'methode_paiement': amount > 0 ? (depot ? 'admin_depot' : 'admin_gagnees') : 'pieces',
          'description': amount > 0 ? 'Crédit $label (admin)' : 'Débit $label (admin)',
          'raison': raison,
          'balance_field': 'giftCoinsBalance',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'statut': StatutTransaction.VALIDER.name,
          'processed_by': adminId,
        });
        return u
          ..giftCoinsBalance = balance + amount
          ..lockedCoins = newLocked
          ..lockedCoinsSpentBaseline = u.totalGiftCoinsSpent ?? 0;
      });
      setState(() {
        _userData!
          ..giftCoinsBalance = updated.giftCoinsBalance
          ..lockedCoins = updated.lockedCoins
          ..lockedCoinsSpentBaseline = updated.lockedCoinsSpentBaseline;
      });
      _showSnack('${amount > 0 ? '+' : ''}$amount pièce(s) appliquée(s)', _gold);
    } catch (e) {
      _showSnack('Erreur : ${e.toString().replaceFirst('Exception: ', '')}', _red);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showBalanceDialog({required bool isDeposit, required String field}) {
    final montantCtrl     = TextEditingController();
    final raisonCtrl      = TextEditingController();
    final descCtrl        = TextEditingController();
    final isDepotField    = field == 'votre_solde_depot';
    final color           = isDeposit ? _green : _amber;
    final label           = isDepotField ? 'Dépôt FCFA' : 'Gains à retirer';

    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: isDeposit ? 'Crédit — $label' : 'Débit — $label',
        accentColor: color,
        icon: isDeposit ? Iconsax.add_circle : Iconsax.minus_cirlce,
        currentAmount: isDepotField
            ? (_userData!.votre_solde_depot ?? 0).toStringAsFixed(2)
            : (_userData!.votre_solde_principal ?? 0).toStringAsFixed(2),
        unit: 'FCFA',
        onConfirm: (montant, raison, desc) {
          final val = double.tryParse(montant) ?? 0;
          if (val <= 0) return;
          _updateUserBalance(
            isDeposit ? val : -val,
            isDeposit ? TypeTransaction.DEPOTADMIN.name : TypeTransaction.RETRAITADMIN.name,
            desc.isNotEmpty ? desc : (isDeposit ? 'Dépôt administratif' : 'Retrait administratif'),
            raison,
            balanceField: field,
          );
        },
        montantCtrl: montantCtrl,
        raisonCtrl: raisonCtrl,
        descCtrl: descCtrl,
      ),
    );
  }

  void _showCoinsDialog({required bool isDeposit, required bool depot}) {
    final montantCtrl = TextEditingController();
    final raisonCtrl  = TextEditingController();
    final descCtrl    = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: '${isDeposit ? 'Crédit' : 'Débit'} — ${depot ? 'Pièces de dépôt' : 'Pièces gagnées'}',
        accentColor: depot ? _gold : _green,
        icon: isDeposit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
        currentAmount: (depot ? _userData!.lockedGiftCoins : _userData!.convertibleGiftCoins).toString(),
        unit: 'pièces',
        onConfirm: (montant, raison, desc) {
          final val = int.tryParse(montant) ?? 0;
          if (val <= 0) return;
          _updateCoinsBalance(isDeposit ? val : -val, raison, depot: depot);
        },
        montantCtrl: montantCtrl,
        raisonCtrl: raisonCtrl,
        descCtrl: descCtrl,
        isInt: true,
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDate(int ts) {
    if (ts == 0) return '—';
    final ms = ts > 9999999999999 ? ts ~/ 1000 : ts;
    return DateFormat('dd MMM yyyy  HH:mm', 'fr').format(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    AdminPalette.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }
    if (_userData == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _bg, foregroundColor: _textP),
        body: Center(
          child: Text('Utilisateur introuvable', style: TextStyle(color: _textS)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _isUpdating
          ? Center(child: CircularProgressIndicator(color: _gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_userData!.accountStatus == 'PENDING_DELETION') ...[
                    _buildDeletionBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildCertificationSection(),
                  const SizedBox(height: 16),
                  _buildBalancesSection(),
                  const SizedBox(height: 16),
                  _buildActionsSection(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildInfoSection(),
                  if ((_userData!.interests ?? []).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInterestsCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildPostsSection(),
                ],
              ),
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final pseudo = _userData?.pseudo ?? widget.userId;
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textP,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('@$pseudo',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textP)),
          Text('Gestion utilisateur',
              style: TextStyle(fontSize: 11, color: _textS, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.refresh, size: 20),
          tooltip: 'Actualiser',
          onPressed: () { setState(() => _isLoading = true); _loadUserData(); },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          color: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) {
            if (v == 'transactions') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => UserTransactionsPage(userId: widget.userId)));
            } else if (v == 'monetisation') {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => MesGainsPage(userId: widget.userId, isAdminView: true)));
            } else if (v == 'profil') {
              showUserDetailsModalDialog(
                _userData!, MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height, context);
            } else if (v == 'copier') {
              Clipboard.setData(ClipboardData(text: widget.userId));
              _showSnack('ID copié', _blue);
            }
          },
          itemBuilder: (_) => [
            _menuItem('profil',       Icons.person_outline,        'Voir le profil'),
            _menuItem('transactions', Iconsax.receipt,             'Transactions'),
            _menuItem('monetisation', Iconsax.money,               'Monétisation posts'),
            const PopupMenuDivider(),
            _menuItem('copier',       Icons.copy_rounded,          'Copier l\'ID utilisateur'),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: _textS),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: _textP, fontSize: 14)),
      ]),
    );
  }

  // ── Profil ────────────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final isBlocked  = _userData!.isBlocked == true;
    final isVerified = _userData!.isVerify  == true;
    final role       = _userData!.role ?? '';
    final imgUrl     = _userData!.imageUrl ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isBlocked ? _red : _gold, width: 2.5),
            ),
            child: CircleAvatar(onBackgroundImageError: (imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null) != null ? (Object _, StackTrace? __) {} : null, 
              radius: 36,
              backgroundColor: _surface,
              backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
              child: imgUrl.isEmpty ? Icon(Icons.person, size: 36, color: _textS) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData!.pseudo ?? '—',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _textP, height: 1.1),
                ),
                const SizedBox(height: 3),
                if ((_userData!.email ?? '').isNotEmpty)
                  Text(_userData!.email!, style: TextStyle(fontSize: 12, color: _textS)),
                if ((_userData!.numeroDeTelephone ?? '').isNotEmpty)
                  Text(_userData!.numeroDeTelephone!, style: TextStyle(fontSize: 12, color: _textS)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _StatusChip(
                    label: isVerified ? 'Vérifié' : 'Non vérifié',
                    color: isVerified ? _green : _textS,
                    icon: isVerified ? Icons.verified_rounded : Icons.help_outline_rounded,
                  ),
                  _StatusChip(
                    label: isBlocked ? 'Bloqué' : 'Actif',
                    color: isBlocked ? _red : _green,
                    icon: isBlocked ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  ),
                  if (role.isNotEmpty)
                    _StatusChip(
                      label: role == 'ADM' ? 'Admin' : role,
                      color: _gold,
                      icon: Icons.shield_outlined,
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section certification ─────────────────────────────────────────────────

  Widget _buildCertificationSection() {
    final isVerified = _userData!.isVerify == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CERTIFICATION'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isVerified ? _green.withOpacity(0.45) : _border,
              width: 1.3,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isVerified
                      ? _green.withOpacity(0.15)
                      : const Color(0xFF2A2A3A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.verified_rounded : Icons.help_outline_rounded,
                  color: isVerified ? _green : _textS,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified ? 'Compte certifié' : 'Non certifié',
                      style: TextStyle(
                        color: isVerified ? _green : _textP,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVerified
                          ? 'Badge ✓ visible sur le profil public'
                          : 'Aucun badge de vérification',
                      style: TextStyle(color: _textS, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _toggleVerification,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? _red.withOpacity(0.12)
                        : _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isVerified ? _red : _green,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    isVerified ? 'Retirer' : 'Certifier',
                    style: TextStyle(
                      color: isVerified ? _red : _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Soldes ────────────────────────────────────────────────────────────────

  Widget _buildBalancesSection() {
    final depot  = _userData!.votre_solde_depot     ?? 0.0;
    final gains  = _userData!.votre_solde_principal ?? 0.0;
    final pDepot = _userData!.lockedGiftCoins;
    final pGagne = _userData!.convertibleGiftCoins;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ARGENT (FCFA)'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _BalanceCard(
            label: 'Dépôt FCFA',
            amount: depot.toStringAsFixed(2),
            unit: 'FCFA',
            accentColor: _blue,
            isNegative: depot < 0,
            onAdd:    () => _showBalanceDialog(isDeposit: true,  field: 'votre_solde_depot'),
            onRemove: () => _showBalanceDialog(isDeposit: false, field: 'votre_solde_depot'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _BalanceCard(
            label: 'Gains à retirer',
            amount: gains.toStringAsFixed(2),
            unit: 'FCFA',
            accentColor: _amber,
            isNegative: gains < 0,
            onAdd:    () => _showBalanceDialog(isDeposit: true,  field: 'votre_solde_principal'),
            onRemove: () => _showBalanceDialog(isDeposit: false, field: 'votre_solde_principal'),
          )),
        ]),
        const SizedBox(height: 16),
        _sectionLabel('PIÈCES'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _BalanceCard(
            label: 'Pièces de dépôt',
            amount: '$pDepot',
            unit: 'non convertibles',
            accentColor: _gold,
            isNegative: false,
            onAdd:    () => _showCoinsDialog(isDeposit: true,  depot: true),
            onRemove: () => _showCoinsDialog(isDeposit: false, depot: true),
          )),
          const SizedBox(width: 10),
          Expanded(child: _BalanceCard(
            label: 'Pièces gagnées',
            amount: '$pGagne',
            unit: 'convertibles',
            accentColor: _green,
            isNegative: false,
            onAdd:    () => _showCoinsDialog(isDeposit: true,  depot: false),
            onRemove: () => _showCoinsDialog(isDeposit: false, depot: false),
          )),
        ]),
      ],
    );
  }

  // ── Statistiques ──────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final abonnes = (_userData!.userAbonnesIds ?? []).length;
    final pubs    = _userData!.mesPubs ?? 0;
    final likes   = _userData!.likes   ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STATISTIQUES'),
        const SizedBox(height: 10),
        Row(children: [
          _StatCell(label: 'Abonnés',      value: _fmtNum(abonnes), icon: Iconsax.people),
          const SizedBox(width: 10),
          _StatCell(label: 'Publications', value: _fmtNum(pubs),    icon: Iconsax.gallery),
          const SizedBox(width: 10),
          _StatCell(label: 'Likes',        value: _fmtNum(likes),   icon: Iconsax.heart),
        ]),
      ],
    );
  }

  // ── Informations ──────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: () => setState(() => _infoExpanded = !_infoExpanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                _sectionLabel('INFORMATIONS', inline: true),
                const Spacer(),
                Icon(
                  _infoExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _textS, size: 22,
                ),
              ]),
            ),
          ),
          if (_infoExpanded) ...[
            Divider(color: _border, height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _InfoRow('Nom complet',    '${_userData!.nom ?? ''} ${_userData!.prenom ?? ''}'.trim()),
                  _InfoRow('Genre',          _userData!.genre ?? '—'),
                  _InfoRow('Adresse',        _userData!.adresse ?? '—'),
                  _InfoRow('Code parrainage',_userData!.codeParrainage ?? '—'),
                  _InfoRow('Code parrain',   _userData!.codeParrain ?? '—'),
                  _InfoRow('Rôle',           _userData!.role?.isNotEmpty == true ? _userData!.role! : 'Utilisateur'),
                  _InfoRow('Créé le',        _formatDate(_userData!.createdAt ?? 0)),
                  _InfoRow('Dernière activité', _formatDate(_userData!.last_time_active ?? 0)),
                  _InfoRow('ID',             widget.userId, mono: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Intérêts ──────────────────────────────────────────────────────────────

  Widget _buildInterestsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CENTRES D\'INTÉRÊT'),
          const SizedBox(height: 12),
          InterestsDisplayWidget(codes: _userData!.interests ?? [], compact: true),
        ],
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {bool inline = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _textS,
        height: inline ? 1 : null,
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Composants réutilisables ─────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color  color;
  final IconData icon;
  const _StatusChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String amount;
  final String unit;
  final Color  accentColor;
  final String? emoji;
  final bool   isNegative;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.unit,
    required this.accentColor,
    required this.isNegative,
    required this.onAdd,
    required this.onRemove,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = isNegative ? _red : accentColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNegative ? _red.withOpacity(0.4) : displayColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + boutons
          Row(children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(label.toUpperCase(),
                style: TextStyle(fontSize: 10, color: _textS,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const Spacer(),
            _ActionBtn(icon: Icons.remove_rounded, color: displayColor, onTap: onRemove),
            const SizedBox(width: 4),
            _ActionBtn(icon: Icons.add_rounded,    color: displayColor, onTap: onAdd,  filled: true),
          ]),
          const SizedBox(height: 10),
          // Montant
          Text(
            amount,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: displayColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(unit,
              style: TextStyle(fontSize: 11, color: _textS, fontWeight: FontWeight.w500)),
          if (isNegative)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 12, color: _red),
                SizedBox(width: 4),
                Text('Solde négatif', style: TextStyle(fontSize: 10, color: _red)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  final bool     filled;
  const _ActionBtn({required this.icon, required this.color, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(filled ? 0 : 0.3)),
        ),
        child: Icon(icon, size: 16, color: filled ? Colors.white : color),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCell({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: _textS),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: _textP, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: _textS),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   mono;
  const _InfoRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: _textS, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                color: _textP,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog admin générique ────────────────────────────────────────────────────

class _AdminDialog extends StatelessWidget {
  final String     title;
  final Color      accentColor;
  final IconData   icon;
  final String     currentAmount;
  final String     unit;
  final bool       isInt;
  final Function(String montant, String raison, String desc) onConfirm;
  final TextEditingController montantCtrl;
  final TextEditingController raisonCtrl;
  final TextEditingController descCtrl;

  const _AdminDialog({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.currentAmount,
    required this.unit,
    required this.onConfirm,
    required this.montantCtrl,
    required this.raisonCtrl,
    required this.descCtrl,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: TextStyle(color: accentColor, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.2)),
              ),
              child: Row(children: [
                Text('Solde actuel', style: TextStyle(color: _textS, fontSize: 12)),
                const Spacer(),
                Text('$currentAmount $unit',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 14),
            _DialogField(
              controller: montantCtrl,
              label: 'Montant',
              hint: '0',
              keyboardType: isInt
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              suffix: unit,
              accentColor: accentColor,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: raisonCtrl,
              label: 'Raison *',
              hint: 'Motif obligatoire',
              accentColor: accentColor,
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: descCtrl,
              label: 'Description',
              hint: 'Optionnel',
              maxLines: 2,
              accentColor: accentColor,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: _textS)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            if (raisonCtrl.text.trim().isEmpty) return;
            Navigator.pop(context);
            onConfirm(montantCtrl.text.trim(), raisonCtrl.text.trim(), descCtrl.text.trim());
          },
          child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? suffix;
  final int maxLines;
  final TextInputType keyboardType;
  final Color accentColor;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.accentColor,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _textS, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: _textP, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _textS, fontSize: 13),
            suffixText: suffix,
            suffixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor.withOpacity(0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
