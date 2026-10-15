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
import 'montage_state.dart';

const _c = AppColors.dark;

class MontageGalleryPage extends StatefulWidget {
  const MontageGalleryPage({super.key, this.forChronique = false});
  final bool forChronique;

  @override
  State<MontageGalleryPage> createState() => _MontageGalleryPageState();
}

class _MontageGalleryPageState extends State<MontageGalleryPage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: kMontageLoop)..repeat();
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
      MaterialPageRoute(builder: (_) => MontageEditorPage(template: t, forChronique: widget.forChronique)),
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
    final pseudo = context.read<UserAuthProvider>().loginUserData.pseudo ?? '';
    return DefaultTabController(
      length: MontageCat.values.length,
      child: Scaffold(
        backgroundColor: _c.background,
        appBar: AppBar(
          backgroundColor: _c.background,
          foregroundColor: _c.textPrimary,
          elevation: 0,
          title: const Text('Templates prêts à poster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _c.accent,
            unselectedLabelColor: _c.textSecondary,
            indicatorColor: _c.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [for (final cat in MontageCat.values) Tab(text: cat.label)],
          ),
        ),
        body: TabBarView(children: [
          for (final cat in MontageCat.values) _grid(cat, pseudo),
        ]),
      ),
    );
  }

  Widget _grid(MontageCat cat, String pseudo) {
    final list = kMontageTemplates.where((t) => t.cat == cat).toList();
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 480 ? 3 : 2);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .48),
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
