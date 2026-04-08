// pages/admin/advertisement_management_page.dart
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

class _AdvertisementManagementPageState extends State<AdvertisementManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserAuthProvider authProvider;

  final Color _primaryColor = const Color(0xFFE21221);
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  final Color _successColor = const Color(0xFF4CAF50);

  String? _selectedAdId;
  String? _rejectionReason;
  int? _extensionDays;
  final TextEditingController _rejectionController = TextEditingController();
  final TextEditingController _extensionController = TextEditingController();

  // Statistiques globales
  int _totalAds = 0;
  int _pendingAds = 0;
  int _activeAds = 0;
  int _expiredAds = 0;
  int _rejectedAds = 0;
  int _totalViews = 0;
  int _totalClicks = 0;
  int _totalUniqueViews = 0;
  int _totalUniqueClicks = 0;
  double _globalCTR = 0.0;
  int _totalRevenue = 0; // Somme des pricePaid des pubs acceptées (actives + expirées)

  // Top performances
  List<MapEntry<String, int>> _topAdsByViews = [];
  List<MapEntry<String, int>> _topAdsByClicks = [];
  Map<String, int> _dailyActivity = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    if (authProvider.loginUserData.role != UserRole.ADM.name) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accès réservé aux administrateurs'), backgroundColor: _primaryColor),
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
    _extensionController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalStats() async {
    try {
      final adsSnapshot = await FirebaseFirestore.instance.collection('Advertisements').get();

      int totalViews = 0, totalClicks = 0, totalUniqueViews = 0, totalUniqueClicks = 0;
      int pending = 0, active = 0, expired = 0, rejected = 0, totalRevenue = 0;
      Map<String, int> viewsByAd = {};
      Map<String, int> clicksByAd = {};
      Map<String, int> dailyActivity = {};

      for (var doc in adsSnapshot.docs) {
        final ad = Advertisement.fromJson(doc.data());
        totalViews += ad.views ?? 0;
        totalClicks += ad.clicks ?? 0;
        totalUniqueViews += ad.uniqueViews ?? 0;
        totalUniqueClicks += ad.uniqueClicks ?? 0;

        // Comptage par statut
        switch (ad.status) {
          case 'pending': pending++; break;
          case 'active': active++; break;
          case 'expired': expired++; break;
          case 'rejected': rejected++; break;
        }

        // Revenus : seulement pour les pubs acceptées (actives ou expirées)
        if ((ad.status == 'active' || ad.status == 'expired') && ad.pricePaid != null) {
          totalRevenue += ad.pricePaid!;
        }

        if (ad.views! > 0) viewsByAd[ad.id!] = ad.views!;
        if (ad.clicks! > 0) clicksByAd[ad.id!] = ad.clicks!;

        if (ad.dailyStats != null) {
          ad.dailyStats!.forEach((date, value) {
            dailyActivity[date] = (dailyActivity[date] ?? 0) + value;
          });
        }
      }

      var sortedViews = viewsByAd.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      var sortedClicks = clicksByAd.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _totalAds = adsSnapshot.docs.length;
        _pendingAds = pending;
        _activeAds = active;
        _expiredAds = expired;
        _rejectedAds = rejected;
        _totalViews = totalViews;
        _totalClicks = totalClicks;
        _totalUniqueViews = totalUniqueViews;
        _totalUniqueClicks = totalUniqueClicks;
        _globalCTR = totalViews > 0 ? (totalClicks / totalViews) * 100 : 0;
        _totalRevenue = totalRevenue;
        _topAdsByViews = sortedViews.take(5).toList();
        _topAdsByClicks = sortedClicks.take(5).toList();
        _dailyActivity = dailyActivity;
      });
    } catch (e) {
      print('Erreur chargement stats globales: $e');
    }
  }

  // Remboursement de l'utilisateur
  Future<void> _refundUser(Advertisement ad) async {
    if (ad.pricePaid == null || ad.pricePaid! <= 0) return;
    final userId = ad.createdBy;
    if (userId == null) return;

    try {
      // Créditer l'utilisateur
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'votre_solde_principal': FieldValue.increment(ad.pricePaid!.toDouble()),
      });

      // Enregistrer la transaction
      final transaction = TransactionSolde()
        ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
        ..user_id = userId
        ..type = TypeTransaction.GAIN.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = 'Remboursement publicité rejetée (ID: ${ad.id})'
        ..montant = ad.pricePaid!.toDouble()
        ..methode_paiement = 'remboursement'
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());

      print('✅ Remboursement de ${ad.pricePaid} FCFA à l\'utilisateur $userId');
    } catch (e) {
      print('❌ Erreur lors du remboursement: $e');
    }
  }

  // Suppression complète (publicité + post)
  Future<void> _deleteAd(Advertisement ad) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Confirmer la suppression', style: TextStyle(color: _textColor)),
        content: Text('Voulez-vous vraiment supprimer cette publicité ? Cette action est irréversible.', style: TextStyle(color: _hintColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Supprimer l'advertisement
                await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).delete();
                // Supprimer le post associé
                if (ad.postId != null) {
                  await FirebaseFirestore.instance.collection('Posts').doc(ad.postId).delete();
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicité supprimée'), backgroundColor: _successColor));
                _loadGlobalStats();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  // Mise à jour du statut (avec remboursement si rejet)
  Future<void> _updateAdStatus(Advertisement ad, String newStatus, {String? reason}) async {
    try {
      // Si on rejette une pub en attente, on rembourse
      if (newStatus == 'rejected' && ad.status == 'pending') {
        await _refundUser(ad);
      }

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'status': newStatus,
        'rejectionReason': reason,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publicité ${newStatus == 'active' ? 'activée' : newStatus == 'rejected' ? 'rejetée' : 'annulée'}'),
          backgroundColor: _successColor,
        ),
      );
      _loadGlobalStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor));
    }
  }

  // Prolongation (admin)
  Future<void> _renewAd(Advertisement ad, int days) async {
    try {
      int now = DateTime.now().microsecondsSinceEpoch;
      int newEndDate;
      if (ad.isExpired) {
        newEndDate = now + (days * 24 * 60 * 60 * 1000000);
      } else {
        newEndDate = (ad.endDate ?? now) + (days * 24 * 60 * 60 * 1000000);
      }

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'endDate': newEndDate,
        'status': 'active',
        'renewalCount': FieldValue.increment(1),
        'updatedAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publicité prolongée de $days jours'), backgroundColor: _successColor),
      );
      _loadGlobalStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor));
    }
  }

  // ========== WIDGETS DASHBOARD ==========
  Widget _buildStatsOverview() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _secondaryColor),
      ),
      child: Column(
        children: [
          Text('APERÇU GLOBAL', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard(Iconsax.dollar_circle, 'Total', '$_totalAds', _primaryColor),
              _buildStatCard(Icons.hourglass_empty, 'En attente', '$_pendingAds', Colors.orange),
              _buildStatCard(Icons.check_circle, 'Actives', '$_activeAds', Colors.green),
              _buildStatCard(Icons.timer_off, 'Expirées', '$_expiredAds', Colors.grey),
              _buildStatCard(Icons.cancel, 'Rejetées', '$_rejectedAds', Colors.red),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.grey[800]),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard(Iconsax.eye, 'Vues', _formatNumber(_totalViews), Colors.blue),
              _buildStatCard(Icons.ads_click, 'Clics', _formatNumber(_totalClicks), _secondaryColor),
              _buildStatCard(Icons.person, 'Vues uniques', _formatNumber(_totalUniqueViews), Colors.purple),
              _buildStatCard(Icons.trending_up, 'CTR', '${_globalCTR.toStringAsFixed(1)}%', _globalCTR > 5 ? Colors.green : Colors.orange),
              _buildStatCard(Icons.monetization_on, 'Revenus', '${_formatNumber(_totalRevenue)} FCFA', _successColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 100,
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 6),
          Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(color: _hintColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRankingCard('TOP 5 - Plus vues', _topAdsByViews, Colors.blue, 'vues'),
          SizedBox(height: 12),
          _buildRankingCard('TOP 5 - Plus cliquées', _topAdsByClicks, _secondaryColor, 'clics'),
        ],
      ),
    );
  }

  Widget _buildRankingCard(String title, List<MapEntry<String, int>> data, Color color, String unit) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.trending_up, color: color), SizedBox(width: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
          SizedBox(height: 12),
          if (data.isEmpty)
            Text('Aucune donnée', style: TextStyle(color: _hintColor))
          else
            ...data.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final adEntry = entry.value;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: rank <= 3 ? color.withOpacity(0.2) : Colors.transparent, shape: BoxShape.circle),
                      child: Center(child: Text('$rank', style: TextStyle(color: rank <= 3 ? color : _hintColor, fontWeight: FontWeight.bold))),
                    ),
                    SizedBox(width: 8),
                    Expanded(child: Text('ID: ${adEntry.key.substring(0, 6)}...', style: TextStyle(color: _textColor, fontSize: 13))),
                    Text('${_formatNumber(adEntry.value)} $unit', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_dailyActivity.isEmpty) return SizedBox.shrink();
    final recentDays = _dailyActivity.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final last7Days = recentDays.take(7).toList();
    int maxValue = _dailyActivity.values.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.history, color: _primaryColor), SizedBox(width: 8), Text('Activité récente (7 jours)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold))]),
          SizedBox(height: 16),
          ...last7Days.map((entry) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(entry.key, style: TextStyle(color: _hintColor, fontSize: 12))),
                  Expanded(child: LinearProgressIndicator(value: entry.value / maxValue, backgroundColor: _backgroundColor, valueColor: AlwaysStoppedAnimation<Color>(_primaryColor), minHeight: 8)),
                  SizedBox(width: 8),
                  Text(_formatNumber(entry.value), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ========== CARTE D'UNE PUBLICITÉ ==========
  Widget _buildAdCard(DocumentSnapshot doc) {
    final ad = Advertisement.fromJson(doc.data() as Map<String, dynamic>);

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (ad.status) {
      case 'active': statusColor = Colors.green; statusText = 'Active'; statusIcon = Icons.check_circle; break;
      case 'pending': statusColor = Colors.orange; statusText = 'En attente'; statusIcon = Icons.hourglass_empty; break;
      case 'expired': statusColor = Colors.grey; statusText = 'Expirée'; statusIcon = Icons.timer_off; break;
      case 'rejected': statusColor = Colors.red; statusText = 'Rejetée'; statusIcon = Icons.cancel; break;
      default: statusColor = Colors.grey; statusText = ad.status ?? 'Inconnu'; statusIcon = Icons.help;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get(),
      builder: (context, postSnapshot) {
        String? imageUrl;
        String? description;
        if (postSnapshot.hasData && postSnapshot.data!.exists) {
          final postData = postSnapshot.data!.data() as Map<String, dynamic>;
          imageUrl = (postData['images'] as List?)?.isNotEmpty == true ? (postData['images'] as List).first : null;
          description = postData['description'];
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ad.status == 'pending' ? _secondaryColor : Colors.grey[800]!, width: ad.status == 'pending' ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))),
                child: Row(
                  children: [
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(statusIcon, color: statusColor, size: 16)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${ad.id?.substring(0, 6)}...', style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Créé le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMicrosecondsSinceEpoch(ad.createdAt ?? 0))}', style: TextStyle(color: _hintColor, fontSize: 10)),
                          if (ad.pricePaid != null) Text('💰 ${ad.pricePaid} FCFA', style: TextStyle(color: _secondaryColor, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)), child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              if (imageUrl != null) Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[900], child: Icon(Icons.broken_image, color: Colors.grey))),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null) Text(description, style: TextStyle(color: _textColor, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 12),
                    Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ad.getActionIcon(), color: _primaryColor, size: 14), SizedBox(width: 4), Text(ad.getActionButtonText(), style: TextStyle(color: _primaryColor, fontSize: 11, fontWeight: FontWeight.bold))])),
                    SizedBox(height: 8),
                    Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.link, color: _hintColor, size: 14), SizedBox(width: 8), Expanded(child: Text(ad.actionUrl ?? '', style: TextStyle(color: _secondaryColor, fontSize: 12), overflow: TextOverflow.ellipsis))])),
                    SizedBox(height: 12),
                    Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[900]!, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _buildStatItem('Vues', _formatNumber(ad.views ?? 0), Icons.remove_red_eye, Colors.blue),
                      _buildStatItem('Clics', _formatNumber(ad.clicks ?? 0), Icons.ads_click, _secondaryColor),
                      _buildStatItem('CTR', '${ad.ctr.toStringAsFixed(1)}%', Icons.trending_up, ad.ctr > 5 ? Colors.green : Colors.orange),
                      _buildStatItem('Uniques', _formatNumber(ad.uniqueClicks ?? 0), Icons.person, Colors.purple),
                    ])),
                    SizedBox(height: 12),
                    Row(children: [Icon(Icons.calendar_today, color: _hintColor, size: 14), SizedBox(width: 8), Text('Durée: ${ad.durationDays} jours', style: TextStyle(color: _textColor, fontSize: 12)), SizedBox(width: 16), Icon(Icons.update, color: _hintColor, size: 14), SizedBox(width: 8), Text('Renouvellements: ${ad.renewalCount}', style: TextStyle(color: _textColor, fontSize: 12))]),
                    SizedBox(height: 8),
                    Row(children: [Icon(Icons.play_arrow, color: Colors.green, size: 14), SizedBox(width: 8), Text('Début: ${ad.startDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!)) : 'N/A'}', style: TextStyle(color: _hintColor, fontSize: 11)), SizedBox(width: 16), Icon(Icons.stop, color: Colors.red, size: 14), SizedBox(width: 8), Text('Fin: ${ad.endDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!)) : 'N/A'}', style: TextStyle(color: _hintColor, fontSize: 11))]),
                    if (ad.rejectionReason != null) ...[
                      SizedBox(height: 8),
                      Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)), child: Row(children: [Icon(Icons.warning, color: Colors.red, size: 14), SizedBox(width: 8), Expanded(child: Text('Motif: ${ad.rejectionReason}', style: TextStyle(color: Colors.red, fontSize: 11)))])),
                    ],
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          if (ad.status == 'pending') ...[
                            Expanded(child: ElevatedButton.icon(onPressed: () => _updateAdStatus(ad, 'active'), icon: Icon(Icons.check, size: 16), label: Text('Accepter'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
                            SizedBox(width: 8),
                            Expanded(child: ElevatedButton.icon(onPressed: () => _showRejectionDialog(ad), icon: Icon(Icons.close, size: 16), label: Text('Rejeter'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
                          ],
                          if (ad.status == 'active' || ad.status == 'expired') ...[
                            Expanded(child: OutlinedButton.icon(onPressed: ad.status == 'active' ? () => _updateAdStatus(ad, 'cancelled') : null, icon: Icon(Icons.cancel, size: 16), label: Text('Annuler'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red)))),
                            SizedBox(width: 8),
                            Expanded(child: ElevatedButton.icon(onPressed: () => _showRenewalDialog(ad), icon: Icon(Icons.update, size: 16), label: Text('Prolonger'), style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black))),
                          ],
                          SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(onPressed: () => _deleteAd(ad), icon: Icon(Icons.delete, size: 16), label: Text('Supprimer'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red)))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(children: [Icon(icon, color: color, size: 16), SizedBox(height: 2), Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 12)), Text(label, style: TextStyle(color: _hintColor, fontSize: 9))]);
  }

  void _showRejectionDialog(Advertisement ad) {
    _rejectionController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text('Rejeter la publicité', style: TextStyle(color: _textColor))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Veuillez indiquer le motif du rejet', style: TextStyle(color: _hintColor)),
            SizedBox(height: 16),
            TextField(controller: _rejectionController, style: TextStyle(color: _textColor), maxLines: 3, decoration: InputDecoration(hintText: 'Motif...', hintStyle: TextStyle(color: _hintColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: _backgroundColor)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
          ElevatedButton(onPressed: () { if (_rejectionController.text.isNotEmpty) { _updateAdStatus(ad, 'rejected', reason: _rejectionController.text); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('REJETER')),
        ],
      ),
    );
  }

  void _showRenewalDialog(Advertisement ad) {
    final List<int> extensionOptions = [7, 14, 30, 60, 90];
    int? selectedDays;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [Icon(Icons.update, color: _secondaryColor), SizedBox(width: 10), Text('Prolonger la publicité', style: TextStyle(color: _textColor))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sélectionnez la durée de prolongation', style: TextStyle(color: _hintColor)),
                SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: extensionOptions.map((days) {
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedDays = days),
                    child: Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: selectedDays == days ? _secondaryColor : _backgroundColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: selectedDays == days ? _secondaryColor : Colors.grey[700]!)), child: Text(days < 30 ? '$days jours' : days == 30 ? '1 mois' : days == 60 ? '2 mois' : '3 mois', style: TextStyle(color: selectedDays == days ? Colors.black : _textColor))),
                  );
                }).toList()),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
              ElevatedButton(onPressed: selectedDays != null ? () { _renewAd(ad, selectedDays!); Navigator.pop(context); } : null, style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black), child: Text('PROLONGER')),
            ],
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Text('Gestion des publicités', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _secondaryColor,
          labelColor: _secondaryColor,
          unselectedLabelColor: _hintColor,
          tabs: const [
            Tab(text: 'Stats'),
            Tab(text: 'En attente'),
            Tab(text: 'Actives'),
            Tab(text: 'Expirées'),
            Tab(text: 'Rejetées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Stats
          SingleChildScrollView(child: Column(children: [_buildStatsOverview(), _buildTopPerformers(), _buildRecentActivity(), SizedBox(height: 20)])),
          // En attente
          _buildStreamList('pending'),
          // Actives
          _buildStreamList('active'),
          // Expirées
          _buildStreamList('expired'),
          // Rejetées
          _buildStreamList('rejected'),
        ],
      ),
    );
  }

  Widget _buildStreamList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Advertisements').where('status', isEqualTo: status).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        if (!snapshot.hasData) return Center(child: LoadingAnimationWidget.flickr(size: 50, leftDotColor: _primaryColor, rightDotColor: _secondaryColor));
        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.dollar_circle, size: 80, color: _hintColor), SizedBox(height: 16), Text('Aucune publicité $status', style: TextStyle(color: _hintColor))]));
        }
        return ListView.builder(padding: EdgeInsets.all(16), itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) => _buildAdCard(snapshot.data!.docs[index]));
      },
    );
  }
}


