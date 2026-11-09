import '../../../widgets/draft_widgets_layer.dart';
import '../../../widgets/widgets_sheet.dart';
import '../../../models/post_widget.dart';
import '../../../services/authentic_video_check.dart';
import '../../../models/community_template.dart';
import 'save_template_sheet.dart';
import '../../../services/branded_save.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../../../ads/gold_gate.dart';
import '../../../ads/rewards_service.dart';
import 'dart:math' as math;
// Éditeur d'un template « prêt à poster » : tout est déjà rempli, la personne change ce qu'elle veut,
// retire les éléments qui ne l'intéressent pas, puis publie (image fixe ou vidéo animée).

import '../../create/prepare_screen.dart';
import '../../../widgets/music/music_overlay.dart';
import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';
import '../../cards/card_flags.dart';
import '../studio_models.dart';
import 'montage_canvas.dart';
import 'montage_catalog.dart';
import 'montage_export.dart';
import 'montage_fx.dart';
import '../artist_sound_common.dart';
import '../../coins/coin_recharge_screen.dart';
import 'montage_look.dart';
import 'montage_text_style.dart';
import '../../../l10n/tr.dart';
import 'montage_music.dart';
import '../../../services/api/music_api.dart';
import '../../../services/music_likes.dart';
import '../../../services/music_queue.dart';
import 'montage_pin.dart';
import '../../../services/montage_signature.dart';
import '../../../services/music_clip.dart';
import '../../../services/studio_project.dart';
import '../../../services/slideshow_plan.dart';
import '../../../widgets/reply_split.dart';
import 'montage_preview_page.dart';
import '../../create/chronique_flow.dart' show ChroniqueFlow;
import 'montage_state.dart';
import 'montage_stickers.dart';
import '../studio_theme.dart';
import '../../../widgets/gold_badge.dart';
import '../../../widgets/gold_lock_row.dart';

AppColors get _c => studioColors;

class MontageEditorPage extends StatefulWidget {
  const MontageEditorPage({super.key, required this.template, this.forChronique = false, this.presetMusic, this.presetKeepAudio = false, this.presetVideoPath, this.presetPhotoPath, this.focus, this.presetPin, this.photoOnly = false, this.showSignature = false, this.project});
  final MontageTemplate template;
  final bool forChronique;

  /// Retouche d'une IMAGE qui doit rester une image (carrousel de plusieurs images) : ni musique, ni effet animé, ni vidéo ; le résultat est toujours une image fixe.
  final bool photoOnly;

  /// Montage « sans habillage » où la signature (@pseudo, ou #titre du canal) reste visible d'office : collage et diaporama de plusieurs images.
  final bool showSignature;

  /// Réglages en attente de la retouche (découpe, vitesse, voix, sous-titres) : envoyés avec le montage, le serveur les applique dans la même chaîne (interrupteur « une passe »).
  final StudioProject? project;

  /// Média déjà préparé (parcours « Créer un post » : la vidéo qu'on vient de filmer, la photo choisie) : l'éditeur s'ouvre dessus, sans demander de média.
  final String? presetVideoPath;
  final String? presetPhotoPath;

  /// Section à montrer d'emblée (« looks » ou « music ») : l'éditeur du parcours ouvre l'outil choisi dans sa barre.
  final String? focus;

  /// Son choisi avant d'arriver ici (« Créer un post avec ce son ») : il remplace la musique du template.
  final MontageMusic? presetMusic;

  /// « Épingler cette vidéo » : la vidéo d'un autre à poser dans le coin, avec son extrait, sa taille et son créneau réglables.
  final MontagePinSource? presetPin;

  /// Musique choisie dans la feuille de l'éditeur avec « Garder le son de ma vidéo » activé.
  final bool presetKeepAudio;

  @override
  State<MontageEditorPage> createState() => _MontageEditorPageState();
}

class _MontageEditorPageState extends State<MontageEditorPage> with SingleTickerProviderStateMixin, MusicSuspendMixin {
  late final MontageState s = MontageState(widget.template)
    ..post = !widget.forChronique
    // Sans habillage : on ne garde que la vidéo (le filigrane « Créé sur Afrolook » reste, comme partout)
    ..hidden.addAll(widget.template.id == kPlainTemplateId ? MontageState.plainHidden(signature: widget.showSignature) : const <MontageLayer>{});
  late final AnimationController _anim = AnimationController(vsync: this, duration: kMontageLoop);
  final _keys = MontageKeys();
  final _looksKey = GlobalKey();
  final _textKey = GlobalKey();
  final _stickersKey = GlobalKey();
  String? _selSticker;   // autocollant sélectionné (cadre blanc sur l'aperçu)
  final _freeText = TextEditingController();
  final _musicKey = GlobalKey();
  final _picker = ImagePicker();

  /// Sections ouvertes de la liste de réglages (la première s'ouvre d'office ; celle qu'on utilise reste ouverte).
  final Set<String> _openGroups = {'media'};
  VideoPlayerController? _video;
  String? _lastJobId;

  /// Identifiant du montage, gardé d'un essai à l'autre tant que le son est le même : un échec puis un nouvel essai ne repaie jamais le son.
  String? _payJobId;
  String? _payJobSoundId;
  double? _frozenT;
  bool _busy = false;

  final _kick = TextEditingController();
  final _title = TextEditingController();
  final _wish = TextEditingController();
  final _prenom = TextEditingController(text: 'Kofi');
  final _date = TextEditingController();
  final _likes = TextEditingController();
  final _comments = TextEditingController();
  final _followers = TextEditingController();

  /// Aperçu sonore dans l'éditeur (la musique reste dans le montage même coupée ici).
  bool _musicPlaying = false;
  int? _musicDurationMs;

  MontageTemplate get tp => widget.template;

