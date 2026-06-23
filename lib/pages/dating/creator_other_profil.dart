// lib/pages/creator/creator_profile_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/dating/coin_service.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
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
      printVm('❌ Erreur chargement profil créateur: $e');
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
      printVm('❌ Erreur enregistrement vue: $e');
    }
  }

  Future<void> _withdrawCoins() async {
    final t = AppLocalizations.of(context);
    if (_wallet == null || _wallet!.balanceCoins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.creatorNoCoinsToWithdraw), backgroundColor: Colors.orange),
      );
      return;
    }

    final amountController = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.of(context).surface,
        title: Text(t.creatorWithdrawCoinsDialogTitle, style: TextStyle(color: AppColors.of(context).textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.creatorCurrentBalanceLabel.replaceAll('{balance}', '${_wallet!.balanceCoins}'), style: TextStyle(color: AppColors.of(context).textPrimary)),
            SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.of(context).textPrimary),
              decoration: InputDecoration(
                labelText: t.creatorCoinsAmountLabel,
                labelStyle: TextStyle(color: AppColors.of(context).textSecondary),
                filled: true,
                fillColor: AppColors.of(context).surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 8),
            Text(t.creatorConversionRateLabel, style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text(t.datingCancelButton, style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(amountController.text.trim());
              if (value != null && value > 0 && value <= _wallet!.balanceCoins) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.creatorInvalidAmount), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            child: Text(t.creatorValidateButton, style: TextStyle(color: Colors.black)),
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
          SnackBar(content: Text(t.creatorCoinsConvertedSuccess.replaceAll('{count}', '$amount')), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.creatorConversionError), backgroundColor: Colors.red));
      }
    } catch (e) {
      printVm('❌ Erreur conversion: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.creatorRegisterError}: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToCreateContent() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorContentFormPage())).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryRed),
              SizedBox(height: 16),
              Text(t.datingLoadingText, style: TextStyle(color: AppColors.of(context).textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: Center(child: Text(t.creatorProfileNotFound, style: TextStyle(color: AppColors.of(context).textPrimary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
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
                    _cdnUrl(_profile!.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppColors.of(context).surfaceVariant),
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
                            _buildStatChip(t.creatorSubscribersCount.replaceAll('{count}', '${_profile!.subscribersCount}'), Icons.people),
                            SizedBox(width: 8),
                            _buildStatChip(t.creatorViewsCount.replaceAll('{count}', '${_profile!.totalViews}'), Icons.visibility),
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
                  tooltip: t.creatorAddContentTooltip,
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
                  child: Text(t.creatorSubscribeButton),
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
                  color: AppColors.of(context).surface,
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
                            Text(t.creatorWalletTitle, style: TextStyle(color: AppColors.of(context).textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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
                            child: Text(t.creatorWithdrawButton, style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.creatorBalanceCoinsLabel, style: TextStyle(color: AppColors.of(context).textSecondary)),
                        Text(t.creatorPriceCoinsShort.replaceAll('{price}', '${_wallet?.balanceCoins ?? 0}'), style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.creatorTotalEarnedLabel, style: TextStyle(color: AppColors.of(context).textSecondary)),
                        Text(t.creatorPriceCoinsShort.replaceAll('{price}', '${_wallet?.totalEarnedCoins ?? 0}'), style: TextStyle(color: AppColors.of(context).textPrimary)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.creatorTotalConvertedLabel, style: TextStyle(color: AppColors.of(context).textSecondary)),
                        Text(t.creatorPriceCoinsShort.replaceAll('{price}', '${_wallet?.totalConvertedCoins ?? 0}'), style: TextStyle(color: AppColors.of(context).textPrimary)),
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
                    (context, index) => _buildContentCard(context, _contents[index]),
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
                      Icon(Icons.article_outlined, size: 80, color: AppColors.of(context).textSecondary),
                      SizedBox(height: 16),
                      Text(
                        _isOwner ? t.creatorNoPublishedContent : t.creatorNoContentYet,
                        style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 16),
                      ),
                      if (_isOwner)
                        ElevatedButton(
                          onPressed: _goToCreateContent,
                          child: Text(t.creatorCreateFirstContent),
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

  Widget _buildContentCard(BuildContext context, CreatorContent content) {
    final t = AppLocalizations.of(context);
    final canAccess = !content.isPaid || _isSubscribed || _isOwner;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorContentDetailPage(content: content)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.of(context).surface,
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
                      _cdnUrl(content.thumbnailUrl ?? content.mediaUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(color: AppColors.of(context).surfaceVariant),
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
                              Text(t.creatorSubscriptionRequired, style: TextStyle(color: Colors.white, fontSize: 10)),
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
                            t.creatorPriceCoinsShort.replaceAll('{price}', '${content.priceCoins}'),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.of(context).textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 10, color: Colors.red),
                      SizedBox(width: 2),
                      Text('${content.likesCount + content.lovesCount}', style: TextStyle(fontSize: 10, color: AppColors.of(context).textSecondary)),
                      SizedBox(width: 8),
                      Icon(Icons.visibility, size: 10, color: AppColors.of(context).textSecondary),
                      SizedBox(width: 2),
                      Text('${content.viewsCount}', style: TextStyle(fontSize: 10, color: AppColors.of(context).textSecondary)),
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

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }
}