// lib/pages/creator/creator_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/dating/coin_service.dart';
import 'creator_content_detail_page.dart';
import 'creator_subscription_page.dart';
import 'creator_content_form_page.dart';

class CreatorOtherProfilePage extends StatefulWidget {
  final String creatorId;

  const CreatorOtherProfilePage({Key? key, required this.creatorId}) : super(key: key);

  @override
  State<CreatorOtherProfilePage> createState() => _CreatorOtherProfilePageState();
}

class _CreatorOtherProfilePageState extends State<CreatorOtherProfilePage> {
  bool _isLoading = true;
  bool _isSubscribed = false;
  CreatorProfile? _profile;
  List<CreatorContent> _contents = [];
  CreatorCoinWallet? _wallet;
  bool _isOwner = false;
  String? _currentUserId;
  bool _hasRecordedView = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _currentUserId = authProvider.loginUserData.id;
    _isOwner = _currentUserId == widget.creatorId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Profil créateur
      final profileDoc = await _firestore
          .collection('creator_profiles')
          .doc(widget.creatorId)
          .get();
      if (profileDoc.exists) {
        _profile = CreatorProfile.fromJson(profileDoc.data()!);
      }

      // Contenus
      final contentsSnapshot = await _firestore
          .collection('creator_contents')
          .where('creatorId', isEqualTo: widget.creatorId)
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      _contents = contentsSnapshot.docs
          .map((doc) => CreatorContent.fromJson(doc.data()))
          .toList();

