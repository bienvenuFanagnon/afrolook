import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/pages/contenuPayant/widgets/boost_modal.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({Key? key}) : super(key: key);

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    // Guard: admin only
    if (authProvider.loginUserData.role != UserRole.ADM.name) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé à l\'administration')),
      );
    }

    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Gestion contenus',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: colors.textSecondary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Contenus'),
            Tab(text: 'Commentaires'),
            Tab(text: 'Statistiques'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ContentsTab(colors: colors),
          _CommentsTab(colors: colors),
          _StatsTab(colors: colors),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Contenus
// ─────────────────────────────────────────────────────────────────────────────
class _ContentsTab extends StatefulWidget {
  final AppColors colors;
  const _ContentsTab({required this.colors});

  @override
  State<_ContentsTab> createState() => _ContentsTabState();
}

class _ContentsTabState extends State<_ContentsTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'all'; // all | boosted | free | reported

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Column(
      children: [
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Titre, ID créateur...',
                    hintStyle: TextStyle(
                        color: colors.textSecondary, fontSize: 12),
                    prefixIcon: Icon(Icons.search,
                        color: colors.textSecondary, size: 18),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
                colors: colors,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = snap.data!.docs
                  .map((d) => ContentPaie.fromJson(
                      {...d.data() as Map<String, dynamic>, 'id': d.id}))
                  .toList();

              if (_search.isNotEmpty) {
                items = items
                    .where((c) =>
                        c.title.toLowerCase().contains(_search) ||
                        c.ownerId.toLowerCase().contains(_search))
                    .toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Text('Aucun contenu',
                      style: TextStyle(color: colors.textSecondary)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: items.length,
                itemBuilder: (_, i) => _AdminContentTile(
                  content: items[i],
                  colors: colors,
                  onDeleted: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('ContentPaies');
    switch (_filter) {
      case 'boosted':
        q = q
            .where('isBoosted', isEqualTo: true)
            .orderBy('boostEndDate', descending: true);
        break;
      case 'free':
        q = q
            .where('isFree', isEqualTo: true)
            .orderBy('createdAt', descending: true);
        break;
      default:
        q = q.orderBy('createdAt', descending: true);
    }
    return q.limit(80);
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  final AppColors colors;

  const _FilterDropdown({
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary),
          dropdownColor: colors.surface,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'boosted', child: Text('Boostés')),
            DropdownMenuItem(value: 'free', child: Text('Gratuits')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _AdminContentTile extends StatelessWidget {
  final ContentPaie content;
  final AppColors colors;
  final VoidCallback onDeleted;

  const _AdminContentTile({
    required this.content,
    required this.colors,
    required this.onDeleted,
  });

  Future<void> _toggleBoost(BuildContext context) async {
    if (content.isBoostActive) {
      // Désactiver le boost
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(content.id)
          .update({
        'isBoosted': false,
        'boostEndDate': null,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boost désactivé')),
        );
      }
    } else {
      // Activer via modal admin
      if (context.mounted) {
        BoostModal.show(context, content, isAdmin: true);
      }
    }
  }

  Future<void> _deleteContent(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce contenu ?'),
        content: Text(
          '"${content.title}" sera supprimé définitivement.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || content.id == null) return;
    await FirebaseFirestore.instance
        .collection('ContentPaies')
        .doc(content.id)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenu supprimé')),
      );
    }
    onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final coverUrl = content.coverImages.isNotEmpty
        ? content.coverImages.first
        : content.thumbnailUrl;
    final cdnUrl = authProvider.convertToCdnUrl(
        coverUrl, authProvider.appDefaultData);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: content.isBoostActive
              ? const Color(0xFFFFD400).withOpacity(0.4)
              : colors.divider,
          width: content.isBoostActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ContentDetailPage(content: content))),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colors.background),
              clipBehavior: Clip.antiAlias,
              child: cdnUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cdnUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(_emoji(content.contentType),
                          style: const TextStyle(fontSize: 22))),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary),
                      ),
                    ),
                    _TypePill(type: content.contentType),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 11, color: colors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        content.ownerId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniStat(
                        icon: Icons.visibility_outlined,
                        value: _fmt(content.views),
                        colors: colors),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: Icons.shopping_cart_outlined,
                        value: _fmt(content.comments),
                        colors: colors),
                    const SizedBox(width: 8),
                    Text(
                      content.isFree
                          ? 'GRATUIT'
                          : '${content.effectivePrice.toInt()} F',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: content.isFree
                            ? const Color(0xFF25D366)
                            : const Color(0xFFFFD400),
                      ),
                    ),
                    if (content.isBoostActive) ...[
                      const SizedBox(width: 6),
                      const Text('⚡',
                          style: TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Actions
          Column(
            children: [
              _ActionBtn(
                icon: content.isBoostActive
                    ? Icons.bolt
                    : Icons.bolt_outlined,
                color: const Color(0xFFFFD400),
                tooltip:
                    content.isBoostActive ? 'Désactiver boost' : 'Booster',
                onTap: () => _toggleBoost(context),
              ),
              const SizedBox(height: 4),
              _ActionBtn(
                icon: Icons.delete_outline,
                color: Colors.red,
                tooltip: 'Supprimer',
                onTap: () => _deleteContent(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _emoji(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return '🎬';
      case ContentType.EBOOK: return '📘';
      case ContentType.FORMATION: return '🎓';
      case ContentType.TEMPLATE: return '🎨';
      case ContentType.PACK_ZIP: return '📦';
      case ContentType.AUDIO: return '🎵';
      case ContentType.PRESET: return '🎛️';
      case ContentType.BUNDLE: return '🗂️';
    }
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Commentaires
// ─────────────────────────────────────────────────────────────────────────────
class _CommentsTab extends StatelessWidget {
  final AppColors colors;
  const _CommentsTab({required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ContentComments')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('Aucun commentaire',
                style: TextStyle(color: colors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _AdminCommentTile(
              docId: docs[i].id,
              data: d,
              colors: colors,
            );
          },
        );
      },
    );
  }
}

class _AdminCommentTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final AppColors colors;

  const _AdminCommentTile({
    required this.docId,
    required this.data,
    required this.colors,
  });

  Future<void> _delete(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('ContentComments')
        .doc(docId)
        .delete();
    // Décrémenter le compteur
    final contentId = data['contentId'] as String?;
    if (contentId != null) {
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(contentId)
          .update({'comments': FieldValue.increment(-1)});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commentaire supprimé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pseudo = data['pseudo'] as String? ?? 'Anonyme';
    final text = data['text'] as String? ?? '';
    final ts = data['createdAt'] as int? ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF25D366).withOpacity(0.15),
            child: Text(
              pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF25D366)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pseudo,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          fontSize: 9, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ActionBtn(
            icon: Icons.delete_outline,
            color: Colors.red,
            tooltip: 'Supprimer',
            onTap: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Statistiques
// ─────────────────────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final AppColors colors;
  const _StatsTab({required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ContentPaies')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        final items = docs
            .map((d) => ContentPaie.fromJson(
                {...d.data() as Map<String, dynamic>, 'id': d.id}))
            .toList();

        final totalContents = items.length;
        final totalBoosted = items.where((c) => c.isBoostActive).length;
        final totalFree = items.where((c) => c.isFree).length;
        final totalViews = items.fold(0, (s, c) => s + c.views);
        final totalAffiliable =
            items.where((c) => c.affiliationEnabled).length;
        final totalFlash =
            items.where((c) => c.isFlashSaleActive).length;

        // Top 5 by views
        final top5 = [...items]
          ..sort((a, b) => b.views.compareTo(a.views));
        final top = top5.take(5).toList();

        // Répartition par type
        final byType = <ContentType, int>{};
        for (final c in items) {
          byType[c.contentType] = (byType[c.contentType] ?? 0) + 1;
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // KPI grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _KpiCard(
                    label: 'Contenus',
                    value: '$totalContents',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF4a90e2),
                    colors: colors),
                _KpiCard(
                    label: 'Vues totales',
                    value: _fmt(totalViews),
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF25D366),
                    colors: colors),
                _KpiCard(
                    label: 'Boostés actifs',
                    value: '$totalBoosted',
                    icon: Icons.bolt,
                    color: const Color(0xFFFFD400),
                    colors: colors),
                _KpiCard(
                    label: 'Gratuits',
                    value: '$totalFree',
                    icon: Icons.card_giftcard_outlined,
                    color: const Color(0xFF1abc9c),
                    colors: colors),
                _KpiCard(
                    label: 'En affiliation',
                    value: '$totalAffiliable',
                    icon: Icons.people_outline,
                    color: const Color(0xFF9b59b6),
                    colors: colors),
                _KpiCard(
                    label: 'Flash sales',
                    value: '$totalFlash',
                    icon: Icons.local_fire_department_outlined,
                    color: Colors.red,
                    colors: colors),
              ],
            ),
            const SizedBox(height: 18),

            // Répartition par type
            Text(
              'RÉPARTITION PAR TYPE',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...byType.entries
                .toList()
                .map((e) => _TypeBar(
                      type: e.key,
                      count: e.value,
                      total: totalContents,
                      colors: colors,
                    )),

            const SizedBox(height: 18),

            // Top 5
            Text(
              'TOP 5 — PLUS VUS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...top.asMap().entries.map((e) => _Top5Row(
                  rank: e.key + 1,
                  content: e.value,
                  colors: colors,
                )),
          ],
        );
      },
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AppColors colors;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 9, color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  final ContentType type;
  final int count;
  final int total;
  final AppColors colors;

  const _TypeBar({
    required this.type,
    required this.count,
    required this.total,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    final (label, color) = _info(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10, color: colors.textSecondary))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: colors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return ('Vidéo', const Color(0xFF4a90e2));
      case ContentType.EBOOK: return ('Ebook', const Color(0xFF9b59b6));
      case ContentType.FORMATION: return ('Formation', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE: return ('Template', const Color(0xFFe67e22));
      case ContentType.PACK_ZIP: return ('Pack ZIP', const Color(0xFF25D366));
      case ContentType.AUDIO: return ('Audio', const Color(0xFFe74c3c));
      case ContentType.PRESET: return ('Preset', const Color(0xFF1abc9c));
      case ContentType.BUNDLE: return ('Bundle', const Color(0xFF16a085));
    }
  }
}

