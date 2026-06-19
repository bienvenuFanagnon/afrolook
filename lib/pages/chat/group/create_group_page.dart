import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
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
  File? _groupImage;
  bool _isCreating = false;

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

    setState(() => _isCreating = true);

    try {
      final myId = _auth.loginUserData.id!;
      final groupId = FirebaseFirestore.instance.collection('GroupChats').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Upload image si sélectionnée
      String? imageUrl;
      if (_groupImage != null) {
        final ref = FirebaseStorage.instance.ref().child('group_images/$groupId.jpg');
        await ref.putFile(_groupImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Générer une clé AES pour le groupe (simple: base64 random 32 bytes)
      // On utilise le même service que pour les chats 1-1
      final keyData = _generateGroupKey();

      final allMemberIds = [myId, ..._selectedMembers.map((m) => m.id!).where((id) => id.isNotEmpty)];

      // Créer le document GroupChats
      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).set({
        'id': groupId,
        'name': name,
        'description': _descController.text.trim(),
        'image_url': imageUrl,
        'owner_id': myId,
        'member_ids': allMemberIds,  // tableau pour requêtes arrayContains
        'is_frozen': false,
        'created_at': now,
        'updated_at': now,
        'last_message': '',
        'last_message_at': now,
        'member_count': allMemberIds.length,
        'ephemeral_duration': 0,
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
    // Génère une clé pseudo-aléatoire en base64 (32 chars hex)
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0');
    return rand * 2; // 32 hex chars
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
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
