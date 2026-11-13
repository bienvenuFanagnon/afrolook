
import '../../models/post_widget.dart';
import '../../widgets/reply_banner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/account_gate.dart';
import '../../services/post_source_link.dart';
import '../../services/authentic_video_check.dart';
import '../../theme/app_colors.dart';
import '../cards/card_entry.dart';
import '../cards/card_events.dart';
import '../cards/card_models.dart' show CardStyleId;
import '../studio/montage/montage_catalog.dart' show MontageTemplate;
import '../studio/montage/montage_gallery_page.dart';
import '../studio/montage/template_thumb.dart';
import '../studio/montage/montage_music.dart' show MontageMusic;
import '../studio/studio_models.dart' show StudioResult;
import '../../services/api/template_stats_api.dart';
import '../../services/template_link.dart';
import '../../widgets/studio/post_template_try.dart' show TemplateTry;
import '../studio/montage/montage_pin.dart';
import 'create_voice_page.dart';
import 'voice_effect_page.dart';
import 'create_camera_page.dart';
import 'create_editor_page.dart';
import 'multi_images_page.dart';
import '../../services/create_draft.dart';
import '../../widgets/reply_split.dart';
import 'chronique_flow.dart';
import 'create_flow.dart';
import 'create_result.dart';
import 'create_text_page.dart';

/// Ce que le parcours démarre tout seul à l'ouverture (appel à poster dans le fil : « Filme-toi », « Laisse un message vocal »).
enum CreateStart { none, video, audio, galleryVideo }

/// Écran « Que créer ? » : l'entrée unique de la création (publication, Studio et cartes réunis). On choisit le type, on prépare le média, on le retouche, puis
/// un seul formulaire demande le reste. Ce qui est filmé ou enregistré dans l'application passe en premier ; la galerie n'a plus de limite par jour (tout média passe par le contrôle d'authenticité).
class CreateHubPage extends StatefulWidget {
  const CreateHubPage({super.key, this.canal, this.defiPostId, this.start = CreateStart.none, this.replyToPostId, this.presetSound, this.pinSource, this.chronique});

  /// Création d'une chronique (24 h) ou d'une chronique business : même parcours et même Studio que les posts, puis aperçu et publication de la chronique.
  final ChroniqueKind? chronique;

  final Canal? canal;
  final String? defiPostId;
  final CreateStart start;

  /// Réponse en vidéo à ce post : caméra limitée à 15 s ; le serveur n'accepte qu'une vidéo.
  final String? replyToPostId;

  /// « Créer avec ce son » : ce son devient l'audio du post. La caméra le joue pendant qu'on filme, puis l'éditeur l'applique ; photo et galerie marchent aussi.
  final MontageMusic? presetSound;

  /// « Épingler cette vidéo » : la vidéo d'un autre, à poser dans le coin de ce qu'on filme (réglée dans le Studio).
  final MontagePinSource? pinSource;

  @override
  State<CreateHubPage> createState() => _CreateHubPageState();
}

class _CreateHubPageState extends State<CreateHubPage> {
  bool _busy = false;

  /// Un travail démarre en arrière-plan (ouverture de la caméra, vérification du compte) : on affiche une roue de chargement au lieu de laisser l'écran figé.
  bool _opening = false;
  CreateDraft? _draft;   // brouillon enregistré en quittant l'éditeur

  Future<void> _loadDraft() async {
    final d = await CreateDraft.load();
    if (mounted) setState(() => _draft = d);
  }
  String _openingLabel = '';

