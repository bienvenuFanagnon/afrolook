import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class AffiliationMarketplacePage extends StatefulWidget {
  const AffiliationMarketplacePage({Key? key}) : super(key: key);

  @override
  State<AffiliationMarketplacePage> createState() =>
      _AffiliationMarketplacePageState();
}

class _AffiliationMarketplacePageState
    extends State<AffiliationMarketplacePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.loginUserData.id ?? '';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Gagner en affiliant',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF25D366),
          labelColor: const Color(0xFF25D366),
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'Marketplace'),
            Tab(text: 'Mes gains'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MarketplaceTab(uid: uid, colors: colors),
          _MyGainsTab(uid: uid, colors: colors),
        ],
      ),
    );
  }
}

class _MarketplaceTab extends StatelessWidget {
  final String uid;
  final AppColors colors;

  const _MarketplaceTab({required this.uid, required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ContentPaies')
          .where('affiliationEnabled', isEqualTo: true)
          .where('affiliationRate', isGreaterThan: 0)
          .orderBy('affiliationRate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!.docs
            .map((d) => ContentPaie.fromJson(
                {...d.data() as Map<String, dynamic>, 'id': d.id}))
            .toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💰', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Aucun contenu en affiliation pour l\'instant',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Revenez bientôt — les créateurs activent leurs produits',
                  style: TextStyle(
                      fontSize: 12, color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // KPIs affilié
            _MyAffiliateStats(uid: uid, colors: colors),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _AffiliateContentCard(
                  content: items[i],
                  uid: uid,
                  colors: colors,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyAffiliateStats extends StatelessWidget {
  final String uid;
  final AppColors colors;

  const _MyAffiliateStats({required this.uid, required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('AffiliateLinks')
          .where('affiliateId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        double total = 0;
        int sales = 0;
        int clicks = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m = d.data() as Map<String, dynamic>;
            total += (m['totalEarned'] as num?)?.toDouble() ?? 0;
            sales += (m['sales'] as int?) ?? 0;
            clicks += (m['clicks'] as int?) ?? 0;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: [
              _StatBox(
                  label: 'Gains totaux',
                  value: '${total.toInt()} F',
                  color: const Color(0xFF25D366),
                  colors: colors),
              const SizedBox(width: 8),
              _StatBox(
                  label: 'Ventes',
                  value: '$sales',
                  color: const Color(0xFF4a90e2),
                  colors: colors),
              const SizedBox(width: 8),
              _StatBox(
                  label: 'Clics',
                  value: '$clicks',
                  color: const Color(0xFFFFD400),
                  colors: colors),
            ],
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppColors colors;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AffiliateContentCard extends StatelessWidget {
  final ContentPaie content;
  final String uid;
  final AppColors colors;

  const _AffiliateContentCard({
    required this.content,
    required this.uid,
    required this.colors,
  });

  Future<bool> _isAlreadyAffiliated() async {
    if (content.id == null) return false;
    final snap = await FirebaseFirestore.instance
        .collection('AffiliateLinks')
        .where('affiliateId', isEqualTo: uid)
        .where('contentId', isEqualTo: content.id)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _affiliate(BuildContext context) async {
    if (content.id == null || uid.isEmpty) return;
    final already = await _isAlreadyAffiliated();
    if (!context.mounted) return;
    if (already) {
      _shareLink(context);
      return;
    }
    await FirebaseFirestore.instance.collection('AffiliateLinks').add({
      'affiliateId': uid,
      'contentId': content.id,
      'creatorId': content.ownerId,
      'contentTitle': content.title,
      'commissionRate': content.affiliationRate,
      'clicks': 0,
      'sales': 0,
      'totalEarned': 0.0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (context.mounted) _shareLink(context);
  }

  void _shareLink(BuildContext context) {
    final link =
        'https://afrolookmedia.com/share/contenu/${content.id}?ref=$uid';
    Share.share(
      '🛍️ ${content.title}\n\nDécouvre ce contenu sur Afrolook !\n$link',
      subject: content.title,
    );
  }

  String _commissionLabel() {
    final rate = content.affiliationRate;
    final amount = content.effectivePrice * rate;
    return '${(rate * 100).toInt()}% = ${amount.toInt()} F / vente';
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

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContentDetailPage(content: content))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colors.background,
              ),
              clipBehavior: Clip.antiAlias,
              child: cdnUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cdnUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(_emoji(content.contentType),
                          style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${content.effectivePrice.toInt()} F',
                    style: TextStyle(
                        fontSize: 11, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          size: 12, color: Color(0xFF25D366)),
                      const SizedBox(width: 3),
                      Text(
                        _commissionLabel(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF25D366)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _affiliate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF25D366).withOpacity(0.12),
                foregroundColor: const Color(0xFF25D366),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                      color: Color(0xFF25D366), width: 1),
                ),
              ),
              child: const Text('Affilier',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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
}

class _MyGainsTab extends StatelessWidget {
  final String uid;
  final AppColors colors;

  const _MyGainsTab({required this.uid, required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('AffiliateLinks')
          .where('affiliateId', isEqualTo: uid)
          .orderBy('totalEarned', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final links = snap.data!.docs
            .map((d) => AffiliateLink.fromJson(
                {...d.data() as Map<String, dynamic>, 'id': d.id}))
            .toList();

        if (links.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📊', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Aucune affiliation active',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 6),
                Text('Affiliez des contenus dans l\'onglet Marketplace',
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          );
        }

        double totalEarned =
            links.fold(0.0, (acc, l) => acc + l.totalEarned);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF25D366).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: Color(0xFF25D366), size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total gagné en affiliation',
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary)),
                        Text(
                          '${totalEarned.toInt()} F',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF25D366)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: links.length,
                itemBuilder: (_, i) => _GainItemCard(
                  link: links[i],
                  uid: uid,
                  colors: colors,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GainItemCard extends StatefulWidget {
  final AffiliateLink link;
  final String uid;
  final AppColors colors;

  const _GainItemCard(
      {required this.link, required this.uid, required this.colors});

  @override
  State<_GainItemCard> createState() => _GainItemCardState();
}

class _GainItemCardState extends State<_GainItemCard> {
  ContentPaie? _content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final doc = await FirebaseFirestore.instance
        .collection('ContentPaies')
        .doc(widget.link.contentId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _content =
          ContentPaie.fromJson({...doc.data()!, 'id': doc.id}));
    }
  }

  void _navigate() {
    if (_content == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContentDetailPage(content: _content!)));
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final colors = widget.colors;
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);

    String? coverUrl;
    if (_content != null) {
      final raw = _content!.coverImages.isNotEmpty
          ? _content!.coverImages.first
          : _content!.thumbnailUrl;
      coverUrl = authProvider.convertToCdnUrl(raw, authProvider.appDefaultData);
    }

    return GestureDetector(
      onTap: _navigate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          children: [
            // Miniature du contenu
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colors.background,
              ),
              clipBehavior: Clip.antiAlias,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl, fit: BoxFit.cover)
                  : Center(
                      child: Icon(Icons.image_outlined,
                          color: colors.textSecondary, size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.contentTitle ??
                        'Contenu #${link.contentId.length > 8 ? link.contentId.substring(0, 8) : link.contentId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniStat(
                          icon: Icons.touch_app_outlined,
                          value: '${link.clicks} clics',
                          colors: colors),
                      const SizedBox(width: 10),
                      _MiniStat(
                          icon: Icons.shopping_cart_outlined,
                          value: '${link.sales} ventes',
                          colors: colors),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${link.totalEarned.toInt()} F',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF25D366)),
                ),
                GestureDetector(
                  onTap: () {
                    final shareLink =
                        'https://afrolookmedia.com/share/contenu/${link.contentId}?ref=${widget.uid}';
                    Clipboard.setData(ClipboardData(text: shareLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lien copié !')));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4a90e2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF4a90e2)
                              .withOpacity(0.3)),
                    ),
                    child: const Text('Copier lien',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4a90e2),
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        Icon(icon, size: 12, color: colors.textSecondary),
        const SizedBox(width: 3),
        Text(value,
            style:
                TextStyle(fontSize: 10, color: colors.textSecondary)),
      ],
    );
  }
}
