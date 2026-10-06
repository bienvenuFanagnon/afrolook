import 'etude_admin_page.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../contenuPayant/admin_content_page.dart';
import '../user/profile/adminprofil.dart';
import '../user/profile/retraitAdmin/retraitAdminList.dart';
import '../user/profile/retraitAdmin/searchUserAdmin.dart';
import '../weekly_top/weekly_top_commentators_page.dart';
import 'AfrolookPub/afrolookAdminPubPage.dart';
import 'ad_admin_page.dart';
import 'admin_canaux_page.dart';
import 'admin_email_screen.dart';
import 'afrolook_group_migration_page.dart';
import 'commissions_admin_page.dart';
import 'dating/admin_dating_profiles_page.dart';
import 'influencer_requests_page.dart';
import 'moderation_reports_page.dart';
import 'official_accounts_page.dart';
import 'payment_methods_admin_page.dart';
import 'remuneration_admin_page.dart';
import 'quiz_admin_page.dart';
import 'stickers/admin_stickers_page.dart';
import 'pseudo_migration_page.dart';
import '../intro/tutos/tuto_scene_card.dart';

/// Tableau de bord admin unique (fusion de l'ancien « Tableau de bord » et de l'« ADMIN HUB » / AppData).
/// Les données se chargent à l'ouverture de la page et via le bouton « Actualiser » uniquement,
/// pas au retour d'une sous-page.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _db = FirebaseFirestore.instance;
  bool _forcingReward = false;
  bool _rankingOnlyMode = false;
  bool _loading = true;
  bool _financeDetails = false;
  bool _showSettings = false;

  // Statistiques
  int _totalUsers = 0;
  int _newUsersToday = 0;
  int _officialPending = 0;
  int _officialApproved = 0;
  int _influencerPending = 0;
  int _transactionsMonth = 0;
  int _activeToday = 0;
  int _activeWeek = 0;
  int _active30d = 0;
  int _active90d = 0;
  int _moderationPending = 0;
  int _boostsPending = 0;
  int _stickersPending = 0;
  int _retraitsTotal = 0;
  int _retraitsPending = 0;
  int _retraitsValides = 0;
  int _retraitsAnnules = 0;
  // Connexions par plateforme : [total, aujourd'hui, 7 jours, 30 jours, 3 mois]
  Map<String, List<int>> _platformStats = {};
  String? _platformError;
  AppDefaultData? _appData;
  List<_RecentEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadStats(showBoostAlert: true);
    _loadPlatformStats();
  }

  /// Utilisateurs et connexions par plateforme (champ `platform` : ios / android). Séparé du reste pour qu'un index
  /// manquant n'empêche pas l'affichage du tableau de bord.
  Future<void> _loadPlatformStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      int since(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;
      final out = <String, List<int>>{};
      for (final p in ['ios', 'android']) {
        final q = _db.collection('Users').where('platform', isEqualTo: p);
        final r = await Future.wait([
          q.count().get(),
          q.where('last_time_active', isGreaterThanOrEqualTo: startOfDay).count().get(),
          q.where('last_time_active', isGreaterThanOrEqualTo: since(7)).count().get(),
          q.where('last_time_active', isGreaterThanOrEqualTo: since(30)).count().get(),
          q.where('last_time_active', isGreaterThanOrEqualTo: since(90)).count().get(),
        ]);
        out[p] = [for (final x in r) x.count ?? 0];
      }
      if (!mounted) return;
      setState(() {
        _platformStats = out;
        _platformError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _platformError = e.toString().contains('index') ? 'Index en cours de création : réessaie dans quelques minutes.' : 'Statistiques par plateforme indisponibles.');
    }
  }

  Future<void> _loadStats({bool showBoostAlert = false}) async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      // Borne haute : exclut les anciens documents dont createdAt est en microsecondes
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
      int since(int days) => now.subtract(Duration(days: days)).millisecondsSinceEpoch;

      final retraits = _db.collection('TransactionRetraits');
      final counts = await Future.wait([
        _db.collection('Users').count().get(), // 0
        _db.collection('Users')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .where('createdAt', isLessThanOrEqualTo: endOfDay)
            .count()
            .get(), // 1
        _db.collection('OfficialAccountRequests').where('status', isEqualTo: 'pending').count().get(), // 2
        _db.collection('OfficialAccountRequests').where('status', isEqualTo: 'approved').count().get(), // 3
        _db.collection('InfluenceurRequests').where('status', isEqualTo: 'pending').count().get(), // 4
        _db.collection('TransactionSoldes').where('createdAt', isGreaterThanOrEqualTo: startOfMonth).count().get(), // 5
        _db.collection('Users').where('last_time_active', isGreaterThanOrEqualTo: startOfDay).count().get(), // 6
        _db.collection('Users').where('last_time_active', isGreaterThanOrEqualTo: since(7)).count().get(), // 7
        _db.collection('Users').where('last_time_active', isGreaterThanOrEqualTo: since(30)).count().get(), // 8
        _db.collection('Users').where('last_time_active', isGreaterThanOrEqualTo: since(90)).count().get(), // 9
        _db.collection('ModerationReports').where('status', isEqualTo: 'pending').count().get(), // 10
        _db.collection('Advertisements').where('status', isEqualTo: 'pending').count().get(), // 11
        retraits.count().get(), // 12
        retraits.where('statut', isEqualTo: 'EN_ATTENTE').count().get(), // 13
        retraits.where('statut', isEqualTo: 'VALIDER').count().get(), // 14
        retraits.where('statut', isEqualTo: 'ANNULE').count().get(), // 15
        _db.collection('StickerPacks').where('status', isEqualTo: 'pending').count().get(), // 16
      ]);

      final appData = await context.read<UserAuthProvider>().getAppDataStream().first;

      // Activité récente : 5 dernières actions sur comptes officiels
      final recentSnap = await _db
          .collection('OfficialAccountRequests')
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();
      final events = recentSnap.docs.map((d) {
        final data = d.data();
        return _RecentEvent(
          pseudo: data['pseudo'] as String? ?? '',
          status: data['status'] as String? ?? 'pending',
          timestamp: data['updatedAt'] as int? ?? 0,
        );
      }).toList();

      if (!mounted) return;
      int c(int i) => counts[i].count ?? 0;
      setState(() {
        _totalUsers = c(0);
        _newUsersToday = c(1);
        _officialPending = c(2);
        _officialApproved = c(3);
        _influencerPending = c(4);
        _transactionsMonth = c(5);
        _activeToday = c(6);
        _activeWeek = c(7);
        _active30d = c(8);
        _active90d = c(9);
        _moderationPending = c(10);
        _boostsPending = c(11);
        _retraitsTotal = c(12);
        _retraitsPending = c(13);
        _retraitsValides = c(14);
        _retraitsAnnules = c(15);
        _stickersPending = c(16);
        _appData = appData;
        _recentEvents = events;
        _loading = false;
      });
      if (showBoostAlert && _boostsPending > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingBoostModal(_boostsPending));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chargement incomplet : $e')));
    }
  }

  // Navigation simple : pas de rechargement au retour (demande du propriétaire)
  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Tableau de bord admin',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 22),
            onPressed: _loading ? null : () { _loadStats(); _loadPlatformStats(); },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading && _appData == null
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: () => _loadStats(),
              color: colors.primary,
              child: CenteredContent(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    _AdminHeader(me: me, colors: colors),
                    const SizedBox(height: 16),
                    _buildTodo(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Accès rapides', colors),
                    const SizedBox(height: 8),
                    _buildQuickAccess(colors),
                    const SizedBox(height: 20),
                    _SectionLabel("Finances de l'app", colors),
                    const SizedBox(height: 8),
                    _buildFinances(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Retraits', colors),
                    const SizedBox(height: 8),
                    _buildRetraits(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Activité', colors),
                    const SizedBox(height: 8),
                    _buildActivity(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Modules', colors),
                    const SizedBox(height: 8),
                    _buildModules(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Actions', colors),
                    const SizedBox(height: 8),
                    _AdminActionCard(
                      icon: Icons.emoji_events_rounded,
                      iconColor: colors.supportAccent,
                      label: 'Forcer le classement commentateurs',
                      desc: 'Recalcule et récompense le Top 5 de la semaine précédente',
                      loading: _forcingReward,
                      onTap: _forceWeeklyCommentatorsReward,
                      colors: colors,
                      trailing: TextButton.icon(
                        onPressed: () => _push(const WeeklyTopCommentatorsPage()),
                        icon: const Icon(Icons.leaderboard_rounded, size: 16),
                        label: const Text('Voir le classement'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.supportAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    if (_recentEvents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel('Comptes officiels — activité récente', colors),
                      const SizedBox(height: 8),
                      _RecentActivity(events: _recentEvents, colors: colors),
                    ],
                    const SizedBox(height: 20),
                    _buildSettings(colors),
                  ],
                ),
              ),
            ),
    );
  }

  // ── À traiter ──────────────────────────────────────────────────────────────

  Widget _buildTodo(AppColors c) {
    final items = <_TodoItem>[
      _TodoItem(Icons.gavel_rounded, 'Signalements à modérer', _moderationPending, c.danger,
          () => _push(const ModerationReportsPage())),
      _TodoItem(Icons.north_east_rounded, 'Retraits en attente', _retraitsPending, c.warning,
          () => _push(AdminRetraitListPage())),
      _TodoItem(Icons.campaign_rounded, 'Boosts / publicités à valider', _boostsPending, const Color(0xFF8E3CC4),
          () => _push(const AdvertisementManagementPage())),
      _TodoItem(Icons.verified_rounded, 'Comptes officiels à traiter', _officialPending, c.info,
          () => _push(const OfficialAccountsPage())),
      _TodoItem(Icons.star_rounded, 'Demandes influenceur', _influencerPending, c.supportAccent,
          () => _push(const InfluencerRequestsPage())),
    ].where((i) => i.count > 0).toList();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _box(c),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: c.success, size: 20),
          const SizedBox(width: 10),
          Text('Rien à traiter pour le moment', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _box(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('À TRAITER',
                style: TextStyle(color: c.danger, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, indent: 48, color: c.border),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Icon(items[i].icon, color: items[i].color, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(items[i].label,
                        style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  _Badge(items[i].count, items[i].color),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Accès rapides ──────────────────────────────────────────────────────────

  Widget _buildQuickAccess(AppColors c) {
    final tiles = [
      _QuickTile(Icons.people_alt_rounded, 'Utilisateurs', 'Recherche & gestion', c.info, 0,
          () => _push(UserSearchPage())),
      _QuickTile(Icons.receipt_long_rounded, 'Transactions', 'Tous les utilisateurs', c.primary, 0,
          () => _push(TransactionsListPage())),
      _QuickTile(Icons.account_balance_rounded, 'Retraits', 'Demandes de retrait', c.warning, _retraitsPending,
          () => _push(AdminRetraitListPage())),
      _QuickTile(Icons.gavel_rounded, 'Modération', 'Signalements, blocages', c.danger, _moderationPending,
          () => _push(const ModerationReportsPage())),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [for (final t in tiles) _QuickTileCard(tile: t, colors: c)],
    );
  }

  // ── Finances (ex-AppData) ──────────────────────────────────────────────────

  Widget _buildFinances(AppColors c) {
    final a = _appData ?? AppDefaultData();
    final principal = a.solde_principal ?? 0;
    final gain = a.solde_gain ?? 0;
    final affiliation = a.solde_affiliation ?? 0;
    final gainPieces = a.solde_gain_pieces ?? 0;
    final total = principal + gain + affiliation + 0.4 * gainPieces;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: _box(c),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _metric(c, 'Solde principal', _money(principal), Icons.account_balance_wallet_rounded, c.primary)),
            Expanded(child: _metric(c, 'Ancien compteur gains', _money(gain), Icons.history_rounded, c.textSecondary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _metric(c, 'Affiliation', _money(affiliation), Icons.group_rounded, c.info)),
            Expanded(child: _metric(c, 'Gains en pièces', '${_int(gainPieces.ceil())} pièces', Icons.toll_rounded, c.warning)),
          ]),
          InkWell(
            onTap: () => setState(() => _financeDetails = !_financeDetails),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Text('Total général', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                const Spacer(),
                Text(_money(total),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                Icon(_financeDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: c.textSecondary, size: 20),
              ]),
            ),
          ),
          if (_financeDetails)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Total = solde principal + ancien compteur + affiliation + 40 % des gains en pièces (valeur en FCFA). '
                "L'ancien compteur de gains était faussé (parts des canaux et lives > 100 %) : il est conservé en historique. "
                'Les vrais gains de l\'app, par source, sont dans « Commissions ».',
                style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _push(const CommissionsAdminPage()),
              icon: const Icon(Icons.pie_chart_rounded, size: 18),
              label: const Text('Voir les commissions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary.withOpacity(0.5)),
                minimumSize: const Size(0, 38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Retraits ───────────────────────────────────────────────────────────────

  Widget _buildRetraits(AppColors c) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(AdminRetraitListPage()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: _box(c),
        child: Column(children: [
          Row(children: [
            Expanded(child: _counter(c, 'Total', _retraitsTotal, c.textPrimary)),
            Expanded(child: _counter(c, 'En attente', _retraitsPending, c.warning)),
            Expanded(child: _counter(c, 'Validés', _retraitsValides, c.success)),
            Expanded(child: _counter(c, 'Annulés', _retraitsAnnules, c.danger)),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ]),
          if (_retraitsTotal > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(children: [
                  if (_retraitsPending > 0) Expanded(flex: _retraitsPending, child: Container(color: c.warning)),
                  if (_retraitsValides > 0) Expanded(flex: _retraitsValides, child: Container(color: c.success)),
                  if (_retraitsAnnules > 0) Expanded(flex: _retraitsAnnules, child: Container(color: c.danger)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Activité ───────────────────────────────────────────────────────────────

  Widget _buildActivity(AppColors c) {
    final a = _appData ?? AppDefaultData();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _box(c),
      child: Column(children: [
        Row(children: [
          Expanded(child: _metric(c, 'Utilisateurs', _int(_totalUsers), Icons.people_rounded, c.primary,
              sub: '+$_newUsersToday aujourd\'hui')),
          Expanded(child: _metric(c, 'Transactions', _int(_transactionsMonth), Icons.receipt_long_rounded, c.info,
              sub: 'ce mois')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric(c, 'Comptes officiels', _int(_officialApproved), Icons.verified_rounded, c.info)),
          Expanded(child: _metric(c, 'Abonnés', _int(a.nbr_abonnes ?? 0), Icons.person_add_alt_1_rounded, c.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric(c, 'Likes', _int(a.nbr_likes ?? 0), Icons.favorite_rounded, c.danger)),
          Expanded(child: _metric(c, 'Commentaires', _int(a.nbr_comments ?? 0), Icons.chat_bubble_rounded, c.warning)),
        ]),
        Divider(height: 24, color: c.border),
        Row(children: [
          Text('Connexions', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _counter(c, "Aujourd'hui", _activeToday, c.primary)),
          Expanded(child: _counter(c, '7 jours', _activeWeek, c.info)),
          Expanded(child: _counter(c, '30 jours', _active30d, const Color(0xFF8E3CC4))),
          Expanded(child: _counter(c, '3 mois', _active90d, c.warning)),
        ]),
        Divider(height: 24, color: c.border),
        Text('Par plateforme', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_platformError != null)
          Text(_platformError!, style: TextStyle(color: c.textSecondary, fontSize: 12))
        else if (_platformStats.isEmpty)
          const SizedBox(height: 18, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
        else ...[
          _platformRow(c, 'iPhone / iPad', Icons.apple_rounded, _platformStats['ios']!),
          const SizedBox(height: 10),
          _platformRow(c, 'Android', Icons.android_rounded, _platformStats['android']!),
          const SizedBox(height: 6),
          Text(
            'Plateforme inconnue : ${_int((_totalUsers - (_platformStats['ios']![0] + _platformStats['android']![0])).clamp(0, 1 << 31))} (compte sans notification activée ou ancien profil ; renseignée à la prochaine connexion avec la nouvelle version).',
            style: TextStyle(color: c.textSecondary, fontSize: 10.5, height: 1.3),
          ),
        ],
      ]),
    );
  }

  // ── Modules ────────────────────────────────────────────────────────────────

  Widget _buildModules(AppColors c) {
    final modules = [
      _Module(Icons.verified_rounded, 'Comptes officiels', c.info, _officialPending, const OfficialAccountsPage()),
      _Module(Icons.star_rounded, 'Influenceurs', c.supportAccent, _influencerPending, const InfluencerRequestsPage()),
      _Module(Icons.campaign_rounded, 'Publicités', const Color(0xFF8E3CC4), _boostsPending, const AdvertisementManagementPage()),
      _Module(Icons.ondemand_video_rounded, 'Pub AdMob', const Color(0xFF8E3CC4), 0, AdAdminPage()),
      _Module(Icons.quiz_rounded, 'Quiz', const Color(0xFFE0A100), 0, const QuizAdminPage()),
      _Module(Icons.school_rounded, 'Étude', const Color(0xFF1FAA59), 0, const EtudeAdminPage()),
      _Module(Icons.pie_chart_rounded, 'Commissions', c.primary, 0, const CommissionsAdminPage()),
      _Module(Icons.account_balance_wallet_rounded, 'Rémunération', c.primary, 0, RemunerationAdminPage()),
      _Module(Icons.storefront_rounded, 'Contenus payants', c.supportAccent, 0, const AdminContentPage()),
      _Module(Icons.favorite_rounded, 'Afrolove', const Color(0xFFD6204A), 0, AdminDatingProfilesPage()),
      _Module(Icons.mail_rounded, 'Emailing', c.textSecondary, 0, AdminEmailScreen()),
      _Module(Icons.payment_rounded, 'Moyens de paiement', c.primary, 0, const PaymentMethodsAdminPage()),
      _Module(Icons.groups_rounded, 'Groupe Afrolook', c.info, 0, const AfrolookGroupMigrationPage()),
      _Module(Icons.school_rounded, 'Tutoriels', c.supportAccent, 0, const TutoListPage(showAll: true)),
      _Module(Icons.alternate_email_rounded, 'Pseudos', c.info, 0, const PseudoMigrationPage()),
      _Module(Icons.live_tv_rounded, 'Canaux', c.info, 0, const AdminCanauxPage()),
      _Module(Icons.emoji_emotions_rounded, 'Stickers', c.warning, _stickersPending, const AdminStickersPage()),
      _Module(Icons.tag_rounded, 'Noms de canaux', c.primary, 0, const PseudoMigrationPage(canaux: true)),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [for (final m in modules) _ModuleCard(module: m, colors: c, onTap: () => _push(m.page))],
    );
  }

  // ── Réglages de l'app (ex-AppData) ─────────────────────────────────────────

  Widget _buildSettings(AppColors c) {
    final a = _appData ?? AppDefaultData();
    String f2(double? v) => (v ?? 0).toStringAsFixed(2);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _box(c),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _showSettings = !_showSettings),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(Icons.tune_rounded, color: c.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Réglages de l'app",
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text('Version, tarifs, points', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              Icon(_showSettings ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textSecondary),
            ]),
          ),
        ),
        if (_showSettings)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(children: [
              _settingsGroup(c, 'Version', [
                _kv(c, 'Version actuelle', '${a.app_version_code ?? 0}'),
                _kv(c, 'Version officielle', '${a.app_version_code_officiel ?? 0}'),
                _kv(c, 'Vérification Google', a.googleVerification == true ? 'Activée' : 'Désactivée',
                    valueColor: a.googleVerification == true ? c.success : c.danger),
              ]),
              _settingsGroup(c, 'Tarifs', [
                _kv(c, 'PubliCash', f2(a.tarifPubliCash)),
                _kv(c, 'Conversion PubliCash', '${f2(a.tarifPubliCash_to_xof)} FCFA'),
                _kv(c, 'Image', f2(a.tarifImage)),
                _kv(c, 'Vidéo', f2(a.tarifVideo)),
                _kv(c, 'Par jour', f2(a.tarifjour)),
              ]),
              _settingsGroup(c, 'Points par défaut', [
                _kv(c, 'Nouvel utilisateur', '${a.default_point_new_user ?? 0} pts'),
                _kv(c, 'Nouveau like', '${a.default_point_new_like ?? 0} pts'),
                _kv(c, 'Nouveau love', '${a.default_point_new_love ?? 0} pts'),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _settingsGroup(AppColors c, String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        ...rows,
      ]),
    );
  }

  Widget _kv(AppColors c, String k, String v, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13))),
          Text(v, style: TextStyle(color: valueColor ?? c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Petits éléments ────────────────────────────────────────────────────────

  BoxDecoration _box(AppColors c) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      );

  Widget _metric(AppColors c, String label, String value, IconData icon, Color color, {String? sub}) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color.withOpacity(c.isDark ? 0.18 : 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          Text(sub == null ? label : '$label · $sub',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _counter(AppColors c, String label, int value, Color color) => Column(children: [
        Text(_int(value),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
      ]);

  Widget _platformRow(AppColors c, String label, IconData icon, List<int> v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: c.textPrimary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
          const Spacer(),
          Text('${_int(v[0])} inscrits', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _counter(c, "Aujourd'hui", v[1], c.primary)),
          Expanded(child: _counter(c, '7 jours', v[2], c.info)),
          Expanded(child: _counter(c, '30 jours', v[3], const Color(0xFF8E3CC4))),
          Expanded(child: _counter(c, '3 mois', v[4], c.warning)),
        ]),
      ]);

  static final NumberFormat _intFmt = NumberFormat.decimalPattern('fr');
  static final NumberFormat _moneyFmt = NumberFormat('#,##0', 'fr');
  String _int(int v) => _intFmt.format(v);
  String _money(double v) => '${_moneyFmt.format(v)} FCFA';

  // ── Boosts en attente (alerte à l'ouverture) ───────────────────────────────

  void _showPendingBoostModal(int count) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Boosts en attente',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
            '$count demande${count > 1 ? 's' : ''} de boost en attente de validation. '
            'Les utilisateurs attendent une activation sous 24 h.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Plus tard', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _push(const AdvertisementManagementPage());
              },
              style: FilledButton.styleFrom(backgroundColor: colors.danger, foregroundColor: Colors.white),
              child: Text('Voir les boosts ($count)'),
            ),
          ],
        );
      },
    );
  }

  // ── Classement commentateurs ───────────────────────────────────────────────

  Future<void> _forceWeeklyCommentatorsReward() async {
    if (_forcingReward) return;
    final colors = AppColors.of(context);

    setState(() => _forcingReward = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'forceWeeklyCommentatorsReward',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      // Première vérification : déjà traité ?
      final checkResult = await callable.call({'confirm': false});
      final checkData = checkResult.data as Map<String, dynamic>? ?? {};
      if (!mounted) return;

      if (checkData['alreadyProcessed'] == true) {
        final existingCount = checkData['rankingsCount'] as int? ?? 0;
        final processedAtMs = checkData['processedAt'] as int?;
        final dateStr = processedAtMs != null
            ? DateFormat("dd/MM 'à' HH'h'mm", 'fr').format(DateTime.fromMillisecondsSinceEpoch(processedAtMs))
            : 'date inconnue';

        setState(() => _forcingReward = false);
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Déjà calculé', style: TextStyle(color: colors.textPrimary, fontSize: 16)),
            content: Text(
              'Ce classement a déjà été exécuté le $dateStr.\n$existingCount gagnant(s) récompensé(s).\n\nQue veux-tu faire ?',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'rankingOnly'),
                child: Text('Mettre à jour le classement\n(sans re-récompenser)',
                    style: TextStyle(color: colors.info, fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'full'),
                child: Text('Relancer complet\n(re-crédite les pièces ⚠️)',
                    style: TextStyle(color: colors.danger, fontSize: 12)),
              ),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        _rankingOnlyMode = choice == 'rankingOnly';
        setState(() => _forcingReward = true);
      } else {
        setState(() => _forcingReward = false);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Lancer le classement commentateurs', style: TextStyle(color: colors.textPrimary)),
            content: Text(
              'Cela va calculer le Top Commentateurs de la semaine précédente et envoyer les récompenses + notifications.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Confirmer', style: TextStyle(color: colors.info)),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        setState(() => _forcingReward = true);
      }

      final runResult = await callable.call({'confirm': true, 'rankingOnly': _rankingOnlyMode});
      final runData = runResult.data as Map<String, dynamic>? ?? {};
      if (!mounted) return;

      final count = runData['rankingsCount'] as int? ?? 0;
      final note = runData['note'] as String? ?? '';
      final String msg;
      if (count > 0) {
        msg = 'Terminé — $count gagnant(s) récompensé(s).';
      } else if (note == 'no_eligible_comments') {
        msg = 'Aucun commentaire éligible trouvé (min. 10 caractères) pour la semaine.';
      } else if (note == 'no_eligible_users') {
        msg = 'Commentaires trouvés mais aucun utilisateur éligible (compte < 7 jours).';
      } else {
        msg = 'Terminé — 0 gagnant. Note : $note';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: count > 0 ? colors.success : colors.warning,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: colors.danger),
      );
    } finally {
      if (mounted) setState(() => _forcingReward = false);
    }
  }
}

// ── Composants ───────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final dynamic me;
  final AppColors colors;
  const _AdminHeader({required this.me, required this.colors});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(colors.isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.admin_panel_settings_rounded, color: colors.primary, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet, @${me?.pseudo ?? 'admin'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          Text(DateFormat('EEEE d MMMM yyyy', 'fr').format(DateTime.now()),
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ]),
      ),
    ]);
  }
}

class _TodoItem {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _TodoItem(this.icon, this.label, this.count, this.color, this.onTap);
}

class _QuickTile {
  final IconData icon;
  final String label, sub;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _QuickTile(this.icon, this.label, this.sub, this.color, this.badge, this.onTap);
}

class _QuickTileCard extends StatelessWidget {
  final _QuickTile tile;
  final AppColors colors;
  const _QuickTileCard({required this.tile, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tile.color.withOpacity(c.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tile.icon, color: tile.color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(tile.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (tile.badge > 0) _Badge(tile.badge, tile.color),
          ]),
        ),
      ),
    );
  }
}

