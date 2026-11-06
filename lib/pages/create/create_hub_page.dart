import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/account_gate.dart';
import '../../services/api/posts_api.dart';
import '../../services/post_source_link.dart';
import '../../theme/app_colors.dart';
import '../cards/card_entry.dart';
import '../cards/card_events.dart';
import '../cards/card_models.dart' show CardStyleId;
import '../studio/montage/montage_music.dart' show MontageMusic;
import '../studio/montage/montage_pin.dart';
import 'create_voice_page.dart';
import 'voice_effect_page.dart';
import 'create_camera_page.dart';
import 'create_editor_page.dart';
import 'create_flow.dart';
import 'create_result.dart';
import 'create_text_page.dart';

/// Ce que le parcours démarre tout seul à l'ouverture (appel à poster dans le fil : « Filme-toi », « Laisse un message vocal »).
enum CreateStart { none, video, audio }

/// Écran « Que créer ? » : l'entrée unique de la création (publication, Studio et cartes réunis). On choisit le type, on prépare le média, on le retouche, puis
/// un seul formulaire demande le reste. Ce qui est filmé ou enregistré dans l'application passe en premier ; la galerie est limitée à 2 médias par jour.
class CreateHubPage extends StatefulWidget {
  const CreateHubPage({super.key, this.canal, this.defiPostId, this.start = CreateStart.none, this.replyToPostId, this.presetSound, this.pinSource});

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
  ({int limit, int used, int remaining})? _quota;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.replyToPostId != null) PostReplyLink.set(widget.replyToPostId);
    _loadQuota();
    if (widget.start != CreateStart.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.start == CreateStart.video ? _guard(() => _openCamera(photo: false)) : _guard(_audio);
      });
    }
  }

  @override
  void dispose() {
    if (widget.replyToPostId != null) PostReplyLink.clear();
    super.dispose();
  }

  /// Publier dans un canal : aucune limite de médias de galerie (et pas de live).
  bool get _isChannel => widget.canal != null;

  Future<void> _loadQuota() async {
    if (_isChannel) return;
    final q = await PostsApi.importQuota();
    if (mounted) setState(() => _quota = q);
  }

  bool get _galleryOpen => _isChannel || _quota == null || _quota!.remaining > 0;

  /// Compte bloqué pour inactivité : déblocage avant de continuer ; un seul parcours à la fois.
  Future<void> _guard(Future<void> Function() run) async {
    if (_busy) return;
    _busy = true;
    try {
      if (!await AccountGate.ensureCanPublish(context) || !mounted) return;
      await run();
    } finally {
      _busy = false;
    }
  }

  Future<void> _after(String r) async {
    if (r == kCreateDone && mounted) Navigator.of(context).pop(kCreateDone);
    if (mounted) _loadQuota();
  }

  // ── Vidéo et photo : caméra d'abord ──────────────────────────────────────

  Future<void> _openCamera({required bool photo}) async {
    if (kIsWeb) return _pickGallery(video: !photo);
    final r = await Navigator.of(context).push<CreateCaptureResult>(MaterialPageRoute(builder: (_) => CreateCameraPage(startOnPhoto: photo && widget.replyToPostId == null, maxSeconds: widget.replyToPostId != null ? 15 : 60, sound: widget.presetSound)));
    if (r == null || !mounted) return;
    if (r.openGallery) return _pickGallery(video: r.isVideo);
    await _editor(r.path!, r.isVideo, PostSourceLink.captured);
  }

  /// Galerie : au plus 2 médias par jour ; après, la personne est invitée à se filmer.
  Future<void> _pickGallery({required bool video}) async {
    await _loadQuota();
    if (!mounted) return;
    if (!_galleryOpen) {
      await _quotaDialog(video: video);
      return;
    }
    final picker = ImagePicker();
    if (video) {
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null || !mounted) return;
      await _editor(x.path, true, PostSourceLink.imported);
    } else {
      final xs = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 92, limit: 4);
      if (xs.isEmpty || !mounted) return;
      if (xs.length == 1) {
        await _editor(xs.first.path, false, PostSourceLink.imported);
      } else {
        // plusieurs photos : directement au formulaire (l'éditeur ne retouche qu'un seul média)
        final bytes = [for (final x in xs) await File(x.path).readAsBytes()];
        final r = await openCreateForm(context, kind: CreatePostKind.image, images: bytes, canal: widget.canal, defiPostId: widget.defiPostId, source: PostSourceLink.imported);
        await _after(r);
      }
    }
  }

  Future<void> _editor(String path, bool isVideo, String source) async {
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => CreateEditorPage(path: path, isVideo: isVideo, source: source, canal: widget.canal, defiPostId: widget.defiPostId, sound: widget.presetSound, pin: widget.pinSource),
    ));
    if (r == kCreateRedo && mounted) {
      // « Refaire » : on rouvre la caméra (ou la galerie si le média venait de la galerie)
      return source == PostSourceLink.captured ? _openCamera(photo: !isVideo) : _pickGallery(video: isVideo);
    }
    await _after(r ?? kCreateBack);
  }

  Future<void> _quotaDialog({required bool video}) async {
    final c = AppColors.of(context);
    final film = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(context.tr('Tes 2 médias de galerie du jour sont utilisés'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(context.tr('Pour continuer aujourd\'hui, filme-toi ou enregistre-toi avec l\'application. Demain, tu retrouveras ta galerie.'), style: TextStyle(color: c.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Plus tard'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent), child: Text(context.tr('Me filmer'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (film == true && mounted) await _openCamera(photo: !video);
  }

  // ── Audio, texte, carte ──────────────────────────────────────────────────

  /// Audio : on s'enregistre (ou on prend un fichier), on choisit éventuellement un effet de voix en écoutant le vrai rendu, puis le formulaire.
  Future<void> _audio() async {
    final rec = await Navigator.of(context).push<CreateVoiceResult>(MaterialPageRoute(builder: (_) => CreateVoicePage(allowPick: _galleryOpen)));
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
    if (mounted) _loadQuota();
  }

  // ── Écran ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    final soon = CardEvents.upcoming(me.countryData?['countryCode'], DateTime.now());
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(
          widget.defiPostId != null ? '🏆 ${context.tr('Répondre au Défi')}' : (widget.canal != null ? '#${widget.canal!.titre ?? 'Canal'}' : context.tr('Créer un post')),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          if (soon != null) ...[
            _EventBanner(event: soon, onTap: () => _card(text: soon.event.text, hint: CardStyleHint(soon.event.style, soon.event.country))),
            const SizedBox(height: 12),
          ],
          if (widget.presetSound != null) ...[
            _SoundBanner(sound: widget.presetSound!),
            const SizedBox(height: 10),
          ],
          _VideoHero(
            onFilm: () => _guard(() => _openCamera(photo: false)),
            onGallery: _galleryOpen ? () => _guard(() => _pickGallery(video: true)) : () => _guard(() => _quotaDialog(video: true)),
            galleryLeft: _quota?.remaining,
          ),
          const SizedBox(height: 8),
          if (!_isChannel) _QuotaLine(quota: _quota) else const SizedBox(height: 10),
          const SizedBox(height: 12),
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
              _Tile(key: const ValueKey('tile_card'), icon: Icons.auto_awesome_rounded, color: c.accentText, label: context.tr('Carte'), hint: context.tr('Une affiche à ton style'), onTap: () => _guard(_card)),
            ],
          ),
          const SizedBox(height: 22),
          const SizedBox(height: 18),
          Text(
            _isChannel
                ? context.tr('Dans un canal, tu peux publier autant de médias de ta galerie que tu veux.')
                : context.tr('Ce que tu filmes ou enregistres ici passe en premier dans le fil, avec la mention « Fait sur Afrolook ».'),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ]),
      ),
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
  const _VideoHero({required this.onFilm, required this.onGallery, required this.galleryLeft});
  final VoidCallback onFilm;
  final VoidCallback onGallery;
  final int? galleryLeft;

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

/// « Galerie aujourd'hui : 1 sur 2 » : deux pastilles qui se vident ; à zéro, on invite à se filmer.
class _QuotaLine extends StatelessWidget {
  const _QuotaLine({required this.quota});
  final ({int limit, int used, int remaining})? quota;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = quota;
    if (q == null) return const SizedBox(height: 18);
    final out = q.remaining <= 0;
    return Row(key: const ValueKey('quota_line'), children: [
      for (var i = 0; i < q.limit; i++)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: i < q.remaining ? c.primary : c.border),
        ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          out
              ? context.tr('Galerie utilisée pour aujourd\'hui : filme-toi pour continuer.')
              : context.tr('Galerie aujourd\'hui : {a} sur {b}', {'a': '${q.remaining}', 'b': '${q.limit}'}),
          style: TextStyle(color: out ? c.danger : c.textSecondary, fontSize: 12.5, fontWeight: out ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    ]);
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
