// Galerie des templates « prêts à poster », par catégorie. Chaque aperçu est déjà rempli et animé.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../../models/community_template.dart';
import '../../../services/face_engine.dart' show FaceEngine;
import 'montage_face_capture.dart';
import 'template_thumb.dart';
import 'collage_template.dart';
import 'collage_template_page.dart';
import 'credits_page.dart';
import 'story_page.dart';
import '../../../widgets/draft_widgets_layer.dart' show PresetWidgetsPreview;
import 'story_script.dart';
import '../../create/create_result.dart';
import '../../../services/api/community_templates_api.dart';
import '../../../services/api/template_stats_api.dart';
import '../../../widgets/studio/community_template_open.dart';
import 'my_templates_page.dart';
import '../../cards/card_events.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/tr.dart';
import '../studio_models.dart';
import 'montage_canvas.dart';
import 'montage_catalog.dart';
import 'montage_editor_page.dart';
import 'montage_fx.dart';
import '../artist_sound_common.dart';
import 'montage_music.dart';
import 'montage_state.dart';
import '../studio_theme.dart';

AppColors get _c => studioColors;

/// Les modèles du Studio classés par popularité : ceux qui ont des utilisations (la semaine d'abord, puis le total, selon le serveur), puis les autres dans l'ordre du catalogue.
/// Sert à l'onglet « Populaires » de la galerie et à la bande « Les plus utilisés » de « Que créer ? ».
List<MontageTemplate> popularMontageTemplates() {
  final all = kMontageTemplates.where((t) => t.id != kPlainTemplateId && (t.face == null || FaceEngine.enabled)).toList();
  // les nouveautés d'abord (tant qu'elles sont récentes), puis le classement du serveur, puis le reste dans l'ordre du catalogue
  final fresh = newMontageTemplates();
  final rest = all.where((t) => !t.isNew).toList();
  final ranked = rest.where((t) => TemplateStatsApi.rankOf('m:${t.id}') != null).toList()
    ..sort((a, b) => TemplateStatsApi.rankOf('m:${a.id}')!.compareTo(TemplateStatsApi.rankOf('m:${b.id}')!));
  return [...fresh, ...ranked, ...rest.where((t) => TemplateStatsApi.rankOf('m:${t.id}') == null)];
}

/// Les modèles récents (voir `MontageTemplate.isNew`) : d'abord ceux qui se font en vidéo ou en plusieurs médias (histoires, duos, collages), puis la fin d'année, puis les autres dans l'ordre du catalogue.
List<MontageTemplate> newMontageTemplates() {
  final l = kMontageTemplates.where((t) => t.id != kPlainTemplateId && t.isNew && (t.face == null || FaceEngine.enabled)).toList();
  int rank(MontageTemplate t) => (t.isStory || t.isCollage || t.duoLayout != null) ? 0 : (t.cat == MontageCat.finannee ? 1 : 2);
  final idx = {for (var i = 0; i < l.length; i++) l[i].id: i};
  l.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : idx[a.id]!.compareTo(idx[b.id]!);
  });
  return l;
}

class MontageGalleryPage extends StatefulWidget {
  const MontageGalleryPage({super.key, this.forChronique = false, this.presetMusic, this.presetVideoPath, this.presetPhotoPath});
  final bool forChronique;

  /// Média déjà préparé (parcours « Créer un post ») : chaque modèle s'ouvre directement dessus.
  final String? presetVideoPath;
  final String? presetPhotoPath;

  /// Son choisi avant d'arriver ici : chaque modèle s'ouvre avec ce son (payant : prix et solde annoncés dans l'éditeur).
  final MontageMusic? presetMusic;

  @override
  State<MontageGalleryPage> createState() => _MontageGalleryPageState();
}

