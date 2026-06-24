import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../user/profile/adminprofil.dart';
import 'AfrolookPub/afrolookAdminPubPage.dart';
import 'afrolook_group_migration_page.dart';
import 'admin_email_screen.dart';
import 'dating/admin_dating_profiles_page.dart';
import 'influencer_requests_page.dart';
import 'official_accounts_page.dart';
import 'remuneration_admin_page.dart';
import '../challenge/challengeDashbord.dart';
import '../pronostics/admin_pronostics_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _db = FirebaseFirestore.instance;

  // Stats chargées une fois
  int _totalUsers = 0;
  int _officialPending = 0;
  int _officialApproved = 0;
  int _influencerPending = 0;
  int _transactionsMonth = 0;
  int _newUsersToday = 0;
  bool _loading = true;

  // Activité récente
  List<_RecentEvent> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final startOfDay  = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

      final results = await Future.wait([
        _db.collection('Users').count().get(),
        _db.collection('OfficialAccountRequests')
            .where('status', isEqualTo: 'pending').count().get(),
        _db.collection('OfficialAccountRequests')
            .where('status', isEqualTo: 'approved').count().get(),
        _db.collection('InfluenceurRequests')
            .where('status', isEqualTo: 'pending').count().get(),
        _db.collection('TransactionSoldes')
            .where('createdAt', isGreaterThanOrEqualTo: startOfMonth).count().get(),
        _db.collection('Users')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay).count().get(),
      ]);

      // Activité récente : 5 dernières actions sur comptes officiels
      final recentSnap = await _db
          .collection('OfficialAccountRequests')
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();

      final events = recentSnap.docs.map((d) {
        final status = d.data()['status'] as String? ?? 'pending';
        final pseudo = d.data()['pseudo'] as String? ?? '';
        final ts = d.data()['updatedAt'] as int? ?? 0;
        return _RecentEvent(pseudo: pseudo, status: status, timestamp: ts);
      }).toList();

      if (mounted) {
        setState(() {
          _totalUsers        = results[0].count ?? 0;
          _officialPending   = results[1].count ?? 0;
          _officialApproved  = results[2].count ?? 0;
          _influencerPending = results[3].count ?? 0;
          _transactionsMonth = results[4].count ?? 0;
          _newUsersToday     = results[5].count ?? 0;
          _recentEvents      = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Tableau de bord',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 20),
            onPressed: _loadStats,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: colors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Identité admin ─────────────────────────────────────────
                  _AdminHeader(me: me, colors: colors),
                  const SizedBox(height: 12),

                  // ── AppData ─────────────────────────────────────────────────
                  _AppDataButton(onTap: () => _push(AdminHubPage())),
                  const SizedBox(height: 20),

                  // ── Stats ──────────────────────────────────────────────────
                  _SectionLabel('Vue d\'ensemble', colors),
                  const SizedBox(height: 10),
                  _StatsGrid(
                    totalUsers:        _totalUsers,
                    officialApproved:  _officialApproved,
                    officialPending:   _officialPending,
                    influencerPending: _influencerPending,
                    transactionsMonth: _transactionsMonth,
                    newUsersToday:     _newUsersToday,
                    colors: colors,
                  ),
                  const SizedBox(height: 20),

                  // ── Alertes ────────────────────────────────────────────────
                  if (_officialPending > 0 || _influencerPending > 0) ...[
                    _SectionLabel('Alertes', colors),
                    const SizedBox(height: 10),
                    if (_officialPending > 0)
                      _AlertBanner(
                        icon: Icons.verified_rounded,
                        label: 'Comptes officiels à traiter',
                        count: _officialPending,
                        color: const Color(0xFFFF9800),
                        onTap: () => _push(const OfficialAccountsPage()),
                        colors: colors,
                      ),
                    if (_influencerPending > 0)
                      _AlertBanner(
                        icon: Icons.star_rounded,
                        label: 'Demandes influenceur en attente',
                        count: _influencerPending,
                        color: const Color(0xFF9C27B0),
                        onTap: () => _push(const InfluencerRequestsPage()),
                        colors: colors,
                      ),
                    const SizedBox(height: 20),
                  ],

                  // ── Modules ────────────────────────────────────────────────
                  _SectionLabel('Modules', colors),
                  const SizedBox(height: 10),
                  _ModulesGrid(
                    pending: {
                      'official':    _officialPending,
                      'influencer':  _influencerPending,
                    },
                    colors: colors,
                    onTap: _push,
                  ),
                  const SizedBox(height: 20),

                  // ── Activité récente ───────────────────────────────────────
                  if (_recentEvents.isNotEmpty) ...[
                    _SectionLabel('Activité récente', colors),
                    const SizedBox(height: 10),
                    _RecentActivity(events: _recentEvents, colors: colors),
                  ],
                ],
              ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadStats());
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final dynamic me;
  final AppColors colors;

  const _AdminHeader({required this.me, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF534AB7), Color(0xFF185FA5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${me?.pseudo ?? 'Admin'}',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF534AB7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Administrateur',
                      style: TextStyle(
                          color: Color(0xFF534AB7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _greet(),
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              Text(
                _dateLabel(),
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bonne après-midi';
    return 'Bonsoir';
  }

  String _dateLabel() {
    final d = DateTime.now();
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${months[d.month - 1]}. ${d.year}';
  }
}

// ── AppData button ─────────────────────────────────────────────────────────────

class _AppDataButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AppDataButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A5E), Color(0xFF234E9C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF185FA5).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('AppData',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.3)),
                  SizedBox(height: 2),
                  Text('Statistiques globales & opérations',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats grid ─────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final int totalUsers, officialApproved, officialPending,
      influencerPending, transactionsMonth, newUsersToday;
  final AppColors colors;

  const _StatsGrid({
    required this.totalUsers,
    required this.officialApproved,
    required this.officialPending,
    required this.influencerPending,
    required this.transactionsMonth,
    required this.newUsersToday,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(
              label: 'Utilisateurs',
              value: _fmt(totalUsers),
              sub: '+$newUsersToday aujourd\'hui',
              subColor: const Color(0xFF0F6E56),
              icon: Icons.people_rounded,
              iconBg: const Color(0xFFE1F5EE),
              iconColor: const Color(0xFF0F6E56),
              colors: colors,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'Comptes officiels',
              value: _fmt(officialApproved),
              sub: '$officialPending en attente',
              subColor: officialPending > 0 ? const Color(0xFF854F0B) : colors.textSecondary,
              icon: Icons.verified_rounded,
              iconBg: const Color(0xFFE6F1FB),
              iconColor: const Color(0xFF185FA5),
              colors: colors,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(
              label: 'Influenceurs',
              value: _fmt(influencerPending),
              sub: 'demandes en attente',
              subColor: influencerPending > 0 ? const Color(0xFF854F0B) : colors.textSecondary,
              icon: Icons.star_rounded,
              iconBg: const Color(0xFFFAEEDA),
              iconColor: const Color(0xFFBA7517),
              colors: colors,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'Transactions',
              value: _fmt(transactionsMonth),
              sub: 'ce mois',
              subColor: colors.textSecondary,
              icon: Icons.receipt_long_rounded,
              iconBg: const Color(0xFFEEEDFE),
              iconColor: const Color(0xFF534AB7),
              colors: colors,
            )),
          ],
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor, iconBg, iconColor;
  final IconData icon;
  final AppColors colors;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Alertes ────────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final AppColors colors;

  const _AlertBanner({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 13),
          ],
        ),
      ),
    );
  }
}

