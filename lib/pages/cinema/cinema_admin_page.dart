import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import 'cinema_widgets.dart';

/// Gestion de Cartoon Cinéma par l'équipe (21/11/2026), dans l'application et dans la version web : séries et films, épisodes, vidéo sans voix,
/// voix off et sous-titres par langue, accès (gratuit ou 10 s puis Gold), sortie programmée, mesures. Chaque bouton n'apparaît qu'avec le droit
/// correspondant (créer, modifier, supprimer, mesures) ; le serveur vérifie de toute façon chaque action.
class CinemaAdminPage extends StatefulWidget {
  const CinemaAdminPage({super.key, required this.rights});

  final CinemaRights rights;

  @override
  State<CinemaAdminPage> createState() => _CinemaAdminPageState();
}

class _CinemaAdminPageState extends State<CinemaAdminPage> {
  List<Map<String, dynamic>>? _titles;
  String? _error;

  CinemaRights get r => widget.rights;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await CinemaApi.adminTitles();
      if (mounted) setState(() {
        _titles = t;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = CinemaApi.message(e));
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: TextStyle(color: AppColors.of(ctx).danger))),
          ],
        ),
      ) ==
      true;

  Future<void> _editTitle([Map<String, dynamic>? t]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _TitleForm(title: t),
    );
    if (saved == true) _load();
  }

  Future<void> _newEpisode(Map<String, dynamic> t) async {
    final ctrl = TextEditingController();
    final numCtrl = TextEditingController();
    final seasonCtrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['kind'] == 'film' ? 'Ajouter la vidéo du film' : 'Nouvel épisode'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Titre de l\'épisode')),
          if (t['kind'] != 'film')
            Row(children: [
              Expanded(child: TextField(controller: seasonCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Saison'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: numCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Numéro (auto)'))),
            ]),
          const SizedBox(height: 8),
          const Text("Seul l'épisode 1 de la saison 1 est gratuit (avec la pub de 10 s à la fin) ; les autres : 15 secondes gratuites, la pub de 10 s, puis Gold. Modifiable ensuite.", style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final e = await CinemaApi.createEpisode('${t['id']}', {
        'name': ctrl.text.trim().isEmpty ? (t['kind'] == 'film' ? '${t['title']}' : 'Épisode') : ctrl.text.trim(),
        if (int.tryParse(seasonCtrl.text) != null) 'season': int.parse(seasonCtrl.text),
        if (int.tryParse(numCtrl.text) != null) 'number': int.parse(numCtrl.text),
      });
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaEpisodeEditor(episode: e, rights: r)));
      _load();
    } catch (e) {
      _toast(CinemaApi.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Gestion du cinéma', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (r.stats) IconButton(tooltip: 'Mesures', icon: const Icon(Icons.insights_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CinemaStatsPage()))),
        ],
      ),
      floatingActionButton: r.create
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFD400),
              foregroundColor: const Color(0xFF121212),
              onPressed: () => _editTitle(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Série ou film', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: c.textPrimary)))
          : _titles == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                    if (r.edit || r.delete) _AdVideoCard(rights: r),
                    if (_titles!.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('Aucune série ni film pour l\'instant.', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))),
                    for (final t in _titles!) _titleCard(c, t),
                  ]),
                ),
    );
  }

  Widget _titleCard(AppColors c, Map<String, dynamic> t) {
    final eps = ((t['episodes'] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final published = t['status'] == 'published';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          leading: SizedBox(width: 44, height: 62, child: CinemaImage(t['poster_url'] as String? ?? t['banner_url'] as String?, radius: 8)),
          title: Text('${t['title']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          subtitle: Text('${t['kind'] == 'film' ? 'Film' : 'Série'} · ${published ? 'Publié' : 'Brouillon'}${t['featured'] == true ? ' · À la une' : ''} · ${eps.length} vidéo(s)',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              try {
                if (v == 'edit') await _editTitle(t);
                if (v == 'publish') {
                  await CinemaApi.updateTitle('${t['id']}', {'status': published ? 'draft' : 'published'});
                  _load();
                }
                if (v == 'delete' && await _confirm('Supprimer « ${t['title']} » et tous ses épisodes ?')) {
                  await CinemaApi.deleteTitle('${t['id']}');
                  _load();
                }
              } catch (e) {
                _toast(CinemaApi.message(e));
              }
            },
            itemBuilder: (_) => [
              if (r.edit) const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              if (r.edit) PopupMenuItem(value: 'publish', child: Text(published ? 'Repasser en brouillon' : 'Publier')),
              if (r.delete) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ),
        for (final e in eps)
          ListTile(
            dense: true,
            leading: SizedBox(width: 64, height: 38, child: CinemaImage(e['thumb_url'] as String?, radius: 6)),
            title: Text('S${e['season']} · Ép. ${e['number']} · ${e['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(_epStatus(e), style: TextStyle(color: e['status'] == 'failed' ? c.danger : c.textSecondary, fontSize: 11.5)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CinemaEpisodeEditor(episode: e, rights: r))).then((_) => _load()),
          ),
        if (r.create)
          TextButton.icon(
            onPressed: () => _newEpisode(t),
            icon: const Icon(Icons.add_rounded),
            label: Text(t['kind'] == 'film' ? 'Ajouter la vidéo' : 'Ajouter un épisode'),
          ),
      ]),
    );
  }

  static String _epStatus(Map<String, dynamic> e) {
    final access = e['access'] == 'free' ? 'Gratuit' : 'Gold (15 s gratuites)';
    final st = switch ('${e['status']}') {
      'draft' => 'Vidéo à envoyer',
      'uploaded' => 'En attente de préparation',
      'processing' => 'Préparation ${e['progress'] ?? 0} %',
      'ready' => e['published_at'] == null ? 'Prêt, sortie non programmée' : 'Prêt',
      'failed' => 'Échec de préparation',
      _ => '${e['status']}',
    };
    return '$access · $st · ${cinemaCount((e['views_count'] as num?) ?? 0)} vues';
  }
}

