// afrolookAdminPubPage.dart — refonte UI session 49
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/models/model_data.dart';
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
  State<AdvertisementManagementPage> createState() => _AdvertisementManagementPageState();
}

class _AdvertisementManagementPageState extends State<AdvertisementManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserAuthProvider authProvider;
  late AppColors _colors;

  final TextEditingController _rejectionController = TextEditingController();

  // Stats globales
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

  // Auto-fix : IDs d'annonces corrigées active → expired
  final Set<String> _autoFixedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

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
    super.dispose();
  }

  // ── DONNÉES ──────────────────────────────────────────────────────────────────

  Future<void> _loadGlobalStats() async {
    setState(() => _loadingStats = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Advertisements').get();

      int totalViews = 0, totalClicks = 0, totalUniqueViews = 0;
      int pending = 0, active = 0, expired = 0, rejected = 0, cancelled = 0;
      int revenue = 0;
      final Map<String, int> viewsByAd = {};
      final Map<String, int> clicksByAd = {};
      final Map<String, int> daily = {};
      final now = DateTime.now().microsecondsSinceEpoch;
      final List<Future> fixes = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ad = Advertisement.fromJson(data);
        String status = data['status'] as String? ?? '';
        final endDate = data['endDate'] as int?;

        // Auto-fix : active mais date dépassée
        if (status == 'active' && endDate != null && endDate <= now) {
          status = 'expired';
          _autoFixedIds.add(doc.id);
          fixes.add(FirebaseFirestore.instance
              .collection('Advertisements')
              .doc(doc.id)
              .update({'status': 'expired', 'updatedAt': now}));
        }

        switch (status) {
          case 'pending': pending++; break;
          case 'active': active++; break;
          case 'expired': expired++; break;
          case 'rejected': rejected++; break;
          case 'cancelled': cancelled++; break;
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

      final sortedViews = viewsByAd.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final sortedClicks = clicksByAd.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
        _globalCTR = totalViews > 0 ? (totalClicks / totalViews) * 100 : 0;
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
    if (status == 'active' && endDate != null && endDate <= DateTime.now().microsecondsSinceEpoch) {
      return 'expired';
    }
    return status;
  }

  // ── ACTIONS ADMIN ─────────────────────────────────────────────────────────────

  Future<void> _refundUser(Advertisement ad) async {
    if ((ad.pricePaid ?? 0) <= 0 || ad.createdBy == null) return;
    try {
      await FirebaseFirestore.instance.collection('Users').doc(ad.createdBy).update({
        'votre_solde_principal': FieldValue.increment(ad.pricePaid!.toDouble()),
      });
      final tx = TransactionSolde()
        ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
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

  Future<void> _updateAdStatus(Advertisement ad, String newStatus, {String? reason}) async {
    try {
      if (newStatus == 'rejected' && ad.status == 'pending') await _refundUser(ad);

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'status': newStatus,
        'rejectionReason': reason,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      if (mounted) {
        final label = newStatus == 'active'
            ? 'activée'
            : newStatus == 'rejected'
                ? 'rejetée'
                : 'annulée';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Publicité $label'),
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

  Future<void> _renewAd(Advertisement ad, int days) async {
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final newEndDate = ad.isExpired
          ? now + days * 24 * 60 * 60 * 1000000
          : (ad.endDate ?? now) + days * 24 * 60 * 60 * 1000000;

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
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
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Action irréversible. Le post associé sera aussi supprimé.',
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
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
              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Indiquez le motif du rejet (obligatoire)',
              style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _rejectionController,
            style: TextStyle(color: _colors.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Motif...',
              hintStyle: TextStyle(color: _colors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionController.text.trim().isNotEmpty) {
                _updateAdStatus(ad, 'rejected', reason: _rejectionController.text.trim());
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

  void _showRenewalDialog(Advertisement ad) {
    const extensionOptions = [7, 14, 30, 60, 90];
    int? selectedDays;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.update, color: _colors.accent, size: 22),
            const SizedBox(width: 10),
            Text('Prolonger la publicité',
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _colors.accent.withOpacity(0.15) : _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _colors.accent : _colors.border, width: sel ? 1.5 : 0.5),
                    ),
                    child: Text(
                      d < 30 ? '$d jours' : d == 30 ? '1 mois' : d == 60 ? '2 mois' : '3 mois',
                      style: TextStyle(
                          color: sel ? _colors.supportAccent : _colors.textPrimary,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
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
              child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
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
                foregroundColor: _colors.onAccent,
                disabledBackgroundColor: _colors.border,
              ),
              child: const Text('Prolonger'),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return _colors.primary;
      case 'pending': return _colors.warning;
      case 'expired': return _colors.textSecondary;
      case 'rejected': return _colors.danger;
      case 'cancelled': return _colors.info;
      default: return _colors.border;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active': return Icons.check_circle;
      case 'pending': return Icons.hourglass_empty;
      case 'expired': return Icons.timer_off;
      case 'rejected': return Icons.cancel;
      case 'cancelled': return Icons.block;
      default: return Icons.help_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'Active';
      case 'pending': return 'En attente';
      case 'expired': return 'Expirée';
      case 'rejected': return 'Rejetée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  // ── APERÇU DU POST SELON SON TYPE ─────────────────────────────────────────────

  Widget _buildPostPreview(Map<String, dynamic>? postData) {
    if (postData == null) return _buildPlaceholder(Icons.image_not_supported);

    final dataType = postData['dataType'] as String? ?? '';
    final rawImages = postData['images'];
    final images = (rawImages is List) ? rawImages.whereType<String>().toList() : <String>[];
    final thumbnail = postData['thumbnail'] as String?;
    final description = postData['description'] as String?;

    if (dataType == PostDataType.IMAGE.name) {
      return images.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: images.first, fit: BoxFit.cover, width: double.infinity,
              placeholder: (_, __) => Container(color: _colors.surfaceVariant),
              errorWidget: (_, __, ___) => _buildPlaceholder(Icons.broken_image))
          : _buildPlaceholder(Icons.image, label: 'Image');
    }

    if (dataType == PostDataType.VIDEO.name) {
      final thumb = (thumbnail?.isNotEmpty == true) ? thumbnail! : (images.isNotEmpty ? images.first : null);
      return thumb != null
          ? Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _colors.surfaceVariant),
                  errorWidget: (_, __, ___) => _buildPlaceholder(Icons.videocam)),
              Center(child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28))),
              Positioned(top: 8, left: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 10))]))),
            ])
          : _buildPlaceholder(Icons.videocam, label: 'Vidéo');
    }

    if (dataType == PostDataType.AUDIO.name) {
      final thumb = (thumbnail?.isNotEmpty == true) ? thumbnail! : (images.isNotEmpty ? images.first : null);
      return thumb != null
          ? Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _colors.surfaceVariant),
                  errorWidget: (_, __, ___) => _buildAudioGradient()),
              Positioned(bottom: 8, left: 8, child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.headphones, color: Colors.white, size: 14))),
            ])
          : _buildAudioGradient();
    }

    if (dataType == PostDataType.TEXT.name) {
      return Container(
        color: _colors.surfaceVariant, padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.text_fields, color: _colors.textSecondary, size: 20),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description,
                style: TextStyle(color: _colors.textPrimary, fontSize: 12, height: 1.4),
                maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ]),
      );
    }

    if (images.isNotEmpty) {
      return CachedNetworkImage(
          imageUrl: images.first, fit: BoxFit.cover, width: double.infinity,
          placeholder: (_, __) => Container(color: _colors.surfaceVariant),
          errorWidget: (_, __, ___) => _buildPlaceholder(Icons.menu_book, label: 'Ebook'));
    }
    return _buildPlaceholder(Icons.menu_book, label: 'Ebook');
  }

  Widget _buildAudioGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0080), Color(0xFF311B92)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: const Center(child: Icon(Icons.headphones, color: Colors.white, size: 36)));

  Widget _buildPlaceholder(IconData icon, {String? label}) => Container(
        color: _colors.surfaceVariant,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _colors.textSecondary, size: 28),
          if (label != null) ...[const SizedBox(height: 4),
            Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 11))],
        ])));

  // ── ÉDITEUR DE TARIFS (admin) ─────────────────────────────────────────────────

  void _showTariffsEditor() async {
    final currentDurations = await AdConfigService.getDurations();
    // Copie éditable
    final edited = currentDurations.map((d) => AdDuration(weeks: d.weeks, price: d.price, label: d.label)).toList();
    final controllers = {for (final d in edited) d.weeks: TextEditingController(text: d.price.toString())};

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) {
          bool saving = false;
          return AlertDialog(
            backgroundColor: _colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.price_change_outlined, color: _colors.accent, size: 22),
              const SizedBox(width: 10),
              Text('Tarifs publicités',
                  style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Modifiez les tarifs (FCFA). Les changements s\'appliquent immédiatement.',
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.label,
                              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${d.weeks} semaines',
                              style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
                        ]),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                        child: TextField(
                          controller: controllers[d.weeks],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            suffix: Text('FCFA', style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            filled: true,
                            fillColor: _colors.surface,
                          ),
                          onChanged: (v) {
                            final idx = edited.indexWhere((x) => x.weeks == d.weeks);
                            if (idx >= 0 && v.isNotEmpty) {
                              edited[idx] = AdDuration(weeks: d.weeks, price: int.tryParse(v) ?? d.price, label: d.label);
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
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
              ),
              StatefulBuilder(
                builder: (__, setSaving) => ElevatedButton.icon(
                  onPressed: saving ? null : () async {
                    setSaving(() => saving = true);
                    // Mettre à jour edited avec les valeurs des controllers
                    final finalList = edited.map((d) {
                      final val = int.tryParse(controllers[d.weeks]?.text ?? '') ?? d.price;
                      return AdDuration(weeks: d.weeks, price: val, label: d.label);
                    }).toList();
                    await AdConfigService.update(finalList, authProvider.loginUserData.id ?? '');
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Tarifs mis à jour'),
                        backgroundColor: _colors.primary,
                      ));
                    }
                  },
                  icon: saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _colors.accent, foregroundColor: _colors.onAccent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── WIDGETS STATS ─────────────────────────────────────────────────────────────

  Widget _buildMetricCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border, width: 0.5),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(color: _colors.textSecondary, fontSize: 11),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildStatsTab() {
    if (_loadingStats) {
      return Center(
          child: LoadingAnimationWidget.flickr(
              size: 48, leftDotColor: _colors.primary, rightDotColor: _colors.accent));
    }
    return RefreshIndicator(
      onRefresh: _loadGlobalStats,
      color: _colors.primary,
      child: CenteredContent(child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Titre section
          Text('Publicités',
              style: TextStyle(
                  color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.95,
            children: [
              _buildMetricCard(Iconsax.dollar_circle, 'Total', '$_totalAds', _colors.textSecondary),
              _buildMetricCard(Icons.hourglass_empty, 'En attente', '$_pendingAds', _colors.warning),
              _buildMetricCard(Icons.check_circle, 'Actives', '$_activeAds', _colors.primary),
              _buildMetricCard(Icons.timer_off, 'Expirées', '$_expiredAds', _colors.textSecondary),
              _buildMetricCard(Icons.cancel, 'Rejetées', '$_rejectedAds', _colors.danger),
              _buildMetricCard(Icons.block, 'Annulées', '$_cancelledAds', _colors.info),
            ],
          ),

          const SizedBox(height: 16),
          Text('Performances',
              style: TextStyle(
                  color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6,
            children: [
              _buildMetricCard(Icons.remove_red_eye, 'Vues totales', _formatNumber(_totalViews), _colors.info),
              _buildMetricCard(Icons.ads_click, 'Clics totaux', _formatNumber(_totalClicks), _colors.warning),
              _buildMetricCard(Icons.person_outline, 'Vues uniques', _formatNumber(_totalUniqueViews), _colors.accent),
              _buildMetricCard(Icons.trending_up, 'CTR global',
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
              border: Border.all(color: _colors.border, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.monetization_on, color: _colors.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Revenus totaux',
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                  Text('${_formatNumber(_totalRevenue)} FCFA',
                      style: TextStyle(
                          color: _colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
              Text('Pubs actives + expirées',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
            ]),
          ),

          // Top performers
          if (_topAdsByViews.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Top 5 — Vues',
                style: TextStyle(
                    color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildRankingCard(_topAdsByViews, _colors.info, 'vues'),
          ],
          if (_topAdsByClicks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Top 5 — Clics',
                style: TextStyle(
                    color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildRankingCard(_topAdsByClicks, _colors.warning, 'clics'),
          ],

          // Activité récente
          if (_dailyActivity.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Activité récente (7 jours)',
                style: TextStyle(
                    color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _buildActivityBars(),
          ],

          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  Widget _buildRankingCard(List<MapEntry<String, int>> data, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border, width: 0.5),
      ),
      child: Column(
        children: data.asMap().entries.map((e) {
          final rank = e.key + 1;
          final entry = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _colors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: rank <= 3 ? color.withOpacity(0.15) : Colors.transparent,
                  shape: BoxShape.circle),
                child: Center(child: Text('$rank',
                    style: TextStyle(
                        color: rank <= 3 ? color : _colors.textSecondary,
                        fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('ID: ${entry.key.substring(0, 8).toUpperCase()}...',
                  style: TextStyle(color: _colors.textPrimary, fontSize: 12))),
              Text('${_formatNumber(entry.value)} $unit',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityBars() {
    final sorted = _dailyActivity.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final last7 = sorted.take(7).toList();
    final maxVal = last7.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border, width: 0.5)),
      child: Column(children: last7.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 72, child: Text(e.key,
              style: TextStyle(color: _colors.textSecondary, fontSize: 11))),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: maxVal > 0 ? e.value / maxVal : 0,
              minHeight: 6,
              backgroundColor: _colors.border,
              valueColor: AlwaysStoppedAnimation(_colors.primary)))),
          const SizedBox(width: 8),
          Text(_formatNumber(e.value),
              style: TextStyle(color: _colors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
        ]),
      )).toList()),
    );
  }

  // ── CARTE PUBLICITÉ ────────────────────────────────────────────────────────────

  Widget _buildAdCardWithPost(DocumentSnapshot doc) {
    final adData = doc.data() as Map<String, dynamic>;
    final ad = Advertisement.fromJson(adData);
    final wasAutoFixed = _autoFixedIds.contains(ad.id) ||
        (adData['status'] == 'active' &&
            ad.endDate != null &&
            ad.endDate! <= DateTime.now().microsecondsSinceEpoch);

    if (ad.postId == null || ad.postId!.isEmpty) {
      return _buildAdCard(ad, null, wasAutoFixed);
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get(),
      builder: (context, snap) {
        final postData =
            snap.hasData && snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : null;
        return _buildAdCard(ad, postData, wasAutoFixed);
      },
    );
  }

  Widget _buildAdCard(Advertisement ad, Map<String, dynamic>? postData, bool wasAutoFixed) {
    final effectiveStatus = wasAutoFixed ? 'expired' : (ad.status ?? '');
    final statusColor = _statusColor(effectiveStatus);
    final now = DateTime.now().microsecondsSinceEpoch;
    final remainingDays = ad.endDate != null
        ? ((ad.endDate! - now) / (24 * 60 * 60 * 1000000)).ceil()
        : 0;
    final totalDays = ad.durationDays ?? 1;
    final usedDays = totalDays - (remainingDays > 0 ? remainingDays : 0);
    final progress = totalDays > 0 ? (usedDays / totalDays).clamp(0.0, 1.0) : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: effectiveStatus == 'pending'
              ? _colors.warning.withOpacity(0.8)
              : wasAutoFixed
                  ? _colors.warning.withOpacity(0.6)
                  : _colors.border,
          width: (effectiveStatus == 'pending' || wasAutoFixed) ? 1.5 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Aperçu du post (type-aware)
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          child: SizedBox(height: 130, width: double.infinity, child: _buildPostPreview(postData)),
        ),

        // En-tête : statut + ID + date + prix
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(effectiveStatus), color: statusColor, size: 12),
                const SizedBox(width: 4),
                Text(_statusLabel(effectiveStatus),
                    style: TextStyle(
                        color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            const Spacer(),
            if (ad.pricePaid != null && ad.pricePaid! > 0) ...[
              Icon(Icons.monetization_on, color: _colors.accent, size: 12),
              const SizedBox(width: 3),
              Text('${ad.pricePaid} FCFA',
                  style: TextStyle(color: _colors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
            ],
            Text(
              '#${ad.id?.substring(0, 6).toUpperCase() ?? '---'}',
              style: TextStyle(
                  color: _colors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
            ),
          ]),
        ),

        // Créé le + auteur
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            Icon(Icons.schedule, color: _colors.textSecondary, size: 12),
            const SizedBox(width: 4),
            Text(
              ad.createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm')
                      .format(DateTime.fromMicrosecondsSinceEpoch(ad.createdAt!))
                  : '',
              style: TextStyle(color: _colors.textSecondary, fontSize: 11),
            ),
          ]),
        ),

        // Alerte auto-fix
        if (wasAutoFixed)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _colors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.warning.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: _colors.warning, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Date de fin dépassée — statut corrigé automatiquement',
                    style: TextStyle(color: _colors.warning, fontSize: 11)),
              ),
            ]),
          ),

        // Description
        if (postData?['description'] != null &&
            (postData!['description'] as String).isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(postData['description'] as String,
                style: TextStyle(color: _colors.textPrimary, fontSize: 13, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),

        // Lien + action
        if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _colors.primary.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ad.getActionIcon(), color: _colors.primary, size: 12),
                  const SizedBox(width: 4),
                  Text(ad.getActionButtonText(),
                      style: TextStyle(color: _colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ad.actionUrl!,
                    style: TextStyle(color: _colors.info, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),

        // Barre de progression + dates
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(children: [
            Row(children: [
              Icon(Icons.play_arrow, color: _colors.primary, size: 13),
              const SizedBox(width: 3),
              Text(
                ad.startDate != null
                    ? DateFormat('dd/MM/yyyy')
                        .format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!))
                    : 'N/A',
                style: TextStyle(color: _colors.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Icon(Icons.stop, color: _colors.danger, size: 13),
              const SizedBox(width: 3),
              Text(
                ad.endDate != null
                    ? DateFormat('dd/MM/yyyy')
                        .format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!))
                    : 'N/A',
                style: TextStyle(
                  color: wasAutoFixed ? _colors.danger : _colors.textSecondary,
                  fontSize: 11,
                  fontWeight: wasAutoFixed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (ad.renewalCount != null && ad.renewalCount! > 0)
                Text('×${ad.renewalCount} renouv.',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress, minHeight: 4,
                backgroundColor: _colors.border,
                valueColor: AlwaysStoppedAnimation(
                  effectiveStatus == 'expired' || effectiveStatus == 'cancelled'
                      ? _colors.textSecondary
                      : remainingDays <= 3 && remainingDays > 0 ? _colors.warning : _colors.primary),
              ),
            ),
          ]),
        ),

        // Stats : Vues / Clics / CTR / Uniques
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          decoration: BoxDecoration(
            color: _colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colors.border),
          ),
          child: Row(children: [
            _buildStatBox(Icons.remove_red_eye, _formatNumber(ad.views ?? 0), 'Vues', _colors.info),
            Container(width: 0.5, height: 40, color: _colors.border),
            _buildStatBox(Icons.ads_click, _formatNumber(ad.clicks ?? 0), 'Clics', _colors.warning),
            Container(width: 0.5, height: 40, color: _colors.border),
            _buildStatBox(Icons.trending_up, '${ad.ctr.toStringAsFixed(1)}%', 'CTR',
                ad.ctr > 5 ? _colors.primary : _colors.warning),
            Container(width: 0.5, height: 40, color: _colors.border),
            _buildStatBox(Icons.person_outline, _formatNumber(ad.uniqueViews ?? 0), 'Uniques', _colors.accent),
          ]),
        ),

        // Motif de rejet
        if (ad.rejectionReason != null && ad.rejectionReason!.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colors.danger.withOpacity(0.4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber, color: _colors.danger, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text('Motif : ${ad.rejectionReason}',
                  style: TextStyle(color: _colors.danger, fontSize: 11))),
            ]),
          ),

        // Boutons d'action admin
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _buildActionButtons(ad, effectiveStatus),
        ),
      ]),
    );
  }

  Widget _buildActionButtons(Advertisement ad, String effectiveStatus) {
    if (effectiveStatus == 'pending') {
      return Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _updateAdStatus(ad, 'active'),
          icon: const Icon(Icons.check, size: 15),
          label: const Text('Accepter', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary, foregroundColor: _colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8)),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _showRejectionDialog(ad),
          icon: const Icon(Icons.close, size: 15),
          label: const Text('Rejeter', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
              backgroundColor: _colors.danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8)),
        )),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _deleteAd(ad),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: _colors.danger.withOpacity(0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40)),
          child: Icon(Icons.delete_outline, color: _colors.danger, size: 18),
        ),
      ]);
    }

    if (effectiveStatus == 'active' || effectiveStatus == 'expired') {
      return Row(children: [
        if (effectiveStatus == 'active') ...[
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _updateAdStatus(ad, 'cancelled'),
            icon: Icon(Icons.block, size: 15, color: _colors.danger),
            label: Text('Annuler', style: TextStyle(color: _colors.danger, fontSize: 13)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: _colors.danger.withOpacity(0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8)),
          )),
          const SizedBox(width: 8),
        ],
        Expanded(child: OutlinedButton.icon(
          onPressed: () => _showRenewalDialog(ad),
          icon: Icon(Icons.update, size: 15, color: _colors.primary),
          label: Text('Prolonger', style: TextStyle(color: _colors.primary, fontSize: 13)),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: _colors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8)),
        )),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _deleteAd(ad),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: _colors.danger.withOpacity(0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40)),
          child: Icon(Icons.delete_outline, color: _colors.danger, size: 18),
        ),
      ]);
    }

    // rejected / cancelled : seulement supprimer
    return Row(children: [
      const Spacer(),
      OutlinedButton.icon(
        onPressed: () => _deleteAd(ad),
        icon: Icon(Icons.delete_outline, size: 15, color: _colors.danger),
        label: Text('Supprimer', style: TextStyle(color: _colors.danger, fontSize: 13)),
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: _colors.danger.withOpacity(0.6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
    ]);
  }

  Widget _buildStatBox(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildStreamList(String status) {
    return StreamBuilder<QuerySnapshot>(
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
                  size: 48, leftDotColor: _colors.primary, rightDotColor: _colors.accent));
        }

        // Filtrage client-side pour les auto-fix en transit
        final allDocs = snapshot.data!.docs;
        final docs = status == 'active'
            ? allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _effectiveStatus(data) == 'active';
              }).toList()
            : allDocs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Iconsax.dollar_circle, size: 60, color: _colors.textSecondary),
              const SizedBox(height: 12),
              Text('Aucune publicité ${_statusLabel(status).toLowerCase()}',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
            ]),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadGlobalStats,
          color: _colors.primary,
          child: CenteredContent(child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildAdCardWithPost(docs[i]),
          )),
        );
      },
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

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
                color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: IconThemeData(color: _colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.price_change_outlined, color: _colors.accent),
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
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Stats'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('En attente'),
              if (_pendingAds > 0) ...[const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: _colors.warning, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_pendingAds', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ])),
            const Tab(text: 'Actives'),
            const Tab(text: 'Expirées'),
            const Tab(text: 'Rejetées'),
            const Tab(text: 'Annulées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildStreamList('pending'),
          _buildStreamList('active'),
          _buildStreamList('expired'),
          _buildStreamList('rejected'),
          _buildStreamList('cancelled'),
        ],
      ),
    );
  }
}
