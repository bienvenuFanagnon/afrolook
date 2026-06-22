import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
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

                // Paramètres admin
                if (isOwnerOrAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'PARAMÈTRES ADMIN',
                      style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ),
                  SwitchListTile(
                    value: _groupData['is_read_only'] == true,
                    activeColor: _colors.primary,
                    secondary: Icon(Icons.edit_off_rounded, color: _colors.primary),
                    title: Text('Mode lecture seule', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Seuls les admins peuvent écrire', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                    onChanged: _toggleReadOnly,
                  ),
                  Divider(color: _colors.border.withOpacity(0.3)),
                  const SizedBox(height: 8),
                ],

                // Section membres
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_members.length} MEMBRE(S)',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                  ),
                ),
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
        Text(
          _groupData['name'] as String? ?? widget.groupName,
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        Text(
          '${_members.length} membres',
          style: TextStyle(color: _colors.textSecondary, fontSize: 13),
        ),
      ],
    );
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
              'Groupe gelé — le propriétaire n\'est plus Premium. Les messages sont en lecture seule.',
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

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
        backgroundColor: _colors.surfaceVariant,
        child: imageUrl.isEmpty ? Icon(Icons.person, color: _colors.textSecondary) : null,
      ),
      title: Text('@$pseudo', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: isMe ? Text('Vous', style: TextStyle(color: _colors.primary, fontSize: 12)) : null,
      trailing: _buildRoleBadge(role),
      onLongPress: canManage && !isMe && role != 'owner'
          ? () => _showMemberOptions(userId, pseudo, role)
          : null,
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
    final memberDoc = await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(widget.groupId)
        .collection('members')
        .doc(userId)
        .get();
    final current = (memberDoc.data()?['permissions'] as Map<String, dynamic>?) ?? {};

    final perms = <String, bool>{
      'can_share': current['can_share'] == true,
      'can_delete_others': current['can_delete_others'] == true,
      'can_pin': current['can_pin'] == true,
      'can_invite': current['can_invite'] == true,
    };

    final labels = {
      'can_share': 'Partager des contenus',
      'can_delete_others': 'Supprimer les messages des autres',
      'can_pin': 'Épingler des messages',
      'can_invite': 'Inviter des membres',
    };

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Container(
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
                ...perms.entries.map((e) => SwitchListTile(
                  value: e.value,
                  activeColor: _colors.primary,
                  title: Text(labels[e.key]!, style: TextStyle(color: _colors.textPrimary, fontSize: 14)),
                  onChanged: (val) {
                    setStateDialog(() => perms[e.key] = val);
                    FirebaseFirestore.instance
                        .collection('GroupChats')
                        .doc(widget.groupId)
                        .collection('members')
                        .doc(userId)
                        .update({'permissions.${e.key}': val});
                  },
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
