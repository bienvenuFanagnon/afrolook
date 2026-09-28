import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';
import '../../l10n/tr.dart';

/// « Mes canaux » : canaux créés et canaux administrés par l'utilisateur.
/// Chargement rapide : les deux requêtes partent en parallèle, la liste s'affiche dès leur retour,
/// puis les créateurs des canaux administrés sont complétés (une lecture par créateur, en parallèle).
class CanalListPageByUser extends StatefulWidget {
  @override
  _CanalListPageByUserState createState() => _CanalListPageByUserState();
}

class _CanalListPageByUserState extends State<CanalListPageByUser> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  List<Canal> createdCanaux = [];
  List<Canal> adminCanaux = [];
  bool isLoading = true;
  bool hasError = false;

  late AppColors _colors;

  @override
  void initState() {
    super.initState();
    _loadCanaux();
  }

  Canal _parse(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final canal = Canal.fromJson(doc.data());
    canal.id = doc.id;
    canal.adminIds ??= [];
    canal.allowedPostersIds ??= [];
    canal.usersSuiviId ??= [];
    return canal;
  }

  Future<void> _loadCanaux() async {
    setState(() {
      isLoading = createdCanaux.isEmpty && adminCanaux.isEmpty;
      hasError = false;
    });

    try {
      final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
      final uid = me.id!;
      final canaux = firestore.collection('Canaux');

      // Les deux requêtes en parallèle (avant : l'une après l'autre)
      final results = await Future.wait([
        canaux.where('userId', isEqualTo: uid).orderBy('updatedAt', descending: true).limit(50).get(),
        canaux.where('adminIds', arrayContains: uid).orderBy('updatedAt', descending: true).limit(50).get(),
      ]);

      // Mes canaux : je suis le créateur, pas besoin de relire ma fiche
      final created = results[0].docs.map(_parse).toList();
      for (final c in created) {
        c.user = me;
      }
      final createdIds = created.map((c) => c.id).toSet();
      final admin = results[1].docs.where((d) => !createdIds.contains(d.id)).map(_parse).toList();

      if (!mounted) return;
      setState(() {
        createdCanaux = created;
        adminCanaux = admin;
        isLoading = false;
      });

      _loadCreators(admin);
    } catch (e) {
      printVm('Erreur chargement canaux: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = createdCanaux.isEmpty && adminCanaux.isEmpty;
      });
    }
  }

  /// Créateurs des canaux administrés : une lecture par créateur distinct, en parallèle, après l'affichage.
  Future<void> _loadCreators(List<Canal> canals) async {
    final ids = canals.map((c) => c.userId).whereType<String>().where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    try {
      final docs = await Future.wait(ids.map((id) => firestore.collection('Users').doc(id).get()));
      final byId = <String, UserData>{
        for (final d in docs)
          if (d.exists) d.id: UserData.fromJson(d.data()!),
      };
      if (!mounted) return;
      setState(() {
        for (final c in canals) {
          c.user = byId[c.userId] ?? c.user;
        }
      });
    } catch (e) {
      printVm('Erreur créateurs des canaux: $e');
    }
  }

  // ── Construction ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(
          context.tr('Mes canaux'),
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadCanaux,
            icon: Icon(Icons.refresh_rounded, color: _colors.textPrimary),
            tooltip: context.tr('Actualiser'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _colors.divider),
        ),
      ),
      body: CenteredContent(
        child: isLoading
            ? _buildSkeleton()
            : hasError
                ? _buildError()
                : (createdCanaux.isEmpty && adminCanaux.isEmpty)
                    ? _buildEmptyAll(l10n)
                    : RefreshIndicator(
                        onRefresh: _loadCanaux,
                        color: _colors.primary,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                          children: [
                            _buildSummary(),
                            const SizedBox(height: 18),
                            _buildSectionHeader(context.tr('Créés par moi'), createdCanaux.length, _colors.primary),
                            if (createdCanaux.isEmpty)
                              _buildEmptySection(l10n.canalNoneCreated, Icons.add_circle_outline_rounded)
                            else
                              ...createdCanaux.map((c) => _buildCanalCard(c, isOwner: true)),
                            const SizedBox(height: 18),
                            _buildSectionHeader(context.tr('J\'administre'), adminCanaux.length, _colors.warning),
                            if (adminCanaux.isEmpty)
                              _buildEmptySection(l10n.canalNoneManaged, Icons.admin_panel_settings_outlined)
                            else
                              ...adminCanaux.map((c) => _buildCanalCard(c, isOwner: false)),
                          ],
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewCanal())),
        backgroundColor: _colors.primary,
        foregroundColor: _colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Créer un canal'), style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Chiffres clés : canaux, abonnés cumulés, publications cumulées.
  Widget _buildSummary() {
    final all = [...createdCanaux, ...adminCanaux];
    final followers = all.fold<int>(0, (s, c) => s + (c.membersCount));
    final posts = all.fold<int>(0, (s, c) => s + (c.publication ?? 0));
    Widget stat(String value, String label, IconData icon, Color color) => Expanded(
          child: Column(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 11.5)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          stat('${all.length}', all.length > 1 ? 'canaux' : 'canal', Icons.campaign_rounded, _colors.primary),
          VerticalDivider(width: 1, color: _colors.border),
          stat(_n.format(followers), context.tr('abonnés'), Icons.people_alt_rounded, _colors.accent),
          VerticalDivider(width: 1, color: _colors.border),
          stat(_n.format(posts), 'publications', Icons.article_rounded, _colors.info),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: _colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _colors.isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _buildCanalCard(Canal canal, {required bool isOwner}) {
    final l10n = AppLocalizations.of(context);
    final isPrivate = canal.isPrivate == true;
    final roleColor = isOwner ? _colors.primary : _colors.warning;
    final hasImage = canal.urlImage != null && canal.urlImage!.isNotEmpty;
    final creator = canal.user?.pseudo;
    final subtitle = !isOwner && creator != null && creator.isNotEmpty
        ? context.tr('Créé par @{a}', {'a': creator})
        : (canal.description?.trim().isNotEmpty == true ? canal.description!.trim() : null);

    Widget chip(IconData icon, String text, {Color? color}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? _colors.textSecondary),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  color: color ?? _colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Avatar + badge vérifié
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: roleColor, width: 2)),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: _colors.surfaceVariant,
                    backgroundImage: hasImage ? NetworkImage(canal.urlImage!) : null,
                    child: hasImage ? null : Icon(Icons.campaign_rounded, color: roleColor, size: 22),
                  ),
                ),
                if (canal.isVerify == true)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      decoration: BoxDecoration(color: _colors.surface, shape: BoxShape.circle),
                      child: Icon(Icons.verified_rounded, size: 17, color: _colors.info),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        '#${canal.titre ?? 'Sans nom'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _colors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: _colors.isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(isOwner ? l10n.canalProprioLabel : l10n.canalAdminLabel,
                          style: TextStyle(color: roleColor, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _colors.textSecondary, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    chip(Icons.people_alt_rounded, _n.format(canal.membersCount)),
                    chip(Icons.article_rounded, _n.format(canal.publication ?? 0)),
                    isPrivate
                        ? chip(Icons.lock_rounded,
                            canal.subscriptionPriceCoins > 0
                                ? context.tr('{a} · {b} pièces', {'a': l10n.canalPrivate, 'b': _n.format(canal.subscriptionPriceCoins)})
                                : l10n.canalPrivate,
                            color: _colors.accent)
                        : chip(Icons.public_rounded, l10n.canalPublic, color: _colors.primary),
                  ]),
                ]),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: _colors.textSecondary),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colors.border),
      ),
      child: Row(children: [
        Icon(icon, color: _colors.textSecondary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: _colors.textSecondary, fontSize: 13.5))),
      ]),
    );
  }

  /// Squelette pendant le premier chargement (au lieu d'un simple indicateur).
  Widget _buildSkeleton() {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: _colors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 78,
          decoration: BoxDecoration(color: _colors.surface, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _colors.border),
            ),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: _colors.surfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  bar(140, 13),
                  const SizedBox(height: 8),
                  bar(200, 10),
                  const SizedBox(height: 8),
                  bar(120, 10),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: _colors.textSecondary),
          const SizedBox(height: 12),
          Text(context.tr('Impossible de charger tes canaux'),
              style: TextStyle(color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(context.tr('Vérifie ta connexion, puis réessaie.'), style: TextStyle(color: _colors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadCanaux,
            style: FilledButton.styleFrom(backgroundColor: _colors.primary, foregroundColor: _colors.onPrimary),
            child: Text(context.tr('Réessayer')),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyAll(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _colors.primary.withValues(alpha: _colors.isDark ? 0.18 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_rounded, size: 40, color: _colors.primary),
          ),
          const SizedBox(height: 14),
          Text(l10n.canalCreateFirstOne,
              style: TextStyle(color: _colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            context.tr('Un canal regroupe tes publications et tes abonnés autour d\'un thème. Il peut être public ou privé (abonnement en pièces).'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _colors.textSecondary, height: 1.4),
          ),
        ]),
      ),
    );
  }
}