  @override
  void initState() {
    super.initState();
    if (widget.presetVideoPath != null) {
      s.videoPath = widget.presetVideoPath;
      s.useVideo = true;
    } else if (widget.presetPhotoPath != null) {
      s.photoPath = widget.presetPhotoPath;
      s.useVideo = false;
    }
    // modèle qui pose d'office des widgets de publication (compte à rebours, lieu…) : seulement si la personne n'en a pas déjà posé ; elle les modifie, les déplace ou les retire
    final presetWidgets = widget.template.presetWidgets;
    if (presetWidgets != null && PostWidgetsLink.drafts.value.isEmpty) {
      for (final w in presetWidgets()) {
        PostWidgetsLink.add(w);
      }
    }
    _syncAnim();
    _syncFields();
    MontageCountries.load().then((_) {
      if (mounted) setState(_syncFields);
    });
    if (s.useVideo) _initVideo();
    final real = context.read<UserAuthProvider>().loginUserData.followersCount;
    _likes.text = s.likesLabel();
    _comments.text = s.commentsLabel();
    _followers.text = s.followersLabel(real) ?? '';
    ArtistSoundPricing.load();
    if (widget.focus == 'second') {   // bouton « 2 vidéos » de l'éditeur : on propose vidéo ou image de la galerie
      _openGroups.add('pin');
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _pickSecond() : null);
    } else if (widget.focus != null) {
      _openGroups.add(widget.focus == 'music' ? 'music' : widget.focus == 'looks' ? 'looks' : 'text');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = (widget.focus == 'music' ? _musicKey : widget.focus == 'text' ? _textKey : widget.focus == 'stickers' ? _stickersKey : _looksKey).currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    }
    // « Ma vidéo avec ce son » : on propose tout de suite de choisir la vidéo
    if (tp.id == kPlainTemplateId && widget.presetVideoPath == null && widget.presetPhotoPath == null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _pickMedia() : null);
    // modèle « duo » : on demande ma vidéo, puis la 2e, et les deux se posent dans la disposition du modèle (haut / bas ou côte à côte)
    if (tp.duoLayout != null) {
      _openGroups.add('pin');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (widget.presetVideoPath == null && widget.presetPhotoPath == null) await _pickMedia();
        if (!mounted) return;
        await _pickSecond();
        if (mounted && s.pins.isNotEmpty) setState(() => s.layout = tp.duoLayout);
      });
    }
    final pinSrc = widget.presetPin;
    if (pinSrc != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _addPin(pinSrc) : null);
    final preset = widget.presetMusic;
    if (preset != null) {
      s.music = preset;
      s.keepVideoAudio = widget.presetKeepAudio;
      // Son payant : on informe tout de suite (prix, solde) ; refus ou solde insuffisant = musique du template
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!await _confirmArtistCost(preset)) {
          final def = studioTrack(tp.music);
          if (mounted) setState(() => s.music = def == null ? null : MontageMusic.free(def));
        }
        _playMusic();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playMusic());
    }
  }

  // ── Musique ──

  /// Ce qu'on entend dans l'éditeur suit les réglages : la voix de la vidéo (si gardée) et la musique, chacune à son volume.
  void _applyVolumes() {
    final v = _video;
    if (v != null && v.value.isInitialized) v.setVolume(s.keepVideoAudio ? s.videoVolume.clamp(0.0, 1.0) : 0);
    MontageMusicPlayer.setVolume(s.musicVolume);
  }

  Future<void> _playMusic() async {
    final m = s.music;
    if (m == null || !mounted) return;
    final ok = await MontageMusicPlayer.playClip(m, _plan, volume: s.musicVolume);
    if (!mounted) return;
    setState(() => _musicPlaying = ok);
    // la vidéo continue de tourner pendant que la musique joue (elle ne doit jamais se figer à l'arrivée du son)
    final v = _video;
    if (s.useVideo && v != null && v.value.isInitialized && !v.value.isPlaying) await v.play();
    if (ok) {
      final known = m.isArtist ? null : studioTrack(m.id)?.durationMs;
      final d = known ?? (await MontageMusicPlayer.duration())?.inMilliseconds;
      if (mounted) {
        final firstTime = _musicDurationMs == null && d != null;
        setState(() => _musicDurationMs = d);
        // la durée du son vient d'être connue : s'il faut le répéter ou le couper, l'aperçu repart avec ce réglage
        if (firstTime && (_plan.loops || _plan.cuts)) await MontageMusicPlayer.playClip(m, _plan, volume: s.musicVolume);
      }
    }
  }

  /// Durée du FILM sur lequel le son est posé (millisecondes) : la vidéo (30 s au plus pour une chronique, 60 s pour un post), ou la durée choisie pour une photo.
  int get _clipMs {
    final maxSec = widget.forChronique ? 30 : 60;
    final sec = s.useVideo ? math.min(_videoSeconds, maxSec.toDouble()) : s.musicSeconds.clamp(3, maxSec).toDouble();
    return (sec * 1000).round();
  }

  MusicClipPlan get _plan => MusicClipPlan(clipMs: _clipMs, startMs: s.musicStartMs, trackMs: _musicDurationMs);

  /// Ce que la personne doit savoir sur son son : durée du film, répété ou coupé, et le bouton pour caler la fin du son sur la fin de la vidéo.
  List<Widget> _musicClipInfo() {
    final plan = _plan;
    final track = plan.trackMs;
    final film = SlideshowPlan.fmt(plan.clipMs / 1000);
    String? note;
    if (track != null) {
      if (plan.loops) {
        note = s.musicStartMs > 0
            ? tr('Depuis ce point, il reste {a} s de son : il sera répété pour remplir tes {b} s.', {'a': SlideshowPlan.fmt(plan.availableMs! / 1000), 'b': film})
            : tr('Ce son dure {a} s : il sera répété pour remplir tes {b} s.', {'a': SlideshowPlan.fmt(track / 1000), 'b': film});
      } else if (plan.cuts) {
        note = tr('Ce son dure {a} : on garde {b} s à partir de {c}.', {'a': MusicClipPlan.mmss(track), 'b': film, 'c': MusicClipPlan.mmss(s.musicStartMs)});
      } else {
        note = tr('Le son et la vidéo ont presque la même durée ({b} s).', {'b': film});
      }
    }
    return [
      const SizedBox(height: 6),
      Text(tr('La vidéo dure {b} s.', {'b': film}), key: const ValueKey('music_film'), style: TextStyle(color: _c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, key: const ValueKey('music_note'), style: TextStyle(color: _c.textSecondary, fontSize: 12.5))),
      if (plan.alignedStartMs != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('music_align'),
            onPressed: plan.isAligned
                ? null
                : () {
                    setState(() => s.musicStartMs = plan.alignedStartMs!);
                    _playMusic();
                  },
            icon: Icon(plan.isAligned ? Icons.check_circle_rounded : Icons.vertical_align_bottom_rounded, size: 18, color: plan.isAligned ? _c.primary : _c.textSecondary),
            label: Text(tr(plan.isAligned ? 'La fin du son tombe sur la fin de la vidéo' : 'Caler la fin du son sur la fin de la vidéo'), style: TextStyle(color: plan.isAligned ? _c.primary : _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ),
    ];
  }

  Future<void> _toggleMusic() async {
    if (_musicPlaying) {
      await MontageMusicPlayer.stop();
      if (mounted) setState(() => _musicPlaying = false);
    } else {
      await _playMusic();
    }
  }

  Future<void> _chooseMusic() async {
    await MontageMusicPlayer.stop();
    if (!mounted) return;
    setState(() => _musicPlaying = false);
    final pick = await showMontageMusicPicker(context, current: s.music, onArtistCta: () => openArtistSpace(context));
    if (!mounted || pick == null) return;
    // Son payant : on informe tout de suite (prix, solde) ; refus ou solde insuffisant = on garde la musique d'avant
    if (pick.music != null && !await _confirmArtistCost(pick.music)) {
      await _playMusic();
      return;
    }
    if (!mounted) return;
    setState(() {
      final hadMusic = s.music != null;
      s.music = pick.music;
      s.musicStartMs = 0;
      _musicDurationMs = null;
      if (pick.music == null) {
        s.keepVideoAudio = true;   // musique retirée : ta voix revient
      } else if (!hadMusic) {
        s.keepVideoAudio = false;   // première musique : seule la musique joue, sauf si tu gardes ta voix
      }
    });
    await _playMusic();
  }

  @override
  void dispose() {
    _anim.dispose();
    _video?.dispose();
    MontageMusicPlayer.stop();
    for (final c in [_kick, _title, _wish, _prenom, _date, _likes, _comments, _followers]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncAnim() {
    if (s.fxActive && (s.animated || s.useVideo)) {
      if (!_anim.isAnimating) _anim.repeat();
    } else {
      _anim.stop();
      _anim.value = .3;
    }
  }

  /// Recopie les textes pré-remplis (ou modifiés) dans les champs.
  void _syncFields() {
    final r = resolveMontageTexts(s);
    _kick.text = r.kick;
    _title.text = r.title;
    _wish.text = r.wish;
  }

  Future<void> _initVideo() async {
    final old = _video;
    // mixWithOthers : la vidéo ne demande pas le « focus audio » du téléphone, sinon la musique d'aperçu (qui le demande) mettait la vidéo en pause
    final opts = VideoPlayerOptions(mixWithOthers: true);
    final v = s.videoPath != null ? VideoPlayerController.file(File(s.videoPath!), videoPlayerOptions: opts) : VideoPlayerController.asset(kMontageSampleVideo, videoPlayerOptions: opts);
    _video = v;
    await old?.dispose();
    try {
      await v.initialize();
      // la vidéo de la personne garde sa forme : paysage = cadre 16:9, 4:5 ou carré = 4:5, vertical long = 9:16 (une chronique reste verticale)
      if (s.videoPath != null && !widget.forChronique && v.value.size.height > 0) {
        final r = v.value.size.width / v.value.size.height;
        s.setFormat(r > 1.1 ? 'landscape' : (r >= 0.7 ? 'post' : 'story'));
      }
      await v.setLooping(true);
      await v.setVolume(s.keepVideoAudio ? s.videoVolume.clamp(0.0, 1.0) : 0);   // la voix de la vidéo s'entend seulement si « Garder le son de ma vidéo » est activé
      await v.play();
      // certains téléphones n'animent l'image qu'après un second « lecture » (la surface vidéo n'est prête qu'après le premier affichage) : on vérifie et on relance
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        if (mounted && identical(_video, v) && v.value.isInitialized && !v.value.isPlaying) {
          await v.seekTo(Duration.zero);
          await v.play();
          if (mounted) setState(() {});
        }
      });
    } catch (_) {
      if (mounted) _say('La vidéo ne peut pas être lue dans l’éditeur (format non pris en charge). Elle sera quand même utilisée telle quelle.');
    }
    if (mounted) setState(() {});
  }

  // ── Médias ──

  Future<void> _pickMedia({bool second = false}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          _sheetTile(ctx, Icons.photo_library_rounded, 'Photo de la galerie', 'pg'),
          _sheetTile(ctx, Icons.photo_camera_rounded, 'Prendre une photo', 'pc'),
          if (!second && _videoAllowed) ...[

            _sheetTile(ctx, Icons.video_library_rounded, 'Vidéo de la galerie', 'vg'),
            _sheetTile(ctx, Icons.videocam_rounded, 'Filmer une vidéo', 'vc'),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    final src = choice.endsWith('c') ? ImageSource.camera : ImageSource.gallery;
    if (choice.startsWith('p')) {
      final x = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 92);
      if (x == null || !mounted) return;
      // photo de la galerie : même contrôle d'authenticité que les vidéos (marque d'un autre réseau, contenu explicite) ; la caméra n'en a pas besoin
      if (src == ImageSource.gallery && (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: !widget.forChronique) || !mounted)) return;
      // une photo à la place de la vidéo : la 2e vidéo (ou image) posée ne pourrait plus être montée ; on prévient avant de la retirer
      if (!second && s.pins.isNotEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _c.surface,
            title: Text('Remplacer ta vidéo par une photo ?', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
            content: Text('Le montage deviendrait une image : la 2e vidéo ou image ajoutée sera retirée.', style: TextStyle(color: _c.textSecondary)),
            actions: [
              TextButton(key: const ValueKey('swap_keep'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Garder ma vidéo')),
              TextButton(key: const ValueKey('swap_photo'), onPressed: () => Navigator.pop(ctx, true), child: Text('Remplacer', style: TextStyle(color: _c.danger))),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        _clearPins();
      }
      setState(() {
        if (second) {
          s.secondPhotoPath = x.path;
        } else {
          s.photoPath = x.path;
          s.useVideo = false;
          s.videoPath = null;
        }
      });
      if (!second) {
        await _video?.dispose();
        _video = null;
        setState(_syncAnim);
      }
    } else {
      final maxSec = widget.forChronique ? 30 : 60;
      final x = await _picker.pickVideo(source: src, maxDuration: Duration(seconds: maxSec));
      if (x == null || !mounted) return;
      if (src == ImageSource.gallery && (!await AuthenticVideoCheck.gate(context, x.path, allowClaim: !widget.forChronique) || !mounted)) return;   // vidéo de la galerie : vérification d'authenticité
      if (await File(x.path).length() > 60 * 1024 * 1024) {
        _say('La vidéo est trop lourde (60 Mo maximum).');
        return;
      }
      setState(() {
        s.videoPath = x.path;
        s.useVideo = true;
        _syncAnim();
      });
      await _initVideo();
    }
  }

  Widget _sheetTile(BuildContext ctx, IconData icon, String label, String v) => ListTile(
        leading: Icon(icon, color: _c.primary),
        title: Text(label, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w600)),
        onTap: () => Navigator.pop(ctx, v),
      );

  Widget _mediaWidget() {
    final v = _video;
    if (s.useVideo && v != null && v.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)),
      );
    }
    if (s.photoPath != null) return Image.file(File(s.photoPath!), fit: BoxFit.cover);
    final sample = tp.sampleIsVideo ? Image.asset('assets/images/intro4.jpg', fit: BoxFit.cover) : Image.asset(tp.sample, fit: BoxFit.cover);
    // Tant que la personne n'a pas choisi sa propre photo, le modèle s'ouvre sur SA photo de profil (et non sur une photo d'exemple)
    final avatar = context.read<UserAuthProvider>().loginUserData.imageUrl;
    if (avatar != null && avatar.startsWith('http') && tp.id != kPlainTemplateId) {
      return Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, __, ___) => sample);
    }
    return sample;
  }

  Widget? _secondWidget() {
    if (s.secondPhotoPath != null) return Image.file(File(s.secondPhotoPath!), fit: BoxFit.cover);
    if (tp.dualSample != null) return Image.asset(tp.dualSample!, fit: BoxFit.cover);
    return null;
  }

  // ── Pays ──

  Future<void> _pickCountry() async {
    await MontageCountries.load();
    if (!mounted) return;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _CountrySheet(current: s.country),
    );
    if (code == null || !mounted) return;
    setState(() {
      s.country = code;
      s.wish = null;
      s.kick = null;
      s.title = null;
      s.customDate = '';
      _date.clear();
      _syncFields();
    });
  }

  // ── Publication ──

  String _caption() {
    final w = resolveMontageTexts(s).wish.trim();
    if (widget.forChronique) return w.length > 100 ? w.substring(0, 100) : w;
    return '${w.isEmpty ? resolveMontageTexts(s).title : w}\n#AfrolookStudio';
  }

  Future<void> _setT(double t) async {
    setState(() => _frozenT = t);
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Le titre est-il déjà dans la bibliothèque de la personne (acheté) ? On le demande au serveur si on ne le sait pas encore.
  Future<bool> _ownsSound(String id) async {
    if (MusicQueue.ownedIds.value.contains(id)) return true;
    try {
      MusicLikes.start();
      await MusicApi.sound(id);
    } catch (_) {}
    return MusicQueue.ownedIds.value.contains(id);
  }

  /// Son d'artiste payant : on informe avant (prix, part de l'artiste, solde) et on bloque si le solde est insuffisant.
  /// Rien n'est débité ici : le serveur débite seulement quand le montage est réussi.
  Future<bool> _confirmArtistCost([MontageMusic? music]) async {
    final m = music ?? s.music;
    final user = context.read<UserAuthProvider>().loginUserData;
    if (m == null || !m.isArtist || !m.paid || m.artistId == user.id) return true;
    if (await _ownsSound(m.id)) return true;   // déjà acheté : utilisable sans second paiement
    await ArtistSoundPricing.load();
    final price = m.useCoins;
    final balance = user.giftCoinsBalance ?? 0;
    if (!mounted) return false;
    if (balance < price) {
      final recharge = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _c.surface,
          title: Text('Solde insuffisant', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(
            '« ${m.title} » coûte $price pièces et tu en as $balance. Recharge tes pièces, ou choisis une musique gratuite (les musiques Afrolook et les sons gratuits des artistes ne coûtent rien).',
            style: TextStyle(color: _c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Plus tard', style: TextStyle(color: _c.textSecondary))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _c.primary), child: const Text('Recharger mes pièces')),
          ],
        ),
      );
      if (recharge == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
      }
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text('Son d’artiste payant', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('« ${m.title} »', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Prix : $price pièces', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
          Text('${m.shareCoins} pièces vont directement à l’artiste ${m.subtitle.split(' · ').first}.', style: TextStyle(color: _c.textSecondary, height: 1.35)),
          const SizedBox(height: 8),
          Text('Ton solde : $balance pièces → ${balance - price} après.', style: TextStyle(color: _c.textSecondary)),
          const SizedBox(height: 8),
          Text('Les pièces sont débitées quand tu lances « Terminer ». Si le montage échoue, tu peux réessayer sans repayer ce son.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: _c.textSecondary))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _c.primary), child: Text('Utiliser ($price 🪙)')),
        ],
      ),
    );
    return ok == true;
  }

  /// « Voir le rendu exact » : le serveur fabrique le même montage en basse définition (360 p, 6 s au plus), sans fin animée, sans payer ni compter le son d'un artiste.
  Future<void> _previewExact() async {
    if (_busy || !s.exportsVideo) return;
    if (s.pins.isNotEmpty && !s.hasVideo) {
      _say(tr('Une 2e vidéo ou image demande une vidéo de base : filme-toi ou retire-la.'));
      return;
    }
    await MontageMusicPlayer.stop();
    setState(() {
      _busy = true;
      _musicPlaying = false;
    });
    final step = ValueNotifier<String>(tr('Préparation…'));
    var dialogOpen = true;
    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: Dialog.fullscreen(child: PrepareScreen(step: step, video: true))),
    );
    File? made;
    try {
      made = await MontageExport.video(
        keys: _keys,
        s: s,
        videoPath: s.videoPath,
        videoAsset: s.videoPath == null ? kMontageSampleVideo : null,
        setT: _setT,
        onStep: (v) => step.value = v,
        maxSeconds: widget.forChronique ? 30 : 60,
        project: widget.project,
        preview: true,
      );
    } catch (e) {
      closeDialog();
      if (mounted) {
        final busy = e is ApiException && (e.code == 'render_busy' || e.code == 'montage_busy');
        _say(busy ? tr("Le serveur prépare d'autres vidéos en ce moment : réessaie dans un instant.") : tr("L'aperçu exact n'a pas pu être fabriqué. Tu peux quand même terminer ton montage."));
      }
    } finally {
      step.dispose();
      closeDialog();
      if (mounted) {
        setState(() {
          s.exportCapture = false;
          _busy = false;
          _frozenT = null;
        });
      }
    }
    if (made != null && mounted) {
      await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => MontagePreviewPage(file: made!, video: true, exact: true)));
    }
  }

  Future<void> _publish() async {
    if (_busy) return;
    // garde-fou : une 2e vidéo ou image sans vidéo de base ne serait pas montée (le résultat serait une image) ; on ne laisse jamais partir ce montage à moitié
    if (s.pins.isNotEmpty && !s.hasVideo) {
      _say('Une 2e vidéo ou image demande une vidéo de base : filme-toi ou retire-la.');
      return;
    }
    if (!await _confirmArtistCost() || !mounted) return;
    await MontageMusicPlayer.stop();
    setState(() {
      _busy = true;
      _musicPlaying = false;
    });
    final step = ValueNotifier<String>('Préparation…');
    final video = s.exportsVideo;
    var dialogOpen = true;
    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(child: PrepareScreen(step: step, video: video)),
      ),
    );
    File? made;
    try {
      if (video) {
        made = await MontageExport.video(
          keys: _keys,
          s: s,
          videoPath: s.videoPath,
          videoAsset: s.videoPath == null ? kMontageSampleVideo : null,
          setT: _setT,
          onStep: (v) => step.value = v,
          maxSeconds: widget.forChronique ? 30 : 60,
          project: widget.project,
          jobId0: (_payJobId != null && _payJobSoundId == s.music?.id) ? _payJobId : null,
          onJob: (id) {
            _lastJobId = id;
            _payJobId = id;
            _payJobSoundId = s.music?.id;
          },
          onPaid: (coins) => _say('🎤 $coins pièces utilisées pour le son de l’artiste. Merci de soutenir les artistes !'),
          outroLabel: MontageSignature.outroLabel(context.read<UserAuthProvider>().loginUserData.pseudo),
        );
      } else {
        await _setT(.3);
        made = await MontageExport.still(_keys);
      }
    } catch (e) {
      closeDialog();
      if (mounted) _say(_exportErrorText(e));
    } finally {
      step.dispose();
      closeDialog();
      if (mounted) {
        setState(() {
          s.exportCapture = false;
          _busy = false;
          _frozenT = null;
        });
      }
    }
    // la suite (aperçu, publication) est hors du « try » : une erreur d'enregistrement ne doit jamais fermer la page de montage
    if (made != null && mounted) await _afterCreate(made, video);
  }

  /// Message clair pour chaque échec possible du montage (le texte du serveur quand il est précis).
  String _exportErrorText(Object e) {
    if (e is ApiException) {
      if (e.isInsufficientCoins) return 'Solde insuffisant : il te faut ${s.music?.useCoins ?? 0} pièces pour ce son. Recharge ou choisis une musique gratuite.';
      switch (e.code) {
        case 'montage_busy':
          return 'Un montage précédent se termine encore. Patiente quelques secondes puis réessaie.';
        case 'single_pass_off':
          SinglePassConfig.enabled = false;
          return tr('Le rendu en une passe vient d\'être coupé : reviens en arrière et refais la retouche, elle se fera étape par étape.');
        case 'trim_invalid':
          return tr('Le passage gardé est hors de la vidéo ou dure moins de 1 seconde.');
        case 'render_busy':
          return tr("Le serveur prépare d'autres vidéos en ce moment : réessaie dans un instant.");
        case 'music_unavailable':
          return e.message.isNotEmpty ? e.message : 'Ce son n’est plus disponible. Choisis une autre musique.';
        case 'payment_required':
          return 'Le paiement du son n’a pas pu être confirmé. Réessaie : tu n’es débité(e) qu’une seule fois.';
        case 'upload_invalid':
        case 'layers_missing':
          return 'Une partie du montage n’a pas été reçue. Vérifie ta connexion et réessaie.';
      }
      return e.message.isNotEmpty ? e.message : 'Le montage a échoué.';
    }
    if (e is TimeoutException) return 'La connexion est trop lente pour terminer le montage. Réessaie avec une meilleure connexion.';
    return 'Le montage a échoué. Vérifie ta connexion et réessaie.';
  }

  /// Montage prêt : publier, l'enregistrer dans la galerie, les deux, ou continuer à le modifier.
  Future<void> _afterCreate(File file, bool video) async {
    // d'abord on regarde le résultat (avec le son) : « Modifier » revient à l'éditeur, « Poursuivre » continue. Dans un parcours de chronique, l'aperçu de la chronique suit déjà.
    if (ChroniqueFlow.active == null) {
      final go = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => MontagePreviewPage(file: file, video: video)));
      if (go != true || !mounted) return;
    }
    var saved = false;
    while (mounted) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _c.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(video ? 'Ta vidéo est prête 🎬' : 'Ton image est prête ✨', style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              if (saved)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('✅ Enregistrée dans ta galerie (album Afrolook)', style: TextStyle(color: _c.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 6),
              _sheetTile(ctx, Icons.send_rounded, widget.forChronique ? 'Publier en chronique' : 'Publier en post', 'publish'),
              if (!saved) _sheetTile(ctx, Icons.download_rounded, 'Enregistrer dans ma galerie', 'save'),
              if (!saved) _sheetTile(ctx, Icons.download_done_rounded, 'Enregistrer et publier', 'both'),
              _sheetTile(ctx, Icons.edit_rounded, 'Continuer à modifier', 'edit'),
            ]),
          ),
        ),
      );
      if (!mounted || choice == null || choice == 'edit') return;
      if (choice == 'save' || choice == 'both') {
        // l'export (enregistrer hors d'Afrolook) demande Gold ou 2-3 pubs ; publier dans Afrolook reste libre
        if (!await GoldGate.export(context, context.read<UserAuthProvider>().loginUserData.id ?? '')) {
          if (!mounted) return;
          continue;
        }
        if (!mounted) return;
        // la copie enregistrée porte la marque Afrolook comme un téléchargement (pastille qui change de coin, logo animé, fin Afrolook) ; la version publiée reste sans signature
        _say('Ajout de la signature Afrolook…');
        final branded = await BrandedSave.prepare(file, video: video, pseudo: context.read<UserAuthProvider>().loginUserData.pseudo);
        if (!mounted) return;
        if (branded == null) {
          _say('La signature Afrolook n’a pas pu être ajoutée : réessaie dans un instant.');
          saved = false;
        } else {
          saved = await MontageExport.saveToGallery(branded, video: video);
          if (!mounted) return;
          if (!saved) _say('Impossible d’enregistrer : autorise l’accès aux photos dans les réglages du téléphone.');
        }
        if (choice == 'save') continue;
      }
      Navigator.pop(
        context,
        StudioResult(
          type: video ? StudioContentType.video : StudioContentType.image,
          mediaFile: file,
          textContent: _caption(),
          templateId: 'montage_${tp.id}',
          forChronique: widget.forChronique,
          artistSoundId: s.music?.isArtist == true && video ? s.music!.id : null,
          soundJobId: s.music?.isArtist == true && video ? _lastJobId : null,
          usedOwnMedia: s.photoPath != null || s.videoPath != null,
          pins: video && s.pins.any((p) => !p.source.isLocal) ? [for (final p in s.pins.take(kMaxPins).where((p) => !p.source.isLocal)) p.toLink()] : null,   // une vidéo de galerie n'a pas de publication à ouvrir
        ),
      );
      return;
    }
  }

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  // ── Écran ──

  @override
  Widget build(BuildContext context) {
    syncStudioColors(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    final pseudo = MontageSignature.label(me.pseudo);   // « #titre » dans un canal, sinon le pseudo
    final screenH = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        foregroundColor: _c.textPrimary,
        elevation: 0,
        title: Text(tp.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          if (s.exportsVideo)
            IconButton(
              key: const ValueKey('preview_exact'),
              tooltip: tr('Voir le rendu exact'),
              onPressed: _busy ? null : _previewExact,
              icon: const Icon(Icons.slow_motion_video_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              onPressed: _busy ? null : _publish,
              style: FilledButton.styleFrom(backgroundColor: _c.primary),
              child: Text(s.exportsVideo ? 'Terminer 🎬' : 'Terminer'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: screenH * .5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(clipBehavior: Clip.none, children: [
               ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MontageCanvas(
                  state: s,
                  keys: _keys,
                  t: _frozenT ?? .3,
                  animation: _frozenT == null && _anim.isAnimating ? _anim : null,
                  media: _mediaWidget(),
                  secondMedia: _secondWidget(),
                  meVideo: s.useVideo ? _video : null,
                  pseudo: pseudo,
                  avatarUrl: MontageSignature.avatar(me.imageUrl),
                  followers: MontageSignature.followers(me.followersCount),
                  // la personne glisse elle-même le pseudo, les chiffres, le texte, le logo et les autocollants ; tout reste dans le cadre
                  onMove: _moveElement,
                  onScale: _scaleSticker,
                  onTapSticker: (id) => setState(() => _selSticker = id),
                  selectedSticker: _selSticker,
                ),
               ),
               // widgets (sondage, question, lien…) : les mêmes qu'à l'écran de création, déplaçables, redimensionnables et supprimables ici aussi, quel que soit le média
               Positioned.fill(child: DraftWidgetsLayer(videoSeconds: () => s.hasVideo ? _videoSeconds : null)),
              ]),
            ),
          ),
        ),
        Expanded(child: _controls()),
      ]),
    ),
    );
  }

  /// Retour (bouton de l'application ou du téléphone) : on demande avant de perdre le montage.
  Future<void> _confirmLeave() async {
    if (_busy) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text(context.tr('Quitter le montage ?'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(context.tr('Les changements faits dans le Studio seront perdus.'), style: TextStyle(color: _c.textSecondary)),
        actions: [
          TextButton(key: const ValueKey('studio_stay'), onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Continuer le montage'))),
          TextButton(key: const ValueKey('studio_leave'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Quitter'), style: TextStyle(color: _c.danger))),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  /// Une section repliable de la liste de réglages : titre, icône, et son contenu quand elle est ouverte.
  /// « Enregistrer comme modèle » : la recette vient de l'état de l'éditeur (modèle de base, textes, musique de la bibliothèque, widgets sans donnée personnelle).
  Future<void> _saveAsTemplate() async {
    final r = resolveMontageTexts(s);
    final baseId = tp.id.startsWith('u_') ? (CommunityTemplate.known['u:${tp.id.substring(2)}']?.baseId ?? '') : tp.id;
    if (baseId.isEmpty || baseId == kPlainTemplateId) return;
    String cut(String x, int n) => x.length > n ? x.substring(0, n) : x;
    final lines = <String>[
      for (final l in [r.wish, ...r.options])
        if (l.trim().isNotEmpty) cut(l.trim(), 160),
    ].toSet().take(6).toList();
    final m = s.music;
    final recipe = CommunityTemplate.buildRecipe(
      baseId: baseId,
      kick: cut(r.kick, 80),
      title: cut(r.title, 80),
      chip: tp.chip == null ? null : cut(tp.chip!, 80),
      lines: lines,
      musicId: (m != null && m.type == 'free') ? m.id : null,
      widgets: PostWidgetsLink.drafts.value,
    );
    final created = await showSaveTemplateSheet(context, recipe: recipe, suggestedName: tp.name);
    if (created == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Modèle publié ! Retrouve-le, ses utilisations et tes gains dans « Mes modèles ».')));
  }

  Widget _group(String id, IconData icon, String title, List<Widget> kids) {
    final open = _openGroups.contains(id);
    return Container(
      key: ValueKey('group_$id'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: open ? _c.primary : _c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          key: ValueKey('group_head_$id'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => open ? _openGroups.remove(id) : _openGroups.add(id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Icon(icon, color: _c.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _c.textSecondary),
            ]),
          ),
        ),
        if (open) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids)),
      ]),
    );
  }

  /// « 2 vidéos » depuis l'éditeur : on choisit une vidéo ou une image de la galerie.
  Future<void> _pickSecond() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _c.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetTile(ctx, Icons.video_library_rounded, 'Une vidéo de ma galerie', 'video'),
          _sheetTile(ctx, Icons.image_rounded, 'Une image de ma galerie', 'image'),
        ]),
      ),
    );
    if (!mounted || v == null) return;
    v == 'image' ? await _pickGalleryImagePin() : await _pickGalleryPin();
  }

  /// IMAGES de la galerie posées comme médias épinglés, jusqu'à [kMaxPins] au total : la 1re (si rien n'est épinglé) prend les dispositions, les autres sont posées librement,
  /// chacune avec sa taille, sa place et son créneau. Sans son, sans extrait. Chaque image passe la vérification d'authenticité des images.
  Future<void> _pickGalleryImagePin() async {
    final room = kMaxPins - s.pins.length;
    if (room <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('5 médias au plus.')));
      return;
    }
    List<XFile> files;
    if (room == 1) {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92, maxWidth: 2000);
      files = x == null ? const [] : [x];
    } else {
      files = (await _picker.pickMultiImage(imageQuality: 92, maxWidth: 2000, limit: room)).take(room).toList();
    }
    for (final x in files) {
      if (!mounted) return;
      if (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: false) || !mounted) continue;
      final first = s.pins.isEmpty;
      _addPin(MontagePinSource(postId: '', thumbUrl: x.path, authorPseudo: '', durationSec: 2, localImagePath: x.path), extra: !first);
      if (first && s.layout == null && s.pins.isNotEmpty) setState(() => s.layout = 'tb');
    }
  }

  Widget _controls() {
    final r = resolveMontageTexts(s);
    final day = kNationalDays[s.country];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        // Les réglages sont rangés par sujet, dans l'ordre où on s'en sert : ma vidéo, 2e vidéo ou image, texte et autocollants, musique et sons, effets, format.
        _group('media', Icons.perm_media_rounded, 'Ma vidéo ou ma photo', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _btn(Icons.add_a_photo_rounded, _videoAllowed ? 'Changer ma photo ou vidéo' : 'Changer ma photo', () => _pickMedia()),
            if (tp.dualSample != null || tp.baby) _btn(Icons.add_photo_alternate_rounded, tp.baby ? 'Photo de bébé' : '2e photo', () => _pickMedia(second: true)),
          ]),
          // son de CHAQUE vidéo réglé ici, sans musique nécessaire (la vidéo ajoutée a son propre curseur dans « Deuxième vidéo ou image »)
          if (s.hasVideo) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              key: const ValueKey('own_audio'),
              contentPadding: EdgeInsets.zero,
              value: s.keepVideoAudio,
              onChanged: (v) {
                setState(() => s.keepVideoAudio = v);
                _applyVolumes();
              },
              activeThumbColor: _c.primary,
              title: Text('Son de ma vidéo', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(s.keepVideoAudio ? 'Ta voix est gardée dans le montage.' : 'Ta vidéo est muette dans le montage.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
            ),
            if (s.keepVideoAudio)
              _volumeRow('Volume de ma vidéo', s.videoVolume, 1.5, (v) {
                setState(() => s.videoVolume = v);
                _applyVolumes();
              }, const ValueKey('vol_own')),
          ],
        ]),
        if ((s.hasVideo && !widget.forChronique) || s.pins.isNotEmpty)
          _group('pin', Icons.splitscreen_rounded, 'Deuxième vidéo ou image', [
            if (s.pins.isEmpty) ...[
              Text('Ajoute une autre vidéo ou une image de ta galerie : en haut / en bas, côte à côte, en bandeau ou dans un coin.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.35)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _btn(Icons.video_library_rounded, 'Vidéo de ma galerie', _pickGalleryPin),
                _btn(Icons.image_rounded, 'Image de ma galerie', _pickGalleryImagePin),
              ]),
            ],
            _pinSection(),
          ]),
        _group('text', Icons.title_rounded, 'Texte et autocollants', [
          KeyedSubtree(key: _textKey, child: _freeTextSection()),
          const SizedBox(height: 14),
          KeyedSubtree(key: _stickersKey, child: _stickersSection()),
        ]),
        if (!widget.photoOnly) _group('music', Icons.music_note_rounded, 'Musique et sons', [KeyedSubtree(key: _musicKey, child: _musicSection())]),
        _group('looks', Icons.auto_awesome_rounded, 'Effets et couleurs', [KeyedSubtree(key: _looksKey, child: _looksSection()), if (!widget.photoOnly) _fxSection()]),
        if (!widget.photoOnly && tp.id != kPlainTemplateId)
          _group('savemodel', Icons.dashboard_customize_rounded, 'Mon modèle', [
            Text('Enregistre ce montage (textes, musique de la bibliothèque, widgets) pour que les autres le refassent avec leurs médias. Gratuit ou payant en pièces : tu choisis.',
                style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 8),
            _btn(Icons.bookmark_add_rounded, 'Enregistrer comme modèle', _saveAsTemplate),
          ]),
        _group('format', Icons.tune_rounded, 'Format et contenu du modèle', [
        _label('Format'),
        _seg(['Chronique 9:16', 'Post 4:5', 'Paysage 16:9'], s.landscape ? 2 : (s.post ? 1 : 0), (i) => setState(() => s.setFormat(const ['story', 'post', 'landscape'][i]))),
        if (tp.fx != MontageFx.none && !widget.photoOnly) ...[
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.useVideo || s.animated,
            onChanged: s.useVideo
                ? null
                : (v) => setState(() {
                      s.animated = v;
                      _syncAnim();
                    }),
            activeThumbColor: _c.primary,
            title: Text('Animé (vidéo)', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(
              s.useVideo
                  ? 'Ta vidéo garde l’effet animé.'
                  : (s.animated ? 'L’effet bouge dans la vidéo.' : (s.music != null ? 'Effet figé (la musique fait quand même une vidéo).' : 'Publié en image fixe.')),
              style: TextStyle(color: _c.textSecondary, fontSize: 12),
            ),
          ),
        ],
        if (tp.country) ...[
          const SizedBox(height: 10),
          _label('Pays'),
          InkWell(
            onTap: _pickCountry,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.border)),
              child: Row(children: [
                ClipOval(child: SizedBox(width: 30, height: 30, child: CardFlag(s.country))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(MontageCountries.name(s.country), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
                    if (tp.indep)
                      Text(
                        day == null
                            ? 'Pas de date enregistrée : choisis-la ci-dessous.'
                            : '${day.$4 ? 'Indépendance' : 'Fête nationale'} : ${montageDayLabel(day.$1, day.$2)}${day.$3 != null ? ' ${day.$3}' : ''}',
                        style: TextStyle(color: _c.textSecondary, fontSize: 12),
                      ),
                  ]),
                ),
                Text('Changer', style: TextStyle(color: _c.primary, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          if (tp.indep && day == null) ...[
            const SizedBox(height: 10),
            _seg(['Fête nationale', 'Indépendance'], s.indepChosen ? 1 : 0, (i) => setState(() {
                  s.indepChosen = i == 1;
                  s.wish = null;
                  s.title = null;
                  _syncFields();
                })),
            const SizedBox(height: 8),
            _field(_date, 'Date de la fête (ex. 15 septembre)', (v) {
              s.customDate = v;
              s.kick = null;
              s.wish = null;
              final rr = resolveMontageTexts(s);
              _kick.text = rr.kick;
              _wish.text = rr.wish;
            }),
          ],
        ],
        const SizedBox(height: 14),
        _label('Texte de souhait — choisis ou écris le tien'),
        for (var i = 0; i < r.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                s.textIndex = i;
                s.wish = null;
                _wish.text = resolveMontageTexts(s).wish;
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.wish == null && s.textIndex == i ? _c.accent : _c.border),
                ),
                child: Text(r.options[i], style: TextStyle(color: _c.textPrimary, fontSize: 13)),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _field(_wish, 'Texte', (v) => s.wish = v, maxLines: 3),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field(_kick, 'Sur-titre', (v) => s.kick = v)),
          const SizedBox(width: 8),
          Expanded(child: _field(_title, 'Titre', (v) => s.title = v)),
        ]),
        if (tp.usesPrenom) ...[
          const SizedBox(height: 8),
          _field(_prenom, 'Prénom dans le texte', (v) {
            s.prenom = v;
            if (s.wish == null) _wish.text = resolveMontageTexts(s).wish;
          }),
        ],
        if (s.shows(MontageLayer.stats) || s.shows(MontageLayer.followers)) ...[
          const SizedBox(height: 16),
          _label('Chiffres affichés (modifiables)'),
          Row(children: [
            if (s.shows(MontageLayer.stats)) ...[
              Expanded(child: _field(_likes, '❤️ J’aime', (v) => s.likesText = v)),
              const SizedBox(width: 8),
              Expanded(child: _field(_comments, '💬 Comm.', (v) => s.commentsText = v)),
            ],
            if (s.shows(MontageLayer.stats) && s.shows(MontageLayer.followers)) const SizedBox(width: 8),
            if (s.shows(MontageLayer.followers)) Expanded(child: _field(_followers, '👥 Abonnés', (v) => s.followersText = v)),
          ]),
          const SizedBox(height: 4),
          Text('Écris 1400 ou 1,4k. Les abonnés partent de ton vrai nombre.', style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
        ],
        const SizedBox(height: 16),
        _label('Éléments — touche pour retirer ou remettre'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in _layers())
            FilterChip(
              selected: s.shows(l),
              label: Text(l.label),
              onSelected: (on) => setState(() {
                on ? s.hidden.remove(l) : s.hidden.add(l);
                _syncAnim();
              }),
              selectedColor: _c.primary.withValues(alpha: .22),
              checkmarkColor: _c.primary,
              backgroundColor: _c.surface,
              labelStyle: TextStyle(color: s.shows(l) ? _c.textPrimary : _c.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5),
              side: BorderSide(color: s.shows(l) ? _c.primary : _c.border),
            ),
        ]),
        const SizedBox(height: 8),
        Text('« Créé sur Afrolook » reste toujours, en petit, en bas à droite.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _musicSection() {
    final m = s.music;
    final maxSec = widget.forChronique ? 30 : 60;
    final durs = [7, 15, 30, 60].where((d) => d <= maxSec).toList();   // 7, 15, 30 ou 60 s (30 au plus pour une chronique)
    final dur = _musicDurationMs;
    final clip = _clipMs;
    final slideMax = m != null && dur != null && dur > clip + 1000 ? dur - clip : 0;
    final canSlide = slideMax > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Musique'),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: m != null ? _c.primary : _c.border)),
        child: Row(children: [
          if (m != null)
            IconButton(
              onPressed: _toggleMusic,
              icon: Icon(_musicPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: _c.primary, size: 34),
            )
          else
            Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.music_off_rounded, color: _c.textSecondary, size: 26)),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: _chooseMusic,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m == null ? 'Sans musique' : '${studioTrack(m.id)?.emoji ?? '🎤'} ${m.title}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
                Text(
                  m == null
                      ? 'Touche pour ajouter une musique'
                      : (m.isArtist ? '${m.subtitle} · 🪙 ${m.useCoins} pièces' : m.subtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _c.textSecondary, fontSize: 12),
                ),
              ]),
            ),
          ),
          TextButton(onPressed: _chooseMusic, child: Text(m == null ? 'Ajouter' : 'Changer', style: TextStyle(color: _c.primary, fontWeight: FontWeight.w800))),
          if (m != null)
            IconButton(
              tooltip: 'Retirer la musique',
              onPressed: () async {
                await MontageMusicPlayer.stop();
                setState(() {
                  s.music = null;
                  s.keepVideoAudio = true;   // sans musique, ta voix revient
                  _musicPlaying = false;
                });
                _applyVolumes();
              },
              icon: Icon(Icons.close_rounded, color: _c.textSecondary),
            ),
        ]),
      ),
      if (m != null && canSlide) ...[
        const SizedBox(height: 6),
        Row(children: [
          Text('Début : ${_mmss(s.musicStartMs)}', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
          Expanded(
            child: Slider(
              value: s.musicStartMs.clamp(0, slideMax).toDouble(),
              min: 0,
              max: slideMax.toDouble(),
              activeColor: _c.primary,
              onChanged: (v) => setState(() => s.musicStartMs = v.round()),
              onChangeEnd: (_) => _playMusic(),
            ),
          ),
        ]),
      ],
      if (m != null) ..._musicClipInfo(),
      if (m != null && !s.useVideo) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Durée de la vidéo', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
          for (final d in durs)
            ChoiceChip(
              label: Text('$d s'),
              selected: s.musicSeconds == d,
              onSelected: (_) {
                setState(() => s.musicSeconds = d);
                _playMusic();   // l'aperçu suit tout de suite la nouvelle durée
              },
              selectedColor: _c.primary.withValues(alpha: .25),
              backgroundColor: _c.surface,
              labelStyle: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
              side: BorderSide(color: s.musicSeconds == d ? _c.primary : _c.border),
            ),
        ]),
      ],
      if (m != null && s.useVideo)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: s.keepVideoAudio,
          onChanged: (v) {
            setState(() => s.keepVideoAudio = v);
            _applyVolumes();
          },
          activeThumbColor: _c.primary,
          title: Text('Garder le son de ma vidéo', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text(s.keepVideoAudio ? 'Ta voix et la musique sont mélangées.' : 'Le son de ta vidéo est coupé : seule la musique est jouée.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
        ),
      // réglage des volumes : gratuit pour tout le monde (musique, voix de la vidéo, baisse automatique de la musique)
      if (m != null) ...[
        _volumeRow('Volume de la musique', s.musicVolume, 1, (v) {
          setState(() => s.musicVolume = v);
          _applyVolumes();
        }, const ValueKey('vol_music')),
        if (s.useVideo && s.keepVideoAudio) ...[
          _volumeRow('Volume de ma voix (vidéo)', s.videoVolume, 1.5, (v) {
            setState(() => s.videoVolume = v);
            _applyVolumes();
          }, const ValueKey('vol_video')),
          SwitchListTile(
            key: const ValueKey('duck_music'),
            contentPadding: EdgeInsets.zero,
            value: s.duckMusic,
            onChanged: (v) => setState(() => s.duckMusic = v),
            activeThumbColor: _c.primary,
            title: Text('Baisser la musique quand je parle', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text('La musique redevient forte dans les silences.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
          ),
        ],
      ],
      // la fin Afrolook : obligatoire pour tout le monde ; SEUL le plan Gold peut la retirer (le serveur l'impose aussi). Les autres ne voient aucun interrupteur.
      if (s.useVideo)
        RewardsService.goldActive
            ? SwitchListTile(
                key: const ValueKey('outro_switch'),
                contentPadding: EdgeInsets.zero,
                value: s.outro,
                onChanged: (v) => setState(() => s.outro = v),
                activeThumbColor: _c.primary,
                title: Text(context.tr('Ajouter la fin Afrolook'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(context.tr('2,8 secondes à la fin de ta vidéo : logo, ton @pseudo et une invitation. Avec Gold, tu peux la retirer.'), style: TextStyle(color: _c.textSecondary, fontSize: 12)),
              )
            : GoldLockRow(
                key: const ValueKey('outro_locked'),
                title: context.tr('Fin Afrolook incluse'),
                subtitle: context.tr('2,8 secondes à la fin de ta vidéo : logo, ton @pseudo et une invitation. Seul le plan Gold peut la retirer.'),
              ),
      if (m != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Avec une musique, ton montage est publié en vidéo.', style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
        ),
    ]);
  }

  /// Un curseur de volume (0 à [max]) avec le pourcentage affiché.
  Widget _volumeRow(String label, double value, double max, ValueChanged<double> onChanged, Key key) {
    return Row(children: [
      Expanded(flex: 5, child: Text(label, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
      Expanded(flex: 6, child: Slider(key: key, value: value.clamp(0, max).toDouble(), min: 0, max: max, divisions: (max * 20).round(), onChanged: onChanged, activeColor: _c.primary)),
      SizedBox(width: 42, child: Text('${(value * 100).round()} %', textAlign: TextAlign.right, style: TextStyle(color: _c.textSecondary, fontSize: 12.5))),
    ]);   // au-delà de 100 %, le renforcement ne s'entend que dans la vidéo finale (l'aperçu du téléphone s'arrête à 100 %)
  }

  String _mmss(int ms) {
    final t = ms ~/ 1000;
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Looks de couleur sobres (style Instagram) : valables pour une photo comme pour une vidéo.
  // ── Déplacer et autocollants ─────────────────────────────────────────────

  void _moveElement(String id, Offset center) {
    setState(() {
      if (id.startsWith('pin:')) {
        final pin = s.pins.where((e) => 'pin:${e.id}' == id).firstOrNull;
        if (pin != null) {
          pin.center = center;
          _selSticker = id;
        }
      } else if (id.startsWith('st:')) {
        final st = s.stickers.where((e) => 'st:${e.id}' == id).firstOrNull;
        if (st != null) {
          st.center = center;
          _selSticker = st.id;
        }
      } else {
        s.moved[id] = center;
      }
    });
  }

  void _scaleSticker(String id, double scale) {
    if (id.startsWith('pin:')) {
      final pin = s.pins.where((e) => 'pin:${e.id}' == id).firstOrNull;
      if (pin != null) setState(() => pin.scale = scale.clamp(.5, 3.3));
      return;
    }
    final st = s.stickers.where((e) => 'st:${e.id}' == id).firstOrNull;
    if (st != null) setState(() => st.scale = scale.clamp(kStickerMinScale, kStickerMaxScale));
  }

  Future<bool> _gate(String key) => GoldGate.feature(context, context.read<UserAuthProvider>().loginUserData.id ?? '', key);

  /// Durée de la vidéo en secondes (10 s par défaut tant qu'elle n'est pas lue).
  double get _videoSeconds {
    final v = _video;
    var d = (v != null && v.value.isInitialized) ? v.value.duration.inMilliseconds / 1000 : 10.0;
    final pr = widget.project;
    if (pr != null && pr.isNotEmpty && SinglePassConfig.enabled && v != null && v.value.isInitialized) d = pr.finalMs(v.value.duration.inMilliseconds) / 1000;
    return d < 1 ? 10 : d;
  }

  String _sec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Choisir de quel instant à quel instant un élément est affiché. Renvoie `null` si on annule, `(0, 0)` pour « toujours affiché ».
  Future<(double, double)?> _pickTimeRange({double? start, double? end}) {
    final total = _videoSeconds;
    var range = RangeValues((start ?? 0).clamp(0, total).toDouble(), (end ?? math.min(total, 3.0)).clamp(0.3, total).toDouble());
    return showDialog<(double, double)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _c.surface,
          title: Text('Quand l\'afficher ?', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('De ${_sec(range.start)} s à ${_sec(range.end)} s (vidéo de ${_sec(total)} s)', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            RangeSlider(
              key: const ValueKey('timed_range'),
              values: range,
              min: 0,
              max: total,
              divisions: (total * 10).round().clamp(1, 600),
              onChanged: (v) => setD(() => range = v.end - v.start < 0.3 ? RangeValues(v.start, math.min(total, v.start + 0.3)) : v),
            ),
            Text('L\'élément n\'apparaît que pendant ce temps.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, (0.0, 0.0)), child: const Text('Toujours afficher')),
            FilledButton(key: const ValueKey('timed_ok'), onPressed: () => Navigator.pop(ctx, (range.start, range.end)), child: const Text('Valider')),
          ],
        ),
      ),
    );
  }

  /// « Message à l'écran » : un texte court affiché de tel instant à tel instant de la vidéo.
  Future<void> _addTimedMessage() async {
    if (!await _gate('timed_message') || !mounted) return;
    if (s.stickers.length >= kMaxStickers) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tu peux mettre jusqu\'à $kMaxStickers éléments.')));
      return;
    }
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text('Message à l\'écran', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
        content: TextField(key: const ValueKey('timed_text'), controller: ctrl, autofocus: true, maxLength: 40, style: TextStyle(color: _c.textPrimary), decoration: const InputDecoration(hintText: 'Ex. : Livraison gratuite aujourd\'hui')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Suivant')),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final range = await _pickTimeRange();
    if (range == null || !mounted) return;
    final n = s.stickers.length;
    final st = MontageSticker(id: '${DateTime.now().microsecondsSinceEpoch}_$n', kind: 'badge', value: text, center: const Offset(.5, .2));
    if (range.$2 > range.$1) {
      st.startSec = range.$1;
      st.endSec = range.$2;
    }
    setState(() {
      s.stickers.add(st);
      _selSticker = st.id;
    });
  }

  /// Pose un média épinglé avec, pour la vidéo d'un autre, son crédit « avec @nom ». Le 1er remplace l'ancien (vidéo ou image, il peut tenir une disposition) ;
  /// avec [extra], c'est une IMAGE de plus (jusqu'à [kMaxPins] médias au total) : elle s'ajoute sans rien effacer, posée librement à une place libre.
  void _addPin(MontagePinSource src, {bool extra = false}) {
    if (!RewardsService.featureUnlocked('pin_video')) {
      _gate('pin_video').then((ok) {
        if (ok && mounted) _addPin(src, extra: extra);
      });
      return;
    }
    if (!s.hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Épingler une vidéo demande une vidéo : filme-toi d\'abord.')));
      return;
    }
    if (extra) {
      if (!s.canAddPin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('5 médias au plus.')));
        return;
      }
    } else if (s.pins.isNotEmpty) {
      s.stickers.removeWhere((e) => e.id.startsWith('credit_'));
      s.pins.clear();
    }
    final pin = MontagePin(id: '${DateTime.now().microsecondsSinceEpoch}_${s.pins.length}', source: src);
    if (extra) {
      pin.center = kPinSpots[s.pins.length % kPinSpots.length].$2;   // chaque image arrive à une place différente : elles ne se cachent pas entre elles
      pin.scale = .8;
    } else {
      s.layout = ReplyLayout.id.value;   // choisie dans la caméra (réponse en vidéo) ; null = vidéo dans un coin
      s.layoutSwap = ReplyLayout.swap.value;
    }
    pin.startSec = 0;
    pin.endSec = src.isImage ? math.max(1.0, _videoSeconds) : math.min(_videoSeconds, math.max(1.0, pin.clipSeconds));
    setState(() {
      _openGroups.add('pin');
      s.pins.add(pin);
      // crédit visible : le créateur d'origine est toujours cité
      if (!src.isLocal) s.stickers.add(MontageSticker(id: 'credit_${pin.id}', kind: 'badge', value: 'avec @${src.authorPseudo}', center: const Offset(.5, .94)));
      _selSticker = 'pin:${pin.id}';
    });
  }

  /// 2e vidéo choisie dans la GALERIE : posée comme une vidéo épinglée (coin, haut/bas, côte à côte ou bandeau), sans son ; elle est envoyée au serveur au moment de terminer.
  Future<void> _pickGalleryPin() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (x == null || !mounted) return;
    // comme toute vidéo de la galerie : refusée si elle vient d'un autre réseau (TikTok, Instagram…) ou si elle est explicite ; ici pas de « C'est la mienne » (elle n'a pas de publication à vérifier)
    if (!await AuthenticVideoCheck.gate(context, x.path, allowClaim: false) || !mounted) return;
    double secs = 0;
    String thumb = '';
    try {
      final v = VideoPlayerController.file(File(x.path));
      await v.initialize();
      secs = v.value.duration.inMilliseconds / 1000;
      await v.dispose();
      final dir = await getTemporaryDirectory();
      thumb = await VideoThumbnail.thumbnailFile(video: x.path, thumbnailPath: dir.path, imageFormat: ImageFormat.JPEG, maxWidth: 480, quality: 70) ?? '';
    } catch (_) {}
    if (!mounted) return;
    if (secs > 0 && secs < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette vidéo est trop courte (1 seconde au moins).')));
      return;
    }
    final me = context.read<UserAuthProvider>().loginUserData.pseudo ?? '';
    _addPin(MontagePinSource(postId: '', thumbUrl: thumb, authorPseudo: me, durationSec: secs, localVideoPath: x.path));
    if (s.layout == null) setState(() => s.layout = 'tb');   // une 2e vidéo de galerie se montre d'abord en haut / bas : on peut la mettre dans un coin ensuite
  }

  /// Retire TOUS les médias épinglés (la vidéo de base devient une photo : plus rien à épingler).
  void _clearPins() {
    setState(() {
      s.clearPins();
      _selSticker = null;
    });
  }

  /// Retire UN média épinglé (et son crédit) ; les autres restent. Si c'était le 1er (celui des dispositions) et qu'il en reste, les dispositions s'arrêtent : les images restantes sont libres.
  void _removePin(MontagePin p) {
    setState(() {
      s.removePin(p);
      _selSticker = s.pins.isEmpty ? null : 'pin:${s.pins.first.id}';
    });
  }

  /// Le média épinglé choisi (touché sur l'aperçu ou dans la rangée de pastilles) ; null si aucun.
  MontagePin? get _selPin => s.pins.where((e) => 'pin:${e.id}' == _selSticker).firstOrNull;

  /// Réglages des médias épinglés (jusqu'à 5) : on choisit un média, puis sa taille, sa place, son créneau, sa forme ; chacun se retire seul.
  /// Les dispositions (haut / bas, côte à côte, bandeau), l'extrait, le son et le rebouclage ne concernent que le 1er média.
  Widget _pinSection() {
    if (s.pins.isEmpty) return const SizedBox.shrink();
    final p = _selPin ?? s.pins.first;
    final isFirst = identical(p, s.pins.first);
    final inLayout = s.layout != null && isFirst;
    final free = !inLayout;   // taille, place et créneau libres (le 1er média en disposition occupe sa place)
    final dur = p.source.durationSec > 0 ? p.source.durationSec : 15.0;
    final clipMax = math.min(dur, 15.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      if (s.pins.length < kMaxPins)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _btn(Icons.add_photo_alternate_rounded, 'Ajouter une image (${s.pins.length}/$kMaxPins)', _pickGalleryImagePin),
        ),
      if (s.pins.length > 1) ...[
        _label('Mes médias épinglés'),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (var i = 0; i < s.pins.length; i++)
            ChoiceChip(
              key: ValueKey('pin_pick_$i'),
              avatar: Icon(s.pins[i].source.isImage ? Icons.image_rounded : Icons.videocam_rounded, size: 16, color: _c.textSecondary),
              label: Text('${i + 1}'),
              selected: identical(s.pins[i], p),
              onSelected: (_) => setState(() => _selSticker = 'pin:${s.pins[i].id}'),
            ),
        ]),
        const SizedBox(height: 8),
      ],
      _label(isFirst ? (p.source.isImage ? 'Image ajoutée' : 'Vidéo ajoutée${p.source.authorPseudo.isEmpty || p.source.isLocal ? '' : ' · @${p.source.authorPseudo}'}') : 'Image ${s.pins.indexOf(p) + 1}'),
      if (isFirst)
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final e in const [(null, 'Dans un coin'), ('tb', 'Haut / bas'), ('sbs', 'Côte à côte'), ('bar', 'Bandeau')])
            ChoiceChip(key: ValueKey('layout_${e.$1 ?? 'corner'}'), label: Text(e.$2), selected: s.layout == e.$1, onSelected: (_) => setState(() {
              s.layout = e.$1;
              s.layoutRatio = null;   // chaque disposition repart de son partage de base
            })),
        ]),
      if (inLayout) ...[
        Text('Part de la place ${s.layout == 'sbs' ? 'de gauche' : 'du haut'} : ${(s.firstShare * 100).round()} %', style: TextStyle(color: _c.textSecondary, fontSize: 13)),
        Slider(key: const ValueKey('layout_ratio'), value: s.firstShare, min: .25, max: .75, onChanged: (v) => setState(() => s.layoutRatio = v)),
        Text('Zoom de ${p.source.isImage ? 'l\'image' : 'la vidéo'} ajoutée : ${s.originZoom.toStringAsFixed(1)} ×', style: TextStyle(color: _c.textSecondary, fontSize: 13)),
        Slider(key: const ValueKey('layout_origin_zoom'), value: s.originZoom, min: 1, max: 2.5, onChanged: (v) => setState(() => s.originZoom = v)),
        Text('Zoom de ta vidéo : ${s.meZoom.toStringAsFixed(1)} ×', style: TextStyle(color: _c.textSecondary, fontSize: 13)),
        Slider(key: const ValueKey('layout_me_zoom'), value: s.meZoom, min: 1, max: 2.5, onChanged: (v) => setState(() => s.meZoom = v)),
        SwitchListTile(key: const ValueKey('layout_swap'), contentPadding: EdgeInsets.zero, title: const Text('Inverser les places'), value: s.layoutSwap, onChanged: (v) => setState(() => s.layoutSwap = v)),
      ],
      if (isFirst && !p.source.isImage) Text('Extrait de sa vidéo : de ${_sec(p.clipStartSec)} s à ${_sec(p.clipEndSec)} s (${_sec(p.clipSeconds)} s, 15 s au plus). Le téléphone ne charge que cet extrait, léger.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
      if (isFirst && !p.source.isImage) RangeSlider(
        key: const ValueKey('pin_clip_range'),
        values: RangeValues(p.clipStartSec.clamp(0, dur).toDouble(), p.clipEndSec.clamp(0, dur).toDouble()),
        min: 0,
        max: dur,
        divisions: (dur * 10).round().clamp(1, 900),
        onChanged: (v) => setState(() {
          var a = v.start, b = v.end;
          if (b - a > clipMax) {
            if (a != p.clipStartSec) {
              b = a + clipMax;
            } else {
              a = b - clipMax;
            }
          }
          if (b - a < 1) b = math.min(dur, a + 1);
          p.clipStartSec = a;
          p.clipEndSec = b;
        }),
      ),
      if (free) Row(children: [
        Icon(Icons.timer_rounded, size: 18, color: _c.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text('Affichée de ${_sec(p.startSec)} s à ${_sec(p.endSec)} s de ta vidéo', style: TextStyle(color: _c.textSecondary, fontSize: 13))),
        TextButton(
          key: const ValueKey('pin_time'),
          onPressed: () async {
            final r = await _pickTimeRange(start: p.startSec, end: p.endSec);
            if (r == null || !mounted) return;
            setState(() {
              p.startSec = r.$2 > r.$1 ? r.$1 : 0;
              p.endSec = r.$2 > r.$1 ? r.$2 : _videoSeconds;
            });
          },
          child: const Text('Régler le temps'),
        ),
      ]),
      if (free) ...[
        Text('Taille : ${(p.widthFrac * 100).round()} % de la largeur', style: TextStyle(color: _c.textSecondary, fontSize: 13)),
        Slider(key: const ValueKey('pin_size'), value: p.scale.clamp(.5, 3.3).toDouble(), min: .5, max: 3.3, onChanged: (v) => setState(() => p.scale = v)),
        Text('Place', style: TextStyle(color: _c.textSecondary, fontSize: 13)),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (var i = 0; i < kPinSpots.length; i++)
            ActionChip(key: ValueKey('pin_spot_$i'), label: Text(kPinSpots[i].$1), onPressed: () => setState(() => p.center = kPinSpots[i].$2)),
        ]),
      ],
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (free) ...[
          ChoiceChip(key: const ValueKey('pin_rect'), label: const Text('Rectangle'), selected: !p.circle, onSelected: (_) => setState(() => p.circle = false)),
          ChoiceChip(key: const ValueKey('pin_round'), label: const Text('Rond'), selected: p.circle, onSelected: (_) => setState(() => p.circle = true)),
          IconButton(key: const ValueKey('pin_smaller'), tooltip: 'Plus petite', icon: Icon(Icons.remove_circle_outline_rounded, color: _c.textPrimary), onPressed: () => setState(() => p.scale = (p.scale - .25).clamp(.5, 3.3))),
          IconButton(key: const ValueKey('pin_bigger'), tooltip: 'Plus grande', icon: Icon(Icons.add_circle_outline_rounded, color: _c.textPrimary), onPressed: () => setState(() => p.scale = (p.scale + .25).clamp(.5, 3.3))),
        ],
        IconButton(key: const ValueKey('pin_delete'), tooltip: p.source.isImage ? 'Retirer cette image' : 'Retirer la vidéo épinglée', icon: Icon(Icons.delete_outline_rounded, color: _c.textPrimary), onPressed: () => _removePin(p)),
      ]),
      if (isFirst && !p.source.isImage) SwitchListTile(key: const ValueKey('layout_origin_audio'), contentPadding: EdgeInsets.zero, title: const Text('Garder le son de la vidéo ajoutée'), value: s.originAudio, onChanged: (v) => setState(() => s.originAudio = v)),
      if (isFirst && s.originAudio && !p.source.isImage) _volumeRow('Volume de la vidéo ajoutée', s.originVolume, 1.5, (v) => setState(() => s.originVolume = v), const ValueKey('layout_origin_volume')),
      if (isFirst && !p.source.isImage) SwitchListTile(key: const ValueKey('layout_origin_loop'), contentPadding: EdgeInsets.zero, title: const Text('Reboucler la vidéo ajoutée'), subtitle: Text('Elle recommence tant que ta vidéo dure ; sinon elle reste figée sur sa dernière image.', style: TextStyle(color: _c.textSecondary, fontSize: 12)), value: s.originLoop, onChanged: (v) => setState(() => s.originLoop = v)),
      Text('Touche un média pour le choisir, glisse-le pour le placer, pince-le pour le zoomer. Son créneau règle quand il apparaît${isFirst && !p.source.isImage ? ' (et quand on l\'entend)' : ''}. Tu peux en poser 5 au plus.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
    ]);
  }

  /// Ajoute un widget (sondage, question, lien…) depuis le Studio : même parcours que l'éditeur de création (5 au plus par publication).
  Future<void> _addDraftWidget() async {
    if (PostWidgetsLink.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('5 widgets au plus par publication.')));
      return;
    }
    final w = await addWidgetFlow(context);
    if (w != null) PostWidgetsLink.add(w);
  }

  Future<void> _addSticker() async {
    if (s.stickers.length >= kMaxStickers) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tu peux mettre jusqu\'à $kMaxStickers autocollants.')));
      return;
    }
    final pick = await showStickerPicker(context);
    if (pick == null || !mounted) return;
    // posé au centre, légèrement décalé à chaque ajout pour ne pas cacher le précédent
    final n = s.stickers.length;
    final st = MontageSticker(id: '${DateTime.now().microsecondsSinceEpoch}_$n', kind: pick.kind, value: pick.value, center: Offset(.5 + ((n % 3) - 1) * .12, .42 + ((n ~/ 3) % 3) * .1));
    setState(() {
      s.stickers.add(st);
      _selSticker = st.id;
    });
  }

  /// Vidéo permise dans cet éditeur : le modèle l'accepte et ce n'est pas la retouche d'une image de carrousel.
  bool get _videoAllowed => tp.canUseVideo && !widget.photoOnly;

  MontageSticker? get _selected => s.stickers.where((e) => e.id == _selSticker).firstOrNull;

  /// Outil « Placer » : déplacer les éléments avec le doigt, ajouter des autocollants du pack, les agrandir ou les retirer.
  Widget _stickersSection() {
    final sel = _selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Placer et décorer'),
      Text('Touche et glisse le pseudo, les chiffres, le texte ou un autocollant pour le poser où tu veux. Pince un autocollant pour l\'agrandir. Tout reste toujours visible dans l\'image.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5, height: 1.35)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _btn(Icons.add_reaction_rounded, 'Ajouter un autocollant', _addSticker),
        _btn(Icons.widgets_rounded, 'Ajouter un widget', _addDraftWidget),
        if (s.hasVideo) _btn(Icons.timer_rounded, 'Message à l\'écran', _addTimedMessage, gold: 'timed_message'),
        if (s.moved.isNotEmpty) _btn(Icons.restart_alt_rounded, 'Tout remettre en place', () => setState(s.moved.clear)),
      ]),
      if (sel != null) ...[
        const SizedBox(height: 10),
        if (s.hasVideo)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.timer_rounded, size: 18, color: _c.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(sel.timed ? 'Affiché de ${_sec(sel.startSec!)} s à ${_sec(sel.endSec!)} s' : 'Affiché pendant toute la vidéo', style: TextStyle(color: _c.textSecondary, fontSize: 13))),
              TextButton(
                key: const ValueKey('sticker_time'),
                onPressed: () async {
                  final r = await _pickTimeRange(start: sel.startSec, end: sel.endSec);
                  if (r == null || !mounted) return;
                  setState(() {
                    if (r.$2 > r.$1) {
                      sel.startSec = r.$1;
                      sel.endSec = r.$2;
                    } else {
                      sel.startSec = null;
                      sel.endSec = null;
                    }
                  });
                },
                child: const Text('Régler le temps'),
              ),
            ]),
          ),
        Row(children: [
          Text('Autocollant', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(key: const ValueKey('sticker_smaller'), tooltip: 'Plus petit', icon: Icon(Icons.remove_circle_outline_rounded, color: _c.textPrimary), onPressed: () => _scaleSticker('st:${sel.id}', sel.scale / 1.2)),
          IconButton(key: const ValueKey('sticker_bigger'), tooltip: 'Plus grand', icon: Icon(Icons.add_circle_outline_rounded, color: _c.textPrimary), onPressed: () => _scaleSticker('st:${sel.id}', sel.scale * 1.2)),
          IconButton(
            key: const ValueKey('sticker_delete'),
            tooltip: 'Retirer',
            icon: Icon(Icons.delete_outline_rounded, color: _c.textPrimary),
            onPressed: () => setState(() {
              s.stickers.removeWhere((e) => e.id == sel.id);
              _selSticker = null;
            }),
          ),
        ]),
      ],
    ]);
  }

  /// Outil « Texte » : un texte libre posé sur la photo ou la vidéo (couleur et position au choix).
  Widget _freeTextSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Texte sur l\'image'),
      TextField(
        key: const ValueKey('free_text_field'),
        controller: _freeText,
        maxLength: 120,
        maxLines: 3,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: _c.textPrimary),
        onChanged: (v) => setState(() => s.freeText = v),
        decoration: InputDecoration(
          hintText: 'Écris ton texte…',
          hintStyle: TextStyle(color: _c.textSecondary),
          counterStyle: TextStyle(color: _c.textSecondary),
          filled: true,
          fillColor: _c.surface,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.primary)),
        ),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (var i = 0; i < kFreeTextColors.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              key: ValueKey('free_color_$i'),
              onTap: () => setState(() => s.freeColor = i),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kFreeTextColors[i], border: Border.all(color: s.freeColor == i ? _c.primary : _c.border, width: s.freeColor == i ? 3 : 1)),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      _seg(['Haut', 'Milieu', 'Bas'], s.freePos, (i) => setState(() => s.freePos = i)),
      const SizedBox(height: 16),
      _label(tr('Style d\'écriture')),
      SizedBox(
        height: 64,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < kFreeTextFonts.length; i++)
            GestureDetector(
              key: ValueKey('free_font_$i'),
              onTap: () => setState(() => s.freeFont = i),
              child: Container(
                width: 74,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: s.freeFont == i ? _c.primary : _c.border, width: s.freeFont == i ? 2.5 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Aa', style: TextStyle(fontFamily: kFreeTextFonts[i].family, fontSize: 22, color: _c.textPrimary, height: 1.1)),
                  Text(tr(kFreeTextFonts[i].name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: _c.textSecondary, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      _label(tr('Arrière-plan du texte')),
      _seg([for (final m in kFreeBgModes) tr(m)], s.freeBg, (i) => setState(() => s.freeBg = i)),
      if (s.freeBg > 0) ...[
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < kFreeTextColors.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                key: ValueKey('free_bg_color_$i'),
                onTap: () => setState(() => s.freeBgColor = i),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kFreeTextColors[i], border: Border.all(color: s.freeBgColor == i ? _c.primary : _c.border, width: s.freeBgColor == i ? 3 : 1)),
                ),
              ),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      _label(tr('Cadre')),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < kFreeFrames.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('free_frame_$i'),
                label: Text(tr(kFreeFrames[i]), style: TextStyle(color: s.freeFrame == i ? Colors.white : _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                selected: s.freeFrame == i,
                selectedColor: _c.primary,
                backgroundColor: _c.surface,
                onSelected: (_) => setState(() => s.freeFrame = i),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _looksSection() {
    final sel = {for (final l in s.looks) l.id};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Look'),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(tr('Touche plusieurs looks pour les mélanger ({n} au plus).', {'n': MontageState.maxLooks}), style: TextStyle(color: _c.textSecondary, fontSize: 12)),
      ),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kMontageLooks.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final look = i == 0 ? null : kMontageLooks[i - 1];
            final on = i == 0 ? sel.isEmpty : sel.contains(look!.id);
            final colors = look?.swatch ?? const [Color(0xFF3A3A3A), Color(0xFF1A1A1A)];
            return GestureDetector(
              onTap: () {
                if (look == null) {
                  setState(() => s.look = null);
                } else if (!s.toggleLook(look)) {
                  _say(tr('{n} looks au plus : retires-en un pour en ajouter un autre.', {'n': MontageState.maxLooks}));
                } else {
                  setState(() {});
                }
              },
              child: SizedBox(
                width: 62,
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                      border: Border.all(color: on ? _c.primary : _c.border, width: on ? 3 : 1),
                    ),
                    child: i == 0 ? Icon(Icons.auto_awesome_outlined, size: 20, color: _c.textSecondary) : null,
                  ),
                  const SizedBox(height: 5),
                  Text(i == 0 ? 'Modèle' : look!.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? _c.textPrimary : _c.textSecondary, fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  /// Effet animé : disponible SANS modèle, avec n'importe quel look, texte, épingle ou musique (tout est rendu en une seule passe).
  Widget _fxSection() {
    final tp = s.template;
    final cur = s.fxChoice;
    Widget chip(Key key, String label, bool on, VoidCallback onTap) => ChoiceChip(key: key, label: Text(label), selected: on, onSelected: (_) => onTap());
    void pick(MontageFx? f) {
      setState(() {
        s.fxChoice = f;
        // un effet qui bouge fait une vidéo ; « Aucun » ou « Du modèle » rendent la main au réglage du modèle
        if (f != null && f != MontageFx.none) {
          s.animated = true;
          s.hidden.remove(MontageLayer.fx);
        }
        _syncAnim();
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _label('Effet animé'),
      Text(s.exportsVideo ? tr('L\'effet bouge dans la vidéo.') : tr('Avec un effet, l\'image devient une courte vidéo.'), style: TextStyle(color: _c.textSecondary, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        chip(const ValueKey('fx_none'), tr('Aucun'), cur == MontageFx.none || (cur == null && tp.fx == MontageFx.none), () => pick(MontageFx.none)),
        if (tp.fx != MontageFx.none) chip(const ValueKey('fx_template'), tr('Du modèle'), cur == null, () => pick(null)),
        for (final e in kMontageFxLabels.entries) chip(ValueKey('fx_${e.key.name}'), e.value, cur == e.key, () => pick(e.key)),
      ]),
    ]);
  }

  List<MontageLayer> _layers() => [
        MontageLayer.kick,
        MontageLayer.title,
        MontageLayer.wish,
        if (tp.chip != null) MontageLayer.chip,
        MontageLayer.brand,
        MontageLayer.pseudo,
        MontageLayer.stats,
        MontageLayer.followers,
        if (tp.fx != MontageFx.none) MontageLayer.fx,
        if (tp.frame != MontageFrame.none) MontageLayer.frame,
        MontageLayer.tint,
        if (tp.country) MontageLayer.flag,
      ];

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: TextStyle(color: _c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      );

  Widget _btn(IconData icon, String label, VoidCallback onTap, {String? gold}) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: _c.primary),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
          // option réservée à Gold et encore fermée : pastille GOLD ; un toucher propose Gold ou des pubs
          if (GoldBadge.locked(gold)) ...[const SizedBox(width: 8), const GoldBadge()],
        ]),
        style: OutlinedButton.styleFrom(side: BorderSide(color: _c.border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      );

  Widget _seg(List<String> items, int sel, ValueChanged<int> onTap) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.border)),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(color: i == sel ? _c.primary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text(items[i], style: TextStyle(color: i == sel ? Colors.white : _c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ),
        ]),
      );

  Widget _field(TextEditingController c, String hint, ValueChanged<String> onChanged, {int maxLines = 1}) => TextField(
        controller: c,
        maxLines: maxLines,
        minLines: 1,
        onChanged: (v) => setState(() => onChanged(v)),
        style: TextStyle(color: _c.textPrimary, fontSize: 13.5),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: _c.textSecondary, fontSize: 12.5),
          filled: true,
          fillColor: _c.surface,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _c.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _c.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _c.primary)),
        ),
      );
}

