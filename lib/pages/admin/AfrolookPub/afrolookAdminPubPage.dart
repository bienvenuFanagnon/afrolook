// afrolookAdminPubPage.dart — dashboard admin v2
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/chat/group/group_info_page.dart';
import 'package:afrotok/pages/chat/group/group_chat_page.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

class AdvertisementManagementPage extends StatefulWidget {
  const AdvertisementManagementPage({Key? key}) : super(key: key);

  @override
  State<AdvertisementManagementPage> createState() =>
      _AdvertisementManagementPageState();
}

class _AdvertisementManagementPageState
    extends State<AdvertisementManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserAuthProvider authProvider;
  late AppColors _colors;

  final TextEditingController _rejectionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'all';

  Advertisement? _selectedAd;
  Map<String, dynamic>? _selectedAdRaw;
  Map<String, dynamic>? _selectedAdPostData;

  // Stats
  int _totalAds = 0;
  int _pendingAds = 0;
  int _activeAds = 0;
  int _expiredAds = 0;
  int _rejectedAds = 0;
  int _cancelledAds = 0;
  int _totalViews = 0;
  int _totalClicks = 0;
  int _totalUniqueViews = 0;
  double _globalCTR = 0.0;
  int _totalRevenue = 0;
  bool _loadingStats = true;
  List<MapEntry<String, int>> _topAdsByViews = [];
  List<MapEntry<String, int>> _topAdsByClicks = [];
  Map<String, int> _dailyActivity = {};
  final Set<String> _autoFixedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
    if (authProvider.loginUserData.role != UserRole.ADM.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé aux administrateurs')),
        );
      });
    } else {
      _loadGlobalStats();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── DONNÉES ─────────────────────────────────────────────────────────────────

  Future<void> _loadGlobalStats() async {
    setState(() => _loadingStats = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('Advertisements').get();
      final now = DateTime.now().microsecondsSinceEpoch;

      int totalViews = 0, totalClicks = 0, totalUniqueViews = 0;
      int pending = 0, active = 0, expired = 0, rejected = 0, cancelled = 0;
      int revenue = 0;
      final Map<String, int> viewsByAd = {};
      final Map<String, int> clicksByAd = {};
      final Map<String, int> daily = {};
      final List<Future> fixes = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ad = Advertisement.fromJson(data);
        String status = data['status'] as String? ?? '';
        final endDate = data['endDate'] as int?;

        if (status == 'active' && endDate != null && endDate <= now) {
          status = 'expired';
          _autoFixedIds.add(doc.id);
          fixes.add(FirebaseFirestore.instance
              .collection('Advertisements')
              .doc(doc.id)
              .update({'status': 'expired', 'updatedAt': now}));
        }

        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'active':
            active++;
            break;
          case 'expired':
            expired++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }

        totalViews += ad.views ?? 0;
        totalClicks += ad.clicks ?? 0;
        totalUniqueViews += ad.uniqueViews ?? 0;
        if (status == 'active' || status == 'expired') {
          revenue += ad.pricePaid ?? 0;
        }
        if ((ad.views ?? 0) > 0) viewsByAd[ad.id!] = ad.views!;
        if ((ad.clicks ?? 0) > 0) clicksByAd[ad.id!] = ad.clicks!;
        ad.dailyStats?.forEach((d, v) => daily[d] = (daily[d] ?? 0) + v);
      }

      if (fixes.isNotEmpty) await Future.wait(fixes);

      final sortedViews = viewsByAd.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedClicks = clicksByAd.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _totalAds = snapshot.docs.length;
        _pendingAds = pending;
        _activeAds = active;
        _expiredAds = expired;
        _rejectedAds = rejected;
        _cancelledAds = cancelled;
        _totalViews = totalViews;
        _totalClicks = totalClicks;
        _totalUniqueViews = totalUniqueViews;
        _globalCTR =
            totalViews > 0 ? (totalClicks / totalViews) * 100 : 0.0;
        _totalRevenue = revenue;
        _topAdsByViews = sortedViews.take(5).toList();
        _topAdsByClicks = sortedClicks.take(5).toList();
        _dailyActivity = daily;
        _loadingStats = false;
      });
    } catch (e) {
      setState(() => _loadingStats = false);
    }
  }

  String _effectiveStatus(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';
    final endDate = data['endDate'] as int?;
    if (status == 'active' &&
        endDate != null &&
        endDate <= DateTime.now().microsecondsSinceEpoch) {
      return 'expired';
    }
    return status;
  }

  // ── ACTIONS ADMIN ────────────────────────────────────────────────────────────

  Future<void> _refundUser(Advertisement ad) async {
    if ((ad.pricePaid ?? 0) <= 0 || ad.createdBy == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(ad.createdBy)
          .update({'votre_solde_depot': FieldValue.increment(ad.pricePaid!.toDouble())});
      final tx = TransactionSolde()
        ..id =
            FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
        ..user_id = ad.createdBy
        ..type = TypeTransaction.GAIN.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = 'Remboursement publicité rejetée (ID: ${ad.id})'
        ..montant = ad.pricePaid!.toDouble()
        ..methode_paiement = 'remboursement'
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance
          .collection('TransactionSoldes')
          .doc(tx.id)
          .set(tx.toJson());
    } catch (_) {}
  }

  Future<void> _updateAdStatus(Advertisement ad, String newStatus,
      {String? reason}) async {
    try {
      if (newStatus == 'rejected' && ad.status == 'pending') {
        await _refundUser(ad);
      }
      await FirebaseFirestore.instance
          .collection('Advertisements')
          .doc(ad.id)
          .update({
        'status': newStatus,
        'rejectionReason': reason,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
      if (mounted) {
        final label = newStatus == 'active'
            ? 'activée'
            : newStatus == 'rejected'
                ? 'rejetée'
                : newStatus == 'pending'
                    ? 'remise en attente'
                    : 'annulée';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Publicité $label'),
          backgroundColor: _colors.primary,
        ));
        setState(() {
          _selectedAd = null;
          _selectedAdRaw = null;
          _selectedAdPostData = null;
        });
        _loadGlobalStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _colors.danger,
        ));
      }
    }
  }

  Future<void> _renewAd(Advertisement ad, int days) async {
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final newEndDate = ad.isExpired
          ? now + days * 24 * 60 * 60 * 1000000
          : (ad.endDate ?? now) + days * 24 * 60 * 60 * 1000000;
      await FirebaseFirestore.instance
          .collection('Advertisements')
          .doc(ad.id)
          .update({
        'endDate': newEndDate,
        'status': 'active',
        'renewalCount': FieldValue.increment(1),
        'updatedAt': now,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Publicité prolongée de $days jours'),
          backgroundColor: _colors.primary,
        ));
        _loadGlobalStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: _colors.danger,
        ));
      }
    }
  }

  Future<void> _deleteAd(Advertisement ad) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer cette publicité ?',
            style: TextStyle(
                color: _colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Action irréversible.',
            style: TextStyle(color: _colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('Advertisements')
                    .doc(ad.id)
                    .delete();
                if (ad.postId != null && ad.postId!.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('Posts')
                      .doc(ad.postId)
                      .delete();
                }
                if (mounted) {
                  setState(() {
                    _selectedAd = null;
                    _selectedAdRaw = null;
                    _selectedAdPostData = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Publicité supprimée'),
                    backgroundColor: _colors.primary,
                  ));
                  _loadGlobalStats();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: _colors.danger,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _colors.danger, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(Advertisement ad) {
    _rejectionController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber, color: _colors.danger, size: 22),
          const SizedBox(width: 10),
          Text('Rejeter la publicité',
              style: TextStyle(
                  color: _colors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Indiquez le motif (obligatoire)',
              style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _rejectionController,
            style: TextStyle(color: _colors.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Motif...',
              hintStyle: TextStyle(color: _colors.textSecondary),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: _colors.surfaceVariant,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'L\'utilisateur sera remboursé de ${ad.pricePaid ?? 0} FCFA.',
            style: TextStyle(color: _colors.warning, fontSize: 12),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionController.text.trim().isNotEmpty) {
                _updateAdStatus(ad, 'rejected',
                    reason: _rejectionController.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _colors.danger, foregroundColor: Colors.white),
            child: const Text('Rejeter et rembourser'),
          ),
        ],
      ),
    );
  }

  Future<void> _reactivateAd(Advertisement ad) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (ad.endDate != null && ad.endDate! > now) {
      await _updateAdStatus(ad, 'active');
    } else {
      _showRenewalDialog(ad);
    }
  }

  void _showRenewalDialog(Advertisement ad) {
    const extensionOptions = [7, 14, 30, 60, 90];
    int? selectedDays;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _colors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.update, color: _colors.accent, size: 22),
            const SizedBox(width: 10),
            Text('Prolonger la publicité',
                style: TextStyle(
                    color: _colors.textPrimary, fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Durée de prolongation (gratuit — admin)',
                style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extensionOptions.map((d) {
                final sel = selectedDays == d;
                return GestureDetector(
                  onTap: () => setD(() => selectedDays = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? _colors.accent.withOpacity(0.15)
                          : _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              sel ? _colors.accent : _colors.border,
                          width: sel ? 1.5 : 0.5),
                    ),
                    child: Text(
                      d == 7
                          ? '7 jours'
                          : d == 14
                              ? '14 jours'
                              : d == 30
                                  ? '1 mois'
                                  : d == 60
                                      ? '2 mois'
                                      : '3 mois',
                      style: TextStyle(
                          color: sel
                              ? _colors.accent
                              : _colors.textPrimary,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: TextStyle(color: _colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedDays != null
                  ? () {
                      Navigator.pop(ctx);
                      _renewAd(ad, selectedDays!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _colors.border),
              child: const Text('Prolonger'),
            ),
          ],
        ),
      ),
    );
  }

  // ── ÉDITEUR DE TARIFS ────────────────────────────────────────────────────────

  void _showTariffsEditor() async {
    final currentDurations = await AdConfigService.getDurations();
    final edited = currentDurations
        .map((d) =>
            AdDuration(weeks: d.weeks, price: d.price, label: d.label))
        .toList();
    final controllers = {
      for (final d in edited)
        d.weeks: TextEditingController(text: d.price.toString())
    };
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.price_change_outlined, color: _colors.accent, size: 22),
          const SizedBox(width: 10),
          Text('Tarifs publicités',
              style: TextStyle(
                  color: _colors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'Modifiez les tarifs (FCFA). Les changements s\'appliquent immédiatement.',
                style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            ...edited.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _colors.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.label,
                                  style: TextStyle(
                                      color: _colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text('${d.weeks} sem.',
                                  style: TextStyle(
                                      color: _colors.textSecondary,
                                      fontSize: 11)),
                            ]),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            right: 12, top: 4, bottom: 4),
                        child: TextField(
                          controller: controllers[d.weeks],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: TextStyle(
                              color: _colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            suffix: Text('FCFA',
                                style: TextStyle(
                                    color: _colors.textSecondary,
                                    fontSize: 11)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                            filled: true,
                            fillColor: _colors.surface,
                          ),
                          onChanged: (v) {
                            final idx = edited
                                .indexWhere((x) => x.weeks == d.weeks);
                            if (idx >= 0 && v.isNotEmpty) {
                              edited[idx] = AdDuration(
                                  weeks: d.weeks,
                                  price: int.tryParse(v) ?? d.price,
                                  label: d.label);
                            }
                          },
                        ),
                      ),
                    ),
                  ]),
                )),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(color: _colors.textSecondary)),
          ),
          StatefulBuilder(
            builder: (__, setSaving) {
              bool saving = false;
              return ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setSaving(() => saving = true);
                        final finalList = edited.map((d) {
                          final val =
                              int.tryParse(controllers[d.weeks]?.text ?? '') ??
                                  d.price;
                          return AdDuration(
                              weeks: d.weeks, price: val, label: d.label);
                        }).toList();
                        await AdConfigService.update(
                            finalList, authProvider.loginUserData.id ?? '');
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Tarifs mis à jour'),
                            backgroundColor: _colors.primary,
                          ));
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _colors.accent,
                    foregroundColor: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── NAVIGATION VERS L'ENTITÉ ─────────────────────────────────────────────────

  Future<void> _navigateToAdEntity(Advertisement ad) async {
    final id = ad.ownerId;
    try {
      switch (ad.ownerType) {
        case 'canal':
          if (id == null || id.isEmpty) return;
          final doc = await FirebaseFirestore.instance
              .collection('Canaux')
              .doc(id)
              .get();
          if (!doc.exists || !mounted) return;
          final canalData = Map<String, dynamic>.from(doc.data()!);
          canalData['id'] = doc.id;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      CanalDetails(canal: Canal.fromJson(canalData))));
          break;
        case 'group':
          if (id == null || id.isEmpty) return;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => GroupChatPage(
                      groupId: id,
                      groupName: ad.ownerName ?? 'Groupe',
                      groupImageUrl: ad.ownerAvatar ?? '')));
          break;
        case 'user':
          if (id == null || id.isEmpty) return;
          final doc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(id)
              .get();
          if (!doc.exists || !mounted) return;
          final userData = Map<String, dynamic>.from(doc.data()!);
          userData['id'] = doc.id;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      OtherUserPage(otherUser: UserData.fromJson(userData))));
          break;
        default:
          if (ad.postId == null || ad.postId!.isEmpty) return;
          final doc = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(ad.postId)
              .get();
          if (!doc.exists || !mounted) return;
          final postData = Map<String, dynamic>.from(doc.data()!);
          postData['id'] = doc.id;
          final post = Post.fromJson(postData);
          final dt = (postData['dataType'] as String? ?? '').toUpperCase();
          if (dt == 'VIDEO') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        VideoYoutubePageDetails(initialPost: post)));
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailsPost(post: post)));
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'ouvrir : $e'),
          backgroundColor: _colors.danger,
        ));
      }
    }
  }

  // ── HELPERS TYPE ─────────────────────────────────────────────────────────────

  String _adBoostType(Advertisement ad) {
    switch (ad.ownerType) {
      case 'canal':
        return 'canal';
      case 'group':
        return 'groupe';
      case 'user':
        return 'profil';
      default:
        return 'post';
    }
  }

  String _typeLabel(String type, {Map<String, dynamic>? postData}) {
    switch (type) {
      case 'canal':
        return 'Canal';
      case 'groupe':
        return 'Groupe';
      case 'profil':
        return 'Profil';
      default:
        if (postData != null) {
          final dt = (postData['dataType'] as String? ?? '').toUpperCase();
          if (dt == 'VIDEO') return 'Post · Vidéo';
          if (dt == 'AUDIO') return 'Post · Audio';
          if (dt == 'TEXT') return 'Post · Texte';
        }
        return 'Post';
    }
  }

  IconData _typeIcon(String type, {Map<String, dynamic>? postData}) {
    switch (type) {
      case 'canal':
        return Icons.wifi_tethering;
      case 'groupe':
        return Icons.groups_2_outlined;
      case 'profil':
        return Icons.person_outline;
      default:
        if (postData != null) {
          final dt = (postData['dataType'] as String? ?? '').toUpperCase();
          if (dt == 'VIDEO') return Icons.videocam_outlined;
          if (dt == 'AUDIO') return Icons.headphones_outlined;
        }
        return Icons.image_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'canal':
        return _colors.info;
      case 'groupe':
        return _colors.warning;
      case 'profil':
        return _colors.primary;
      default:
        return _colors.accent;
    }
  }

  bool _matchesFilter(Advertisement ad) =>
      _typeFilter == 'all' || _adBoostType(ad) == _typeFilter;

  bool _matchesSearch(Advertisement ad) {
    if (_searchQuery.isEmpty) return true;
    return (ad.ownerName ?? '').toLowerCase().contains(_searchQuery) ||
        (ad.id ?? '').toLowerCase().contains(_searchQuery) ||
        (ad.createdBy ?? '').toLowerCase().contains(_searchQuery);
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'En attente';
      case 'expired':
        return 'Expirée';
      case 'rejected':
        return 'Rejetée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  // ── KPI ROW ──────────────────────────────────────────────────────────────────

  Widget _buildKpiRow() {
    if (_loadingStats) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(children: [
        _kpiCard(Icons.hourglass_empty, 'En attente', '$_pendingAds',
            _colors.warning,
            highlight: _pendingAds > 0),
        const SizedBox(width: 8),
        _kpiCard(Icons.check_circle_outline, 'Actives', '$_activeAds',
            _colors.primary),
        const SizedBox(width: 8),
        _kpiCard(Icons.remove_red_eye_outlined, 'Vues',
            _formatNumber(_totalViews), _colors.info),
        const SizedBox(width: 8),
        _kpiCard(Icons.monetization_on_outlined, 'Revenus',
            '${_formatNumber(_totalRevenue)} F', _colors.accent),
      ]),
    );
  }

  Widget _kpiCard(IconData icon, String label, String value, Color color,
      {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: highlight ? color.withOpacity(0.6) : _colors.border,
              width: highlight ? 1.5 : 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: _colors.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: highlight ? color : _colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // ── SEARCH TOOLBAR ───────────────────────────────────────────────────────────

  Widget _buildSearchToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: _colors.surface,
        border: Border(bottom: BorderSide(color: _colors.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _colors.border, width: 0.5),
          ),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.search, color: _colors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: _colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, ID…',
                  hintStyle: TextStyle(
                      color: _colors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.close,
                      color: _colors.textSecondary, size: 16),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('all', 'Tous', Icons.grid_view),
            const SizedBox(width: 6),
            _filterChip('post', 'Post', Icons.image_outlined),
            const SizedBox(width: 6),
            _filterChip('canal', 'Canal', Icons.wifi_tethering),
            const SizedBox(width: 6),
            _filterChip('profil', 'Profil', Icons.person_outline),
            const SizedBox(width: 6),
            _filterChip('groupe', 'Groupe', Icons.groups_2_outlined),
          ]),
        ),
      ]),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final isSelected = _typeFilter == value;
    final color = value == 'all'
        ? _colors.textPrimary
        : value == 'post'
            ? _colors.accent
            : value == 'canal'
                ? _colors.info
                : value == 'profil'
                    ? _colors.primary
                    : _colors.warning;
    return GestureDetector(
      onTap: () => setState(() {
        _typeFilter = value;
        _selectedAd = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.12)
              : _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : _colors.border,
              width: isSelected ? 1.5 : 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: isSelected ? color : _colors.textSecondary),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? color : _colors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ]),
      ),
    );
  }

  // ── TABLE HEADER ─────────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    final s = TextStyle(
        fontSize: 10,
        color: _colors.textSecondary,
        fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        border: Border(bottom: BorderSide(color: _colors.border, width: 0.5)),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        SizedBox(width: 58, child: Text('Type', style: s)),
        Expanded(child: Text('Entité', style: s)),
        SizedBox(width: 68, child: Text('Statut', style: s)),
        SizedBox(width: 44, child: Text('Date', style: s)),
        const SizedBox(width: 20),
      ]),
    );
  }

  // ── TABLE ROW ────────────────────────────────────────────────────────────────

  Widget _buildTableRowWithPost(DocumentSnapshot doc) {
    final adData = doc.data() as Map<String, dynamic>;
    final ad = Advertisement.fromJson(adData);
    final wasAutoFixed = _autoFixedIds.contains(ad.id) ||
        (_effectiveStatus(adData) == 'expired' &&
            adData['status'] == 'active');

    if (ad.postId == null || ad.postId!.isEmpty) {
      return _buildTableRow(ad, adData, null, wasAutoFixed);
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Posts')
          .doc(ad.postId)
          .get(),
      builder: (context, snap) {
        final postData = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : null;
        return _buildTableRow(ad, adData, postData, wasAutoFixed);
      },
    );
  }

  Widget _buildTableRow(Advertisement ad, Map<String, dynamic> adRaw,
      Map<String, dynamic>? postData, bool wasAutoFixed) {
    if (!_matchesFilter(ad) || !_matchesSearch(ad)) {
      return const SizedBox.shrink();
    }

    final effectiveStatus = wasAutoFixed ? 'expired' : (ad.status ?? '');
    final type = _adBoostType(ad);
    final typeColor = _typeColor(type);
    final isSelected = _selectedAd?.id == ad.id;

    final createdFmt = ad.createdAt != null
        ? DateFormat('dd/MM/yy').format(
            DateTime.fromMicrosecondsSinceEpoch(ad.createdAt!))
        : '—';

    return GestureDetector(
      onTap: () => _showAdModal(ad, adRaw, postData),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _colors.border, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          // dot
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 3),
            decoration:
                BoxDecoration(color: typeColor, shape: BoxShape.circle),
          ),
          // Type
          SizedBox(
            width: 58,
            child: Row(children: [
              Icon(_typeIcon(type, postData: postData),
                  size: 12, color: typeColor),
              const SizedBox(width: 3),
              Flexible(
                  child: Text(
                      _typeLabel(type, postData: postData),
                      style: TextStyle(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
          // Entité
          Expanded(
            child: Row(children: [
              _buildEntityAvatar(ad, type, postData),
              const SizedBox(width: 6),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                      ad.ownerName ??
                          (postData?['description'] as String? ?? 'Post')
                              .split('\n')
                              .first,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((ad.ownerFollowers ?? 0) > 0)
                      Text(
                          '${_formatNumber(ad.ownerFollowers!)} abonn.',
                          style: TextStyle(
                              fontSize: 10,
                              color: _colors.textSecondary))
                    else if (ad.createdBy != null)
                      Text(
                          '${ad.createdBy!.substring(0, ad.createdBy!.length.clamp(0, 8))}…',
                          style: TextStyle(
                              fontSize: 10,
                              color: _colors.textSecondary)),
                  ])),
            ]),
          ),
          // Statut
          SizedBox(
            width: 68,
            child: _buildStatusBadge(effectiveStatus),
          ),
          // Date
          SizedBox(
            width: 44,
            child: Text(createdFmt,
                style: TextStyle(
                    fontSize: 10,
                    color: _colors.textSecondary,
                    fontFamily: 'monospace')),
          ),
          // Chevron
          Icon(Icons.chevron_right, size: 16, color: _colors.textSecondary),
        ]),
      ),
    );
  }

  // ── MODAL DÉTAIL + ACTIONS ───────────────────────────────────────────────────

  void _showAdModal(Advertisement ad, Map<String, dynamic> adRaw,
      Map<String, dynamic>? postData) {
    final type = _adBoostType(ad);
    final typeColor = _typeColor(type);
    final effectiveStatus = _effectiveStatus(adRaw);
    final countries = (adRaw['availableCountries'] as List?)?.cast<String>() ?? [];
    final description = adRaw['description'] as String? ?? ad.ownerDescription ?? '';
    final now = DateTime.now().microsecondsSinceEpoch;
    final totalDays = ad.durationDays ?? 1;
    final remaining = ad.endDate != null
        ? ((ad.endDate! - now) / (24 * 60 * 60 * 1000000)).ceil()
        : 0;
    final progress = totalDays > 0
        ? ((totalDays - (remaining > 0 ? remaining : 0)).clamp(0, totalDays) / totalDays)
            .clamp(0.0, 1.0)
        : 1.0;
    final adCtr = (ad.views ?? 0) > 0
        ? ((ad.clicks ?? 0) / (ad.views ?? 1)) * 100
        : 0.0;
    final followersLabel = type == 'groupe' ? 'membres' : 'abonnés';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: typeColor.withOpacity(0.4), width: 2)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _colors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Header : avatar + nom + badges
              Row(children: [
                // Avatar large
                ClipRRect(
                  borderRadius: BorderRadius.circular(type == 'canal' || type == 'groupe' ? 10 : 24),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ad.ownerAvatar?.isNotEmpty == true
                        ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: typeColor.withOpacity(0.15),
                                child: Icon(_typeIcon(type, postData: postData), size: 22, color: typeColor)))
                        : Container(color: typeColor.withOpacity(0.15),
                            child: Icon(_typeIcon(type, postData: postData), size: 22, color: typeColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    ad.ownerName ?? (postData?['description'] as String? ?? 'Publicité').split('\n').first,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _colors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_typeIcon(type, postData: postData), size: 10, color: typeColor),
                        const SizedBox(width: 3),
                        Text(_typeLabel(type, postData: postData),
                            style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(effectiveStatus),
                  ]),
                  if ((ad.ownerFollowers ?? 0) > 0) ...[
                    const SizedBox(height: 3),
                    Text('${_formatNumber(ad.ownerFollowers!)} $followersLabel',
                        style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
                  ],
                ])),
                // Prix
                if (ad.pricePaid != null && ad.pricePaid! > 0)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_formatNumber(ad.pricePaid!)} FCFA',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _colors.accent)),
                    Text('${ad.durationDays ?? 0} jours',
                        style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
                  ]),
              ]),
              const SizedBox(height: 16),

              // Barre de progression
              if (ad.startDate != null || ad.endDate != null) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                      ad.startDate != null
                          ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!))
                          : '—',
                      style: TextStyle(fontSize: 10, color: _colors.textSecondary)),
                  Text(remaining > 0 ? '$remaining j restants' : 'Terminé',
                      style: TextStyle(fontSize: 10, color: _colors.textSecondary, fontWeight: FontWeight.w500)),
                  Text(
                      ad.endDate != null
                          ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!))
                          : '—',
                      style: TextStyle(fontSize: 10, color: _colors.textSecondary)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _colors.border,
                      valueColor: AlwaysStoppedAnimation(typeColor)),
                ),
                const SizedBox(height: 14),
              ],

              // Stats tiles
              Row(children: [
                _modalStatTile(_formatNumber(ad.views ?? 0), 'Vues', _colors.info),
                const SizedBox(width: 8),
                _modalStatTile(_formatNumber(ad.clicks ?? 0), 'Clics', _colors.warning),
                const SizedBox(width: 8),
                _modalStatTile('${adCtr.toStringAsFixed(1)}%', 'CTR',
                    adCtr > 5 ? _colors.primary : _colors.warning),
                const SizedBox(width: 8),
                _modalStatTile(_formatNumber(ad.uniqueViews ?? 0), 'Uniques', _colors.accent),
              ]),
              const SizedBox(height: 14),

              // Pays
              if (countries.isNotEmpty && !countries.contains('ALL')) ...[
                Text('Pays ciblés', style: TextStyle(fontSize: 11, color: _colors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...countries.take(8).map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: _colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _colors.border, width: 0.5)),
                          child: Text(c, style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
                        )),
                    if (countries.length > 8)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('+${countries.length - 8}',
                            style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else if (countries.contains('ALL')) ...[
                Row(children: [
                  Icon(Icons.public, size: 14, color: _colors.textSecondary),
                  const SizedBox(width: 5),
                  Text('Tous les pays', style: TextStyle(fontSize: 11, color: _colors.textSecondary)),
                ]),
                const SizedBox(height: 14),
              ],

              // Description
              if (description.isNotEmpty) ...[
                Text('Description', style: TextStyle(fontSize: 11, color: _colors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(description,
                    style: TextStyle(fontSize: 13, color: _colors.textPrimary, height: 1.5),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 14),
              ],

              // Motif de rejet
              if (ad.rejectionReason?.isNotEmpty == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _colors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colors.danger.withOpacity(0.3), width: 0.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Motif du rejet',
                        style: TextStyle(fontSize: 10, color: _colors.danger, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(ad.rejectionReason!,
                        style: TextStyle(fontSize: 12, color: _colors.danger)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              Divider(height: 1, color: _colors.border),
              const SizedBox(height: 14),

              // Boutons d'action
              if (effectiveStatus == 'pending') ...[
                Row(children: [
                  Expanded(child: _modalActionBtn('Accepter', _colors.primary, Icons.check, () {
                    Navigator.pop(ctx); _updateAdStatus(ad, 'active');
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _modalActionBtn('Rejeter', _colors.danger, Icons.close, () {
                    Navigator.pop(ctx); _showRejectionDialog(ad);
                  })),
                ]),
              ] else if (effectiveStatus == 'active') ...[
                Row(children: [
                  Expanded(child: _modalActionBtn('Annuler', _colors.danger, Icons.block_outlined, () {
                    Navigator.pop(ctx); _updateAdStatus(ad, 'cancelled');
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _modalActionBtn('Prolonger', _colors.accent, Icons.update, () {
                    Navigator.pop(ctx); _showRenewalDialog(ad);
                  })),
                ]),
              ] else if (effectiveStatus == 'expired' || effectiveStatus == 'cancelled') ...[
                Row(children: [
                  Expanded(child: _modalActionBtn('Réactiver', _colors.primary, Icons.play_circle_outline, () {
                    Navigator.pop(ctx); _reactivateAd(ad);
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _modalActionBtn('Prolonger', _colors.accent, Icons.update, () {
                    Navigator.pop(ctx); _showRenewalDialog(ad);
                  })),
                ]),
              ] else ...[
                _modalActionBtn('Remettre en attente', _colors.warning, Icons.refresh, () {
                  Navigator.pop(ctx); _updateAdStatus(ad, 'pending');
                }),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _modalActionBtn('Supprimer', _colors.textSecondary, Icons.delete_outline, () {
                  Navigator.pop(ctx); _deleteAd(ad);
                }, outlined: true)),
                const SizedBox(width: 10),
                Expanded(child: _modalActionBtn(
                  'Voir ${_typeLabel(type, postData: postData).split(' ·').first}',
                  typeColor,
                  Icons.open_in_new,
                  () { Navigator.pop(ctx); _navigateToAdEntity(ad); },
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _modalStatTile(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colors.border, width: 0.5)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _colors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 10, color: _colors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _modalActionBtn(String label, Color color, IconData icon, VoidCallback onTap, {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outlined ? _colors.border : color.withOpacity(0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildEntityAvatar(Advertisement ad, String type,
      Map<String, dynamic>? postData) {
    final color = _typeColor(type);
    final icon = _typeIcon(type, postData: postData);
    final radius = (type == 'canal' || type == 'groupe') ? 6.0 : 14.0;

    if (ad.ownerAvatar?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CachedNetworkImage(
            imageUrl: ad.ownerAvatar!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                _avatarFallback(icon, color, radius),
          ),
        ),
      );
    }
    if (type == 'post' && postData != null) {
      final thumb = postData['thumbnail'] as String? ??
          (postData['images'] as List?)?.firstOrNull as String?;
      if (thumb?.isNotEmpty == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CachedNetworkImage(
              imageUrl: thumb!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  _avatarFallback(icon, color, 6),
            ),
          ),
        );
      }
    }
    return _avatarFallback(icon, color, radius);
  }

  Widget _avatarFallback(IconData icon, Color color, double radius) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    switch (status) {
      case 'active':
        bg = _colors.primary.withOpacity(0.12);
        fg = _colors.primary;
        break;
      case 'pending':
        bg = _colors.warning.withOpacity(0.12);
        fg = _colors.warning;
        break;
      case 'rejected':
        bg = _colors.danger.withOpacity(0.12);
        fg = _colors.danger;
        break;
      case 'cancelled':
        bg = _colors.info.withOpacity(0.12);
        fg = _colors.info;
        break;
      default:
        bg = _colors.border;
        fg = _colors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabel(status),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // (detail panel moved to _showAdModal)

  Widget _buildDetailPanel_UNUSED() {
    final ad = _selectedAd!;
    final adRaw = _selectedAdRaw!;
    final postData = _selectedAdPostData;
    final type = _adBoostType(ad);
    final typeColor = _typeColor(type);
    final effectiveStatus = _effectiveStatus(adRaw);

    final countries =
        (adRaw['availableCountries'] as List?)?.cast<String>() ?? [];
    final description = adRaw['description'] as String? ??
        ad.ownerDescription ??
        '';
    final now = DateTime.now().microsecondsSinceEpoch;
    final totalDays = ad.durationDays ?? 1;
    final remaining = ad.endDate != null
        ? ((ad.endDate! - now) / (24 * 60 * 60 * 1000000)).ceil()
        : 0;
    final used =
        (totalDays - (remaining > 0 ? remaining : 0)).clamp(0, totalDays);
    final progress =
        totalDays > 0 ? (used / totalDays).clamp(0.0, 1.0) : 1.0;
    final adCtr = (ad.views ?? 0) > 0
        ? ((ad.clicks ?? 0) / (ad.views ?? 1)) * 100
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _colors.surface,
        border: Border(
            top: BorderSide(color: typeColor.withOpacity(0.5), width: 2)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête du panneau
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: typeColor, shape: BoxShape.circle)),
                Expanded(
                    child: Text(
                        ad.ownerName ??
                            (postData?['description'] as String?)
                                ?.split('\n')
                                .first ??
                            'Publicité',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _colors.textPrimary),
                        overflow: TextOverflow.ellipsis)),
                Text(
                    '#${(ad.id ?? '').substring(0, (ad.id?.length ?? 0).clamp(0, 7)).toUpperCase()}',
                    style: TextStyle(
                        fontSize: 10,
                        color: _colors.textSecondary,
                        fontFamily: 'monospace')),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedAd = null;
                    _selectedAdRaw = null;
                    _selectedAdPostData = null;
                  }),
                  child: Icon(Icons.close,
                      size: 18, color: _colors.textSecondary),
                ),
              ]),
            ),
            Divider(height: 0.5, thickness: 0.5, color: _colors.border),

            // Corps — 3 colonnes
            IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Col 1 — Info + Progression
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dpSectionTitle('Informations'),
                            _dpRow('Type',
                                _typeLabel(type, postData: postData)),
                            _dpRow('Durée',
                                '${ad.durationDays ?? 0} jours'),
                            _dpRow('Prix payé',
                                ad.pricePaid != null
                                    ? '${ad.pricePaid} FCFA'
                                    : '—',
                                highlight: true),
                            _dpRow('CTA', ad.actionButtonText ?? '—'),
                            _dpRow(
                                'Statut', _statusLabel(effectiveStatus)),
                            if (ad.rejectionReason?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color:
                                        _colors.danger.withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: Text(
                                    'Rejet : ${ad.rejectionReason}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: _colors.danger)),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _dpSectionTitle('Progression'),
                            const SizedBox(height: 5),
                            Row(children: [
                              Text(
                                  ad.startDate != null
                                      ? DateFormat('dd/MM').format(
                                          DateTime
                                              .fromMicrosecondsSinceEpoch(
                                              ad.startDate!))
                                      : '—',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: _colors.textSecondary)),
                              const Spacer(),
                              Text(
                                  remaining > 0
                                      ? '$remaining j rest.'
                                      : 'Terminé',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: _colors.textSecondary)),
                              const Spacer(),
                              Text(
                                  ad.endDate != null
                                      ? DateFormat('dd/MM').format(
                                          DateTime
                                              .fromMicrosecondsSinceEpoch(
                                              ad.endDate!))
                                      : '—',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: _colors.textSecondary)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: _colors.border,
                                valueColor:
                                    AlwaysStoppedAnimation(typeColor),
                              ),
                            ),
                          ]),
                    )),
                    VerticalDivider(
                        width: 0.5,
                        thickness: 0.5,
                        color: _colors.border),

                    // Col 2 — Performances
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dpSectionTitle('Performances'),
                            const SizedBox(height: 8),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 1.8,
                              children: [
                                _statTile(
                                    _formatNumber(ad.views ?? 0),
                                    'Vues',
                                    _colors.info),
                                _statTile(
                                    _formatNumber(ad.clicks ?? 0),
                                    'Clics',
                                    _colors.warning),
                                _statTile(
                                    '${adCtr.toStringAsFixed(1)}%',
                                    'CTR',
                                    adCtr > 5
                                        ? _colors.primary
                                        : _colors.warning),
                                _statTile(
                                    _formatNumber(
                                        ad.uniqueViews ?? 0),
                                    'Uniques',
                                    _colors.accent),
                              ],
                            ),
                            if ((ad.renewalCount ?? 0) > 0) ...[
                              const SizedBox(height: 8),
                              Text('${ad.renewalCount}× renouvelé',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _colors.textSecondary)),
                            ],
                          ]),
                    )),
                    VerticalDivider(
                        width: 0.5,
                        thickness: 0.5,
                        color: _colors.border),

                    // Col 3 — Pays + Description
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dpSectionTitle('Pays ciblés'),
                            const SizedBox(height: 6),
                            if (countries.isEmpty ||
                                countries.contains('ALL'))
                              Text('Tous les pays',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _colors.textSecondary))
                            else
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  ...countries.take(6).map((c) =>
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                            color: _colors.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: _colors.border,
                                                width: 0.5)),
                                        child: Text(c,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    _colors.textSecondary)),
                                      )),
                                  if (countries.length > 6)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: _colors.accent
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Text(
                                          '+${countries.length - 6}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: _colors.accent,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                ],
                              ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _dpSectionTitle('Description'),
                              const SizedBox(height: 4),
                              Text(description,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _colors.textSecondary,
                                      height: 1.5),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ]),
                    )),
                  ]),
            ),
            Divider(height: 0.5, thickness: 0.5, color: _colors.border),

            // Barre d'actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                if (effectiveStatus == 'pending') ...[
                  _dpBtn('Accepter', _colors.primary, Icons.check,
                      () => _updateAdStatus(ad, 'active')),
                  const SizedBox(width: 8),
                  _dpBtn('Rejeter', _colors.danger, Icons.close,
                      () => _showRejectionDialog(ad)),
                ] else if (effectiveStatus == 'active') ...[
                  _dpBtn('Annuler', _colors.danger, Icons.block_outlined,
                      () => _updateAdStatus(ad, 'cancelled')),
                  const SizedBox(width: 8),
                  _dpBtn('Prolonger', _colors.accent, Icons.update,
                      () => _showRenewalDialog(ad)),
                ] else if (effectiveStatus == 'expired' ||
                    effectiveStatus == 'cancelled') ...[
                  _dpBtn('Réactiver', _colors.primary,
                      Icons.play_circle_outline,
                      () => _reactivateAd(ad)),
                  const SizedBox(width: 8),
                  _dpBtn('Prolonger', _colors.accent, Icons.update,
                      () => _showRenewalDialog(ad)),
                ] else ...[
                  _dpBtn('Remettre en attente', _colors.warning,
                      Icons.refresh,
                      () => _updateAdStatus(ad, 'pending')),
                ],
                const SizedBox(width: 8),
                _dpBtn('Supprimer', _colors.textSecondary,
                    Icons.delete_outline, () => _deleteAd(ad),
                    outlined: true),
                const Spacer(),
                GestureDetector(
                  onTap: () => _navigateToAdEntity(ad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: typeColor.withOpacity(0.3), width: 0.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_new, size: 13, color: typeColor),
                      const SizedBox(width: 5),
                      Text(
                          'Voir ${_typeLabel(type, postData: postData).split(' ·').first}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: typeColor)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
    );
  }

  Widget _dpSectionTitle(String title) => Text(title,
      style: TextStyle(
          fontSize: 10,
          color: _colors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.05));

  Widget _dpRow(String label, String value, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: _colors.textSecondary)),
              Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: highlight
                          ? _colors.accent
                          : _colors.textPrimary)),
            ]),
      );

  Widget _statTile(String value, String label, Color color) => Container(
        decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _colors.border, width: 0.5)),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _colors.textPrimary)),
              Text(label,
                  style: TextStyle(
                      fontSize: 9, color: _colors.textSecondary)),
            ]),
      );

  Widget _dpBtn(String label, Color color, IconData icon, VoidCallback onTap,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: outlined ? _colors.border : color.withOpacity(0.4),
              width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ]),
      ),
    );
  }

  // ── TABLE STREAM LIST ────────────────────────────────────────────────────────

  Widget _buildTableStreamList(String status) {
    return Column(children: [
      _buildSearchToolbar(),
      _buildTableHeader(),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Advertisements')
              .where('status', isEqualTo: status)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erreur : ${snapshot.error}',
                      style: TextStyle(color: _colors.danger)));
            }
            if (!snapshot.hasData) {
              return Center(
                  child: LoadingAnimationWidget.flickr(
                      size: 40,
                      leftDotColor: _colors.primary,
                      rightDotColor: _colors.accent));
            }

            final allDocs = snapshot.data!.docs;
            final docs = status == 'active'
                ? allDocs
                    .where((doc) =>
                        _effectiveStatus(
                            doc.data() as Map<String, dynamic>) ==
                        'active')
                    .toList()
                : allDocs;

            if (docs.isEmpty) {
              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.campaign_outlined,
                        size: 48, color: _colors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                        'Aucune publicité ${_statusLabel(status).toLowerCase()}',
                        style: TextStyle(
                            color: _colors.textSecondary, fontSize: 14)),
                  ]));
            }

            return RefreshIndicator(
              onRefresh: _loadGlobalStats,
              color: _colors.primary,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                itemBuilder: (_, i) =>
                    _buildTableRowWithPost(docs[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── STATS TAB ────────────────────────────────────────────────────────────────

  Widget _buildMetricCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border, width: 0.5),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: _colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style:
                TextStyle(color: _colors.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildStatsTab() {
    if (_loadingStats) {
      return Center(
          child: LoadingAnimationWidget.flickr(
              size: 48,
              leftDotColor: _colors.primary,
              rightDotColor: _colors.accent));
    }
    return RefreshIndicator(
      onRefresh: _loadGlobalStats,
      color: _colors.primary,
      child: CenteredContent(
          child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Publicités',
                  style: TextStyle(
                      color: _colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  _buildMetricCard(Iconsax.dollar_circle, 'Total',
                      '$_totalAds', _colors.textSecondary),
                  _buildMetricCard(Icons.hourglass_empty, 'En attente',
                      '$_pendingAds', _colors.warning),
                  _buildMetricCard(Icons.check_circle, 'Actives',
                      '$_activeAds', _colors.primary),
                  _buildMetricCard(Icons.timer_off, 'Expirées',
                      '$_expiredAds', _colors.textSecondary),
                  _buildMetricCard(Icons.cancel, 'Rejetées',
                      '$_rejectedAds', _colors.danger),
                  _buildMetricCard(Icons.block, 'Annulées',
                      '$_cancelledAds', _colors.info),
                ],
              ),
              const SizedBox(height: 16),
              Text('Performances',
                  style: TextStyle(
                      color: _colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  _buildMetricCard(Icons.remove_red_eye, 'Vues totales',
                      _formatNumber(_totalViews), _colors.info),
                  _buildMetricCard(Icons.ads_click, 'Clics totaux',
                      _formatNumber(_totalClicks), _colors.warning),
                  _buildMetricCard(Icons.person_outline, 'Vues uniques',
                      _formatNumber(_totalUniqueViews), _colors.accent),
                  _buildMetricCard(
                      Icons.trending_up,
                      'CTR global',
                      '${_globalCTR.toStringAsFixed(1)}%',
                      _globalCTR > 5 ? _colors.primary : _colors.warning),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _colors.border, width: 0.5)),
                child: Row(children: [
                  Icon(Icons.monetization_on,
                      color: _colors.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Revenus totaux',
                            style: TextStyle(
                                color: _colors.textSecondary,
                                fontSize: 12)),
                        Text('${_formatNumber(_totalRevenue)} FCFA',
                            style: TextStyle(
                                color: _colors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ])),
                  Text('Actives + expirées',
                      style: TextStyle(
                          color: _colors.textSecondary, fontSize: 11)),
                ]),
              ),
              if (_topAdsByViews.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Top 5 — Vues',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                _buildRankingCard(_topAdsByViews, _colors.info, 'vues'),
              ],
              if (_topAdsByClicks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Top 5 — Clics',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                _buildRankingCard(
                    _topAdsByClicks, _colors.warning, 'clics'),
              ],
              if (_dailyActivity.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Activité récente',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                _buildActivityBars(),
              ],
              const SizedBox(height: 20),
            ]),
      )),
    );
  }

  Widget _buildRankingCard(
      List<MapEntry<String, int>> data, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colors.border, width: 0.5)),
      child: Column(
          children: data.asMap().entries.map((e) {
        final rank = e.key + 1;
        final entry = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: rank <= 3
                      ? color.withOpacity(0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle),
              child: Center(
                  child: Text('$rank',
                      style: TextStyle(
                          color: rank <= 3
                              ? color
                              : _colors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12))),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    'ID: ${entry.key.substring(0, 8).toUpperCase()}…',
                    style: TextStyle(
                        color: _colors.textPrimary, fontSize: 12))),
            Text('${_formatNumber(entry.value)} $unit',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ]),
        );
      }).toList()),
    );
  }

  Widget _buildActivityBars() {
    final sorted = _dailyActivity.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final last7 = sorted.take(7).toList();
    final maxVal = last7.isEmpty
        ? 1
        : last7.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colors.border, width: 0.5)),
      child: Column(
          children: last7
              .map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      SizedBox(
                          width: 72,
                          child: Text(e.key,
                              style: TextStyle(
                                  color: _colors.textSecondary,
                                  fontSize: 11))),
                      Expanded(
                          child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: maxVal > 0 ? e.value / maxVal : 0,
                          minHeight: 6,
                          backgroundColor: _colors.border,
                          valueColor:
                              AlwaysStoppedAnimation(_colors.primary),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Text(_formatNumber(e.value),
                          style: TextStyle(
                              color: _colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ]),
                  ))
              .toList()),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Admin — Publicités',
            style: TextStyle(
                color: _colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        iconTheme: IconThemeData(color: _colors.textPrimary),
        actions: [
          IconButton(
            icon:
                Icon(Icons.price_change_outlined, color: _colors.accent),
            tooltip: 'Tarifs publicités',
            onPressed: _showTariffsEditor,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.textSecondary),
            onPressed: _loadGlobalStats,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _colors.primary,
          labelColor: _colors.primary,
          unselectedLabelColor: _colors.textSecondary,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('En attente'),
                if (_pendingAds > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: _colors.warning,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$_pendingAds',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Actives'),
                if (_activeAds > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: _colors.primary,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$_activeAds',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
            const Tab(text: 'Expirées'),
            const Tab(text: 'Rejetées'),
            const Tab(text: 'Annulées'),
            const Tab(text: 'Stats'),
          ],
        ),
      ),
      body: Column(children: [
        _buildKpiRow(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTableStreamList('pending'),
              _buildTableStreamList('active'),
              _buildTableStreamList('expired'),
              _buildTableStreamList('rejected'),
              _buildTableStreamList('cancelled'),
              _buildStatsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