/// Création ou modification d'une série ou d'un film.
class _TitleForm extends StatefulWidget {
  const _TitleForm({this.title});

  final Map<String, dynamic>? title;

  @override
  State<_TitleForm> createState() => _TitleFormState();
}

class _TitleFormState extends State<_TitleForm> {
  late final _title = TextEditingController(text: widget.title?['title'] as String? ?? '');
  late final _synopsis = TextEditingController(text: widget.title?['synopsis'] as String? ?? '');
  late final _genre = TextEditingController(text: widget.title?['genre'] as String? ?? '');
  late final _age = TextEditingController(text: widget.title?['age_rating'] as String? ?? '');
  late final _poster = TextEditingController(text: widget.title?['poster_url'] as String? ?? '');
  late final _banner = TextEditingController(text: widget.title?['banner_url'] as String? ?? '');
  late String _kind = widget.title?['kind'] as String? ?? 'series';
  late bool _featured = widget.title?['featured'] == true;
  bool _saving = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final body = {
      'title': _title.text.trim(), 'synopsis': _synopsis.text.trim().isEmpty ? null : _synopsis.text.trim(), 'genre': _genre.text.trim().isEmpty ? null : _genre.text.trim(),
      'age_rating': _age.text.trim().isEmpty ? null : _age.text.trim(), 'poster_url': _poster.text.trim().isEmpty ? null : _poster.text.trim(),
      'banner_url': _banner.text.trim().isEmpty ? null : _banner.text.trim(), 'featured': _featured,
    };
    try {
      if (widget.title == null) {
        await CinemaApi.createTitle({...body, 'kind': _kind});
      } else {
        await CinemaApi.updateTitle('${widget.title!['id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title == null ? 'Nouvelle série ou nouveau film' : 'Modifier', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        if (widget.title == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'series', label: Text('Série')), ButtonSegment(value: 'film', label: Text('Film'))],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre')),
        TextField(controller: _synopsis, maxLines: 3, decoration: const InputDecoration(labelText: 'Résumé')),
        TextField(controller: _genre, decoration: const InputDecoration(labelText: 'Genre (comédie, aventure…)')),
        TextField(controller: _age, decoration: const InputDecoration(labelText: 'Public (tous publics, 12 ans et plus…)')),
        TextField(controller: _poster, decoration: const InputDecoration(labelText: 'Lien de l\'affiche verticale (https://…)')),
        TextField(controller: _banner, decoration: const InputDecoration(labelText: 'Lien de l\'annonce en image, format large (https://…)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _featured, onChanged: (v) => setState(() => _featured = v), title: const Text('À la une de l\'accueil du cinéma')),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
      ])),
    );
  }
}

