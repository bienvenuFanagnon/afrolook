import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostAudioTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostImageTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostTextTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostVideoTab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../constant/logo.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';

class UserPostForm extends StatefulWidget {
  final Canal? canal;
  final String? defiPostId;

  const UserPostForm({super.key, this.canal, this.defiPostId});

  @override
  State<UserPostForm> createState() => _UserPostFormState();
}

class _UserPostFormState extends State<UserPostForm> {
  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AppColors _colors;
  static const Color _primaryColor = Color(0xFFE21221);

  int _selectedMediaIndex = 2; // Défaut: Image

  static const List<_MediaType> _mediaTypes = [
    _MediaType(icon: Icons.audiotrack, label: 'Audio'),
    _MediaType(icon: Icons.text_fields, label: 'Texte'),
    _MediaType(icon: Icons.photo, label: 'Image'),
    _MediaType(icon: Icons.videocam, label: 'Vidéo'),
  ];

  bool get _isCanal => widget.canal != null;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surfaceVariant,
        elevation: 0,
        title: Text(
          widget.defiPostId != null
              ? '🏆 Répondre au Défi'
              : _isCanal
                  ? '#${widget.canal!.titre ?? 'Canal'}'
                  : 'Créer une publication',
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Logo(),
          ),
        ],
        iconTheme: IconThemeData(color: _colors.textPrimary),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: CenteredContent(
          maxWidth: AppLayout.isDesktop(context) ? 700 : AppLayout.maxFeedWidth,
          child: Column(
            children: [
              // ── En-tête : profil user ou carte canal ───────────────
              _isCanal ? _buildCanalHeader() : _buildUserHeader(),

              // ── Sélecteur de type de média ─────────────────────────
              _buildMediaSelector(),

              // ── Contenu de l'onglet sélectionné ───────────────────
              Expanded(
                child: IndexedStack(
                  index: _selectedMediaIndex,
                  children: [
                    UserPostLookAudioTab(canal: widget.canal, defiPostId: widget.defiPostId),
                    UserPubText(canal: widget.canal, defiPostId: widget.defiPostId),
                    UserPostLookImageTab(canal: widget.canal, defiPostId: widget.defiPostId),
                    UserPubVideo(canal: widget.canal, defiPostId: widget.defiPostId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête utilisateur ──────────────────────────────────────────────────
  Widget _buildUserHeader() {
    final user = authProvider.loginUserData;
    final imageUrl = user.imageUrl ?? '';
    final pseudo = user.pseudo ?? '';
    final abonnesCount = user.userAbonnesIds?.length ?? 0;

    return Container(
      color: _colors.surfaceVariant,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _colors.border,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty
                ? Icon(Icons.person, color: _colors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@$pseudo',
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '$abonnesCount abonné(s)',
                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── En-tête canal ────────────────────────────────────────────────────────
  Widget _buildCanalHeader() {
    final canal = widget.canal!;
    final imageUrl = canal.urlImage ?? '';
    final titre = canal.titre ?? 'Canal';
    final abonnesCount = canal.usersSuiviId?.length ?? 0;
    final description = canal.description ?? '';

    return Container(
      color: _colors.surfaceVariant,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primaryColor, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _canalFallbackIcon())
                  : _canalFallbackIcon(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$titre',
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.people, size: 13, color: _colors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$abonnesCount abonné(s)',
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _canalFallbackIcon() => Container(
        color: _primaryColor.withOpacity(0.2),
        child: Icon(Icons.group, color: _primaryColor, size: 26),
      );

  // ── Sélecteur de média ───────────────────────────────────────────────────
  Widget _buildMediaSelector() {
    return Container(
      color: _colors.surfaceVariant,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: List.generate(_mediaTypes.length, (i) {
          final selected = i == _selectedMediaIndex;
          final type = _mediaTypes[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMediaIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? _primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _primaryColor : _colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type.icon,
                      size: 22,
                      color: selected ? _primaryColor : _colors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: selected ? _primaryColor : _colors.textSecondary,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MediaType {
  final IconData icon;
  final String label;
  const _MediaType({required this.icon, required this.label});
}
