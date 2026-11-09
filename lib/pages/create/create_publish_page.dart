import 'dart:io';
import '../../models/post_widget.dart';
import '../../widgets/reply_banner.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/api/post_publisher.dart';
import '../../services/media_shrink.dart';
import '../../services/new_content_bus.dart';
import '../../services/postService/post_cooldown_service.dart';
import '../../services/post_source_link.dart';
import '../../services/template_link.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart';
import '../../widgets/monetized_post_option.dart';
import '../../widgets/original_badge.dart';
import '../defi/defi_ui.dart';
import '../studio/studio_sound_link.dart';
import '../studio/montage/montage_preview_page.dart';
import '../user/userAbonnementPage.dart';
import 'create_result.dart';
import 'cover_picker_sheet.dart';

/// Types de publication proposés (le type « Défi » se crée depuis l'espace Défis).
const Map<String, ({String label, IconData icon})> kCreatePostTypes = {
  'LOOKS': (label: 'Looks', icon: Icons.style_rounded),
  'ACTUALITES': (label: 'Actualités', icon: Icons.article_rounded),
  'SPORT': (label: 'Sport', icon: Icons.sports_soccer_rounded),
  'EVENEMENT': (label: 'Événement', icon: Icons.event_rounded),
  'OFFRES': (label: 'Offres', icon: Icons.local_offer_rounded),
  'GAMER': (label: 'Games story', icon: Icons.sports_esports_rounded),
};

/// Limites selon le plan : caractères de la description, poids de la vidéo (Mo), nombre de pays (-1 = tous).
({int chars, int videoMb, int countries}) createLimitsFor(UserData u) {
  if (u.role == UserRole.ADM.name) return (chars: 5000, videoMb: 200, countries: -1);
  if (AbonnementUtils.isGold(u.abonnement)) return (chars: 5000, videoMb: 100, countries: -1);
  if (AbonnementUtils.isPremiumActive(u.abonnement)) return (chars: 3000, videoMb: 40, countries: 20);
  return (chars: 300, videoMb: 30, countries: 1);
}

/// « Formulaire unique » du parcours de création : un seul écran pour tous les types (vidéo, photos, audio, texte). Aperçu du média et description en haut,
/// puis le type de publication et les pays, une note sur ce qui a été ajouté (musique, voix modifiée, « Fait sur Afrolook »), et « Publier » toujours visible.
/// Retour : [kCreateBack] si la personne revient en arrière, [kCreateDone] une fois publié.
class CreatePublishPage extends StatefulWidget {
  const CreatePublishPage({
    super.key,
    required this.kind,
    this.video,
    this.images = const [],
    this.imageFiles = const [],
    this.audio,
    this.audioSeconds,
    this.audioCover,
    this.canal,
    this.defiPostId,
    this.initialDescription,
    this.notes = const [],
    this.publish,
    this.me,
    this.pickCover,
  });

  final CreatePostKind kind;
  final File? video;
  final List<Uint8List> images;
  final List<File> imageFiles;
  final File? audio;
  final int? audioSeconds;

  /// Pochette choisie pour un audio (facultative) : publiée comme image du post.
  final File? audioCover;
  final Canal? canal;
  final String? defiPostId;
  final String? initialDescription;

  /// Lignes d'information sous les champs (ex. « Musique : … ajoutée »).
  final List<String> notes;

  /// Remplace l'envoi réel (tests) : reçoit la description, le type et les pays choisis.
  final Future<void> Function(String description, String type, List<String> countries)? publish;

  /// Profil de la personne (tests) ; par défaut, celui de la session.
  final UserData? me;

  /// Remplace la fenêtre de choix de la couverture (tests) : reçoit la vidéo, sa durée et la couverture actuelle.
  final Future<File?> Function(File video, Duration duration, File? current)? pickCover;

  @override
  State<CreatePublishPage> createState() => _CreatePublishPageState();
}

class _CreatePublishPageState extends State<CreatePublishPage> {
  final _desc = TextEditingController();
  late final UserData _me;
  late final ({int chars, int videoMb, int countries}) _limits;
  String _type = 'LOOKS';
  DateTime? _eventDate;
  final List<String> _countries = [];
  bool _all = false;
  bool _busy = false;
  bool _monetized = false;   // likes payants et vues qui rapportent : désactivé par défaut, comme dans l'ancien formulaire (jamais pour un Défi)
  final _progress = ValueNotifier<double>(0);
  VideoPlayerController? _vc;
  Duration? _videoDuration;
  File? _cover;   // couverture choisie par la personne (null = image prise automatiquement à 1 seconde)

  bool get _isDefi => widget.defiPostId != null;