class _MontageGalleryPageState extends State<MontageGalleryPage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: kMontageLoop)..repeat();
  int _followers = 0;
  String? _avatar;
  late final Map<String, MontageState> _states = {for (final t in kMontageTemplates) t.id: MontageState(t)..post = false};

  @override
  void initState() {
    super.initState();
    MontageCountries.load().then((_) {
      if (mounted) setState(() {});
    });
    // les plus utilisés (compteur du serveur) : l'onglet « Populaires » et le nombre d'utilisations sur chaque carte
    TemplateStatsApi.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<MontageTemplate> _popular() => popularMontageTemplates();

  /// Un modèle créé par une personne : s'il est payant, le prix est annoncé (payé à la publication) ; puis le même éditeur que les autres modèles.
  Future<void> _openCommunity(CommunityTemplate t) async {
    final tp = t.toMontage();
    if (tp == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('Ce modèle n\'est pas disponible dans cette version de l\'application.'))));
      return;
    }
    if (!t.isFree && !await CommunityTemplateOpen.confirmPrice(context, t)) return;
    if (!mounted) return;
    await _open(tp);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _open(MontageTemplate t) async {
    _anim.stop();
    // modèle « générique de fin de film » : le texte monte lentement sur des photos qui changent
    if (t.isCredits) {
      final done = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => CreditsTemplatePage(template: t)));
      if (!mounted) return;
      if (done == kCreateDone) {
        Navigator.pop(context);
      } else {
        _anim.repeat();
      }
      return;
    }
    // modèle « histoire » : la vidéo défile toute seule, scène après scène (diaporama) ; la personne règle les photos, les phrases et les durées
    final story = t.isStory ? storyScriptFor(t.id) : null;
    if (story != null) {
      final done = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => StoryTemplatePage(template: t, script: story)));
      if (!mounted) return;
      if (done == kCreateDone) {
        Navigator.pop(context);
      } else {
        _anim.repeat();
      }
      return;
    }
    // modèle « collage » : une photo par case, étiquettes et titre modifiables
    final collage = t.isCollage ? collageScriptFor(t.id) : null;
    if (collage != null) {
      final done = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => CollageTemplatePage(template: t, script: collage)));
      if (!mounted) return;
      if (done == kCreateDone) {
        Navigator.pop(context);
      } else {
        _anim.repeat();
      }
      return;
    }
    // modèle à filtres de visage : on se filme d'abord, avec l'avatar et l'effet du modèle déjà choisis
    String? video = widget.presetVideoPath;
    String? photo = widget.presetPhotoPath;
    if (t.face != null) {
      final cap = await captureForFaceTemplate(context, t.face!);
      if (cap == null || !mounted) {
        if (mounted) _anim.repeat();
        return;
      }
      video = cap.isVideo ? cap.path : null;
      photo = cap.isVideo ? null : cap.path;
    }
    if (!mounted) return;
    final r = await Navigator.push<StudioResult>(
      context,
      MaterialPageRoute(builder: (_) => MontageEditorPage(template: t, forChronique: widget.forChronique, presetMusic: widget.presetMusic, presetVideoPath: video, presetPhotoPath: photo)),
    );
    if (!mounted) return;
    if (r != null) {
      Navigator.pop(context, r);
    } else {
      _anim.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    syncStudioColors(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    final pseudo = me.pseudo ?? '';
    _followers = me.followersCount;
    _avatar = me.imageUrl;
    // Fête dans 3 jours ou moins (ou aujourd'hui) : son template est mis en avant, et la galerie s'ouvre sur « Fêtes »
    final fete = widget.presetMusic == null ? CardEvents.upcoming(me.countryData?['countryCode'], DateTime.now()) : null;
    final feteTemplate = fete?.studioTemplateId == null ? null : kMontageTemplates.where((t) => t.id == fete!.studioTemplateId).firstOrNull;
    return DefaultTabController(
      length: MontageCat.values.length + 3,   // « Nouveautés », « Populaires » et « Communauté » d'abord, puis les catégories
      initialIndex: feteTemplate == null ? 0 : MontageCat.values.indexOf(MontageCat.fetes) + 3,
      child: Scaffold(
        backgroundColor: _c.background,
        appBar: AppBar(
          backgroundColor: _c.background,
          foregroundColor: _c.textPrimary,
          elevation: 0,
          title: const Text('Templates prêts à poster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          actions: [
            IconButton(
              key: const ValueKey('my_templates_btn'),
              tooltip: tr('Mes modèles'),
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTemplatesPage())),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(widget.presetMusic != null ? 88 : (feteTemplate != null ? 104 : 48)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (widget.presetMusic != null) _presetBanner(widget.presetMusic!),
              if (feteTemplate != null) _feteBanner(fete!, feteTemplate),
              TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _c.accent,
            unselectedLabelColor: _c.textSecondary,
            indicatorColor: _c.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: '✨ ${tr('Nouveautés')}'), Tab(text: tr('Populaires')), Tab(text: tr('Communauté')), for (final cat in MontageCat.values) Tab(text: cat.label)],
              ),
            ]),
          ),
        ),
        body: TabBarView(children: [
          _gridOf(newMontageTemplates(), pseudo),
          _gridOf(_popular(), pseudo),
          _CommunityTab(onOpen: _openCommunity),
          for (final cat in MontageCat.values) _gridOf(kMontageTemplates.where((t) => t.cat == cat && (t.face == null || FaceEngine.enabled)).toList(), pseudo),
        ]),
      ),
    );
  }

  /// Rappel du son choisi : la personne n'a plus qu'à choisir un modèle.
  Widget _presetBanner(MontageMusic m) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _c.primary.withValues(alpha: .16), borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.primary.withValues(alpha: .5))),
      child: Row(children: [
        const Text('🎵', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Choisis un modèle pour « ${m.title} »${m.paid ? ' · ${m.useCoins} pièces' : ' · gratuit'}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => _open(kPlainTemplate),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text('🎬 Ma vidéo', style: TextStyle(color: _c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    );
  }

  /// Fête qui arrive : « Noël dans 2 jours » et le template prêt à utiliser.
  Widget _feteBanner(CardEventSoon f, MontageTemplate t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(color: _c.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12), border: Border.all(color: _c.accent.withValues(alpha: .55))),
      child: Row(children: [
        Text(f.event.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(f.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(tr('Template prêt : {nom}', {'nom': t.name}), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
          ]),
        ),
        TextButton(
          onPressed: () => _open(t),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text(tr('Utiliser'), style: TextStyle(color: _c.accent, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _gridOf(List<MontageTemplate> list, String pseudo) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 480 ? 3 : 2);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .45),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final t = list[i];
          return GestureDetector(
            onTap: () => _open(t),
            child: Container(
              decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _c.border)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(alignment: Alignment.center, children: [
                (TemplatePreview.handles(t) ? AspectRatio(aspectRatio: _states[t.id]!.aspect, child: ClipRect(child: TemplatePreview(t: t))) : RepaintBoundary(
                  child: MontageCanvas(
                    state: _states[t.id]!,
                    animation: t.fx == MontageFx.none ? null : _anim,
                    // les aperçus montrent la photo de profil de la personne (et non une photo d'exemple) : elle voit tout de suite son modèle
                    media: (_avatar != null && _avatar!.startsWith('http') && t.id != kPlainTemplateId)
                        ? Image.network(_avatar!, fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => Image.asset(t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, fit: BoxFit.cover, cacheWidth: 400))
                        : Image.asset(t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, fit: BoxFit.cover, cacheWidth: 400),
                    secondMedia: t.dualSample != null ? Image.asset(t.dualSample!, fit: BoxFit.cover, cacheWidth: 300) : null,
                    pseudo: pseudo,
                    avatarUrl: _avatar,
                    followers: _followers,
                  ),
                )),
                if (t.presetWidgets != null && !TemplatePreview.handles(t)) Positioned.fill(child: PresetWidgetsPreview(widgets: t.presetWidgets!(), aspect: _states[t.id]!.aspect)),
                if (t.showsVideo) const VideoBadge(size: 44),
                if (t.isNew) const Positioned(top: 8, left: 8, child: NewBadge()),
                ]),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          t.dualSample != null || t.baby ? '📷📷 2 photos' : (t.canUseVideo ? '📷 Photo · 🎬 Vidéo' : '📷 Photo'),
                          if (t.country) '🌍 tous les pays',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _c.textSecondary, fontSize: 10.5),
                      ),
                      if (studioTrack(t.music) != null)
                        Text(
                          '🎵 ${studioTrack(t.music)!.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _c.accent, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      // nombre de publications faites avec ce modèle (compteur du serveur ; rien tant qu'il n'a pas servi)
                      if (TemplateStatsApi.usesOf('m:${t.id}') > 0)
                        Text(
                          tr('{n} utilisations', {'n': TemplateStatsApi.format(TemplateStatsApi.usesOf('m:${t.id}'))}),
                          key: ValueKey('tpl_uses_${t.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      );
    });
  }
}

/// Onglet « Communauté » : les modèles créés par les utilisateurs, les plus utilisés ou les plus récents, gratuits ou payants (prix en pièces, payé à la publication).
class _CommunityTab extends StatefulWidget {
  const _CommunityTab({required this.onOpen});
  final void Function(CommunityTemplate t) onOpen;

  @override
  State<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<_CommunityTab> with AutomaticKeepAliveClientMixin {
  final List<CommunityTemplate> _items = [];
  String _sort = 'popular';
  String? _pricing;
  int _page = 1;
  bool _loading = false;
  bool _more = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final r = await CommunityTemplatesApi.list(sort: _sort, pricing: _pricing, page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _more = r.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '${(e as dynamic).message ?? e}';
        });
      }
    }
  }

  Widget _chip(String key, String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(key: ValueKey(key), label: Text(label), selected: on, onSelected: (_) => tap()),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 8, 6, 4), children: [
          _chip('com_popular', tr('Populaires'), _sort == 'popular', () {
            _sort = 'popular';
            _load(reset: true);
          }),
          _chip('com_new', tr('Nouveaux'), _sort == 'new', () {
            _sort = 'new';
            _load(reset: true);
          }),
          _chip('com_free', tr('Gratuits'), _pricing == 'free', () {
            _pricing = _pricing == 'free' ? null : 'free';
            _load(reset: true);
          }),
          _chip('com_paid', tr('Payants'), _pricing == 'paid', () {
            _pricing = _pricing == 'paid' ? null : 'paid';
            _load(reset: true);
          }),
        ]),
      ),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_error != null && _items.isEmpty) return Center(child: Text(_error!, style: TextStyle(color: _c.danger)));
    if (_items.isEmpty) {
      return Center(
        child: _loading
            ? CircularProgressIndicator(color: _c.primary)
            : Padding(
                padding: const EdgeInsets.all(28),
                child: Text(tr('Pas encore de modèle de la communauté. Crée le tien : dans un modèle, choisis « Enregistrer comme modèle ».'), key: const ValueKey('community_empty'), textAlign: TextAlign.center, style: TextStyle(color: _c.textSecondary, height: 1.4)),
              ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 480 ? 3 : 2);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .62),
        itemCount: _items.length + (_more ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return Center(
              child: TextButton(
                key: const ValueKey('community_more'),
                onPressed: () {
                  _page++;
                  _load();
                },
                child: Text(tr('Voir plus')),
              ),
            );
          }
          return _card(_items[i]);
        },
      );
    });
  }

  Widget _card(CommunityTemplate t) {
    final base = kMontageTemplates.where((m) => m.id == t.baseId).firstOrNull;
    final price = t.priceCoins == 0 ? tr('Gratuit') : tr('{n} pièces', {'n': '${t.priceCoins}'});
    return GestureDetector(
      key: ValueKey('community_${t.id}'),
      onTap: () => widget.onOpen(t),
      child: Container(
        decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _c.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (base != null) TemplateThumb(asset: base.sampleIsVideo ? 'assets/images/intro4.jpg' : base.sample, video: base.showsVideo || t.face != null, template: t.toMontage()) else ColoredBox(color: _c.border),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.priceCoins == 0 ? Colors.black54 : _c.accent, borderRadius: BorderRadius.circular(99)),
                  child: Text(price, style: TextStyle(color: t.priceCoins == 0 ? Colors.white : _c.onAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text('@${t.ownerName ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textSecondary, fontSize: 10.5)),
              if (t.usesCount > 0) Text(tr('{n} utilisations', {'n': TemplateStatsApi.format(t.usesCount)}), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}
