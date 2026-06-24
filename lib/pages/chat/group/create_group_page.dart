import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../../theme/app_colors.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  late AppColors _colors;
  late UserAuthProvider _auth;

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  File? _groupImage;
  bool _isCreating = false;
  bool _isPrivate = false;

  // Membres sélectionnés (hors owner)
  final List<UserData> _selectedMembers = [];
  List<UserData> _friends = [];
  bool _loadingFriends = true;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final myId = _auth.loginUserData.id!;
      // Charge les conversations 1-1 pour récupérer la liste d'amis
      final snap = await FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
            Filter('receiver_id', isEqualTo: myId),
            Filter('sender_id', isEqualTo: myId),
          ))
          .where('type', isEqualTo: 'USER')
          .orderBy('updated_at', descending: true)
          .limit(50)
          .get();

      final friends = <UserData>[];
      final seen = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final otherId = data['sender_id'] == myId
            ? data['receiver_id'] as String?
            : data['sender_id'] as String?;
        if (otherId == null || seen.contains(otherId)) continue;
        seen.add(otherId);
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(otherId)
            .get();
        if (userDoc.exists) {
          friends.add(UserData.fromJson(userDoc.data()!));
        }
      }

      if (mounted) setState(() { _friends = friends; _loadingFriends = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) setState(() => _groupImage = File(picked.path));
  }

  void _toggleMember(UserData user) {
    setState(() {
      if (_selectedMembers.any((m) => m.id == user.id)) {
        _selectedMembers.removeWhere((m) => m.id == user.id);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un nom au groupe'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un membre'), backgroundColor: Colors.orange),
      );
      return;
    }

    final myRole = _auth.loginUserData.role;
    final isGold = AbonnementUtils.canCreatePrivateGroup(
        _auth.loginUserData.abonnement, role: myRole);
    final subscriptionPrice = _isPrivate && isGold
        ? (double.tryParse(_priceController.text.trim()) ?? 0.0)
        : 0.0;

    // Vérifier la limite de groupes (Admin : illimité · Gold : illimité · Premium : 2)
    final myId = _auth.loginUserData.id!;
    final maxGroups = AbonnementUtils.maxGroupsOwned(
        _auth.loginUserData.abonnement, role: myRole);
    if (maxGroups != null && maxGroups > 0) {
      final existingSnap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('owner_id', isEqualTo: myId)
          .get();
      if (existingSnap.docs.length >= maxGroups) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Limite atteinte : $maxGroups groupe${maxGroups > 1 ? 's' : ''} maximum (Premium). '
              'Passez Gold pour des groupes illimités.',
            ),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      final groupId = FirebaseFirestore.instance.collection('GroupChats').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      String? imageUrl;
      if (_groupImage != null) {
        final ref = FirebaseStorage.instance.ref().child('group_images/$groupId.jpg');
        await ref.putFile(_groupImage!);
        imageUrl = await ref.getDownloadURL();
      }

      final keyData = _generateGroupKey();
      final joinCode = isGold ? _generateJoinCode() : null;
      final joinCodeExpiresAt = isGold
          ? DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch
          : null;

      final allMemberIds = [myId, ..._selectedMembers.map((m) => m.id!).where((id) => id.isNotEmpty)];

      final isAdminOwner = AbonnementUtils.isAdmin(myRole);

      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).set({
        'id': groupId,
        'name': name,
        'description': _descController.text.trim(),
        'image_url': imageUrl,
        'owner_id': myId,
        'member_ids': allMemberIds,
        'is_frozen': false,
        'is_private': _isPrivate && isGold,
        'subscription_price': subscriptionPrice,
        'join_code': joinCode,
        'join_code_expires_at': joinCodeExpiresAt,
        'paid_subscribers': {},
        'created_at': now,
        'updated_at': now,
        'last_message': '',
        'last_message_at': now,
        'member_count': allMemberIds.length,
        'ephemeral_duration': 0,
        // Groupes créés par un admin = groupes officiels de la plateforme
        if (isAdminOwner) 'is_official': true,
      });

      // Clé de groupe
      await FirebaseFirestore.instance.collection('GroupKeys').doc(groupId).set({
        'group_id': groupId,
        'key_data': keyData,
        'created_at': now,
      });

      // Ajouter l'owner comme membre
      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(groupId)
          .collection('members')
          .doc(myId)
          .set({
        'user_id': myId,
        'pseudo': _auth.loginUserData.pseudo ?? '',
        'image_url': _auth.loginUserData.imageUrl ?? '',
        'role': 'owner',
        'joined_at': now,
      });

      // Ajouter les membres sélectionnés
      for (final member in _selectedMembers) {
        await FirebaseFirestore.instance
            .collection('GroupChats')
            .doc(groupId)
            .collection('members')
            .doc(member.id)
            .set({
          'user_id': member.id,
          'pseudo': member.pseudo ?? '',
          'image_url': member.imageUrl ?? '',
          'role': 'member',
          'joined_at': now,
        });
      }

      // Message système de création
      final msgId = FirebaseFirestore.instance.collection('GroupMessages').doc().id;
      await FirebaseFirestore.instance.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': groupId,
        'send_by': 'system',
        'message': '🎉 Groupe créé par @${_auth.loginUserData.pseudo ?? ''}',
        'message_type': 'text',
        'is_valide': true,
        'is_encrypted': false,
        'create_at_time_spam': now,
        'message_state': 'LU',
      });

      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
        'last_message': '🎉 Groupe créé',
        'last_message_at': now,
      });

      if (mounted) {
        Navigator.pop(context, groupId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _generateGroupKey() {
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0');
    return rand * 2;
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

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
          'Nouveau groupe',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          _isCreating
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _createGroup,
                  child: Text('Créer', style: TextStyle(color: _colors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
        ],
      ),
      body: Column(
        children: [
          // Photo + nom + description
          _buildGroupHeader(),
          Divider(height: 1, color: _colors.border.withOpacity(0.3)),
          // Titre membres
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'MEMBRES',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const Spacer(),
                Text(
                  '${_selectedMembers.length} sélectionné(s)',
                  style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Liste des amis
          Expanded(child: _buildFriendsList()),
        ],
      ),
    );
  }

  Widget _buildGroupHeader() {
    final isGold = AbonnementUtils.canCreatePrivateGroup(
        _auth.loginUserData.abonnement, role: _auth.loginUserData.role);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _colors.surfaceVariant,
                      backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
                      child: _groupImage == null
                          ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 32)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(color: _colors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Nom du groupe',
                        hintStyle: TextStyle(color: _colors.textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(color: _colors.border.withOpacity(0.5), height: 1),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      style: TextStyle(color: _colors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Description (optionnel)',
                        hintStyle: TextStyle(color: _colors.textSecondary, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGoldPrivateSection(isGold),
        ],
      ),
    );
  }

  Widget _buildGoldPrivateSection(bool isGold) {
    return GestureDetector(
      onTap: isGold ? null : () => Navigator.pushNamed(context, '/abonnement'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(isGold ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(isGold ? 0.4 : 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Options Gold',
                  style: TextStyle(
                    color: isGold ? _colors.textPrimary : _colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (isGold) ...[
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                      activeColor: const Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    'Privé',
                    style: TextStyle(color: _colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 11, color: Color(0xFFFFD700)),
                        SizedBox(width: 4),
                        Text('Gold requis', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
            if (!isGold) ...[
              const SizedBox(height: 8),
              Text(
                'Créez des groupes privés payants avec un code d\'accès unique. Passez Gold pour débloquer.',
                style: TextStyle(color: _colors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/abonnement'),
                  icon: const Icon(Icons.workspace_premium, size: 14, color: Color(0xFFFFD700)),
                  label: const Text('Passer Gold', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w700, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFD700)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (isGold && _isPrivate) ...[
              const SizedBox(height: 10),
              Text(
                'Prix d\'abonnement mensuel (FCFA)',
                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'ex: 500',
                  hintStyle: TextStyle(color: _colors.textSecondary),
                  suffix: Text('FCFA/mois', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '70% vous revient · 30% plateforme · Code unique généré automatiquement',
                style: TextStyle(color: _colors.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_loadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Center(
        child: Text('Aucun ami trouvé', style: TextStyle(color: _colors.textSecondary)),
      );
    }

    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (_, index) {
        final user = _friends[index];
        final isSelected = _selectedMembers.any((m) => m.id == user.id);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(user.imageUrl!)
                : null,
            backgroundColor: _colors.surfaceVariant,
            child: user.imageUrl == null || user.imageUrl!.isEmpty
                ? Icon(Icons.person, color: _colors.textSecondary)
                : null,
          ),
          title: Text(
            '@${user.pseudo ?? '...'}',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          trailing: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isSelected ? _colors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? _colors.primary : _colors.border, width: 2),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          onTap: () => _toggleMember(user),
        );
      },
    );
  }
}