// ── Modules grid ───────────────────────────────────────────────────────────────

class _ModulesGrid extends StatelessWidget {
  final Map<String, int> pending;
  final AppColors colors;
  final void Function(Widget) onTap;

  const _ModulesGrid({
    required this.pending,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem(
        icon: Icons.verified_rounded,
        label: 'Comptes officiels',
        desc: 'Valider et gérer les demandes',
        iconBg: const Color(0xFFE6F1FB),
        iconColor: const Color(0xFF185FA5),
        badge: pending['official'] ?? 0,
        page: const OfficialAccountsPage(),
      ),
      _ModuleItem(
        icon: Icons.star_rounded,
        label: 'Influenceurs',
        desc: 'Traiter les demandes de statut',
        iconBg: const Color(0xFFFAEEDA),
        iconColor: const Color(0xFFBA7517),
        badge: pending['influencer'] ?? 0,
        page: const InfluencerRequestsPage(),
      ),
      _ModuleItem(
        icon: Icons.campaign_rounded,
        label: 'Publicités',
        desc: 'Gérer les campagnes pub',
        iconBg: const Color(0xFFEEEDFE),
        iconColor: const Color(0xFF534AB7),
        page: AdvertisementManagementPage(),
      ),
      _ModuleItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Rémunération',
        desc: 'Suivi des paiements',
        iconBg: const Color(0xFFE1F5EE),
        iconColor: const Color(0xFF0F6E56),
        page: RemunerationAdminPage(),
      ),
      _ModuleItem(
        icon: Icons.emoji_events_rounded,
        label: 'Challenge',
        desc: 'Gérer les défis',
        iconBg: const Color(0xFFEAF3DE),
        iconColor: const Color(0xFF3B6D11),
        page: ChallengeDashboardPage(),
      ),
      _ModuleItem(
        icon: Icons.favorite_rounded,
        label: 'Afrolove',
        desc: 'Profils dating',
        iconBg: const Color(0xFFFBEAF0),
        iconColor: const Color(0xFF993556),
        page: AdminDatingProfilesPage(),
      ),
      _ModuleItem(
        icon: Icons.mail_rounded,
        label: 'Emailing',
        desc: 'Campagnes et push',
        iconBg: const Color(0xFFF1EFE8),
        iconColor: const Color(0xFF5F5E5A),
        page: AdminEmailScreen(),
      ),
      _ModuleItem(
        icon: Icons.sports_soccer_rounded,
        label: 'Pronostics',
        desc: 'Paris sportifs admin',
        iconBg: const Color(0xFFFCEBEB),
        iconColor: const Color(0xFFA32D2D),
        page: AdminPronosticsPage(),
      ),
      _ModuleItem(
        icon: Icons.groups_rounded,
        label: 'Groupe Afrolook',
        desc: 'Créer & migrer le groupe officiel',
        iconBg: const Color(0xFFE6F1FB),
        iconColor: Colors.blue,
        page: const AfrolookGroupMigrationPage(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleCard(
        item: modules[i],
        colors: colors,
        onTap: () => onTap(modules[i].page),
      ),
    );
  }
}

class _ModuleItem {
  final IconData icon;
  final String label, desc;
  final Color iconBg, iconColor;
  final int badge;
  final Widget page;

