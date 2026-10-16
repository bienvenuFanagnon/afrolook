// Galerie des templates « prêts à poster », par catégorie. Chaque aperçu est déjà rempli et animé.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';
import '../studio_models.dart';
import 'montage_canvas.dart';
import 'montage_catalog.dart';
import 'montage_editor_page.dart';
import 'montage_fx.dart';
import '../artist_sound_common.dart';
import 'montage_music.dart';
import 'montage_state.dart';

const _c = AppColors.dark;

class MontageGalleryPage extends StatefulWidget {
  const MontageGalleryPage({super.key, this.forChronique = false, this.presetMusic});
  final bool forChronique;

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
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _open(MontageTemplate t) async {
    _anim.stop();
    final r = await Navigator.push<StudioResult>(
      context,
      MaterialPageRoute(builder: (_) => MontageEditorPage(template: t, forChronique: widget.forChronique, presetMusic: widget.presetMusic)),
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
    final me = context.read<UserAuthProvider>().loginUserData;
    final pseudo = me.pseudo ?? '';
    _followers = me.followersCount;
    _avatar = me.imageUrl;
    return DefaultTabController(
      length: MontageCat.values.length,
      child: Scaffold(
        backgroundColor: _c.background,
        appBar: AppBar(
          backgroundColor: _c.background,
          foregroundColor: _c.textPrimary,
          elevation: 0,
          title: const Text('Templates prêts à poster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(widget.presetMusic == null ? 48 : 88),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (widget.presetMusic != null) _presetBanner(widget.presetMusic!),
              TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _c.accent,
            unselectedLabelColor: _c.textSecondary,
            indicatorColor: _c.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [for (final cat in MontageCat.values) Tab(text: cat.label)],
              ),
            ]),
          ),
        ),
        body: TabBarView(children: [
          for (final cat in MontageCat.values) _grid(cat, pseudo),
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
      ]),
    );
  }

  Widget _grid(MontageCat cat, String pseudo) {
    final list = kMontageTemplates.where((t) => t.cat == cat).toList();
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
                RepaintBoundary(
                  child: MontageCanvas(
                    state: _states[t.id]!,
                    animation: t.fx == MontageFx.none ? null : _anim,
                    media: Image.asset(t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, fit: BoxFit.cover, cacheWidth: 400),
                    secondMedia: t.dualSample != null ? Image.asset(t.dualSample!, fit: BoxFit.cover, cacheWidth: 300) : null,
                    pseudo: pseudo,
                    avatarUrl: _avatar,
                    followers: _followers,
                  ),
                ),
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