class _Top5Row extends StatelessWidget {
  final int rank;
  final ContentPaie content;
  final AppColors colors;

  const _Top5Row({
    required this.rank,
    required this.content,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final rankColor =
        rank <= 3 ? medalColors[rank - 1] : colors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: rankColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
          ),
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 11, color: colors.textSecondary),
              const SizedBox(width: 3),
              Text(
                _fmt(content.views),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF25D366)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets partagés
// ─────────────────────────────────────────────────────────────────────────────
class _TypePill extends StatelessWidget {
  final ContentType type;
  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 8, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return ('VID', const Color(0xFF4a90e2));
      case ContentType.EBOOK: return ('BOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION: return ('FORM', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE: return ('TMPL', const Color(0xFFe67e22));
      case ContentType.PACK_ZIP: return ('PACK', const Color(0xFF25D366));
      case ContentType.AUDIO: return ('AUDIO', const Color(0xFFe74c3c));
      case ContentType.PRESET: return ('PRST', const Color(0xFF1abc9c));
      case ContentType.BUNDLE: return ('BNDL', const Color(0xFF16a085));
    }
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final AppColors colors;

  const _MiniStat(
      {required this.icon, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: colors.textSecondary),
        const SizedBox(width: 2),
        Text(value,
            style:
                TextStyle(fontSize: 10, color: colors.textSecondary)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}
