// user_my_advertisements_page.dart
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../paiement/depotPaiment.dart';
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

  // État du filtre sélectionné
  String _selectedStatus = 'pending'; // pending, active, expired, rejected

  // Compteurs pour le dashboard
  int _pendingCount = 0;
  int _activeCount = 0;
  int _expiredCount = 0;
  int _rejectedCount = 0;
  int _totalSpent = 0; // Total dépensé en publicités (optionnel)
  bool _loadingCounts = true;

  final Color _primaryColor = const Color(0xFFE21221);
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;
  final Color _successColor = const Color(0xFF4CAF50);

  // Tarifs pour renouvellement
  final Map<int, int> _durationPrices = {
    2: 2500,
    4: 4500,
    12: 10000,
    24: 18000,
    52: 30000,
  };
  final List<int> _durationOptions = [2, 4, 12, 24, 52];

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadCounters();
  }

  // Charger les compteurs pour le dashboard
  Future<void> _loadCounters() async {
    setState(() => _loadingCounts = true);
    try {
      final userId = authProvider.loginUserData.id;
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Advertisements')
          .where('createdBy', isEqualTo: userId)
          .get();

      int pending = 0, active = 0, expired = 0, rejected = 0;
      for (var doc in snapshot.docs) {
        final status = doc['status'] as String?;
        switch (status) {
          case 'pending': pending++; break;
          case 'active': active++; break;
          case 'expired': expired++; break;
          case 'rejected': rejected++; break;
        }
      }
      setState(() {
        _pendingCount = pending;
        _activeCount = active;
        _expiredCount = expired;
        _rejectedCount = rejected;
        _loadingCounts = false;
      });
    } catch (e) {
      print('Erreur chargement compteurs: $e');
      setState(() => _loadingCounts = false);
    }
  }

  Stream<QuerySnapshot> _getUserAdsStream() {
    Query query = FirebaseFirestore.instance
        .collection('Advertisements')
        .where('createdBy', isEqualTo: authProvider.loginUserData.id)
        .orderBy('createdAt', descending: true);
    if (_selectedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }

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
        // 1. Débiter sur Firestore
        await FirebaseFirestore.instance.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-price),
        });

        // 2. Mettre à jour le solde LOCAL
        setState(() {
          authProvider.loginUserData.votre_solde_principal = (authProvider.loginUserData.votre_solde_principal ?? 0) - price;
        });

        await _createTransaction(price, 'Renouvellement publicité ${ad.id} (${_getDurationLabel(weeks)})');
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      int newEndDate;
      if (ad.isExpired) {
        newEndDate = now + (daysToAdd * 24 * 60 * 60 * 1000000);
      } else {
        newEndDate = (ad.endDate ?? now) + (daysToAdd * 24 * 60 * 60 * 1000000);
      }
      int additionalPrice = _durationPrices[weeks]!;

      await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).update({
        'endDate': newEndDate,
        'status': 'active',
        'renewalCount': FieldValue.increment(1),
        'pricePaid': FieldValue.increment(additionalPrice),

        'updatedAt': now,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publicité prolongée de ${_getDurationLabel(weeks)}'),
          backgroundColor: _successColor,
        ),
      );
      _loadCounters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
      );
    }
  }
  Future<void> _createTransaction(int amount, String reason) async {
    final transaction = TransactionSolde()
      ..id = FirebaseFirestore.instance.collection('TransactionSoldes').doc().id
      ..user_id = authProvider.loginUserData.id
      ..type = TypeTransaction.DEPENSE.name
      ..statut = StatutTransaction.VALIDER.name
      ..description = reason
      ..montant = amount.toDouble()
      ..methode_paiement = "publicité"
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Solde insuffisant', style: TextStyle(color: _secondaryColor)),
        content: Text('Vous n\'avez pas assez de crédits pour ce renouvellement. Veuillez recharger.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
            },
            child: Text('Recharger'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAd(Advertisement ad) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Confirmer la suppression', style: TextStyle(color: _textColor)),
        content: Text('Voulez-vous vraiment supprimer cette publicité ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('Advertisements').doc(ad.id).delete();
                if (ad.postId != null) {
                  await FirebaseFirestore.instance.collection('Posts').doc(ad.postId).delete();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Publicité supprimée'), backgroundColor: _successColor),
                );
                _loadCounters(); // Rafraîchir
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: _primaryColor),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }

  void _showRenewalDialog(Advertisement ad) {
    int? selectedWeek;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.update, color: _secondaryColor),
                SizedBox(width: 10),
                Text('Prolonger la publicité', style: TextStyle(color: _textColor)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisissez la durée', style: TextStyle(color: _hintColor)),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _durationOptions.map((week) {
                    final isSelected = selectedWeek == week;
                    return GestureDetector(
                      onTap: () => setStateDialog(() => selectedWeek = week),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _secondaryColor : _backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? _secondaryColor : Colors.grey[700]!),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _getDurationLabel(week),
                              style: TextStyle(
                                color: isSelected ? Colors.black : _textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '${_durationPrices[week]} FCFA',
                              style: TextStyle(color: isSelected ? Colors.black54 : _hintColor, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('ANNULER', style: TextStyle(color: _hintColor))),
              ElevatedButton(
                onPressed: selectedWeek != null
                    ? () {
                  Navigator.pop(context);
                  _renewAd(ad, selectedWeek!);
                }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor, foregroundColor: Colors.black),
                child: Text('PROLONGER'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDurationLabel(int weeks) {
    switch (weeks) {
      case 2: return '2 semaines';
      case 4: return '1 mois';
      case 12: return '3 mois';
      case 24: return '6 mois';
      case 52: return '12 mois';
      default: return '$weeks semaines';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(height: 2),
        Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(color: _hintColor, fontSize: 9)),
      ],
    );
  }

  Widget _buildAdCard(Advertisement ad, DocumentSnapshot? postSnapshot) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (ad.status) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Active';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusText = 'Expirée';
        statusIcon = Icons.timer_off;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejetée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = ad.status ?? 'Inconnu';
        statusIcon = Icons.help;
    }

    String? imageUrl;
    String? description;
    if (postSnapshot != null && postSnapshot.exists) {
      final postData = postSnapshot.data() as Map<String, dynamic>;
      imageUrl = (postData['images'] as List?)?.isNotEmpty == true
          ? (postData['images'] as List).first
          : null;
      description = postData['description'];
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserAdDetailPage(advertisementId: ad.id!),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ad.status == 'pending' ? _secondaryColor : Colors.grey[800]!,
            width: ad.status == 'pending' ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Icon(statusIcon, color: statusColor, size: 16),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${ad.id?.substring(0, 6)}...',
                          style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Créé le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMicrosecondsSinceEpoch(ad.createdAt ?? 0))}',
                          style: TextStyle(color: _hintColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            if (imageUrl != null)
              Image.network(
                imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey[900], child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null)
                    Text(description, style: TextStyle(color: _textColor, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[900]!, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Vues', _formatNumber(ad.views ?? 0), Icons.remove_red_eye, Colors.blue),
                        _buildStatItem('Clics', _formatNumber(ad.clicks ?? 0), Icons.ads_click, _secondaryColor),
                        _buildStatItem('CTR', '${ad.ctr.toStringAsFixed(1)}%', Icons.trending_up, ad.ctr > 5 ? Colors.green : Colors.orange),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.play_arrow, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text('Début: ${ad.startDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.startDate!)) : 'N/A'}', style: TextStyle(color: _hintColor, fontSize: 10)),
                      SizedBox(width: 12),
                      Icon(Icons.stop, color: Colors.red, size: 14),
                      SizedBox(width: 4),
                      Text('Fin: ${ad.endDate != null ? DateFormat('dd/MM/yy').format(DateTime.fromMicrosecondsSinceEpoch(ad.endDate!)) : 'N/A'}', style: TextStyle(color: _hintColor, fontSize: 10)),
                    ],
                  ),
                  if (ad.rejectionReason != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 14),
                            SizedBox(width: 8),
                            Expanded(child: Text('Motif: ${ad.rejectionReason}', style: TextStyle(color: Colors.red, fontSize: 11))),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      if (ad.status == 'active' || ad.status == 'expired')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showRenewalDialog(ad),
                            icon: Icon(Icons.update, size: 16),
                            label: Text('Renouveler'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _secondaryColor,
                              side: BorderSide(color: _secondaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteAd(ad),
                          icon: Icon(Icons.delete, size: 16),
                          label: Text('Supprimer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dashboard avec cartes statistiques
  Widget _buildDashboard() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          // Bandeau informatif incitatif
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up, color: _secondaryColor, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Boostez votre visibilité !',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Créez une publicité et touchez plus de 10 000 utilisateurs à travers l\'Afrique. Commencez dès maintenant !',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UserCreateAdvertisementPage()));
                  },
                  icon: Icon(Icons.add_circle, color: _secondaryColor),
                  label: Text('CRÉER UNE NOUVELLE PUBLICITÉ', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Cartes de statistiques
          if (!_loadingCounts)
            Row(
              children: [
                _buildStatusCard('En attente', _pendingCount, Icons.hourglass_empty, Colors.orange, 'pending'),
                _buildStatusCard('Actives', _activeCount, Icons.check_circle, Colors.green, 'active'),
                _buildStatusCard('Expirées', _expiredCount, Icons.timer_off, Colors.grey, 'expired'),
                _buildStatusCard('Rejetées', _rejectedCount, Icons.cancel, Colors.red, 'rejected'),
              ],
            )
          else
            Center(child: CircularProgressIndicator(color: _primaryColor)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, int count, IconData icon, Color color, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey[800]!, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                title,
                style: TextStyle(color: _hintColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Text('Mes publicités', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: _secondaryColor),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserCreateAdvertisementPage()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCounters();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildDashboard(),
              // Liste des publicités selon le filtre
              StreamBuilder<QuerySnapshot>(
                stream: _getUserAdsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return Center(child: LoadingAnimationWidget.flickr(size: 50, leftDotColor: _primaryColor, rightDotColor: _secondaryColor));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Iconsax.dollar_circle, size: 80, color: _hintColor),
                          SizedBox(height: 16),
                          Text('Aucune publicité ${_getStatusText(_selectedStatus).toLowerCase()}', style: TextStyle(color: _hintColor)),
                          SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserCreateAdvertisementPage()));
                            },
                            icon: Icon(Icons.add, color: _primaryColor),
                            label: Text('Créer une publicité', style: TextStyle(color: _primaryColor)),
                          ),
                        ],
                      ),
                    );
                  }

                  return FutureBuilder<List<DocumentSnapshot?>>(
                    future: Future.wait(docs.map((doc) async {
                      final ad = Advertisement.fromJson(doc.data() as Map<String, dynamic>);
                      if (ad.postId == null) return null;
                      return FirebaseFirestore.instance.collection('Posts').doc(ad.postId).get();
                    })),
                    builder: (context, postSnapshots) {
                      if (postSnapshots.connectionState == ConnectionState.waiting) {
                        return Center(child: LoadingAnimationWidget.flickr(size: 50, leftDotColor: _primaryColor, rightDotColor: _secondaryColor));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.only(bottom: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final ad = Advertisement.fromJson(docs[index].data() as Map<String, dynamic>);
                          final postSnapshot = postSnapshots.data?[index];
                          return _buildAdCard(ad, postSnapshot);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'en attente';
      case 'active': return 'active';
      case 'expired': return 'expirée';
      case 'rejected': return 'rejetée';
      default: return '';
    }
  }
}