/// Fiche d'un épisode : textes, accès, sortie, vidéo sans voix, voix off et sous-titres par langue, état de la préparation.
class CinemaEpisodeEditor extends StatefulWidget {
  const CinemaEpisodeEditor({super.key, required this.episode, required this.rights});

  final Map<String, dynamic> episode;
  final CinemaRights rights;

  @override
  State<CinemaEpisodeEditor> createState() => _CinemaEpisodeEditorState();
}

class _CinemaEpisodeEditorState extends State<CinemaEpisodeEditor> {
  late Map<String, dynamic> e = Map<String, dynamic>.from(widget.episode);
  late final _name = TextEditingController(text: '${e['name'] ?? ''}');
  late final _synopsis = TextEditingController(text: '${e['synopsis'] ?? ''}');
  String? _busy;
  double _progress = 0;

  CinemaRights get r => widget.rights;
  bool get canUpload => r.create || r.edit;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _patch(Map<String, dynamic> body) async {
    try {
      final out = await CinemaApi.updateEpisode('${e['id']}', body);
      setState(() => e = {...e, ...out});
      _toast('Enregistré.');
    } catch (err) {
      _toast(CinemaApi.message(err));
    }
  }

  Future<void> _pickRelease() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (t == null) return;
    await _patch({'published_at': DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc().toIso8601String()});
  }

  /// Envoie un fichier : vidéo sans voix, voix off ou sous-titres d'une langue.
  Future<void> _upload(String kind) async {
    String? lang;
    String? label;
    if (kind != 'video') {
      final res = await _askLang(kind);
      if (res == null) return;
      (lang, label) = res;
    }
    // sur téléphone : le chemin du fichier (lu par morceaux à l'envoi) ; sur le web : son contenu
    final pick = await FilePicker.platform.pickFiles(
      type: kind == 'subtitle' ? FileType.custom : (kind == 'video' ? FileType.video : FileType.audio),
      allowedExtensions: kind == 'subtitle' ? ['vtt', 'srt'] : null,
      withData: kIsWeb,
    );
    final f = pick?.files.firstOrNull;
    final Uint8List? bytes = f?.bytes;
    final String? path = kIsWeb ? null : f?.path;
    if (f == null || (bytes == null && path == null)) return;
    final size = f.size;
    final ext = (f.extension ?? '').toLowerCase();
    final type = switch (kind) {
      'video' => ext == 'mov' ? 'video/quicktime' : (ext == 'webm' ? 'video/webm' : 'video/mp4'),
      'voice' => switch (ext) { 'wav' => 'audio/wav', 'm4a' => 'audio/mp4', 'aac' => 'audio/aac', 'ogg' => 'audio/ogg', _ => 'audio/mpeg' },
      _ => ext == 'srt' ? 'application/x-subrip' : 'text/vtt',
    };
    setState(() {
      _busy = kind == 'video' ? 'Envoi de la vidéo (${(size / 1048576).toStringAsFixed(0)} Mo)…' : 'Envoi du fichier…';
      _progress = 0;
    });
    try {
      final out = await CinemaApi.uploadFile('${e['id']}', kind: kind, lang: lang, label: label, bytes: bytes, path: path, size: size, contentType: type, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
      setState(() => e = {...e, ...out});
      _toast(kind == 'video' ? 'Vidéo reçue : la préparation des qualités commence (plusieurs minutes).' : 'Fichier reçu : la piste se prépare.');
    } catch (err) {
      _toast(CinemaApi.message(err));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<(String, String)?> _askLang(String kind) async {
    const langs = [('fr', 'Français'), ('en', 'English'), ('ewe', 'Ewe'), ('ln', 'Lingala'), ('wo', 'Wolof'), ('fon', 'Fon'), ('mina', 'Mina'), ('yo', 'Yorùbá'), ('ha', 'Hausa'), ('sw', 'Kiswahili'), ('es', 'Español'), ('pt', 'Português'), ('ar', 'العربية')];
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(kind == 'voice' ? 'Langue de la voix off' : 'Langue des sous-titres'),
        children: [for (final (code, label) in langs) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, (code, label)), child: Text(label))],
      ),
    );
  }

  Future<void> _removeTrack(String kind, String lang) async {
    try {
      await CinemaApi.deleteTrack('${e['id']}', kind, lang);
      final key = kind == 'audio' ? 'audio' : 'subtitles';
      setState(() => e[key] = ((e[key] as List?) ?? const []).where((x) => (x as Map)['lang'] != lang).toList());
    } catch (err) {
      _toast(CinemaApi.message(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final audio = ((e['audio'] as List?) ?? const []).whereType<Map>().toList();
    final subs = ((e['subtitles'] as List?) ?? const []).whereType<Map>().toList();
    final release = e['published_at'] != null ? DateTime.tryParse('${e['published_at']}')?.toLocal() : null;
    Widget section(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .4)));
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text('S${e['season']} · Ép. ${e['number']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (r.delete)
            IconButton(
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline_rounded, color: c.danger),
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(content: const Text('Supprimer cet épisode ?'), actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                ]));
                if (ok != true) return;
                try {
                  await CinemaApi.deleteEpisode('${e['id']}');
                  if (context.mounted) Navigator.pop(context);
                } catch (err) {
                  _toast(CinemaApi.message(err));
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 32), children: [
        if (_busy != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_busy!, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress, color: const Color(0xFFFFD400)),
              const SizedBox(height: 4),
              Text('${(_progress * 100).round()} %', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              const SizedBox(height: 4),
              Text('Garde l\'application ouverte pendant l\'envoi.', style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
          ),
        section('TEXTES'),
        TextField(controller: _name, enabled: r.edit, decoration: const InputDecoration(labelText: 'Titre')),
        TextField(controller: _synopsis, enabled: r.edit, maxLines: 3, decoration: const InputDecoration(labelText: 'Résumé')),
        if (r.edit) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _patch({'name': _name.text.trim(), 'synopsis': _synopsis.text.trim()}), child: const Text('Enregistrer les textes'))),
        section('ACCÈS'),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'free', label: Text('Gratuit')), ButtonSegment(value: 'gold', label: Text('Gold · 15 s gratuites'))],
          selected: {'${e['access']}'},
          onSelectionChanged: r.edit ? (s) => _patch({'access': s.first}) : null,
        ),
        section('SORTIE'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text(release == null ? 'Pas encore programmée' : 'Sortie le ${release.day.toString().padLeft(2, '0')}/${release.month.toString().padLeft(2, '0')}/${release.year} à ${release.hour.toString().padLeft(2, '0')}:${release.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: c.textPrimary)),
          subtitle: Text('Une notification part aux abonnés à la sortie, si la vidéo est prête.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          trailing: r.edit ? TextButton(onPressed: _pickRelease, child: Text(release == null ? 'Programmer' : 'Changer')) : null,
        ),
        if (r.edit && release == null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _patch({'published_at': DateTime.now().toUtc().toIso8601String()}), child: const Text('Publier maintenant'))),
        section('VIDÉO PRINCIPALE (SANS VOIX : MUSIQUE ET EFFETS)'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(e['has_source'] == true ? Icons.check_circle_rounded : Icons.movie_outlined, color: e['has_source'] == true ? c.primary : c.textSecondary),
          title: Text(e['has_source'] == true ? 'Vidéo envoyée · ${_state(e)}' : 'Aucune vidéo envoyée', style: TextStyle(color: c.textPrimary)),
          subtitle: (e['error'] as String?)?.isNotEmpty == true ? Text('${e['error']}', style: TextStyle(color: c.danger, fontSize: 11)) : null,
          trailing: canUpload ? TextButton(onPressed: _busy == null ? () => _upload('video') : null, child: Text(e['has_source'] == true ? 'Remplacer' : 'Envoyer')) : null,
        ),
        section('VOIX OFF (DIALOGUES, NARRATION) · FRANÇAIS PAR DÉFAUT'),
        for (final a in audio)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.record_voice_over_rounded, color: a['status'] == 'ready' ? c.primary : c.textSecondary),
            title: Text('${a['label']}', style: TextStyle(color: c.textPrimary)),
            subtitle: Text(_trackState('${a['status']}'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            trailing: (r.edit || r.delete) ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _removeTrack('audio', '${a['lang']}')) : null,
          ),
        if (canUpload) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _busy == null ? () => _upload('voice') : null, icon: const Icon(Icons.add_rounded), label: const Text('Ajouter une voix off'))),
        section('SOUS-TITRES (FICHIER .VTT OU .SRT)'),
        for (final s in subs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.subtitles_rounded, color: s['status'] == 'ready' ? c.primary : c.textSecondary),
            title: Text('${s['label']}', style: TextStyle(color: c.textPrimary)),
            subtitle: Text(_trackState('${s['status']}'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            trailing: (r.edit || r.delete) ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _removeTrack('subtitles', '${s['lang']}')) : null,
          ),
        if (canUpload) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _busy == null ? () => _upload('subtitle') : null, icon: const Icon(Icons.add_rounded), label: const Text('Ajouter des sous-titres'))),
      ]),
    );
  }

  static String _state(Map<String, dynamic> e) => switch ('${e['status']}') {
        'uploaded' => 'en attente de préparation',
        'processing' => 'préparation ${e['progress'] ?? 0} %',
        'ready' => 'prête',
        'failed' => 'échec de préparation',
        _ => '${e['status']}',
      };

  static String _trackState(String s) => switch (s) { 'ready' => 'Prête', 'pending' => 'En préparation (après la vidéo)', 'failed' => 'Échec', _ => s };
}

