import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../../services/utils/group_permission_utils.dart';
import '../../../theme/app_colors.dart';

class GroupInfoPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoPage({Key? key, required this.groupId, required this.groupName}) : super(key: key);

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late AppColors _colors;
  late UserAuthProvider _auth;

  Map<String, dynamic> _groupData = {};
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String _myRole = 'member';

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final myId = _auth.loginUserData.id!;
      final groupDoc = await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(widget.groupId)
          .get();
      final membersSnap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('members')
          .get();

      final members = membersSnap.docs.map((d) => d.data()).toList();
      final myMember = members.firstWhere((m) => m['user_id'] == myId, orElse: () => {});

      if (mounted) {
        setState(() {
          _groupData = groupDoc.data() ?? {};
          _members = members;
          _myRole = myMember['role'] as String? ?? 'member';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeMember(String userId) async {
    await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(widget.groupId)
        .collection('members')
        .doc(userId)
        .delete();
    await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({
      'member_count': FieldValue.increment(-1),
      'member_ids': FieldValue.arrayRemove([userId]),
    });
    _loadGroup();
  }

  Future<void> _promoteToAdmin(String userId) async {
    await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(widget.groupId)
        .collection('members')
        .doc(userId)
        .update({'role': 'admin'});
    _loadGroup();
  }

  Future<void> _leaveGroup() async {
    final myId = _auth.loginUserData.id!;
    final myPseudo = _auth.loginUserData.pseudo ?? '';
    final confirmed = await _showConfirmDialog(
      'Quitter le groupe',
      'Voulez-vous vraiment quitter ce groupe ?',
    );
    if (!confirmed) return;

    await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(widget.groupId)
        .collection('members')
        .doc(myId)
        .delete();
    await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({
      'member_count': FieldValue.increment(-1),
      'member_ids': FieldValue.arrayRemove([myId]),
    });

    // Notifier le propriétaire
    _notifyOwnerMemberLeft(myId, myPseudo);

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _notifyOwnerMemberLeft(String leaverId, String leaverPseudo) async {
    try {
      final ownerId = _groupData['owner_id'] as String?;
      if (ownerId == null || ownerId == leaverId) return;
      final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
      final oneSignalId = ownerDoc.data()?['oneIgnalUserid'] as String?;
      if (oneSignalId == null || oneSignalId.length <= 5) return;
      final groupName = _groupData['name'] as String? ?? widget.groupName;
      await _auth.sendNotification(
        userIds: [oneSignalId],
        smallImage: '',
        send_user_id: leaverId,
        recever_user_id: ownerId,
        message: '@$leaverPseudo a quitté le groupe "$groupName"',
        type_notif: NotificationType.MESSAGE.name,
        post_id: '',
        post_type: '',
        chat_id: widget.groupId,
      );
    } catch (_) {}
  }

  Future<void> _showAddMemberSheet() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final controller = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text('Ajouter un membre',
                        style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par pseudo...',
                        hintStyle: TextStyle(color: _colors.textSecondary),
                        prefixIcon: Icon(Icons.search, color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (q) async {
                        if (q.length < 2) {
                          setModalState(() => results = []);
                          return;
                        }
                        setModalState(() => searching = true);
                        final found = await userProvider.searchUsersByPseudo(q);
                        final existingIds = _members.map((m) => m['user_id'] as String).toSet();
                        setModalState(() {
                          results = found.where((u) => !existingIds.contains(u.id)).toList();
                          searching = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (searching)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2),
                    )
                  else
                    ...results.map((u) => ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: _colors.surfaceVariant,
                        backgroundImage: (u.imageUrl ?? '').isNotEmpty
                            ? CachedNetworkImageProvider(u.imageUrl!)
                            : null,
                        child: (u.imageUrl ?? '').isEmpty
                            ? Icon(Icons.person, size: 16, color: _colors.textSecondary)
                            : null,
                      ),
                      title: Text('@${u.pseudo ?? ''}',
                          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.person_add_rounded, color: _colors.primary),
                      onTap: () {
                        Navigator.pop(ctx);
                        _addMember(u.id!, u.pseudo ?? '', u.imageUrl ?? '', u.oneIgnalUserid ?? '');
                      },
                    )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _addMember(String userId, String pseudo, String imageUrl, String oneSignalId) async {
    try {
      final groupName = _groupData['name'] as String? ?? widget.groupName;
      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(widget.groupId)
          .collection('members')
          .doc(userId)
          .set({
        'user_id': userId,
        'pseudo': pseudo,
        'image_url': imageUrl,
        'role': 'member',
        'joined_at': DateTime.now().millisecondsSinceEpoch,
      });
      await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({
        'member_count': FieldValue.increment(1),
        'member_ids': FieldValue.arrayUnion([userId]),
      });
      // Notification
      if (oneSignalId.length > 5) {
        final myId = _auth.loginUserData.id!;
        await _auth.sendNotification(
          userIds: [oneSignalId],
          smallImage: _auth.loginUserData.imageUrl ?? '',
          send_user_id: myId,
          recever_user_id: userId,
          message: 'Vous avez été ajouté au groupe "$groupName"',
          type_notif: NotificationType.MESSAGE.name,
          post_id: '',
          post_type: '',
          chat_id: widget.groupId,
        );
      }
      _loadGroup();
    } catch (_) {}
  }

  Future<void> _toggleReadOnly(bool value) async {
    // Réservé aux membres Premium
    final isPremium = _auth.loginUserData.abonnement?.estPremium == true;
    if (!isPremium) {
      _showPremiumGate();
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(widget.groupId)
          .update({'is_read_only': value});
      if (mounted) {
        setState(() => _groupData = {..._groupData, 'is_read_only': value});
      }
    } catch (_) {}
  }

  void _showPremiumGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1FAA59), Color(0xFF2ECC71)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Fonctionnalité Premium 👑',
              style: TextStyle(color: _colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Le mode lecture seule est réservé aux membres Premium.\nPassez à Premium pour débloquer cette fonctionnalité et bien plus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _colors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/abonnement');
                },
                child: const Text('Devenir Premium', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final isFrozen = _groupData['is_frozen'] == true;
    final imageUrl = _groupData['image_url'] as String?;
    final isOwnerOrAdmin = _myRole == 'owner' || _myRole == 'admin';

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Info groupe',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (isOwnerOrAdmin)
            IconButton(
              icon: Icon(Icons.person_add_alt_1_rounded, color: _colors.primary),
              tooltip: 'Ajouter un membre',
              onPressed: _showAddMemberSheet,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // En-tête groupe
                _buildGroupHeader(imageUrl, isFrozen),
                const SizedBox(height: 16),

                // Bannière gelé
                if (isFrozen) _buildFrozenBanner(),

                // Description
                if ((_groupData['description'] as String? ?? '').isNotEmpty)
                  _buildInfoTile(Icons.info_outline_rounded, _groupData['description'] as String),

                const SizedBox(height: 16),

                // Paramètres admin (Premium)
                if (isOwnerOrAdmin) ...[
                  _buildSectionTitle('PARAMÈTRES ADMIN'),
                  Builder(builder: (context) {
                    final hasPremium = _auth.loginUserData.abonnement?.estPremium == true;
                    return SwitchListTile(
                      value: _groupData['is_read_only'] == true,
                      activeColor: _colors.primary,
                      secondary: Icon(
                        hasPremium ? Icons.edit_off_rounded : Icons.lock_rounded,
                        color: hasPremium ? _colors.primary : _colors.textSecondary,
                      ),
                      title: Row(
                        children: [
                          Text('Mode lecture seule', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                          if (!hasPremium) ...[
                            const SizedBox(width: 6),
                            _planBadge('Premium', const Color(0xFFFDB813)),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        hasPremium ? 'Seuls les admins peuvent écrire' : 'Passez Premium pour activer',
                        style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                      ),
                      onChanged: _toggleReadOnly,
                    );
                  }),
                  Divider(color: _colors.border.withOpacity(0.3)),
                  const SizedBox(height: 8),
                ],

                // Section Gold — visible pour le propriétaire uniquement
                if (_myRole == 'owner') ...[
                  _buildSectionTitle('FONCTIONNALITÉS GOLD'),
                  _buildGoldFeaturesSection(),
                  const SizedBox(height: 8),
                ],

                // Section membres — afficher la limite selon le plan du propriétaire
                Builder(builder: (ctx) {
                  final isOwner = _myRole == 'owner';
                  final myAb = isOwner ? _auth.loginUserData.abonnement : null;
                  final maxM = AbonnementUtils.maxGroupMembers(myAb);
                  final countLabel = isOwner && maxM != null
                      ? '${_members.length} / $maxM MEMBRE(S)'
                      : '${_members.length} MEMBRE(S)';
                  return _buildSectionTitle(countLabel);
                }),
                const SizedBox(height: 8),
                ..._members.map((m) => _buildMemberTile(m, isOwnerOrAdmin)),
                const SizedBox(height: 16),

                // Quitter le groupe
                if (_myRole != 'owner')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _leaveGroup,
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                      label: const Text('Quitter le groupe', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildGroupHeader(String? imageUrl, bool isFrozen) {
    final isPrivate = _groupData['is_private'] == true;
    final subscriptionPrice = (_groupData['subscription_price'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: _colors.surfaceVariant,
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(imageUrl)
                  : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 40)
                  : null,
            ),
            if (isFrozen)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.pause_rounded, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _groupData['name'] as String? ?? widget.groupName,
              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (isPrivate) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                ),
                child: const Text(
                  '🔒 Privé',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${_members.length} membres',
          style: TextStyle(color: _colors.textSecondary, fontSize: 13),
        ),
        if (isPrivate && subscriptionPrice > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${subscriptionPrice.toStringAsFixed(0)} FCFA / mois',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        title,
        style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }

  Widget _planBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // ── Section Gold complète ──────────────────────────────────────────────────

  Widget _buildGoldFeaturesSection() {
    final isGold = AbonnementUtils.isGold(_auth.loginUserData.abonnement);
    final isPrivate = _groupData['is_private'] == true;
    final price = (_groupData['subscription_price'] as num?)?.toDouble() ?? 0.0;
    final joinCode = _groupData['join_code'] as String?;
    final codeExpiresAt = _groupData['join_code_expires_at'] as int?;
    final paidSubs = (_groupData['paid_subscribers'] as Map<String, dynamic>?) ?? {};
    final now = DateTime.now().millisecondsSinceEpoch;
    final codeExpired = codeExpiresAt != null && codeExpiresAt < now;
    final daysLeft = codeExpiresAt != null
        ? ((codeExpiresAt - now) / (1000 * 60 * 60 * 24)).ceil()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGold
              ? [const Color(0xFFFFD700).withOpacity(0.10), const Color(0xFFFF8C00).withOpacity(0.06)]
              : [_colors.surface, _colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGold
              ? const Color(0xFFFFD700).withOpacity(0.4)
              : _colors.border.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Gold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isGold
                  ? const Color(0xFFFFD700).withOpacity(0.12)
                  : _colors.surfaceVariant.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Plan Gold',
                  style: TextStyle(
                    color: isGold ? const Color(0xFFFFD700) : _colors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (!isGold)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/abonnement'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Passer Gold',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Actif', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 1. Code d'accès unique
          _buildGoldFeatureTile(
            icon: Icons.key_rounded,
            title: 'Code d\'accès unique (30 jours)',
            subtitle: isGold
                ? (joinCode == null || codeExpired
                    ? 'Code expiré — appuyez pour régénérer'
                    : 'Valide encore $daysLeft jour${daysLeft > 1 ? 's' : ''}')
                : 'Partagez un code pour que les membres rejoignent votre groupe',
            isGold: isGold,
            isActive: isGold && joinCode != null && !codeExpired,
            isExpired: isGold && (joinCode == null || codeExpired),
            trailing: isGold
                ? _buildJoinCodeInline(joinCode, codeExpired, daysLeft)
                : null,
          ),

          // Bouton partage lien (Gold + code valide seulement)
          if (isGold && joinCode != null && !codeExpired)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () => _shareGroupLink(joinCode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ios_share_rounded, color: Colors.black, size: 18),
                      SizedBox(width: 8),
                      Text('Partager le lien d\'invitation', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

          _buildDivider(),

          // 2. Groupe privé payant
          _buildGoldFeatureTile(
            icon: Icons.lock_rounded,
            title: 'Groupe privé payant',
            subtitle: isGold
                ? (isPrivate
                    ? 'Actif · ${price > 0 ? '${price.toStringAsFixed(0)} FCFA/mois' : 'Prix non défini'}'
                    : 'Non activé · définissez un prix d\'accès mensuel')
                : 'Rendez votre groupe payant avec abonnement mensuel pour les membres',
            isGold: isGold,
            isActive: isGold && isPrivate,
            trailing: isGold
                ? Switch(
                    value: isPrivate,
                    onChanged: (v) => _togglePrivate(v, price),
                    activeColor: const Color(0xFFFFD700),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),

          if (isGold && isPrivate) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prix mensuel : ${price > 0 ? '${price.toStringAsFixed(0)} FCFA' : 'Non défini'}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showEditPriceSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Modifier', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildDivider(),

          // 3. Revenus membres
          _buildGoldFeatureTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Revenus sur abonnements',
            subtitle: isGold
                ? '${paidSubs.length} abonné${paidSubs.length > 1 ? 's' : ''} · 70% vous revient · 30% plateforme'
                : 'Recevez 70% des abonnements de vos membres chaque mois',
            isGold: isGold,
            isActive: isGold && paidSubs.isNotEmpty,
            trailing: isGold && paidSubs.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${paidSubs.length} abonné${paidSubs.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
          ),

          _buildDivider(),

          // 4. Permissions d'écriture globales
          _buildGoldFeatureTile(
            icon: Icons.edit_rounded,
            title: 'Contrôle d\'écriture (global)',
            subtitle: isGold
                ? (_groupData['default_can_write'] == false
                    ? 'Désactivé — les membres ne peuvent pas écrire'
                    : 'Activé — les membres peuvent écrire')
                : 'Choisissez qui peut envoyer des messages dans le groupe',
            isGold: isGold,
            isActive: isGold,
            trailing: isGold
                ? Switch(
                    value: _groupData['default_can_write'] != false,
                    onChanged: (v) => _setDefaultPerm('default_can_write', v),
                    activeColor: const Color(0xFFFFD700),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),

          _buildDivider(),

          // 5. Permissions de partage globales
          _buildGoldFeatureTile(
            icon: Icons.share_rounded,
            title: 'Contrôle de partage (global)',
            subtitle: isGold
                ? (_groupData['default_can_share'] == false
                    ? 'Désactivé — les membres ne peuvent pas partager'
                    : 'Activé — les membres peuvent partager des contenus')
                : 'Contrôlez qui peut partager posts, produits, lives dans le groupe',
            isGold: isGold,
            isActive: isGold,
            trailing: isGold
                ? Switch(
                    value: _groupData['default_can_share'] != false,
                    onChanged: (v) => _setDefaultPerm('default_can_share', v),
                    activeColor: const Color(0xFFFFD700),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),

          _buildDivider(),

          // 6. Gestion de la visibilité des messages
          _buildGoldFeatureTile(
            icon: Icons.visibility_off_rounded,
            title: 'Visibilité des messages',
            subtitle: isGold
                ? (_groupData['allow_hidden_msgs'] == true
                    ? 'Activé — masquez un message existant ou choisissez qui peut le voir'
                    : 'Désactivé — activez pour gérer la visibilité de vos messages')
                : 'Masquez un message après envoi ou limitez sa visibilité à certains membres',
            isGold: isGold,
            isActive: isGold && _groupData['allow_hidden_msgs'] == true,
            trailing: isGold
                ? Switch(
                    value: _groupData['allow_hidden_msgs'] == true,
                    onChanged: (v) async {
                      await GroupPermissionUtils.setHiddenMessages(groupId: widget.groupId, value: v);
                      if (mounted) setState(() => _groupData['allow_hidden_msgs'] = v);
                    },
                    activeColor: Colors.purple,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),

          _buildDivider(),

          // 7. Liens externes cliquables dans les messages
          _buildGoldFeatureTile(
            icon: Icons.link_rounded,
            title: 'Liens externes cliquables',
            subtitle: isGold
                ? (_groupData['allow_external_links'] == true
                    ? 'Activé — les URLs dans les messages sont cliquables'
                    : 'Désactivé — activez pour rendre les liens cliquables dans le chat')
                : 'Les membres peuvent cliquer sur des URLs dans les messages pour accéder aux plateformes externes',
            isGold: isGold,
            isActive: isGold && _groupData['allow_external_links'] == true,
            trailing: isGold
                ? Switch(
                    value: _groupData['allow_external_links'] == true,
                    onChanged: (v) async {
                      await FirebaseFirestore.instance
                          .collection('GroupChats')
                          .doc(widget.groupId)
                          .update({'allow_external_links': v});
                      if (mounted) setState(() => _groupData['allow_external_links'] = v);
                    },
                    activeColor: Colors.blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),

          _buildDivider(),

          // 8. Carousel pub
          _buildGoldFeatureTile(
            icon: Icons.campaign_rounded,
            title: 'Visibilité dans le carousel Gold',
            subtitle: isGold
                ? 'Votre groupe est mis en avant dans la liste des conversations'
                : 'Votre groupe apparaît automatiquement dans le carousel de découverte',
            isGold: isGold,
            isActive: isGold,
          ),

          _buildDivider(),

          // 5. Badge Gold sur le groupe
          _buildGoldFeatureTile(
            icon: Icons.verified_rounded,
            title: 'Badge 👑 Gold sur le groupe',
            subtitle: isGold
                ? 'Votre groupe affiche le badge Gold dans toute l\'application'
                : 'Distinguez votre groupe avec un badge exclusif visible par tous',
            isGold: isGold,
            isActive: isGold,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGoldFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGold,
    bool isActive = false,
    bool isExpired = false,
    Widget? trailing,
  }) {
    final Color iconColor = isGold
        ? (isExpired ? Colors.orange : (isActive ? const Color(0xFFFFD700) : _colors.textSecondary))
        : _colors.textSecondary.withOpacity(0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isGold
                  ? (isActive ? const Color(0xFFFFD700).withOpacity(0.15) : _colors.surfaceVariant)
                  : _colors.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: iconColor, size: 18),
                if (!isGold)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: _colors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: _colors.border.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.lock_rounded, size: 8, color: Color(0xFFFFD700)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isGold ? _colors.textPrimary : _colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (!isGold) _planBadge('Gold', const Color(0xFFFFD700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isExpired ? Colors.orange : _colors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  void _shareGroupLink(String joinCode) {
    final link = 'https://afrolookmedia.com/share/group/$joinCode';
    final groupName = _groupData['name'] as String? ?? widget.groupName;
    final message = '👑 Rejoins mon groupe "$groupName" sur AfroLook !\nClique sur le lien pour rejoindre directement :\n$link';
    Share.share(message, subject: 'Invitation groupe Afrolook');
  }

  Widget _buildJoinCodeInline(String? code, bool expired, int daysLeft) {
    if (expired || code == null) {
      return GestureDetector(
        onTap: _regenerateJoinCode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.orange, size: 16),
              Text('Régénérer', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_rounded, size: 10, color: Color(0xFFFFD700)),
                const SizedBox(width: 3),
                Text('$daysLeft j', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(indent: 16, endIndent: 16, height: 1, color: _colors.border.withOpacity(0.2));
  }

  Future<void> _setDefaultPerm(String field, bool value) async {
    await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(widget.groupId)
        .update({field: value});
    if (mounted) setState(() => _groupData[field] = value);
  }

  Future<void> _regenerateJoinCode() async {
    try {
      final newCode = _generateJoinCode();
      final newExpiry = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({
        'join_code': newCode,
        'join_code_expires_at': newExpiry,
      });
      if (mounted) {
        setState(() {
          _groupData['join_code'] = newCode;
          _groupData['join_code_expires_at'] = newExpiry;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouveau code généré — valide 30 jours'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _togglePrivate(bool value, double currentPrice) async {
    try {
      await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({
        'is_private': value,
        if (!value) 'subscription_price': 0.0,
      });
      if (mounted) setState(() => _groupData['is_private'] = value);
      if (value && currentPrice <= 0) await _showEditPriceSheet();
    } catch (_) {}
  }

  Future<void> _showEditPriceSheet() async {
    final controller = TextEditingController(
      text: ((_groupData['subscription_price'] as num?)?.toDouble() ?? 0.0) > 0
          ? (_groupData['subscription_price'] as num).toStringAsFixed(0)
          : '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Prix d\'abonnement mensuel', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('70% vous revient · 30% plateforme Afrolook', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(color: _colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'ex: 500',
                  hintStyle: TextStyle(color: _colors.textSecondary),
                  suffix: const Text('FCFA/mois', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w600)),
                  filled: true,
                  fillColor: _colors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final price = double.tryParse(controller.text.trim()) ?? 0.0;
                    await FirebaseFirestore.instance.collection('GroupChats').doc(widget.groupId).update({'subscription_price': price});
                    if (mounted) {
                      setState(() => _groupData['subscription_price'] = price);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Widget _buildFrozenBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Groupe gelé — le propriétaire n\'est plus Premium ou Gold. Les messages sont en lecture seule.',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return ListTile(
      leading: Icon(icon, color: _colors.primary, size: 20),
      title: Text(text, style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, bool canManage) {
    final myId = _auth.loginUserData.id!;
    final userId = member['user_id'] as String;
    final pseudo = member['pseudo'] as String? ?? '';
    final imageUrl = member['image_url'] as String? ?? '';
    final role = member['role'] as String? ?? 'member';
    final isMe = userId == myId;

    final showManage = canManage && !isMe && role != 'owner';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
        backgroundColor: _colors.surfaceVariant,
        child: imageUrl.isEmpty ? Icon(Icons.person, color: _colors.textSecondary) : null,
      ),
      title: Text('@$pseudo', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: isMe ? Text('Vous', style: TextStyle(color: _colors.primary, fontSize: 12)) : null,
      trailing: showManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleBadge(role),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showMemberOptions(userId, pseudo, role),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune_rounded, size: 18, color: _colors.primary),
                  ),
                ),
              ],
            )
          : _buildRoleBadge(role),
      onLongPress: showManage ? () => _showMemberOptions(userId, pseudo, role) : null,
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'owner':
        color = const Color(0xFFFDB813);
        label = '👑 Propriétaire';
        break;
      case 'admin':
        color = Colors.blue;
        label = 'Admin';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  void _showMemberOptions(String userId, String pseudo, String role) {
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
                width: 36, height: 4,
                decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
              ),
              if (role == 'member')
                ListTile(
                  leading: Icon(Icons.admin_panel_settings_rounded, color: _colors.primary),
                  title: Text('Promouvoir admin', style: TextStyle(color: _colors.textPrimary)),
                  onTap: () { Navigator.pop(ctx); _promoteToAdmin(userId); },
                ),
              ListTile(
                leading: Icon(Icons.tune_rounded, color: _colors.primary),
                title: Text('Gérer les droits', style: TextStyle(color: _colors.textPrimary)),
                onTap: () { Navigator.pop(ctx); _showPermissionsDialog(userId, pseudo); },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.red),
                title: const Text('Retirer du groupe', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _removeMember(userId); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionsDialog(String userId, String pseudo) async {
    final isGold = AbonnementUtils.isGold(_auth.loginUserData.abonnement);

    // Lire les permissions actuelles depuis le document du groupe
    final allPerms = (_groupData['member_permissions'] as Map<String, dynamic>?) ?? {};
    final current = (allPerms[userId] as Map<String, dynamic>?) ?? {};

    // Valeurs par défaut du groupe si pas de permission individuelle
    final defaultWrite = _groupData['default_can_write'] != false;
    final defaultShare = _groupData['default_can_share'] != false;

    final perms = <String, bool>{
      'can_write': current['can_write'] ?? defaultWrite,
      'can_share': current['can_share'] ?? defaultShare,
      'can_delete_others': current['can_delete_others'] == true,
      'can_pin': current['can_pin'] == true,
      'can_invite': current['can_invite'] == true,
    };

    final labels = <String, String>{
      'can_write': 'Écrire des messages',
      'can_share': 'Partager (posts, produits, lives, contenus)',
      'can_delete_others': 'Supprimer les messages des autres',
      'can_pin': 'Épingler des messages',
      'can_invite': 'Inviter des membres',
    };

    final goldRequired = <String>{'can_write', 'can_share'};

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final maxH = MediaQuery.of(ctx).size.height * 0.7;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
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
                    // Poignée
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                    // Titre
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Droits de @$pseudo',
                              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Liste scrollable des permissions
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...perms.entries.map((e) {
                              final needsGold = goldRequired.contains(e.key);
                              final locked = needsGold && !isGold;
                              return SwitchListTile(
                                value: e.value,
                                activeColor: needsGold ? const Color(0xFFFFD700) : _colors.primary,
                                secondary: locked
                                    ? const Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 18)
                                    : null,
                                title: Row(
                                  children: [
                                    Expanded(child: Text(labels[e.key]!, style: TextStyle(color: locked ? _colors.textSecondary : _colors.textPrimary, fontSize: 14))),
                                    if (needsGold) ...[
                                      const SizedBox(width: 4),
                                      _planBadge('Gold', const Color(0xFFFFD700)),
                                    ],
                                  ],
                                ),
                                onChanged: locked ? null : (val) {
                                  setStateDialog(() => perms[e.key] = val);
                                  FirebaseFirestore.instance
                                      .collection('GroupChats')
                                      .doc(widget.groupId)
                                      .update({'member_permissions.$userId.${e.key}': val});
                                  final mp = Map<String, dynamic>.from(
                                      (_groupData['member_permissions'] as Map<String, dynamic>?) ?? {});
                                  mp[userId] = {...(mp[userId] as Map<String, dynamic>? ?? {}), e.key: val};
                                  setState(() => _groupData['member_permissions'] = mp);
                                },
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