class _Module {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final Widget page;
  const _Module(this.icon, this.label, this.color, this.badge, this.page);
}

class _ModuleCard extends StatelessWidget {
  final _Module module;
  final AppColors colors;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Stack(children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: module.color.withOpacity(c.isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(module.icon, color: module.color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(module.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
            if (module.badge > 0) Positioned(top: 0, right: 0, child: _Badge(module.badge, c.danger)),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge(this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
      );
}

class _RecentActivity extends StatelessWidget {
  final List<_RecentEvent> events;
  final AppColors colors;
  const _RecentActivity({required this.events, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _statusColor(events[i].status), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      children: [
                        TextSpan(
                          text: '@${events[i].pseudo} ',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: _statusLabel(events[i].status)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_timeAgo(events[i].timestamp), style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => const Color(0xFF4CAF50),
        'rejected' => const Color(0xFFF44336),
        'underReview' => const Color(0xFF2196F3),
        'moreInfoNeeded' => const Color(0xFF9C27B0),
        'suspended' => const Color(0xFF607D8B),
        _ => const Color(0xFFFF9800),
      };

  String _statusLabel(String status) => switch (status) {
        'approved' => '— demande acceptée',
        'rejected' => '— demande refusée',
        'underReview' => "— en cours d'analyse",
        'moreInfoNeeded' => '— infos demandées',
        'suspended' => '— compte suspendu',
        _ => '— en attente de traitement',
      };

  String _timeAgo(int ts) {
    if (ts == 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }
}

class _RecentEvent {
  final String pseudo, status;
  final int timestamp;
  const _RecentEvent({required this.pseudo, required this.status, required this.timestamp});
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, desc;
  final bool loading;
  final VoidCallback onTap;
  final AppColors colors;
  final Widget? trailing;

  const _AdminActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.desc,
    required this.loading,
    required this.onTap,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(colors.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 10),
            loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.info))
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.info,
                      side: BorderSide(color: colors.info.withOpacity(0.5)),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Lancer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
          ]),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );
}