  @override
  void initState() {
    super.initState();
    _me = widget.me ?? context.read<UserAuthProvider>().loginUserData;
    _limits = createLimitsFor(_me);
    _desc.text = widget.initialDescription ?? '';
    final code = (_me.countryData?['countryCode'])?.toUpperCase();
    if (code != null && code.isNotEmpty) _countries.add(code);
    if (widget.video != null && !kIsWeb) _initVideo();
  }

  Future<void> _initVideo() async {
    final v = VideoPlayerController.file(widget.video!);
    _vc = v;
    try {
      await v.initialize();
      _videoDuration = v.value.duration;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _desc.dispose();
    _vc?.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Choix de la couverture de la vidéo : une image de la vidéo, un instant précis, ou une image de la galerie.
  Future<void> _pickCover() async {
    final v = widget.video;
    if (v == null) return;
    final d = _videoDuration ?? _vc?.value.duration ?? const Duration(seconds: 10);
    final f = widget.pickCover != null ? await widget.pickCover!(v, d, _cover) : await showCoverPicker(context, video: v, duration: d, current: _cover);
    if (f != null && mounted) setState(() => _cover = f);
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, textAlign: TextAlign.center)));

  // ── Choix : type de publication, pays, date ──────────────────────────────

  Future<void> _pickType() async {
    final c = AppColors.of(context);
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('Type de publication'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)))),
          for (final e in kCreatePostTypes.entries)
            ListTile(
              key: ValueKey('type_${e.key}'),
              leading: Icon(e.value.icon, color: _type == e.key ? c.accentText : c.textSecondary),
              title: Text(context.tr(e.value.label), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              trailing: _type == e.key ? Icon(Icons.check_circle_rounded, color: c.primary) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
          const SizedBox(height: 8),
        ])),
      ),
    );
    if (r != null) setState(() => _type = r);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _eventDate ?? now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (d != null) setState(() => _eventDate = DateTime(d.year, d.month, d.day, 12));
  }

  Future<void> _pickCountries() async {
    final c = AppColors.of(context);
    final base = AfricanCountry.sortedFor(_me.countryData?['countryCode']);
    final selected = {..._countries};
    var all = _all;
    final limit = _limits.countries;
    String q = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        final list = AfricanCountry.search(base, q);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .78,
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(children: [
                  Expanded(child: Text(context.tr('Où ta publication sera vue'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
                  Text(limit < 0 ? context.tr('Tous les pays') : '${selected.length}/$limit', style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: TextField(
                  onChanged: (v) => setM(() => q = v),
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: context.tr('Chercher un pays'),
                    hintStyle: TextStyle(color: c.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
                    filled: true,
                    fillColor: c.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (limit < 0)
                SwitchListTile(
                  key: const ValueKey('countries_all'),
                  value: all,
                  activeColor: c.primary,
                  title: Text('🌍 ${context.tr('Le monde entier')}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                  onChanged: (v) => setM(() => all = v),
                )
              else if (limit == 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('1 pays en version gratuite. Premium : jusqu\'à 20 pays. Gold : tous les pays.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final k = list[i];
                    final on = selected.contains(k.code);
                    return CheckboxListTile(
                      value: all ? true : on,
                      activeColor: c.primary,
                      title: Text('${k.flag}  ${k.name}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                      onChanged: all
                          ? null
                          : (v) => setM(() {
                                if (v == true) {
                                  if (limit > 0 && selected.length >= limit) {
                                    if (limit == 1) {
                                      selected
                                        ..clear()
                                        ..add(k.code);
                                    } else {
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(context.tr('Limite de pays atteinte pour ton plan.'))));
                                    }
                                  } else {
                                    selected.add(k.code);
                                  }
                                } else {
                                  selected.remove(k.code);
                                }
                              }),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('countries_ok'),
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.tr('Valider'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    if (!mounted) return;
    setState(() {
      _all = all;
      _countries
        ..clear()
        ..addAll(selected);
    });
  }

  String get _countriesLabel {
    if (_all) return context.tr('Le monde entier');
    if (_countries.isEmpty) return context.tr('Choisir');
    final names = _countries.map((code) => AfricanCountry.sortedFor(null).where((k) => k.code == code).map((k) => k.name).firstOrNull ?? code).toList();
    return names.length <= 2 ? names.join(', ') : '${names.first} +${names.length - 1}';
  }

  // ── Publication ──────────────────────────────────────────────────────────

  void _goPremium() => Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen()));

  /// Vérifie le droit de publier dans le canal (propriétaire, administrateur, publieur autorisé ou membre si le canal est ouvert).
  String? _canalProblem() {
    final canal = widget.canal;
    if (canal == null) return null;
    final id = _me.id;
    final isOwner = id == canal.userId;
    final isAdmin = canal.adminIds?.contains(id) == true;
    final canPost = canal.allowedPostersIds?.contains(id) == true;
    final isMember = canal.usersSuiviId?.contains(id) == true;
    if (!isOwner && !isAdmin && !canPost && !(canal.allowAllMembersToPost == true && isMember)) return context.tr('Tu n\'as pas le droit de publier dans ce canal.');
    if (!isMember && !isOwner && !isAdmin) return context.tr('Abonne-toi au canal pour y publier.');
    return null;
  }

  Future<void> _publish() async {
    if (_busy) return;
    final text = _desc.text.trim();
    if (widget.kind == CreatePostKind.text && text.isEmpty) return _say(context.tr('Écris ton texte avant de publier.'));
    if (text.length > _limits.chars) {
      _say(context.tr('Ta description dépasse {n} caractères.', {'n': '${_limits.chars}'}));
      _goPremium();
      return;
    }
    if (!_all && _countries.isEmpty) return _say(context.tr('Choisis au moins un pays.'));
    if (_type == 'EVENEMENT' && !_isDefi) {
      if (_eventDate == null) return _say(context.tr('Choisis la date de l\'événement.'));
    }
    final problem = _canalProblem();
    if (problem != null) return _say(problem);
    if (widget.video != null && !kIsWeb && _limits.videoMb < 200) {
      final mb = await widget.video!.length() / (1024 * 1024);
      if (mb > _limits.videoMb) {
        if (!mounted) return;
        _say(context.tr('Cette vidéo dépasse la limite de ton plan ({n} Mo). Passe à Premium ou Gold.', {'n': '${_limits.videoMb}'}));
        _goPremium();
        return;
      }
    }
    setState(() => _busy = true);
    _progress.value = 0;
    try {
      final countries = _all ? const ['ALL'] : _countries;
      final type = _isDefi ? 'LOOKS' : _type;
      if (widget.publish != null) {
        await widget.publish!(text, type, countries);
      } else {
        await _send(text, type, countries);
      }
      if (!mounted) return;
      Navigator.of(context).pop(kCreateDone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (_isDefi) {
        DefiDialogs.handleError(context, e, isVote: false, isCreation: false, onRetry: _publish);
      } else {
        handleApiError(context, e, onRetry: _publish, fallback: context.tr('Erreur lors de la publication. Réessaie.'));
      }
    }
  }

  Future<void> _send(String text, String type, List<String> countries) async {
    final files = <File>[];
    var bytes = <Uint8List>[];
    var contentType = 'image/jpeg';
    File? thumb;
    int? w, h;
    switch (widget.kind) {
      case CreatePostKind.video:
        files.add(await MediaShrink.video(widget.video!));
        contentType = 'video/mp4';
        final size = _vc?.value.size;
        if (size != null && size.width > 0) {
          w = size.width.round();
          h = size.height.round();
        }
        if (_cover != null) {
          thumb = _cover;   // couverture choisie par la personne
        } else if (!kIsWeb) {
          try {
            final dir = await getTemporaryDirectory();
            final p = await VideoThumbnail.thumbnailFile(video: widget.video!.path, thumbnailPath: dir.path, imageFormat: ImageFormat.JPEG, maxWidth: 480, quality: 70, timeMs: 1000);
            if (p != null) thumb = File(p);
          } catch (_) {}
        }
      case CreatePostKind.image:
        bytes = widget.images;
        for (final f in widget.imageFiles) {
          files.add(await MediaShrink.file(f));
        }
      case CreatePostKind.audio:
        files.add(await MediaShrink.file(widget.audio!));
        thumb = widget.audioCover;
      case CreatePostKind.text:
        break;
    }
    void onProgress(double v) => _progress.value = v;
    final Post post;
    if (widget.defiPostId != null) {
      post = await PostPublisher.participateDefi(widget.defiPostId!, description: text, files: files, bytes: bytes, bytesContentType: contentType, category: type, countries: countries, thumbnail: thumb, onProgress: onProgress);
    } else {
      post = await PostPublisher.publish(
        description: text,
        files: files,
        bytes: bytes,
        bytesContentType: contentType,
        category: type,
        monetized: _monetized,
        countries: countries,
        canal: widget.canal,
        eventDate: type == 'EVENEMENT' ? _eventDate : null,
        thumbnail: thumb,
        videoWidth: w,
        videoHeight: h,
        onProgress: onProgress,
      );
    }
    StudioSoundLink.linkIfPending(post.id!); // post fait avec un son d'artiste : lien vérifié par le serveur
    PostTemplateLink.published(); // post fait avec un modèle : « Essayer ce modèle » sous le post
    await PostCooldownService.markPosted();
    if (widget.canal != null) {
      widget.canal!.updatedAt = DateTime.now().microsecondsSinceEpoch;
      widget.canal!.publication = (widget.canal!.publication ?? 0) + 1;
    }
    NewContentBus.instance.rememberPublished(post);   // le post créé passe en tête du fil dès le retour à l'accueil
    addPointsForAction(UserAction.post);
    if (mounted) _say(context.tr('Publié !'));
  }

  // ── Écran ────────────────────────────────────────────────────────────────

  Widget _preview(AppColors c) {
    final box = BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12));
    Widget inner;
    String? chip;
    switch (widget.kind) {
      case CreatePostKind.video:
        final v = _vc;
        inner = _cover != null
            ? Image.file(_cover!, key: const ValueKey('publish_cover_preview'), fit: BoxFit.cover, width: 80, height: 104)
            : (v != null && v.value.isInitialized)
            ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
            : Icon(Icons.videocam_rounded, color: c.textSecondary, size: 30);
        final d = _videoDuration;
        if (d != null) chip = '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
      case CreatePostKind.image:
        inner = widget.images.isNotEmpty ? Image.memory(widget.images.first, fit: BoxFit.cover) : (widget.imageFiles.isNotEmpty ? Image.file(widget.imageFiles.first, fit: BoxFit.cover) : Icon(Icons.image_rounded, color: c.textSecondary, size: 30));
        final n = widget.images.length + widget.imageFiles.length;
        if (n > 1) chip = '$n';
      case CreatePostKind.audio:
        inner = widget.audioCover != null ? Image.file(widget.audioCover!, fit: BoxFit.cover) : Icon(Icons.mic_rounded, color: c.accentText, size: 32);
        final s = widget.audioSeconds;
        if (s != null) chip = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      case CreatePostKind.text:
        return const SizedBox.shrink();
    }
    // toucher l'aperçu ouvre le post tel qu'il sera vu, widgets compris (images en mémoire ou fichier) ; pas d'aperçu plein écran pour l'audio
    final File? file = widget.kind == CreatePostKind.video ? widget.video : (widget.imageFiles.isNotEmpty ? widget.imageFiles.first : null);
    final Uint8List? mem = widget.kind == CreatePostKind.image && widget.images.isNotEmpty ? widget.images.first : null;
    final canOpen = widget.kind != CreatePostKind.audio && (file != null || mem != null);
    return GestureDetector(
      onTap: !canOpen
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => MontagePreviewPage(file: mem != null ? null : file, bytes: mem, video: widget.kind == CreatePostKind.video, plain: true))),
      child: Container(
      key: const ValueKey('publish_preview'),
      width: 80,
      height: 104,
      decoration: box,
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        Center(child: inner),
        if (chip != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(6)), child: Text(chip, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
      ]),
      ),
    );
  }

  Widget _field(AppColors c, {Key? key, required String label, required String value, required VoidCallback onTap, IconData? icon}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13))),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.textSecondary),
            ]),
          ),
        ),
      );

  /// Message de garde (page de texte) : ce qui vient d'autres réseaux est refusé, et s'il passe il ne rapporte rien ; Afrolook met en avant l'authentique.
  Widget _authenticNote(AppColors c) => Container(
        key: const ValueKey('authentic_note'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_outlined, size: 20, color: c.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('Afrolook met en avant les contenus authentiques. Les publications copiées d\'autres réseaux sociaux sont refusées, et si l\'une passe, elle ne rapporte aucune pièce.'),
              style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isText = widget.kind == CreatePostKind.text;
    final src = PostSourceLink.pending;
    final notes = <String>[
      ...widget.notes,
      if (PostVoiceLink.pending != null) context.tr('Voix modifiée : le post l\'indiquera.'),
    ];
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          foregroundColor: c.textPrimary,
          centerTitle: true,
          leading: IconButton(key: const ValueKey('publish_back'), icon: const Icon(Icons.chevron_left_rounded, size: 30), onPressed: _busy ? null : () => Navigator.of(context).pop(kCreateBack)),
          title: Text(_isDefi ? '🏆 ${context.tr('Répondre au Défi')}' : (widget.canal != null ? '#${widget.canal!.titre ?? 'Canal'}' : context.tr('Nouveau post')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ),
        body: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
              // widgets posés dans l'éditeur : récapitulatif, avec une croix pour en retirer un
              ValueListenableBuilder<List<PostWidget>>(
                valueListenable: PostWidgetsLink.drafts,
                builder: (context, list, _) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        key: const ValueKey('publish_widgets'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.tr('WIDGETS AJOUTÉS'), style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final w in list)
                              InputChip(
                                label: Text('${w.kind.emoji} ${context.tr(w.kind.label)}${w.question.isEmpty ? '' : ' · ${w.question.length > 22 ? '${w.question.substring(0, 22)}…' : w.question}'}', style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                                onDeleted: () => PostWidgetsLink.remove(w),
                              ),
                          ]),
                        ]),
                      ),
              ),
              // réponse en vidéo : à quelle publication on répond
              const Padding(padding: EdgeInsets.only(bottom: 10), child: Align(alignment: Alignment.centerLeft, child: ReplyBanner(dark: false))),
              // garde : Afrolook met en avant les contenus authentiques, propres à la plateforme
              if (isText) _authenticNote(c),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isText) ...[_preview(c), const SizedBox(width: 12)],
                Expanded(
                  child: TextField(
                    key: const ValueKey('publish_desc'),
                    controller: _desc,
                    minLines: isText ? 8 : 4,
                    maxLines: isText ? 14 : 7,
                    maxLength: _limits.chars,
                    style: TextStyle(color: c.textPrimary, fontSize: 15.5, height: 1.4),
                    decoration: InputDecoration(
                      hintText: switch (widget.kind) {
                        CreatePostKind.video => context.tr('Décris ta vidéo…'),
                        CreatePostKind.image => context.tr('Décris ton image…'),
                        CreatePostKind.audio => context.tr('Description (facultative)…'),
                        CreatePostKind.text => context.tr('Écris ton texte…'),
                      },
                      hintStyle: TextStyle(color: c.textSecondary),
                      filled: true,
                      fillColor: c.surface,
                      counterStyle: TextStyle(color: c.textSecondary, fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.6)),
                    ),
                  ),
                ),
              ]),
              if (widget.kind == CreatePostKind.video && widget.video != null)
                _field(c, key: const ValueKey('field_cover'), label: context.tr('Couverture'), value: _cover == null ? context.tr('Automatique') : context.tr('Choisie'), icon: Icons.image_outlined, onTap: _pickCover),
              if (!_isDefi) _field(c, key: const ValueKey('field_type'), label: context.tr('Type de publication'), value: context.tr(kCreatePostTypes[_type]!.label), icon: kCreatePostTypes[_type]!.icon, onTap: _pickType),
              if (!_isDefi && _type == 'EVENEMENT')
                _field(c, key: const ValueKey('field_date'), label: context.tr('Date de l\'événement'), value: _eventDate == null ? context.tr('Choisir') : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}', icon: Icons.calendar_today_rounded, onTap: _pickDate),
              _field(c, key: const ValueKey('field_countries'), label: context.tr('Pays'), value: _countriesLabel, icon: Icons.public_rounded, onTap: _pickCountries),
              // monétisation : choisie ici par l'auteur (désactivée par défaut) ; un Défi n'est jamais monétisé, un post lien d'un autre réseau non plus (décidé par le serveur)
              if (!_isDefi) ...[
                const SizedBox(height: 14),
                MonetizedPostOption(key: const ValueKey('field_monetized'), value: _monetized, onChanged: (v) => setState(() => _monetized = v)),
              ],
              if (OriginalBadge.isCaptured(src) || notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: c.isDark ? const Color(0xFFEFEBDF) : c.accent.withOpacity(.22), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (OriginalBadge.isCaptured(src)) ...[const OriginalBadge(), const SizedBox(height: 8)],
                    for (final n in notes) Padding(padding: const EdgeInsets.only(top: 2), child: Text(n, style: const TextStyle(color: Color(0xFF15171A), fontSize: 13, height: 1.35))),
                    if (OriginalBadge.isCaptured(src)) Text(context.tr('Ce que tu fais avec Afrolook passe en premier dans le fil.'), style: const TextStyle(color: Color(0xFF5E646C), fontSize: 12.5)),
                  ]),
                ),
              ],
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const ValueKey('publish_go'),
                  onPressed: _busy ? null : _publish,
                  style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, disabledBackgroundColor: c.surfaceVariant, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _busy
                      ? ValueListenableBuilder<double>(
                          valueListenable: _progress,
                          builder: (_, v, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, value: v > 0 ? v : null, color: c.textPrimary)),
                            const SizedBox(width: 12),
                            Text(v > 0 ? '${context.tr('Envoi')} ${(v * 100).round()} %' : context.tr('Publication…'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                          ]),
                        )
                      : Text(context.tr('Publier'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
