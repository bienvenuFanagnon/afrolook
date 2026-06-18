// user_my_advertisements_page.dart — refonte UI session 48
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../../services/ad_config_service.dart';
import '../../paiement/newDepot.dart';
import 'user_ad_detail_page.dart';
import 'user_create_advertisement_page.dart';

class UserMyAdvertisementsPage extends StatefulWidget {
  const UserMyAdvertisementsPage({Key? key}) : super(key: key);

  @override
  State<UserMyAdvertisementsPage> createState() => _UserMyAdvertisementsPageState();
}

class _UserMyAdvertisementsPageState extends State<UserMyAdvertisementsPage> {
  late UserAuthProvider authProvider;
  late AppColors _colors;

  String _selectedStatus = 'all';

  int _pendingCount = 0;
  int _activeCount = 0;
  int _expiredCount = 0;
  int _rejectedCount = 0;
  int _cancelledCount = 0;
  bool _loadingCounts = true;

  // IDs d'annonces dont le statut a été corrigé automatiquement (active → expired)
  final Set<String> _autoFixedIds = {};

  List<AdDuration> _durations = AdConfigService.defaults;
  Map<int, int> get _durationPrices => AdConfigService.toMap(_durations);
  List<int> get _durationOptions => _durations.map((d) => d.weeks).toList();

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadCounters();
    AdConfigService.getDurations().then((d) {
      if (mounted) setState(() => _durations = d);
    });
  }

  // ── DONNÉES ──────────────────────────────────────────────────────────────────

  Future<void> _loadCounters() async {
    setState(() => _loadingCounts = true);
    try {
      final userId = authProvider.loginUserData.id;
      final snapshot = await FirebaseFirestore.instance
          .collection('Advertisements')
          .where('createdBy', isEqualTo: userId)
          .get();

      int pending = 0, active = 0, expired = 0, rejected = 0, cancelled = 0;
      final now = DateTime.now().microsecondsSinceEpoch;
      final List<Future> fixes = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        String status = data['status'] as String? ?? '';
        final endDate = data['endDate'] as int?;

        // Auto-fix : annonce marquée active mais date de fin dépassée
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
      }

      if (fixes.isNotEmpty) await Future.wait(fixes);

      setState(() {
        _pendingCount = pending;
        _activeCount = active;
        _expiredCount = expired;
        _rejectedCount = rejected;
        _cancelledCount = cancelled;
        _loadingCounts = false;
      });
    } catch (e) {
      setState(() => _loadingCounts = false);
    }
  }

  Stream<QuerySnapshot> _getUserAdsStream() {
    Query query = FirebaseFirestore.instance
        .collection('Advertisements')
        .where('createdBy', isEqualTo: authProvider.loginUserData.id)
        .orderBy('createdAt', descending: true);
    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }

  String _effectiveStatus(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';
    final endDate = data['endDate'] as int?;
    if (status == 'active' && endDate != null && endDate <= DateTime.now().microsecondsSinceEpoch) {
      return 'expired';
    }
    return status;
  }

  // ── ACTIONS ──────────────────────────────────────────────────────────────────

  Future<void> _renewAd(Advertisement ad, int weeks) async {
    final int price = _durationPrices[weeks]!;
    final int daysToAdd = weeks * 7;
    final currentBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isAdmin && currentBalance < price) {
      _showInsufficientBalanceDialog();
      return;
    }

    try {
      if (!isAdmin) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(authProvider.loginUserData.id)
            .update({'votre_solde_principal': FieldValue.increment(-price)});
        setState(() {
          authProvider.loginUserData.votre_solde_principal =
              (authProvider.loginUserData.votre_solde_principal ?? 0) - price;
        });
        await _createTransaction(
            price, 'Renouvellement publicité ${ad.id} (${_getDurationLabel(weeks)})');
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      final newEndDate = ad.isExpired
          ? now + daysToAdd * 24 * 60 * 60 * 1000000
          : (ad.endDate ?? now) + daysToAdd * 24 * 60 * 60 * 1000000;

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'endDate': newEndDate,
        'status': 'active',
        'renewalCount': FieldValue.increment(1),
        'pricePaid': FieldValue.increment(price),
        'updatedAt': now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Publicité prolongée de ${_getDurationLabel(weeks)}'),
          backgroundColor: _colors.primary,
        ));
        _loadCounters();
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

  Future<void> _createTransaction(int amount, String reason) async {
    final tx = TransactionSolde()
      ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
      ..user_id = authProvider.loginUserData.id
      ..type = TypeTransaction.DEPENSE.name
      ..statut = StatutTransaction.VALIDER.name
      ..description = reason
      ..montant = amount.toDouble()
      ..methode_paiement = 'publicité'
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance
        .collection('TransactionSoldes')
        .doc(tx.id)
        .set(tx.toJson());
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Solde insuffisant',
            style: TextStyle(color: _colors.warning, fontWeight: FontWeight.bold)),
        content: Text(
          'Vous n\'avez pas assez de crédits pour ce renouvellement.',
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen()));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _colors.primary, foregroundColor: _colors.onPrimary),
            child: const Text('Recharger'),
          ),
        ],
      ),
    );
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
          'Cette action est irréversible. Le post associé sera également supprimé.',
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
                  _loadCounters();
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

  void _showRenewalDialog(Advertisement ad) {
    int? selectedWeek;
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
                style: TextStyle(
                    color: _colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choisissez la durée',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((week) {
                  final sel = selectedWeek == week;
                  return GestureDetector(
                    onTap: () => setD(() => selectedWeek = week),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? _colors.accent.withOpacity(0.15) : _colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? _colors.accent : _colors.border,
                            width: sel ? 1.5 : 0.5),
                      ),
                      child: Column(children: [
                        Text(_getDurationLabel(week),
                            style: TextStyle(
                                color: sel ? _colors.supportAccent : _colors.textPrimary,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13)),
                        Text('${_durationPrices[week]} FCFA',
                            style: TextStyle(
                                color: sel ? _colors.supportAccent : _colors.textSecondary,
                                fontSize: 11)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedWeek != null
                  ? () {
                      Navigator.pop(ctx);
                      _renewAd(ad, selectedWeek!);
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

  String _getDurationLabel(int weeks) => AdConfigService.labelFor(weeks, _durations);

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _colors.primary;
      case 'pending':
        return _colors.warning;
      case 'expired':
        return _colors.textSecondary;
      case 'rejected':
        return _colors.danger;
      case 'cancelled':
        return _colors.info;
      default:
        return _colors.border;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'expired':
        return Icons.timer_off;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
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

  String _filterLabel(String status) {
    if (status == 'all') return 'Toutes';
    return _statusLabel(status);
  }

  // ── WIDGETS ──────────────────────────────────────────────────────────────────

  /// Aperçu du post lié selon son type (IMAGE / VIDEO / AUDIO / TEXT / EBOOK)
  Widget _buildPostPreview(Map<String, dynamic>? postData) {
    if (postData == null) return _buildPreviewPlaceholder(Icons.image_not_supported);

    final dataType = postData['dataType'] as String? ?? '';
    final rawImages = postData['images'];
    final images = (rawImages is List)
        ? rawImages.whereType<String>().toList()
        : <String>[];
    final thumbnail = postData['thumbnail'] as String?;
    final description = postData['description'] as String?;

    // IMAGE
    if (dataType == PostDataType.IMAGE.name) {
      if (images.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: images.first,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (_, __) => Container(color: _colors.surfaceVariant),
          errorWidget: (_, __, ___) => _buildPreviewPlaceholder(Icons.broken_image),
        );
      }
      return _buildPreviewPlaceholder(Icons.image, label: 'Image');
    }

    // VIDEO
    if (dataType == PostDataType.VIDEO.name) {
      final thumb =
          (thumbnail != null && thumbnail.isNotEmpty) ? thumbnail : (images.isNotEmpty ? images.first : null);
      if (thumb != null) {
        return Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: _colors.surfaceVariant),
            errorWidget: (_, __, ___) => _buildPreviewPlaceholder(Icons.videocam),
          ),
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration:
                  BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam, color: Colors.white, size: 12),
                SizedBox(width: 3),
                Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 10)),
              ]),
            ),
          ),
        ]);
      }
      return _buildPreviewPlaceholder(Icons.videocam, label: 'Vidéo');
    }

    // AUDIO
    if (dataType == PostDataType.AUDIO.name) {
      final thumb =
          (thumbnail != null && thumbnail.isNotEmpty) ? thumbnail : (images.isNotEmpty ? images.first : null);
      if (thumb != null) {
        return Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: _colors.surfaceVariant),
            errorWidget: (_, __, ___) => _buildAudioGradient(),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.headphones, color: Colors.white, size: 14),
            ),
          ),
        ]);
      }
      return _buildAudioGradient();
    }

    // TEXT
    if (dataType == PostDataType.TEXT.name) {
      return Container(
        color: _colors.surfaceVariant,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.text_fields, color: _colors.textSecondary, size: 20),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: _colors.textPrimary, fontSize: 12, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      );
    }

    // EBOOK (ou autre) — essayer d'afficher la première image si disponible
    if (images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: images.first,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => Container(color: _colors.surfaceVariant),
        errorWidget: (_, __, ___) => _buildPreviewPlaceholder(Icons.menu_book, label: 'Ebook'),
      );
    }
    return _buildPreviewPlaceholder(Icons.menu_book, label: 'Ebook');
  }

  Widget _buildAudioGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0080), Color(0xFF311B92)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: Icon(Icons.headphones, color: Colors.white, size: 36)),
      );

  Widget _buildPreviewPlaceholder(IconData icon, {String? label}) => Container(
        color: _colors.surfaceVariant,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _colors.textSecondary, size: 28),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
            ],
          ]),
        ),
      );

  Widget _buildStatBox(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 10)),
        ]),
      ),
    );
  }

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

    // Chaque card charge son post indépendamment → pas de blocage global
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
    final canRenew = effectiveStatus == 'active' || effectiveStatus == 'expired';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserAdDetailPage(advertisementId: ad.id!)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: wasAutoFixed ? _colors.warning.withOpacity(0.6) : _colors.border,
            width: wasAutoFixed ? 1.5 : 0.5,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Aperçu du post (type-aware)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: SizedBox(height: 130, width: double.infinity, child: _buildPostPreview(postData)),
          ),

          // En-tête : badge statut + ID + date
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
              Text(
                '#${ad.id?.substring(0, 6).toUpperCase() ?? '---'}',
                style: TextStyle(
                    color: _colors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Text(
                ad.createdAt != null
                    ? DateFormat('dd/MM/yy')
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
                  child: Text(
                    'Date de fin dépassée — statut corrigé automatiquement',
                    style: TextStyle(color: _colors.warning, fontSize: 11),
                  ),
                ),
              ]),
            ),

          // Description
          if (postData?['description'] != null &&
              (postData!['description'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                postData['description'] as String,
                style: TextStyle(color: _colors.textPrimary, fontSize: 13, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Barre de progression + jours restants
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  effectiveStatus == 'active' && remainingDays > 0
                      ? '$remainingDays j restants'
                      : effectiveStatus == 'active'
                          ? 'Se termine aujourd\'hui'
                          : _statusLabel(effectiveStatus),
                  style: TextStyle(
                    color: remainingDays <= 3 && effectiveStatus == 'active'
                        ? _colors.danger
                        : _colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text('${ad.pricePaid ?? 0} FCFA',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: _colors.border,
                  valueColor: AlwaysStoppedAnimation(
                    effectiveStatus == 'expired' || effectiveStatus == 'cancelled'
                        ? _colors.textSecondary
                        : remainingDays <= 3 && remainingDays > 0
                            ? _colors.warning
                            : _colors.primary,
                  ),
                ),
              ),
            ]),
          ),

          // Dates début / fin
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Icon(Icons.play_arrow, color: _colors.primary, size: 14),
              const SizedBox(width: 3),
              Text(
                ad.startDate != null
                    ? DateFormat('dd/MM/yyyy')
                        .format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!))
                    : 'N/A',
                style: TextStyle(color: _colors.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 14),
              Icon(Icons.stop, color: _colors.danger, size: 14),
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
            ]),
          ),

          // Stats : Vues / Clics / CTR
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
                Expanded(
                  child: Text('Motif : ${ad.rejectionReason}',
                      style: TextStyle(color: _colors.danger, fontSize: 11)),
                ),
              ]),
            ),

          // Boutons d'action
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => UserAdDetailPage(advertisementId: ad.id!))),
                  icon: Icon(Icons.visibility_outlined, size: 15, color: _colors.textPrimary),
                  label: Text('Détails',
                      style: TextStyle(color: _colors.textPrimary, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (canRenew) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRenewalDialog(ad),
                    icon: Icon(Icons.update, size: 15, color: _colors.primary),
                    label: Text('Renouveler',
                        style: TextStyle(color: _colors.primary, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _colors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _deleteAd(ad),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _colors.danger.withOpacity(0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                ),
                child: Icon(Icons.delete_outline, color: _colors.danger, size: 18),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildKpiCard(String label, int count, IconData icon, Color color, String statusKey) {
    final isSelected = _selectedStatus == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = statusKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : _colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : _colors.border, width: isSelected ? 1.5 : 0.5),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(count.toString(),
                style: TextStyle(
                    color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label,
                style: TextStyle(color: _colors.textSecondary, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final total =
        _pendingCount + _activeCount + _expiredCount + _rejectedCount + _cancelledCount;
    return Column(children: [
      // Ligne 1 : En attente / Actives / Expirées / Rejetées
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
        child: Row(children: [
          _buildKpiCard('En attente', _pendingCount, Icons.hourglass_empty, _colors.warning, 'pending'),
          _buildKpiCard('Actives', _activeCount, Icons.check_circle, _colors.primary, 'active'),
          _buildKpiCard('Expirées', _expiredCount, Icons.timer_off, _colors.textSecondary, 'expired'),
          _buildKpiCard('Rejetées', _rejectedCount, Icons.cancel, _colors.danger, 'rejected'),
        ]),
      ),
      // Ligne 2 : Annulées / Toutes
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(children: [
          _buildKpiCard('Annulées', _cancelledCount, Icons.block, _colors.info, 'cancelled'),
          _buildKpiCard('Toutes', total, Icons.list_alt, _colors.accent, 'all'),
        ]),
      ),
      // CTA créer
      Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colors.border, width: 0.5),
        ),
        child: Row(children: [
          Icon(Iconsax.chart_21, color: _colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Boostez votre visibilité',
                  style: TextStyle(
                      color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Créez une publicité pour toucher plus d\'utilisateurs',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UserCreateAdvertisementPage())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Créer', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ]),
      ),
    ]);
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
        title: Text('Gestion des publicités',
            style: TextStyle(
                color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: IconThemeData(color: _colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.textSecondary),
            onPressed: () async {
              await _loadCounters();
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: _colors.primary),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const UserCreateAdvertisementPage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCounters();
          setState(() {});
        },
        color: _colors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Dashboard KPI
            if (_loadingCounts)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2)),
              )
            else
              _buildDashboard(),

            // Chips de filtre
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children:
                    ['all', 'active', 'pending', 'expired', 'rejected', 'cancelled'].map((s) {
                  final isSel = _selectedStatus == s;
                  final chipColor = s == 'active'
                      ? _colors.primary
                      : s == 'pending'
                          ? _colors.warning
                          : s == 'expired'
                              ? _colors.textSecondary
                              : s == 'rejected'
                                  ? _colors.danger
                                  : s == 'cancelled'
                                      ? _colors.info
                                      : _colors.textSecondary;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStatus = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel ? chipColor.withOpacity(0.12) : _colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSel ? chipColor : _colors.border,
                            width: isSel ? 1.5 : 0.5),
                      ),
                      child: Text(
                        _filterLabel(s),
                        style: TextStyle(
                          color: isSel ? chipColor : _colors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Titre section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text(_filterLabel(_selectedStatus),
                  style: TextStyle(
                      color: _colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            ),

            // Liste
            StreamBuilder<QuerySnapshot>(
              stream: _getUserAdsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('Erreur : ${snapshot.error}',
                            style: TextStyle(color: _colors.danger))),
                  );
                }
                if (!snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: LoadingAnimationWidget.flickr(
                          size: 48,
                          leftDotColor: _colors.primary,
                          rightDotColor: _colors.accent),
                    ),
                  );
                }

                // Filtrage client-side (rattrape les auto-fix pas encore propagés)
                final allDocs = snapshot.data!.docs;
                final docs = _selectedStatus == 'all'
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final eff = _effectiveStatus(data);
                        return eff == _selectedStatus;
                      }).toList();

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Iconsax.dollar_circle, size: 60, color: _colors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune publicité ${_filterLabel(_selectedStatus).toLowerCase()}',
                        style: TextStyle(color: _colors.textSecondary, fontSize: 14),
                      ),
                      if (_selectedStatus == 'all') ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const UserCreateAdvertisementPage())),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une publicité'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _colors.primary,
                            foregroundColor: _colors.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ]),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _buildAdCardWithPost(docs[i]),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}