  const _ModuleItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.iconBg,
    required this.iconColor,
    this.badge = 0,
    required this.page,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  final AppColors colors;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.item,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 20),
                ),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${item.badge}',
                        style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
              ],
            ),
            const Spacer(),
            Text(item.label,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(item.desc,
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Activité récente ───────────────────────────────────────────────────────────

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
        border: Border.all(color: colors.border.withOpacity(0.3)),
      ),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          return Container(
            decoration: BoxDecoration(
              border: i < events.length - 1
                  ? Border(
                      bottom: BorderSide(
                          color: colors.border.withOpacity(0.2)))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _statusColor(e.status), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary),
                      children: [
                        TextSpan(
                          text: '@${e.pseudo} ',
                          style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: _statusLabel(e.status)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_timeAgo(e.timestamp),
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
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
        'underReview' => '— en cours d\'analyse',
        'moreInfoNeeded' => '— infos demandées',
        'suspended' => '— compte suspendu',
        _ => '— en attente de traitement',
      };

  String _timeAgo(int ts) {
    if (ts == 0) return '';
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }
}

class _RecentEvent {
  final String pseudo, status;
  final int timestamp;
  const _RecentEvent(
      {required this.pseudo, required this.status, required this.timestamp});
}

// ── Utilitaires ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8),
      );
}
