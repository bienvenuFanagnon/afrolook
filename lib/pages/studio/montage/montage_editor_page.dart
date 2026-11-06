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
import 'montage_state.dart';
import 'montage_stickers.dart';
import '../studio_theme.dart';

AppColors get _c => studioColors;

class MontageEditorPage extends StatefulWidget {
  const MontageEditorPage({super.key, required this.template, this.forChronique = false, this.presetMusic, this.presetVideoPath, this.presetPhotoPath, this.focus});
  final MontageTemplate template;
  final bool forChronique;

  /// Média déjà préparé (parcours « Créer un post » : la vidéo qu'on vient de filmer, la photo choisie) : l'éditeur s'ouvre dessus, sans demander de média.
  final String? presetVideoPath;
  final String? presetPhotoPath;

  /// Section à montrer d'emblée (« looks » ou « music ») : l'éditeur du parcours ouvre l'outil choisi dans sa barre.
  final String? focus;

  /// Son choisi avant d'arriver ici (« Créer un post avec ce son ») : il remplace la musique du template.
  final MontageMusic? presetMusic;

  @override
  State<MontageEditorPage> createState() => _MontageEditorPageState();
}

class _MontageEditorPageState extends State<MontageEditorPage> with SingleTickerProviderStateMixin, MusicSuspendMixin {
  late final MontageState s = MontageState(widget.template)
    ..post = !widget.forChronique
    // Sans habillage : on ne garde que la vidéo (le filigrane « Créé sur Afrolook » reste, comme partout)
    ..hidden.addAll(widget.template.id == kPlainTemplateId ? MontageLayer.values : const []);
  late final AnimationController _anim = AnimationController(vsync: this, duration: kMontageLoop);
  final _keys = MontageKeys();
  final _looksKey = GlobalKey();
  final _textKey = GlobalKey();
  final _stickersKey = GlobalKey();
  String? _selSticker;   // autocollant sélectionné (cadre blanc sur l'aperçu)
  final _freeText = TextEditingController();
  final _musicKey = GlobalKey();
  final _picker = ImagePicker();
  VideoPlayerController? _video;
  String? _lastJobId;
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
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = (widget.focus == 'music' ? _musicKey : widget.focus == 'text' ? _textKey : widget.focus == 'stickers' ? _stickersKey : _looksKey).currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    }
    // « Ma vidéo avec ce son » : on propose tout de suite de choisir la vidéo
    if (tp.id == kPlainTemplateId && widget.presetVideoPath == null && widget.presetPhotoPath == null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _pickMedia() : null);
    final preset = widget.presetMusic;
    if (preset != null) {
      s.music = preset;
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

  Future<void> _playMusic() async {
    final m = s.music;
    if (m == null || !mounted) return;
    final ok = await MontageMusicPlayer.play(m, startMs: s.musicStartMs);
    if (!mounted) return;
    setState(() => _musicPlaying = ok);
    if (ok) {
      final known = m.isArtist ? null : studioTrack(m.id)?.durationMs;
      final d = known ?? (await MontageMusicPlayer.duration())?.inMilliseconds;
      if (mounted) setState(() => _musicDurationMs = d);
    }
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
      s.music = pick.music;
      s.musicStartMs = 0;
      _musicDurationMs = null;
      if (pick.music == null) s.keepVideoAudio = false;
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
    final v = s.videoPath != null ? VideoPlayerController.file(File(s.videoPath!)) : VideoPlayerController.asset(kMontageSampleVideo);
    _video = v;
    await old?.dispose();
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.setVolume(0);
      await v.play();
    } catch (_) {}
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
          if (!second && tp.canUseVideo) ...[
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

  /// Son d'artiste payant : on informe avant (prix, part de l'artiste, solde) et on bloque si le solde est insuffisant.
  /// Rien n'est débité ici : le serveur débite seulement quand le montage est réussi.
  Future<bool> _confirmArtistCost([MontageMusic? music]) async {
    final m = music ?? s.music;
    final user = context.read<UserAuthProvider>().loginUserData;
    if (m == null || !m.isArtist || !m.paid || m.artistId == user.id) return true;
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
          Text('Tu n’es débité(e) que si ta vidéo est bien créée.', style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: _c.textSecondary))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _c.primary), child: Text('Utiliser ($price 🪙)')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _publish() async {
    if (_busy) return;
    if (!await _confirmArtistCost() || !mounted) return;
    await MontageMusicPlayer.stop();
    setState(() {
      _busy = true;
      _musicPlaying = false;
    });
    final step = ValueNotifier<String>('Préparation…');
    final video = s.exportsVideo;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(child: PrepareScreen(step: step, video: video)),
      ),
    );
    try {
      final File file;
      if (video) {
        file = await MontageExport.video(
          keys: _keys,
          s: s,
          videoPath: s.videoPath,
          videoAsset: s.videoPath == null ? kMontageSampleVideo : null,
          setT: _setT,
          onStep: (v) => step.value = v,
          maxSeconds: widget.forChronique ? 30 : 60,
          onJob: (id) => _lastJobId = id,
          onPaid: (coins) => _say('🎤 $coins pièces utilisées pour le son de l’artiste. Merci de soutenir les artistes !'),
        );
      } else {
        await _setT(.3);
        file = await MontageExport.still(_keys);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _frozenT = null);
      await _afterCreate(file, video);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (e is ApiException && e.isInsufficientCoins) {
        _say('Solde insuffisant : il te faut ${s.music?.useCoins ?? 0} pièces pour ce son. Recharge ou choisis une musique gratuite.');
      } else {
        _say(e is ApiException ? (e.message.isNotEmpty ? e.message : 'Le montage a échoué.') : 'Le montage a échoué. Vérifie ta connexion et réessaie.');
      }
    } finally {
      step.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _frozenT = null;
        });
      }
    }
  }

  /// Montage prêt : publier, l'enregistrer dans la galerie, les deux, ou continuer à le modifier.
  Future<void> _afterCreate(File file, bool video) async {
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
        saved = await MontageExport.saveToGallery(file, video: video);
        if (!mounted) return;
        if (!saved) _say('Impossible d’enregistrer : autorise l’accès aux photos dans les réglages du téléphone.');
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
    final pseudo = me.pseudo ?? '';
    final screenH = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        foregroundColor: _c.textPrimary,
        elevation: 0,
        title: Text(tp.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MontageCanvas(
                  state: s,
                  keys: _keys,
                  t: _frozenT ?? .3,
                  animation: _frozenT == null && _anim.isAnimating ? _anim : null,
                  media: _mediaWidget(),
                  secondMedia: _secondWidget(),
                  pseudo: pseudo,
                  avatarUrl: me.imageUrl,
                  followers: me.followersCount,
                  // la personne glisse elle-même le pseudo, les chiffres, le texte, le logo et les autocollants ; tout reste dans le cadre
                  onMove: _moveElement,
                  onScale: _scaleSticker,
                  onTapSticker: (id) => setState(() => _selSticker = id),
                  selectedSticker: _selSticker,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _controls()),
      ]),
    );
  }

  Widget _controls() {
    final r = resolveMontageTexts(s);
    final day = kNationalDays[s.country];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _btn(Icons.add_a_photo_rounded, tp.canUseVideo ? 'Ma photo ou vidéo' : 'Ma photo', () => _pickMedia()),
          if (tp.dualSample != null || tp.baby) _btn(Icons.add_photo_alternate_rounded, tp.baby ? 'Photo de bébé' : '2e photo', () => _pickMedia(second: true)),
        ]),
        const SizedBox(height: 14),
        KeyedSubtree(key: _stickersKey, child: _stickersSection()),
        const SizedBox(height: 14),
        KeyedSubtree(key: _textKey, child: _freeTextSection()),
        const SizedBox(height: 14),
        KeyedSubtree(key: _looksKey, child: _looksSection()),
        const SizedBox(height: 14),
        KeyedSubtree(key: _musicKey, child: _musicSection()),
        const SizedBox(height: 14),
        _label('Format'),
        _seg(['Chronique 9:16', 'Post 4:5'], s.post ? 1 : 0, (i) => setState(() => s.post = i == 1)),
        if (tp.fx != MontageFx.none) ...[
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
      ],
    );
  }

  Widget _musicSection() {
    final m = s.music;
    final maxSec = widget.forChronique ? 30 : 60;
    final durs = [10, 15, 30].where((d) => d <= maxSec).toList();
    final dur = _musicDurationMs;
    final clip = (s.useVideo ? maxSec : s.musicSeconds) * 1000;
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
                  s.keepVideoAudio = false;
                  _musicPlaying = false;
                });
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
      if (m != null && !s.useVideo) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Durée de la vidéo', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
          for (final d in durs)
            ChoiceChip(
              label: Text('$d s'),
              selected: s.musicSeconds == d,
              onSelected: (_) => setState(() => s.musicSeconds = d),
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
          onChanged: (v) => setState(() => s.keepVideoAudio = v),
          activeThumbColor: _c.primary,
          title: Text('Garder le son de ma vidéo', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text(s.keepVideoAudio ? 'Ta voix et la musique sont mélangées.' : 'Le son de ta vidéo est coupé : seule la musique est jouée.', style: TextStyle(color: _c.textSecondary, fontSize: 12)),
        ),
      if (m != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Avec une musique, ton montage est publié en vidéo.', style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
        ),
    ]);
  }

  String _mmss(int ms) {
    final t = ms ~/ 1000;
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  /// Looks de couleur sobres (style Instagram) : valables pour une photo comme pour une vidéo.
  // ── Déplacer et autocollants ─────────────────────────────────────────────

  void _moveElement(String id, Offset center) {
    setState(() {
      if (id.startsWith('st:')) {
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
    final st = s.stickers.where((e) => 'st:${e.id}' == id).firstOrNull;
    if (st != null) setState(() => st.scale = scale.clamp(kStickerMinScale, kStickerMaxScale));
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
        if (s.moved.isNotEmpty) _btn(Icons.restart_alt_rounded, 'Tout remettre en place', () => setState(s.moved.clear)),
      ]),
      if (sel != null) ...[
        const SizedBox(height: 10),
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
    final sel = s.look?.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Look'),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kMontageLooks.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final look = i == 0 ? null : kMontageLooks[i - 1];
            final on = i == 0 ? sel == null : sel == look!.id;
            final colors = look?.swatch ?? const [Color(0xFF3A3A3A), Color(0xFF1A1A1A)];
            return GestureDetector(
              onTap: () => setState(() => s.look = look),
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

  Widget _btn(IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: _c.primary),
        label: Text(label, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
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