/// Mesures du cinéma : visites, temps passé, épisodes lancés et terminés, sources des visites, épisodes.
class CinemaStatsPage extends StatefulWidget {
  const CinemaStatsPage({super.key});

  @override
  State<CinemaStatsPage> createState() => _CinemaStatsPageState();
}

class _CinemaStatsPageState extends State<CinemaStatsPage> {
  Map<String, dynamic>? _s;
  int _days = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await CinemaApi.stats(days: _days);
      if (mounted) setState(() => _s = s);
    } catch (e) {
      if (mounted) setState(() => _error = CinemaApi.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = _s;
    String mins(num sec) => sec >= 60 ? '${(sec / 60).round()} min' : '${sec.toInt()} s';
    Widget tile(String v, String l) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(l, style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        );
    final sources = Map<String, dynamic>.from((s?['by_source'] as Map?) ?? const {});
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, elevation: 0, title: const Text('Mesures du cinéma', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _error != null
          ? Center(child: Text(_error!))
          : s == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(14), children: [
                  Wrap(spacing: 6, children: [
                    for (final d in [7, 30, 90])
                      ChoiceChip(label: Text('$d jours'), selected: d == _days, showCheckmark: false, onSelected: (_) {
                        setState(() => _days = d);
                        _load();
                      }),
                  ]),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.3,
                    children: [
                      tile('${s['visits']}', 'VISITES DE LA PAGE'),
                      tile(mins((s['avg_seconds'] as num?) ?? 0), 'TEMPS MOYEN PAR VISITE'),
                      tile('${s['visitors']}', 'PERSONNES DIFFÉRENTES'),
                      tile(mins((s['total_seconds'] as num?) ?? 0), 'TEMPS TOTAL PASSÉ'),
                      tile('${s['plays']}', 'ÉPISODES LANCÉS'),
                      tile('${s['completed']}', 'REGARDÉS JUSQU\'AU BOUT'),
                      tile('${sources['feed'] ?? 0}', 'VISITES VENUES DU FIL'),
                      tile('${s['followers']}', 'NOTIFICATIONS ACTIVÉES'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Par épisode', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                  for (final e in ((s['episodes'] as List?) ?? const []).whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${e['title']} · S${e['season']} Ép. ${e['number']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${e['views']} vues · ${e['completed']} jusqu\'au bout · ${e['comments']} commentaires'
                        '${e['stopped_at_preview'] != null ? " · ${e['stopped_at_preview']} arrêtés à l'extrait gratuit" : ''}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ),
                ]),
    );
  }
}

/// Vidéo de pub du cinéma (10 s) : jouée après les 15 secondes gratuites d'un épisode Gold, et à la fin d'un épisode gratuit.
class _AdVideoCard extends StatefulWidget {
  const _AdVideoCard({required this.rights});

  final CinemaRights rights;

  @override
  State<_AdVideoCard> createState() => _AdVideoCardState();
}

class _AdVideoCardState extends State<_AdVideoCard> {
  String? _url;
  bool _loaded = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    CinemaApi.adVideo().then((d) {
      if (mounted) setState(() {
        _url = d['url'] as String?;
        _loaded = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _upload() async {
    final pick = await FilePicker.platform.pickFiles(type: FileType.video, withData: kIsWeb);
    final f = pick?.files.firstOrNull;
    if (f == null || (f.bytes == null && f.path == null)) return;
    final ext = (f.extension ?? '').toLowerCase();
    final type = ext == 'mov' ? 'video/quicktime' : (ext == 'webm' ? 'video/webm' : 'video/mp4');
    setState(() => _progress = 0);
    try {
      final d = await CinemaApi.uploadAdVideo(bytes: f.bytes, path: kIsWeb ? null : f.path, size: f.size, contentType: type, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
      if (mounted) setState(() => _url = d['url'] as String?);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _remove() async {
    try {
      final d = await CinemaApi.deleteAdVideo();
      if (mounted) setState(() => _url = d['url'] as String?);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CinemaApi.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.campaign_rounded, color: c.accentText),
          const SizedBox(width: 8),
          Expanded(child: Text('Vidéo de pub du cinéma (10 s)', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text("Jouée après les 15 secondes gratuites d'un épisode Gold, et à la fin d'un épisode gratuit.", style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        if (!_loaded)
          const LinearProgressIndicator()
        else if (_progress != null) ...[
          LinearProgressIndicator(value: _progress, color: const Color(0xFFFFD400)),
          Text('Envoi ${((_progress ?? 0) * 100).round()} %', style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ] else
          Row(children: [
            Icon(_url != null ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: _url != null ? c.primary : c.textSecondary, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(_url != null ? 'Vidéo de pub en place' : "Aucune vidéo de pub : rien n'est joué", style: TextStyle(color: c.textPrimary, fontSize: 12.5))),
            if (widget.rights.edit) TextButton(onPressed: _upload, child: Text(_url != null ? 'Remplacer' : 'Envoyer')),
            if (_url != null && (widget.rights.edit || widget.rights.delete)) IconButton(tooltip: 'Retirer', icon: const Icon(Icons.close_rounded), onPressed: _remove),
          ]),
      ]),
    );
  }
}