      // Abonnement (si pas propriétaire)
      if (!_isOwner && _currentUserId != null) {
        final subSnapshot = await _firestore
            .collection('creator_subscriptions')
            .where('userId', isEqualTo: _currentUserId)
            .where('creatorId', isEqualTo: widget.creatorId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        _isSubscribed = subSnapshot.docs.isNotEmpty;
      }

      // Wallet du créateur
      final walletSnapshot = await _firestore
          .collection('creator_coin_wallets')
          .where('creatorId', isEqualTo: widget.creatorId)
          .limit(1)
          .get();
      if (walletSnapshot.docs.isNotEmpty) {
        _wallet = CreatorCoinWallet.fromJson(walletSnapshot.docs.first.data());
      } else {
        // Créer un wallet par défaut
        _wallet = CreatorCoinWallet(
          id: _firestore.collection('creator_coin_wallets').doc().id,
          creatorId: widget.creatorId,
          userId: widget.creatorId,
          balanceCoins: 0,
          totalEarnedCoins: 0,
          totalConvertedCoins: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _firestore
            .collection('creator_coin_wallets')
            .doc(_wallet!.id)
            .set(_wallet!.toJson());
      }

      // Enregistrer la vue (une fois par jour)
      await _recordProfileView();

    } catch (e) {
      print('❌ Erreur chargement profil créateur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordProfileView() async {
    if (_currentUserId == null || _currentUserId == widget.creatorId) return;
    if (_hasRecordedView) return;

    try {
      final today = DateTime.now().millisecondsSinceEpoch;
      final dayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;

      final existingVisit = await _firestore
          .collection('creator_profile_visits')
          .where('visitorUserId', isEqualTo: _currentUserId)
          .where('creatorId', isEqualTo: widget.creatorId)
          .where('viewedAt', isGreaterThanOrEqualTo: dayStart)
          .limit(1)
          .get();

      if (existingVisit.docs.isNotEmpty) {
        _hasRecordedView = true;
        return;
      }

      // Enregistrer la visite
      await _firestore.collection('creator_profile_visits').add({
        'visitorUserId': _currentUserId,
        'creatorId': widget.creatorId,
        'viewedAt': today,
      });

      // Incrémenter totalViews du créateur
      await _firestore
          .collection('creator_profiles')
          .doc(widget.creatorId)
          .update({'totalViews': FieldValue.increment(1)});

      if (_profile != null) {
        _profile = _profile!.copyWith(totalViews: _profile!.totalViews + 1);
      }

      _hasRecordedView = true;
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  Future<void> _withdrawCoins() async {
    if (_wallet == null || _wallet!.balanceCoins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous n\'avez pas de pièces à encaisser'), backgroundColor: Colors.orange),
      );
      return;
    }

    final amountController = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: secondaryGrey,
        title: Text('Encaisser des pièces', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Solde actuel: ${_wallet!.balanceCoins} pièces', style: TextStyle(color: Colors.white)),
            SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre de pièces',
                labelStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 8),
            Text('Taux: 100 pièces = 250 FCFA', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(amountController.text.trim());
              if (value != null && value > 0 && value <= _wallet!.balanceCoins) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            child: Text('Valider', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final coinService = CoinService(authProvider: authProvider);
      final success = await coinService.convertCoinsToXof(creatorId: widget.creatorId, amount: amount);
      if (success) {
        // Recharger le wallet
        final newWallet = await _firestore
            .collection('creator_coin_wallets')
            .where('creatorId', isEqualTo: widget.creatorId)
            .limit(1)
            .get();
        if (newWallet.docs.isNotEmpty) {
          _wallet = CreatorCoinWallet.fromJson(newWallet.docs.first.data());
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$amount pièces converties avec succès !'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la conversion'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print('❌ Erreur conversion: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToCreateContent() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorContentFormPage())).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryRed),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: primaryBlack,
        body: Center(child: Text('Profil créateur introuvable', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: primaryBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _profile!.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: secondaryGrey),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile!.pseudo,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _profile!.bio,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatChip('${_profile!.subscribersCount} abonnés', Icons.people),
                            SizedBox(width: 8),
                            _buildStatChip('${_profile!.totalViews} vues', Icons.visibility),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isOwner)
                IconButton(
                  icon: Icon(Icons.add, color: primaryYellow),
                  onPressed: _goToCreateContent,
                  tooltip: 'Ajouter un contenu',
                ),
              if (!_isOwner && !_isSubscribed)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatorSubscriptionPage(
                          creatorId: widget.creatorId,
                          creatorName: _profile!.pseudo,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('S\'abonner'),
                ),
              if (!_isOwner && _isSubscribed)
                IconButton(
                  icon: Icon(Icons.notifications_active, color: Colors.red),
                  onPressed: () {},
                ),
            ],
          ),

          // Portefeuille (pour le propriétaire)
          if (_isOwner)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryGrey,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monetization_on, color: primaryYellow),
                            SizedBox(width: 8),
                            Text('Portefeuille créateur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        if (_wallet != null && _wallet!.balanceCoins > 0)
                          ElevatedButton(
                            onPressed: _withdrawCoins,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text('Encaisser', style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Solde en pièces :', style: TextStyle(color: Colors.grey[400])),
                        Text('${_wallet?.balanceCoins ?? 0} pièces', style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total gagné :', style: TextStyle(color: Colors.grey[400])),
                        Text('${_wallet?.totalEarnedCoins ?? 0} pièces', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total converti :', style: TextStyle(color: Colors.grey[400])),
                        Text('${_wallet?.totalConvertedCoins ?? 0} pièces', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Contenus
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildContentCard(_contents[index]),
                childCount: _contents.length,
              ),
            ),
          ),

          if (_contents.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 80, color: Colors.grey[600]),
                      SizedBox(height: 16),
                      Text(
                        _isOwner ? 'Aucun contenu publié' : 'Ce créateur n\'a pas encore de contenu',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      if (_isOwner)
                        ElevatedButton(
                          onPressed: _goToCreateContent,
                          child: Text('Créer mon premier contenu'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryYellow, foregroundColor: Colors.black),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildContentCard(CreatorContent content) {
    final canAccess = !content.isPaid || _isSubscribed || _isOwner;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorContentDetailPage(content: content)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: secondaryGrey,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      content.thumbnailUrl ?? content.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[800]),
                    ),
                    if (content.isPaid && !canAccess)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 30, color: Colors.white),
                              SizedBox(height: 4),
                              Text('Abonnement requis', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    if (content.isPaid && canAccess)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '${content.priceCoins} coins',
                            style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.titre,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 10, color: Colors.red),
                      SizedBox(width: 2),
                      Text('${content.likesCount + content.lovesCount}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      SizedBox(width: 8),
                      Icon(Icons.visibility, size: 10, color: Colors.grey[500]),
                      SizedBox(width: 2),
                      Text('${content.viewsCount}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
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
}