/// Sélecteur de pays : recherche, l'Afrique d'abord, puis le reste du monde.
class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.current});
  final String current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    syncStudioColors(context);
    final all = MontageCountries.sorted().where((c) => MontageCountries.matches(c.name, c.code, _q)).toList();
    final africa = all.where((c) => c.africa).toList();
    final world = all.where((c) => !c.africa).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      builder: (_, ctrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            style: TextStyle(color: _c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher un pays (Ghana, Haïti, France…)',
              hintStyle: TextStyle(color: _c.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: _c.textSecondary),
              filled: true,
              fillColor: _c.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView(controller: ctrl, children: [
            if (africa.isNotEmpty) _head('🌍 Afrique · ${africa.length}'),
            for (final c in africa) _row(c.code, c.name),
            if (world.isNotEmpty) _head('🌐 Reste du monde · ${world.length}'),
            for (final c in world) _row(c.code, c.name),
            if (all.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun pays trouvé.', style: TextStyle(color: _c.textSecondary)))),
          ]),
        ),
      ]),
    );
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(t, style: TextStyle(color: _c.accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .8)),
      );

  Widget _row(String code, String name) => ListTile(
        dense: true,
        leading: ClipOval(child: SizedBox(width: 28, height: 28, child: CardFlag(code))),
        title: Text(name, style: TextStyle(color: _c.textPrimary, fontWeight: code == widget.current ? FontWeight.w800 : FontWeight.w500)),
        trailing: code == widget.current ? Icon(Icons.check_rounded, color: _c.primary) : null,
        onTap: () => Navigator.pop(context, code),
      );
}