  void _setOpening(bool v, [String? label]) {
    if (!mounted) return;
    setState(() {
      _opening = v;
      if (label != null) _openingLabel = label;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.replyToPostId != null) {
      PostReplyLink.set(widget.replyToPostId);
      ReplyBanner.load(widget.replyToPostId);   // « Tu réponds à @pseudo » sur chaque écran du parcours
    }
    if (widget.chronique != null) ChroniqueFlow.active = widget.chronique;
    ReplyLayout.clear();
    if (!kIsWeb && widget.chronique == null && widget.canal == null && widget.defiPostId == null) _loadDraft();   // pas de brouillon sur le web : on n'y publie pas
    if (widget.start != CreateStart.none && !kIsWeb) {
      // ouverture directe (icône « répondre en vidéo » d'un post, « Ma vidéo avec ce son »…) : la roue s'affiche tout de suite, sans montrer le menu une seconde
      _opening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.start) {
          case CreateStart.video:
            _guard(() => _openCamera(photo: false));
          case CreateStart.audio:
            _guard(_audio);
          case CreateStart.galleryVideo:
            _guard(() => _pickGallery(video: true));   // « Ma vidéo avec ce son » : on choisit sa vidéo, puis l'éditeur l'ouvre avec la musique
          case CreateStart.none:
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    PostExternalLink.clear();
    if (widget.replyToPostId != null) {
      PostReplyLink.clear();
      ReplyBanner.clear();
    }
    if (widget.chronique != null) ChroniqueFlow.active = null;
    PostWidgetsLink.clear();   // widgets non publiés : on les oublie à la fin du parcours
    super.dispose();
  }

  /// Publier dans un canal : pas de live.
  bool get _isChannel => widget.canal != null;

  /// Compte bloqué pour inactivité : déblocage avant de continuer ; un seul parcours à la fois.
  Future<void> _guard(Future<void> Function() run) async {
    if (kIsWeb) return;   // application web : aucune publication (voir _webNotice)
    if (_busy) return;
    _busy = true;
    _setOpening(true, context.tr('Chargement…'));
    try {
      if (!await AccountGate.ensureCanPublish(context) || !mounted) return;
      await run();
    } finally {
      _busy = false;
      _setOpening(false);
    }
  }

  Future<void> _after(String r) async {
    if (PostExternalLink.takeNotice() && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Ta vidéo est en vérification : elle sera publiée dès que notre équipe l\'aura validée.'))));
    }
    if (r == kCreateDone && mounted) Navigator.of(context).pop(kCreateDone);
  }

  // ── Vidéo et photo : caméra d'abord ──────────────────────────────────────

  Future<void> _openCamera({required bool photo}) async {
    if (kIsWeb) return _pickGallery(video: !photo);
    // la roue est dessinée AVANT d'ouvrir la caméra (son ouverture occupe l'appareil un instant) ; elle disparaît au retour
    _setOpening(true, context.tr('Ouverture de la caméra…'));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final r = await Navigator.of(context).push<CreateCaptureResult>(MaterialPageRoute(builder: (_) => CreateCameraPage(startOnPhoto: photo && widget.replyToPostId == null, maxSeconds: widget.replyToPostId != null ? 15 : (widget.chronique != null ? ChroniqueFlow.maxVideoSeconds : 60), sound: widget.presetSound)));
    _setOpening(false);
    if (r == null || !mounted) return;
    if (r.openGallery) return _pickGallery(video: r.isVideo);
    await _editor(r.path!, r.isVideo, PostSourceLink.captured);
  }

  /// Galerie : sans limite par jour (décision du 09/11/2026) ; tout média choisi passe par le contrôle d'authenticité (vidéo et images) avant d'aller plus loin.
  Future<void> _pickGallery({required bool video}) async {
    final picker = ImagePicker();
    if (video) {
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null || !mounted) return;
      // vidéos authentiques : une vidéo qui porte la marque d'un autre réseau est refusée (plus de « C'est ma vidéo », 13/11/2026)
      if (!await AuthenticVideoCheck.gate(context, x.path, allowClaim: widget.chronique == null) || !mounted) return;
      await _editor(x.path, true, PostSourceLink.imported);
    } else {
      // une chronique n'a qu'une image ; un post peut en avoir plusieurs
      final xs = widget.chronique != null
          ? [if (await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 92) case final one?) one]
          : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 92, limit: 5);
      if (xs.isEmpty || !mounted) return;
      // contenu sexuellement explicite : refusé (modèle gratuit sur le téléphone) ; « C'est une erreur » envoie à la modération
      for (final x in xs) {
        if (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: widget.chronique == null) || !mounted) return;
      }
      if (xs.length == 1) {
        await _editor(xs.first.path, false, PostSourceLink.imported);
      } else {
        // plusieurs photos : l'écran « Mes images » (carrousel, collage ou diaporama vidéo)
        final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => MultiImagesPage(paths: [for (final x in xs) x.path], canal: widget.canal, defiPostId: widget.defiPostId)));
        if (r == kCreateRedo && mounted) return _pickGallery(video: false);
        await _after(r ?? kCreateBack);
      }
    }
  }

  Future<void> _editor(String path, bool isVideo, String source, {CreateDraft? draft}) async {
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => CreateEditorPage(path: path, isVideo: isVideo, source: source, canal: widget.canal, defiPostId: widget.defiPostId, sound: widget.presetSound, pin: widget.pinSource, draft: draft),
    ));
    if (mounted && widget.chronique == null && widget.canal == null && widget.defiPostId == null) _loadDraft();
    if (r == kCreateRedo && mounted) {
      // « Refaire » : on rouvre la caméra (ou la galerie si le média venait de la galerie)
      return source == PostSourceLink.captured ? _openCamera(photo: !isVideo) : _pickGallery(video: isVideo);
    }
    await _after(r ?? kCreateBack);
  }


  /// « Voir plus » : toute la galerie des modèles prêts à poster ; le modèle choisi mène au formulaire unique, avec son modèle retenu pour le compteur.
  Future<void> _openTemplates() async {
    final r = await Navigator.of(context).push<StudioResult>(MaterialPageRoute(builder: (_) => const MontageGalleryPage()));
    if (r == null || !mounted) return;
    await _after(await openCreateForm(context, studio: r, source: PostSourceLink.edited));
  }

  // ── Audio, texte, carte ──────────────────────────────────────────────────

  /// Audio : on s'enregistre (ou on prend un fichier), on choisit éventuellement un effet de voix en écoutant le vrai rendu, puis le formulaire.
  Future<void> _audio() async {
    final rec = await Navigator.of(context).push<CreateVoiceResult>(MaterialPageRoute(builder: (_) => const CreateVoicePage(allowPick: true)));
    if (rec == null || !mounted) return;
    final choice = await Navigator.of(context).push<VoiceChoice>(MaterialPageRoute(builder: (_) => VoiceEffectPage(original: rec.file)));
    if (choice == null || !mounted) return;
    PostVoiceLink.set(choice.effect);
    final r = await openCreateForm(
      context,
      kind: CreatePostKind.audio,
      audio: choice.file,
      audioSeconds: rec.seconds,
      audioCover: rec.cover,
      source: rec.recorded ? PostSourceLink.captured : PostSourceLink.imported,
      canal: widget.canal,
      defiPostId: widget.defiPostId,
    );
    PostVoiceLink.clear();
    await _after(r);
  }

  Future<void> _text() async {
    // écran « Écrire » de la proposition : papier de couleur, puis le formulaire unique avec le texte dans la description
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => CreateTextPage(canal: widget.canal, defiPostId: widget.defiPostId)));
    await _after(r ?? kCreateBack);
  }

  Future<void> _card({String text = '', CardStyleHint? hint}) async {
    await CardEntry.openCompose(context, canal: widget.canal, defiPostId: widget.defiPostId, text: text, style: hint?.style, country: hint?.country);
  }

  // ── Écran ────────────────────────────────────────────────────────────────

  /// Application web : on ne publie pas depuis le navigateur (décision du propriétaire, 10/11/2026 : le contrôle du contenu
  /// tourne sur le téléphone, pas sur le web). L'écran n'affiche qu'un message, sans aucun bouton de création.
  Widget _webNotice(BuildContext context, AppColors c) {
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(context.tr('Créer un post'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          key: const ValueKey('hub_web_notice'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.phone_iphone_rounded, size: 56, color: c.primary),
              const SizedBox(height: 18),
              Text(context.tr('Publie depuis l\'application'), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                context.tr('La publication se fait dans l\'application Afrolook, sur Android et iPhone. Sur le web, tu peux suivre ton fil.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14.5, height: 1.45),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (kIsWeb) return _webNotice(context, c);
    final me = context.read<UserAuthProvider>().loginUserData;
    final soon = widget.chronique != null ? null : CardEvents.upcoming(me.countryData?['countryCode'], DateTime.now());
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(
          widget.chronique == ChroniqueKind.business ? context.tr('Chronique business') : widget.chronique == ChroniqueKind.normal ? context.tr('Chronique (24 h)') : widget.defiPostId != null ? '🏆 ${context.tr('Répondre au Défi')}' : (widget.canal != null ? '#${widget.canal!.titre ?? 'Canal'}' : context.tr('Créer un post')),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Stack(children: [
        SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          if (soon != null) ...[
            _EventBanner(event: soon, onTap: () => _card(text: soon.event.text, hint: CardStyleHint(soon.event.style, soon.event.country))),
            const SizedBox(height: 12),
          ],
          if (widget.presetSound != null) ...[
            _SoundBanner(sound: widget.presetSound!),
            const SizedBox(height: 10),
          ],
          if (_draft != null) ...[
            _DraftBanner(
              draft: _draft!,
              onResume: () => _guard(() => _editor(_draft!.path, _draft!.isVideo, _draft!.source, draft: _draft)),
              onDelete: () async {
                await CreateDraft.clear();
                if (mounted) setState(() => _draft = null);
              },
            ),
            const SizedBox(height: 12),
          ],
          _VideoHero(
            onFilm: () => _guard(() => _openCamera(photo: false)),
            onGallery: () => _guard(() => _pickGallery(video: true)),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _Tile(key: const ValueKey('tile_photo'), icon: Icons.photo_camera_rounded, color: c.info, label: context.tr('Photo'), hint: context.tr('Prends-toi en photo'), onTap: () => _guard(() => _openCamera(photo: true))),
              _Tile(key: const ValueKey('tile_audio'), icon: Icons.mic_rounded, color: const Color(0xFF9B59B6), label: context.tr('Audio'), hint: context.tr('Ta voix, sans montrer ton visage'), onTap: () => _guard(_audio)),
              _Tile(key: const ValueKey('tile_text'), icon: Icons.text_fields_rounded, color: c.primary, label: context.tr('Texte'), hint: context.tr('Écris sur un fond de couleur'), onTap: () => _guard(_text)),
              if (widget.chronique == null) _Tile(key: const ValueKey('tile_card'), icon: Icons.auto_awesome_rounded, color: c.accentText, label: context.tr('Carte'), hint: context.tr('Une affiche à ton style'), onTap: () => _guard(_card)),
            ],
          ),
          const SizedBox(height: 22),
          // « Les plus utilisés » : les modèles prêts à poster que les gens utilisent le plus, et « Voir plus » vers toute la galerie
          if (widget.chronique == null && widget.canal == null && widget.defiPostId == null && !kIsWeb) ...[
            _TemplatesStrip(onOpen: (t) => _guard(() => TemplateTry.open(context, TemplateRef.montage(t.id))), onMore: () => _guard(_openTemplates)),
            const SizedBox(height: 22),
          ],
          const SizedBox(height: 18),
          Text(
            _isChannel
                ? context.tr('Dans un canal, tu peux publier autant de médias de ta galerie que tu veux.')
                : widget.chronique != null
                    ? context.tr('Ta chronique reste visible 24 heures. Vidéo de 30 secondes au plus : filme-toi ou choisis un média, puis monte-le dans le Studio.')
                    : context.tr('Ce que tu filmes ou enregistres ici passe en premier dans le fil, avec la mention « Fait sur Afrolook ».'),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ]),
      ),
        if (_opening)
          Positioned.fill(
            key: const ValueKey('hub_opening'),
            child: ColoredBox(
              color: c.background.withOpacity(.88),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: c.primary, strokeWidth: 3)),
                  const SizedBox(height: 14),
                  Text(_openingLabel.isEmpty ? context.tr('Ouverture…') : _openingLabel, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Style et pays d'une fête, pour ouvrir le studio de cartes aux couleurs de l'occasion.
class CardStyleHint {
  const CardStyleHint(this.style, this.country);
  final CardStyleId? style;
  final String? country;
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.event, required this.onTap});
  final CardEventSoon event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final colors = event.event.colors.length >= 2 ? event.event.colors : [c.accent, c.accent.withOpacity(.8)];
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [colors.first.withOpacity(.92), colors.last.withOpacity(.92)])),
        child: Row(children: [
          Text(event.event.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.2)),
              const SizedBox(height: 2),
              Text(context.tr('Crée ta carte aux couleurs de l\'occasion'), style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}

class _VideoHero extends StatelessWidget {
  const _VideoHero({required this.onFilm, required this.onGallery});
  final VoidCallback onFilm;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = c.onPrimary;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.primary, Color.lerp(c.primary, const Color(0xFF0A3D22), .45)!]),
          boxShadow: [BoxShadow(color: c.primary.withOpacity(.28), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: InkWell(
          key: const ValueKey('hero_video'),
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.mediumImpact();
            onFilm();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: fg.withOpacity(.18), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.videocam_rounded, color: fg, size: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Vidéo'), style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                    Text(context.tr('Filme-toi : on voit ta personnalité, pas celle des autres.'), style: TextStyle(color: fg.withOpacity(.86), fontSize: 13, height: 1.3)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fiber_manual_record_rounded, color: c.onAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(context.tr('Filmer maintenant'), style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w900, fontSize: 14.5)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  key: const ValueKey('hero_gallery'),
                  onTap: onGallery,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(color: fg.withOpacity(.16), borderRadius: BorderRadius.circular(16), border: Border.all(color: fg.withOpacity(.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.photo_library_rounded, color: fg, size: 18),
                      const SizedBox(width: 6),
                      Text(context.tr('Galerie'), style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.color, required this.label, required this.hint, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 24)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: c.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.25)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bandeau « Créer avec ce son » : le son choisi sera l'audio du post.
class _SoundBanner extends StatelessWidget {
  const _SoundBanner({required this.sound});
  final MontageMusic sound;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      key: const ValueKey('sound_banner'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.music_note_rounded, color: c.onAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sound.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
            Text(context.tr('Ce son sera l\'audio de ton post. Filme-toi, prends une photo ou choisis un média.'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

/// « Reprendre ton brouillon » : le média retouché enregistré en quittant l'éditeur (reprendre ou supprimer).
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.draft, required this.onResume, required this.onDelete});

  final CreateDraft draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      key: const ValueKey('draft_banner'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(children: [
        Icon(draft.isVideo ? Icons.videocam_rounded : Icons.photo_rounded, color: c.accentText),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Reprendre ton brouillon'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
            Text(draft.isVideo ? context.tr('Une vidéo en cours de retouche') : context.tr('Une photo en cours de retouche'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ]),
        ),
        TextButton(key: const ValueKey('draft_resume'), onPressed: onResume, child: Text(context.tr('Reprendre'))),
        IconButton(key: const ValueKey('draft_delete'), tooltip: context.tr('Supprimer'), icon: Icon(Icons.delete_outline_rounded, color: c.danger), onPressed: onDelete),
      ]),
    );
  }
}

/// Bande « Les plus utilisés » de l'écran « Que créer ? » : les modèles prêts à poster classés par le serveur (la semaine d'abord), avec leur nombre d'utilisations,
/// puis « Voir plus » qui ouvre toute la galerie. Sans réseau ni utilisation connue, c'est l'ordre du catalogue : la bande n'est jamais vide.
class _TemplatesStrip extends StatefulWidget {
  const _TemplatesStrip({required this.onOpen, required this.onMore});
  final void Function(MontageTemplate t) onOpen;
  final VoidCallback onMore;

  @override
  State<_TemplatesStrip> createState() => _TemplatesStripState();
}

class _TemplatesStripState extends State<_TemplatesStrip> {
  @override
  void initState() {
    super.initState();
    TemplateStatsApi.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final list = popularMontageTemplates().take(6).toList();
    return Column(key: const ValueKey('templates_strip'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(context.tr('Les plus utilisés'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
        TextButton(
          key: const ValueKey('templates_more'),
          onPressed: widget.onMore,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(context.tr('Voir plus'), style: TextStyle(color: c.accentText, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final t = list[i];
            final uses = TemplateStatsApi.usesOf('m:${t.id}');
            return GestureDetector(
              key: ValueKey('template_${t.id}'),
              onTap: () => widget.onOpen(t),
              child: SizedBox(
                width: 104,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 104,
                      height: 120,
                      child: TemplateThumb(asset: t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, video: t.showsVideo, cacheWidth: 260, badgeSize: 34, isNew: t.isNew, template: t),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(uses > 0 ? context.tr('{n} utilisations', {'n': TemplateStatsApi.format(uses)}) : context.tr('Gratuit'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
