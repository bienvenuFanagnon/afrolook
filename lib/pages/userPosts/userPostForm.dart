import '../../services/template_link.dart';
import 'package:afrotok/ads/ad_config.dart';
import 'package:afrotok/ads/admob_service.dart';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:afrotok/services/account_gate.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/services/followers_count_service.dart';
import 'package:afrotok/utils/count_format.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostAudioTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostImageTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostTextTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostVideoTab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../studio/studio_entry_page.dart';
import '../studio/studio_models.dart';

import '../../../theme/app_colors.dart';
import '../../../constant/logo.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../cards/card_post_tab.dart';
import '../studio/studio_sound_link.dart';

class UserPostForm extends StatefulWidget {
  final Canal? canal;
  final String? defiPostId;

  /// Montage déjà fait dans le Studio (ex. « Créer un post avec ce son ») : il pré-remplit le post à l'ouverture.
  final StudioResult? initialStudio;

  const UserPostForm({super.key, this.canal, this.defiPostId, this.initialStudio});

  @override
  State<UserPostForm> createState() => _UserPostFormState();
}

class _UserPostFormState extends State<UserPostForm> {

  @override
  void initState() {
    super.initState();
    if (AdConfig.current.enabled) AdmobService.preloadInterstitial(); // prête pour la fin de la publication
    // Compte bloqué pour inactivité (20 jours sans publication) : déblocage en pièces avant de continuer
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await AccountGate.ensureCanPublish(context) && mounted) Navigator.of(context).maybePop();
    });
    final pre = widget.initialStudio;
    if (pre != null) WidgetsBinding.instance.addPostFrameCallback((_) => _applyStudioResult(pre));
  }

  @override
  void dispose() {
    StudioSoundLink.clear(); // un montage abandonné ne doit pas se lier à un autre post
    PostTemplateLink.clear();
    super.dispose();
  }
  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AppColors _colors;
  static const Color _primaryColor = Color(0xFFE21221);

  int _selectedMediaIndex = 2; // Défaut: Image

  // Studio : résultat stocké pour pré-remplir l'onglet Image
  List<Uint8List>? _studioInitialImages;
  String? _studioInitialDescription;
  int _studioImageKey = 0; // Force rebuild de l'ImageTab quand un résultat Studio arrive
  File? _studioInitialVideo;
  int _studioVideoKey = 0;

  static const List<_MediaType> _mediaTypes = [
    _MediaType(icon: Icons.audiotrack, label: 'Audio'),
    _MediaType(icon: Icons.text_fields, label: 'Texte'),
    _MediaType(icon: Icons.photo, label: 'Image'),
    _MediaType(icon: Icons.videocam, label: 'Vidéo'),
    _MediaType(icon: Icons.auto_awesome_rounded, label: 'Carte'),
  ];

  bool get _isCanal => widget.canal != null;

  Future<void> _openStudio() async {
    final result = await Navigator.push<StudioResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const StudioEntryPage(forChronique: false),
      ),
    );
    if (result == null || !mounted) return;
    await _applyStudioResult(result);
  }

  Future<void> _applyStudioResult(StudioResult result) async {
    if (!mounted) return;
    // Montage fait avec un son d'artiste : le post sera relié au son une fois publié (vérifié par le serveur)
    StudioSoundLink.set(result.artistSoundId != null ? result.soundJobId : null);
    PostTemplateLink.set(TemplateRef.fromStudioId(result.templateId)?.code); // le post affichera « Essayer ce template »
    switch (result.type) {
      case StudioContentType.image:
        if (result.mediaFile != null) {
          final bytes = await result.mediaFile!.readAsBytes();
          setState(() {
            _studioInitialImages = [bytes];
            _studioInitialDescription = result.textContent;
            _studioImageKey++;
            _selectedMediaIndex = 2; // onglet Image
          });
        }
        break;
      case StudioContentType.text:
        setState(() => _selectedMediaIndex = 1);
        break;
      case StudioContentType.audio:
        setState(() => _selectedMediaIndex = 0);
        break;
      case StudioContentType.video:
        setState(() {
          _studioInitialVideo = result.mediaFile;
          _studioInitialDescription = result.textContent;
          _studioVideoKey++;
          _selectedMediaIndex = 3;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Canal bloqué pour inactivité : publication impossible tant qu'il n'est pas débloqué
    if (widget.canal?.isBlocked == true) {
      final c = AppColors.of(context);
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.background, iconTheme: IconThemeData(color: c.textPrimary)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 48, color: c.danger),
              const SizedBox(height: 12),
              Text('Ce canal est bloqué pour inactivité.\nDébloque-le depuis la page du canal pour publier.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.4)),
            ]),
          ),
        ),
      );
    }
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surfaceVariant,
        elevation: 0,
        title: NameTag(label: widget.defiPostId != null
              ? '🏆 Répondre au Défi'
              : _isCanal
                  ? '#${widget.canal!.titre ?? 'Canal'}'
                  : 'Créer une publication',
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          )),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _openStudio,
            child: Container(
              margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _primaryColor.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 13, color: Color(0xFFE21221)),
                  SizedBox(width: 4),
                  Text('Studio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE21221))),
                ],
              ),
            ),
          ),
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
                    UserPostLookImageTab(
                      key: ValueKey('img_$_studioImageKey'),
                      canal: widget.canal,
                      defiPostId: widget.defiPostId,
                      initialImages: _studioInitialImages,
                      initialDescription: _studioInitialDescription,
                    ),
                    UserPubVideo(
                      key: ValueKey('vid_$_studioVideoKey'),
                      canal: widget.canal,
                      defiPostId: widget.defiPostId,
                      initialVideo: _studioInitialVideo,
                      initialDescription: _studioInitialDescription,
                    ),
                    UserPostCardTab(canal: widget.canal, defiPostId: widget.defiPostId),
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
    final abonnesCount = user.followersCount;

    return Container(
      color: _colors.surfaceVariant,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          CircleAvatar(onBackgroundImageError: (imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null) != null ? (Object _, StackTrace? __) {} : null, 
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
              FollowersCountBuilder(
                userId: user.id,
                fallback: abonnesCount,
                builder: (_, c) => Text(
                  '${formatCompactCount(c)} abonné(s)',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                ),
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
    final abonnesCount = canal.membersCount;
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
                NameTag(
                  label: '#$titre',
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
                      '${formatCompactCount(abonnesCount)} abonné(s)',
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
        // la création de carte n'est pas proposée sur le web (impossible d'y bloquer les captures d'écran)
        children: List.generate(kIsWeb ? _mediaTypes.length - 1 : _mediaTypes.length, (i) {
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