// // pages/admin/advertisement_management_page.dart
// import 'package:afrotok/models/model_data.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:intl/intl.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:provider/provider.dart';
//
// import '../../../providers/authProvider.dart';
//
// class AdvertisementManagementPage extends StatefulWidget {
//   const AdvertisementManagementPage({Key? key}) : super(key: key);
//
//   @override
//   State<AdvertisementManagementPage> createState() => _AdvertisementManagementPageState();
// }
//
// class _AdvertisementManagementPageState extends State<AdvertisementManagementPage> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   late UserAuthProvider authProvider;
//
//   final Color _primaryColor = Color(0xFFE21221);
//   final Color _secondaryColor = Color(0xFFFFD600);
//   final Color _backgroundColor = Color(0xFF121212);
//   final Color _cardColor = Color(0xFF1E1E1E);
//   final Color _textColor = Colors.white;
//   final Color _hintColor = Colors.grey[400]!;
//   final Color _successColor = Color(0xFF4CAF50);
//
//   String? _selectedAdId;
//   String? _rejectionReason;
//   int? _extensionDays;
//   final TextEditingController _rejectionController = TextEditingController();
//   final TextEditingController _extensionController = TextEditingController();
//
//   // Statistiques globales
//   int _totalAds = 0;
//   int _activeAds = 0;
//   int _totalViews = 0;
//   int _totalClicks = 0;
//   int _totalUniqueViews = 0;
//   int _totalUniqueClicks = 0;
//   double _globalCTR = 0.0;
//
//   // Données pour le top performances
//   List<MapEntry<String, int>> _topAdsByViews = [];
//   List<MapEntry<String, int>> _topAdsByClicks = [];
//   Map<String, int> _dailyActivity = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 5, vsync: this);
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//     if (authProvider.loginUserData.role != UserRole.ADM.name) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Accès réservé aux administrateurs'),
//             backgroundColor: _primaryColor,
//           ),
//         );
//       });
//     } else {
//       _loadGlobalStats();
//     }
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     _rejectionController.dispose();
//     _extensionController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadGlobalStats() async {
//     try {
//       final adsSnapshot = await FirebaseFirestore.instance
//           .collection('Advertisements')
//           .get();
//
//       int totalViews = 0;
//       int totalClicks = 0;
//       int totalUniqueViews = 0;
//       int totalUniqueClicks = 0;
//       int active = 0;
//
//       Map<String, int> viewsByAd = {};
//       Map<String, int> clicksByAd = {};
//       Map<String, int> dailyActivity = {};
//
//       for (var doc in adsSnapshot.docs) {
//         final ad = Advertisement.fromJson(doc.data());
//         totalViews += ad.views ?? 0;
//         totalClicks += ad.clicks ?? 0;
//         totalUniqueViews += ad.uniqueViews ?? 0;
//         totalUniqueClicks += ad.uniqueClicks ?? 0;
//
//         if (ad.isActive) active++;
//
//         // Collecter pour le classement
//         if (ad.views! > 0) viewsByAd[ad.id!] = ad.views!;
//         if (ad.clicks! > 0) clicksByAd[ad.id!] = ad.clicks!;
//
//         // Agréger les stats quotidiennes
//         if (ad.dailyStats != null) {
//           ad.dailyStats!.forEach((date, value) {
//             dailyActivity[date] = (dailyActivity[date] ?? 0) + value;
//           });
//         }
//       }
//
//       // Trier pour obtenir le top 5
//       var sortedViews = viewsByAd.entries.toList()
//         ..sort((a, b) => b.value.compareTo(a.value));
//       var sortedClicks = clicksByAd.entries.toList()
//         ..sort((a, b) => b.value.compareTo(a.value));
//
//       setState(() {
//         _totalAds = adsSnapshot.docs.length;
//         _activeAds = active;
//         _totalViews = totalViews;
//         _totalClicks = totalClicks;
//         _totalUniqueViews = totalUniqueViews;
//         _totalUniqueClicks = totalUniqueClicks;
//         _globalCTR = totalViews > 0 ? (totalClicks / totalViews) * 100 : 0;
//         _topAdsByViews = sortedViews.take(5).toList();
//         _topAdsByClicks = sortedClicks.take(5).toList();
//         _dailyActivity = dailyActivity;
//       });
//
//     } catch (e) {
//       print('Erreur chargement stats globales: $e');
//     }
//   }
//
//   Future<void> _deleteAd(String adId) async {
//     try {
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           backgroundColor: _cardColor,
//           title: Text('Confirmer la suppression', style: TextStyle(color: _textColor)),
//           content: Text('Voulez-vous vraiment supprimer cette publicité ?',
//               style: TextStyle(color: _hintColor)),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('ANNULER', style: TextStyle(color: _hintColor)),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 Navigator.pop(context);
//                 await FirebaseFirestore.instance
//                     .collection('Advertisements')
//                     .doc(adId)
//                     .delete();
//
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Publicité supprimée'),
//                     backgroundColor: _successColor,
//                   ),
//                 );
//                 _loadGlobalStats();
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               child: Text('SUPPRIMER'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
//       );
//     }
//   }
//
//   Future<void> _updateAdStatus(String adId, String status, {String? reason}) async {
//     try {
//       await FirebaseFirestore.instance.collection('Advertisements').doc(adId).update({
//         'status': status,
//         'rejectionReason': reason,
//         'updatedAt': DateTime.now().microsecondsSinceEpoch,
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Publicité ${status == 'active' ? 'activée' : status == 'rejected' ? 'rejetée' : 'annulée'}'),
//           backgroundColor: _successColor,
//         ),
//       );
//
//       setState(() {
//         _selectedAdId = null;
//         _rejectionReason = null;
//         _rejectionController.clear();
//       });
//       _loadGlobalStats();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
//       );
//     }
//   }
//
//   Future<void> _renewAd(String adId, int days) async {
//     try {
//       final adDoc = await FirebaseFirestore.instance.collection('Advertisements').doc(adId).get();
//       if (!adDoc.exists) return;
//
//       final ad = Advertisement.fromJson(adDoc.data()!);
//       int now = DateTime.now().microsecondsSinceEpoch;
//
//       int newEndDate;
//       if (ad.isExpired) {
//         newEndDate = now + (days * 24 * 60 * 60 * 1000000);
//       } else {
//         newEndDate = (ad.endDate ?? now) + (days * 24 * 60 * 60 * 1000000);
//       }
//
//       await FirebaseFirestore.instance.collection('Advertisements').doc(adId).update({
//         'endDate': newEndDate,
//         'status': 'active',
//         'renewalCount': FieldValue.increment(1),
//         'updatedAt': now,
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Publicité prolongée de $days jours'),
//           backgroundColor: _successColor,
//         ),
//       );
//
//       setState(() {
//         _selectedAdId = null;
//         _extensionDays = null;
//         _extensionController.clear();
//       });
//       _loadGlobalStats();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
//       );
//     }
//   }
//
//   Widget _buildStatsOverview() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       margin: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _secondaryColor),
//       ),
//       child: Column(
//         children: [
//           Text('APERÇU GLOBAL', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
//           SizedBox(height: 20),
//
//           // Première ligne de stats
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildStatCard(Iconsax.dollar_circle, 'Total Ads', '$_totalAds', _primaryColor),
//               _buildStatCard(Iconsax.activity, 'Actives', '$_activeAds', Colors.green),
//               _buildStatCard(Iconsax.eye, 'Vues', _formatNumber(_totalViews), Colors.blue),
//             ],
//           ),
//           SizedBox(height: 16),
//
//           // Deuxième ligne de stats
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildStatCard(Icons.ads_click, 'Clics', _formatNumber(_totalClicks), _secondaryColor),
//               _buildStatCard(Icons.person, 'Vues uniques', _formatNumber(_totalUniqueViews), Colors.purple),
//               _buildStatCard(Iconsax.chart, 'CTR', '${_globalCTR.toStringAsFixed(1)}%',
//                   _globalCTR > 5 ? Colors.green : Colors.orange),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatCard(IconData icon, String label, String value, Color color) {
//     return Column(
//       children: [
//         Container(
//           padding: EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: color.withOpacity(0.3)),
//           ),
//           child: Icon(icon, color: color, size: 22),
//         ),
//         SizedBox(height: 8),
//         Text(value,
//             style: TextStyle(
//                 color: _textColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16
//             )
//         ),
//         Text(label,
//             style: TextStyle(
//                 color: _hintColor,
//                 fontSize: 11
//             )
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTopPerformers() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Top par vues
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: _cardColor,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: Colors.blue.withOpacity(0.3)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.trending_up, color: Colors.blue, size: 20),
//                     SizedBox(width: 8),
//                     Text('TOP 5 - Plus vues',
//                         style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 12),
//                 if (_topAdsByViews.isEmpty)
//                   Text('Aucune donnée', style: TextStyle(color: _hintColor))
//                 else
//                   ..._topAdsByViews.asMap().entries.map((entry) {
//                     final rank = entry.key + 1;
//                     final adEntry = entry.value;
//                     return Container(
//                       margin: EdgeInsets.only(bottom: 8),
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: _backgroundColor,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 24,
//                             height: 24,
//                             decoration: BoxDecoration(
//                               color: rank <= 3 ? Colors.blue.withOpacity(0.2) : Colors.transparent,
//                               shape: BoxShape.circle,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 '$rank',
//                                 style: TextStyle(
//                                   color: rank <= 3 ? Colors.blue : _hintColor,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'ID: ${adEntry.key.substring(0, 6)}...',
//                               style: TextStyle(color: _textColor, fontSize: 13),
//                             ),
//                           ),
//                           Text(
//                             '${_formatNumber(adEntry.value)} vues',
//                             style: TextStyle(
//                               color: Colors.blue,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }),
//               ],
//             ),
//           ),
//
//           SizedBox(height: 12),
//
//           // Top par clics
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: _cardColor,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: _secondaryColor.withOpacity(0.3)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.ads_click, color: _secondaryColor, size: 20),
//                     SizedBox(width: 8),
//                     Text('TOP 5 - Plus cliquées',
//                         style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 12),
//                 if (_topAdsByClicks.isEmpty)
//                   Text('Aucune donnée', style: TextStyle(color: _hintColor))
//                 else
//                   ..._topAdsByClicks.asMap().entries.map((entry) {
//                     final rank = entry.key + 1;
//                     final adEntry = entry.value;
//                     return Container(
//                       margin: EdgeInsets.only(bottom: 8),
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: _backgroundColor,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Container(
//                             width: 24,
//                             height: 24,
//                             decoration: BoxDecoration(
//                               color: rank <= 3 ? _secondaryColor.withOpacity(0.2) : Colors.transparent,
//                               shape: BoxShape.circle,
//                             ),
//                             child: Center(
//                               child: Text(
//                                 '$rank',
//                                 style: TextStyle(
//                                   color: rank <= 3 ? _secondaryColor : _hintColor,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'ID: ${adEntry.key.substring(0, 6)}...',
//                               style: TextStyle(color: _textColor, fontSize: 13),
//                             ),
//                           ),
//                           Text(
//                             '${_formatNumber(adEntry.value)} clics',
//                             style: TextStyle(
//                               color: _secondaryColor,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRecentActivity() {
//     if (_dailyActivity.isEmpty) return SizedBox.shrink();
//
//     // Prendre les 7 derniers jours
//     final recentDays = _dailyActivity.entries.toList()
//       ..sort((a, b) => b.key.compareTo(a.key));
//     final last7Days = recentDays.take(7).toList();
//
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: _primaryColor, size: 20),
//               SizedBox(width: 8),
//               Text('Activité récente (7 jours)',
//                   style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)
//               ),
//             ],
//           ),
//           SizedBox(height: 16),
//           ...last7Days.map((entry) {
//             return Container(
//               margin: EdgeInsets.only(bottom: 8),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 70,
//                     child: Text(
//                       entry.key,
//                       style: TextStyle(color: _hintColor, fontSize: 12),
//                     ),
//                   ),
//                   Expanded(
//                     child: LinearProgressIndicator(
//                       value: entry.value / _dailyActivity.values.reduce((a, b) => a > b ? a : b),
//                       backgroundColor: _backgroundColor,
//                       valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
//                       minHeight: 8,
//                     ),
//                   ),
//                   SizedBox(width: 8),
//                   Text(
//                     _formatNumber(entry.value),
//                     style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
//                   ),
//                 ],
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAdCard(DocumentSnapshot doc) {
//     final ad = Advertisement.fromJson(doc.data() as Map<String, dynamic>);
//
//     Color statusColor;
//     String statusText;
//     IconData statusIcon;
//
//     switch(ad.status) {
//       case 'active':
//         statusColor = Colors.green;
//         statusText = 'Active';
//         statusIcon = Icons.check_circle;
//         break;
//       case 'pending':
//         statusColor = Colors.orange;
//         statusText = 'En attente';
//         statusIcon = Icons.hourglass_empty;
//         break;
//       case 'expired':
//         statusColor = Colors.grey;
//         statusText = 'Expirée';
//         statusIcon = Icons.timer_off;
//         break;
//       case 'rejected':
//         statusColor = Colors.red;
//         statusText = 'Rejetée';
//         statusIcon = Icons.cancel;
//         break;
//       case 'cancelled':
//         statusColor = Colors.red;
//         statusText = 'Annulée';
//         statusIcon = Icons.cancel;
//         break;
//       default:
//         statusColor = Colors.grey;
//         statusText = ad.status ?? 'Inconnu';
//         statusIcon = Icons.help;
//     }
//
//     return FutureBuilder<DocumentSnapshot>(
//       future: FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get(),
//       builder: (context, postSnapshot) {
//         String? imageUrl;
//         String? description;
//
//         if (postSnapshot.hasData && postSnapshot.data!.exists) {
//           final postData = postSnapshot.data!.data() as Map<String, dynamic>;
//           imageUrl = (postData['images'] as List?)?.isNotEmpty == true
//               ? (postData['images'] as List).first
//               : null;
//           description = postData['description'];
//         }
//
//         return Container(
//           margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           decoration: BoxDecoration(
//             color: _cardColor,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: ad.status == 'pending' ? _secondaryColor : Colors.grey[800]!,
//               width: ad.status == 'pending' ? 2 : 1,
//             ),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // En-tête avec statut
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: _backgroundColor,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(15),
//                     topRight: Radius.circular(15),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: statusColor.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Icon(statusIcon, color: statusColor, size: 16),
//                     ),
//                     SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'ID: ${ad.id?.substring(0, 6)}...',
//                             style: TextStyle(
//                               color: _textColor,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text(
//                             'Créé le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMicrosecondsSinceEpoch(ad.createdAt ?? 0))}',
//                             style: TextStyle(color: _hintColor, fontSize: 10),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                       decoration: BoxDecoration(
//                         color: statusColor.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: statusColor),
//                       ),
//                       child: Text(
//                         statusText,
//                         style: TextStyle(
//                           color: statusColor,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Image si disponible
//               if (imageUrl != null)
//                 Image.network(
//                   imageUrl,
//                   height: 150,
//                   width: double.infinity,
//                   fit: BoxFit.cover,
//                   errorBuilder: (context, error, stackTrace) {
//                     return Container(
//                       height: 150,
//                       color: Colors.grey[900],
//                       child: Center(
//                         child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
//                       ),
//                     );
//                   },
//                 ),
//
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Description
//                     if (description != null)
//                       Text(
//                         description,
//                         style: TextStyle(color: _textColor, fontSize: 14),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//
//                     SizedBox(height: 12),
//
//                     // Type d'action
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                       decoration: BoxDecoration(
//                         color: _primaryColor.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(
//                             ad.getActionIcon(),
//                             color: _primaryColor,
//                             size: 14,
//                           ),
//                           SizedBox(width: 4),
//                           Text(
//                             ad.getActionButtonText(),
//                             style: TextStyle(
//                               color: _primaryColor,
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     SizedBox(height: 8),
//
//                     // Lien
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.grey[900],
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.link, color: _hintColor, size: 14),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               ad.actionUrl ?? '',
//                               style: TextStyle(color: _secondaryColor, fontSize: 12),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     SizedBox(height: 12),
//
//                     // Statistiques de performance
//                     Container(
//                       padding: EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.grey[900]!,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Column(
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceAround,
//                             children: [
//                               _buildStatItem('Vues', '${_formatNumber(ad.views ?? 0)}', Icons.remove_red_eye, Colors.blue),
//                               _buildStatItem('Clics', '${_formatNumber(ad.clicks ?? 0)}', Icons.ads_click, _secondaryColor),
//                               _buildStatItem('CTR', '${ad.ctr.toStringAsFixed(1)}%', Icons.trending_up,
//                                   ad.ctr > 5 ? Colors.green : Colors.orange),
//                               _buildStatItem('Uniques', '${_formatNumber(ad.uniqueClicks ?? 0)}', Icons.person, Colors.purple),
//                             ],
//                           ),
//                           if (ad.dailyStats != null && ad.dailyStats!.isNotEmpty)
//                             Padding(
//                               padding: EdgeInsets.only(top: 8),
//                               child: Text(
//                                 'Dernière activité: ${ad.dailyStats!.entries.last.key}',
//                                 style: TextStyle(color: _hintColor, fontSize: 10),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//
//                     SizedBox(height: 12),
//
//                     // Durée
//                     Row(
//                       children: [
//                         Icon(Icons.calendar_today, color: _hintColor, size: 14),
//                         SizedBox(width: 8),
//                         Text(
//                           'Durée: ${ad.durationDays} jours',
//                           style: TextStyle(color: _textColor, fontSize: 12),
//                         ),
//                         SizedBox(width: 16),
//                         Icon(Icons.update, color: _hintColor, size: 14),
//                         SizedBox(width: 8),
//                         Text(
//                           'Renouvellements: ${ad.renewalCount}',
//                           style: TextStyle(color: _textColor, fontSize: 12),
//                         ),
//                       ],
//                     ),
//
//                     SizedBox(height: 8),
//
//                     // Dates
//                     Row(
//                       children: [
//                         Icon(Icons.play_arrow, color: Colors.green, size: 14),
//                         SizedBox(width: 8),
//                         Text(
//                           'Début: ${ad.startDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!)) : 'N/A'}',
//                           style: TextStyle(color: _hintColor, fontSize: 11),
//                         ),
//                         SizedBox(width: 16),
//                         Icon(Icons.stop, color: Colors.red, size: 14),
//                         SizedBox(width: 8),
//                         Text(
//                           'Fin: ${ad.endDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!)) : 'N/A'}',
//                           style: TextStyle(color: _hintColor, fontSize: 11),
//                         ),
//                       ],
//                     ),
//
//                     if (ad.rejectionReason != null) ...[
//                       SizedBox(height: 8),
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Colors.red.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.red),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.warning, color: Colors.red, size: 14),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Motif: ${ad.rejectionReason}',
//                                 style: TextStyle(color: Colors.red, fontSize: 11),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//
//                     // Actions
//                     Padding(
//                       padding: EdgeInsets.only(top: 16),
//                       child: Row(
//                         children: [
//                           if (ad.status == 'pending') ...[
//                             Expanded(
//                               child: ElevatedButton.icon(
//                                 onPressed: () => _updateAdStatus(ad.id!, 'active'),
//                                 icon: Icon(Icons.check, size: 16),
//                                 label: Text('Accepter'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green,
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: ElevatedButton.icon(
//                                 onPressed: () {
//                                   showDialog(
//                                     context: context,
//                                     builder: (context) => _buildRejectionDialog(ad.id!),
//                                   );
//                                 },
//                                 icon: Icon(Icons.close, size: 16),
//                                 label: Text('Rejeter'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.red,
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//
//                           if (ad.status == 'active' || ad.status == 'expired') ...[
//                             Expanded(
//                               child: OutlinedButton.icon(
//                                 onPressed: ad.status == 'active'
//                                     ? () => _updateAdStatus(ad.id!, 'cancelled')
//                                     : null,
//                                 icon: Icon(Icons.cancel, size: 16),
//                                 label: Text('Annuler'),
//                                 style: OutlinedButton.styleFrom(
//                                   foregroundColor: Colors.red,
//                                   side: BorderSide(color: Colors.red),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: ElevatedButton.icon(
//                                 onPressed: () {
//                                   showDialog(
//                                     context: context,
//                                     builder: (context) => _buildRenewalDialog(ad.id!),
//                                   );
//                                 },
//                                 icon: Icon(Icons.update, size: 16),
//                                 label: Text('Prolonger'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: _secondaryColor,
//                                   foregroundColor: Colors.black,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//
//                           // Bouton Supprimer (toujours présent)
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: OutlinedButton.icon(
//                               onPressed: () => _deleteAd(ad.id!),
//                               icon: Icon(Icons.delete, size: 16),
//                               label: Text('Supprimer'),
//                               style: OutlinedButton.styleFrom(
//                                 foregroundColor: Colors.red,
//                                 side: BorderSide(color: Colors.red),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildStatItem(String label, String value, IconData icon, Color color) {
//     return Column(
//       children: [
//         Icon(icon, color: color, size: 16),
//         SizedBox(height: 2),
//         Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 12)),
//         Text(label, style: TextStyle(color: _hintColor, fontSize: 9)),
//       ],
//     );
//   }
//
//   Widget _buildRejectionDialog(String adId) {
//     return AlertDialog(
//       backgroundColor: _cardColor,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       title: Row(
//         children: [
//           Icon(Icons.warning, color: Colors.red),
//           SizedBox(width: 10),
//           Text('Rejeter la publicité', style: TextStyle(color: _textColor)),
//         ],
//       ),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text('Veuillez indiquer le motif du rejet', style: TextStyle(color: _hintColor)),
//           SizedBox(height: 16),
//           TextField(
//             controller: _rejectionController,
//             style: TextStyle(color: _textColor),
//             maxLines: 3,
//             decoration: InputDecoration(
//               hintText: 'Motif...',
//               hintStyle: TextStyle(color: _hintColor),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: Colors.grey[700]!),
//               ),
//               filled: true,
//               fillColor: _backgroundColor,
//             ),
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: Text('ANNULER', style: TextStyle(color: _hintColor)),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_rejectionController.text.isNotEmpty) {
//               _updateAdStatus(adId, 'rejected', reason: _rejectionController.text);
//               Navigator.pop(context);
//             }
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.red,
//             foregroundColor: Colors.white,
//           ),
//           child: Text('REJETER'),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildRenewalDialog(String adId) {
//     final List<int> extensionOptions = [7, 14, 30, 60, 90];
//
//     return AlertDialog(
//       backgroundColor: _cardColor,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       title: Row(
//         children: [
//           Icon(Icons.update, color: _secondaryColor),
//           SizedBox(width: 10),
//           Text('Prolonger la publicité', style: TextStyle(color: _textColor)),
//         ],
//       ),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Sélectionnez la durée de prolongation', style: TextStyle(color: _hintColor)),
//           SizedBox(height: 16),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: extensionOptions.map((days) {
//               return GestureDetector(
//                 onTap: () => setState(() => _extensionDays = days),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   decoration: BoxDecoration(
//                     color: _extensionDays == days ? _secondaryColor : _backgroundColor,
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: _extensionDays == days ? _secondaryColor : Colors.grey[700]!),
//                   ),
//                   child: Text(
//                     days < 30 ? '$days jours' : days == 30 ? '1 mois' : days == 60 ? '2 mois' : '3 mois',
//                     style: TextStyle(
//                       color: _extensionDays == days ? Colors.black : _textColor,
//                       fontWeight: _extensionDays == days ? FontWeight.bold : FontWeight.normal,
//                     ),
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: Text('ANNULER', style: TextStyle(color: _hintColor)),
//         ),
//         ElevatedButton(
//           onPressed: _extensionDays != null
//               ? () {
//             _renewAd(adId, _extensionDays!);
//             Navigator.pop(context);
//           }
//               : null,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: _secondaryColor,
//             foregroundColor: Colors.black,
//           ),
//           child: Text('PROLONGER'),
//         ),
//       ],
//     );
//   }
//
//   String _formatNumber(int number) {
//     if (number >= 1000000) {
//       return '${(number / 1000000).toStringAsFixed(1)}M';
//     } else if (number >= 1000) {
//       return '${(number / 1000).toStringAsFixed(1)}K';
//     }
//     return number.toString();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _backgroundColor,
//       appBar: AppBar(
//         backgroundColor: _cardColor,
//         title: Text(
//           'Gestion des publicités',
//           style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
//         ),
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: _secondaryColor,
//           labelColor: _secondaryColor,
//           unselectedLabelColor: _hintColor,
//           tabs: const [
//             Tab(text: 'Stats'),
//             Tab(text: 'En attente'),
//             Tab(text: 'Actives'),
//             Tab(text: 'Expirées'),
//             Tab(text: 'Rejetées'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // Onglet Statistiques - Sans graphiques
//           SingleChildScrollView(
//             child: Column(
//               children: [
//                 _buildStatsOverview(),
//                 _buildTopPerformers(),
//                 _buildRecentActivity(),
//                 SizedBox(height: 20),
//               ],
//             ),
//           ),
//
//           // En attente
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('Advertisements')
//                 .where('status', isEqualTo: 'pending')
//                 .orderBy('createdAt', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
//               }
//               if (!snapshot.hasData) {
//                 return Center(
//                   child: LoadingAnimationWidget.flickr(
//                     size: 50,
//                     leftDotColor: _primaryColor,
//                     rightDotColor: _secondaryColor,
//                   ),
//                 );
//               }
//               if (snapshot.data!.docs.isEmpty) {
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Iconsax.dollar_circle, size: 80, color: _hintColor),
//                       SizedBox(height: 16),
//                       Text('Aucune publicité en attente', style: TextStyle(color: _hintColor)),
//                     ],
//                   ),
//                 );
//               }
//               return ListView.builder(
//                 padding: EdgeInsets.all(16),
//                 itemCount: snapshot.data!.docs.length,
//                 itemBuilder: (context, index) {
//                   return _buildAdCard(snapshot.data!.docs[index]);
//                 },
//               );
//             },
//           ),
//
//           // Actives
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('Advertisements')
//                 .where('status', isEqualTo: 'active')
//                 .orderBy('createdAt', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
//               }
//               if (!snapshot.hasData) {
//                 return Center(
//                   child: LoadingAnimationWidget.flickr(
//                     size: 50,
//                     leftDotColor: _primaryColor,
//                     rightDotColor: _secondaryColor,
//                   ),
//                 );
//               }
//               if (snapshot.data!.docs.isEmpty) {
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Iconsax.dollar_circle, size: 80, color: _hintColor),
//                       SizedBox(height: 16),
//                       Text('Aucune publicité active', style: TextStyle(color: _hintColor)),
//                     ],
//                   ),
//                 );
//               }
//               return ListView.builder(
//                 padding: EdgeInsets.all(16),
//                 itemCount: snapshot.data!.docs.length,
//                 itemBuilder: (context, index) {
//                   return _buildAdCard(snapshot.data!.docs[index]);
//                 },
//               );
//             },
//           ),
//
//           // Expirées
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('Advertisements')
//                 .where('status', isEqualTo: 'expired')
//                 .orderBy('createdAt', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
//               }
//               if (!snapshot.hasData) {
//                 return Center(
//                   child: LoadingAnimationWidget.flickr(
//                     size: 50,
//                     leftDotColor: _primaryColor,
//                     rightDotColor: _secondaryColor,
//                   ),
//                 );
//               }
//               if (snapshot.data!.docs.isEmpty) {
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Iconsax.dollar_circle, size: 80, color: _hintColor),
//                       SizedBox(height: 16),
//                       Text('Aucune publicité expirée', style: TextStyle(color: _hintColor)),
//                     ],
//                   ),
//                 );
//               }
//               return ListView.builder(
//                 padding: EdgeInsets.all(16),
//                 itemCount: snapshot.data!.docs.length,
//                 itemBuilder: (context, index) {
//                   return _buildAdCard(snapshot.data!.docs[index]);
//                 },
//               );
//             },
//           ),
//
//           // Rejetées
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('Advertisements')
//                 .where('status', isEqualTo: 'rejected')
//                 .orderBy('createdAt', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
//               }
//               if (!snapshot.hasData) {
//                 return Center(
//                   child: LoadingAnimationWidget.flickr(
//                     size: 50,
//                     leftDotColor: _primaryColor,
//                     rightDotColor: _secondaryColor,
//                   ),
//                 );
//               }
//               if (snapshot.data!.docs.isEmpty) {
//                 return Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Iconsax.dollar_circle, size: 80, color: _hintColor),
//                       SizedBox(height: 16),
//                       Text('Aucune publicité rejetée', style: TextStyle(color: _hintColor)),
//                     ],
//                   ),
//                 );
//               }
//               return ListView.builder(
//                 padding: EdgeInsets.all(16),
//                 itemCount: snapshot.data!.docs.length,
//                 itemBuilder: (context, index) {
//                   return _buildAdCard(snapshot.data!.docs[index]);
//                 },
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }