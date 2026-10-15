// Éditeur d'un template « prêt à poster » : tout est déjà rempli, la personne change ce qu'elle veut,
// retire les éléments qui ne l'intéressent pas, puis publie (image fixe ou vidéo animée).

import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
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
import 'montage_state.dart';

const _c = AppColors.dark;

class MontageEditorPage extends StatefulWidget {
  const MontageEditorPage({super.key, required this.template, this.forChronique = false});
  final MontageTemplate template;
  final bool forChronique;

  @override
  State<MontageEditorPage> createState() => _MontageEditorPageState();
}

class _MontageEditorPageState extends State<MontageEditorPage> with SingleTickerProviderStateMixin {
  late final MontageState s = MontageState(widget.template)..post = !widget.forChronique;
  late final AnimationController _anim = AnimationController(vsync: this, duration: kMontageLoop);
  final _keys = MontageKeys();
  final _picker = ImagePicker();
  VideoPlayerController? _video;
  double? _frozenT;
  bool _busy = false;

  final _kick = TextEditingController();
  final _title = TextEditingController();
  final _wish = TextEditingController();
  final _prenom = TextEditingController(text: 'Kofi');
  final _date = TextEditingController();

  MontageTemplate get tp => widget.template;

  @override
  void initState() {
    super.initState();
    _syncAnim();
    _syncFields();
    MontageCountries.load().then((_) {
      if (mounted) setState(_syncFields);
    });
    if (s.useVideo) _initVideo();
  }

  @override
  void dispose() {
    _anim.dispose();
    _video?.dispose();
    for (final c in [_kick, _title, _wish, _prenom, _date]) {
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
    if (tp.sampleIsVideo) return Image.asset('assets/images/intro4.jpg', fit: BoxFit.cover);
    return Image.asset(tp.sample, fit: BoxFit.cover);
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

  Future<void> _publish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final step = ValueNotifier<String>('Préparation…');
    final video = s.exportsVideo;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: _c.surface,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _c.primary),
            const SizedBox(height: 16),
            Text(video ? 'Création de ta vidéo' : 'Création de ton image', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ValueListenableBuilder<String>(valueListenable: step, builder: (_, v, __) => Text(v, style: TextStyle(color: _c.textSecondary, fontSize: 12.5))),
          ]),
        ),
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
        );
      } else {
        await _setT(.3);
        file = await MontageExport.still(_keys);
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pop(
        context,
        StudioResult(
          type: video ? StudioContentType.video : StudioContentType.image,
          mediaFile: file,
          textContent: _caption(),
          templateId: 'montage_${tp.id}',
          forChronique: widget.forChronique,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _say(e is FirebaseFunctionsException ? (e.message ?? 'Le montage a échoué.') : 'Le montage a échoué. Vérifie ta connexion et réessaie.');
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

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  // ── Écran ──

  @override
  Widget build(BuildContext context) {
    final pseudo = context.read<UserAuthProvider>().loginUserData.pseudo ?? '';
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
              child: Text(s.exportsVideo ? 'Publier 🎬' : 'Publier'),
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
            activeColor: _c.primary,
            title: Text('Animé (vidéo)', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(
              s.useVideo ? 'Ta vidéo garde l’effet animé.' : (s.animated ? 'Publié en vidéo avec l’effet animé.' : 'Publié en image fixe.'),
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
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.border)),
          child: Text('🎵 Son suggéré : ${tp.sound}', style: TextStyle(color: _c.textSecondary, fontSize: 12.5)),
        ),
      ],
    );
  }

  List<MontageLayer> _layers() => [
        MontageLayer.kick,
        MontageLayer.title,
        MontageLayer.wish,
        if (tp.chip != null) MontageLayer.chip,
        MontageLayer.brand,
        MontageLayer.pseudo,
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
