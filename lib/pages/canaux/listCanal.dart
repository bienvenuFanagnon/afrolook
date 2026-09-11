import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import '../../providers/postProvider.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

import '../paiement/newDepot.dart';

import 'detailsCanal.dart';

import 'newCanal.dart';

class CanalListPage extends StatefulWidget {
  final bool isUserCanals;

  CanalListPage({required this.isUserCanals});

  @override
  _CanalListPageState createState() => _CanalListPageState();
}

class _CanalListPageState extends State<CanalListPage> {
  late AppColors _colors;

  // CONFIGURATION - Activer/Désactiver le paiement pour les abonnés existants
  // Changez cette valeur selon vos besoins:
  // true = Les abonnés existants doivent payer si le canal devient privé
  // false = Les abonnés existants gardent l'accès gratuit
  final bool _requirePaymentForExistingSubscribers = true;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Canal> _allCanals = [];
  List<Canal> _displayedCanals = [];
  List<Canal> _filteredCanals = [];
  int _currentLimit = 10;
  final int _loadMoreLimit = 5;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _loadInitialCanals();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreCanals();
    }
  }

  Future<void> _loadInitialCanals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final canals = await postProvider.getCanauxLimited(_currentLimit);
      setState(() {
        _allCanals = canals;
        _displayedCanals = canals;
        _filteredCanals = canals;
        _isLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement initial: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreCanals() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newLimit = _currentLimit + _loadMoreLimit;
      final moreCanals = await postProvider.getCanauxLimited(newLimit);

      setState(() {
        _allCanals = moreCanals;
        _currentLimit = newLimit;

        // Appliquer le filtre de recherche si actif
        if (_searchQuery.isNotEmpty) {
          _filteredCanals = _allCanals.where((canal) =>
          canal.titre!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              canal.description!.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
        } else {
          _filteredCanals = _allCanals;
        }

        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('Erreur chargement supplémentaire: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _searchCanals(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCanals = _allCanals;
      } else {
        _filteredCanals = _allCanals.where((canal) =>
        canal.titre!.toLowerCase().contains(query.toLowerCase()) ||
            (canal.description != null &&
                canal.description!.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      }
    });
  }

  Future<void> _handleFollowCanal(Canal canal) async {
    final isFollowing = canal.usersSuiviId!.contains(authProvider.loginUserData.id);
    final isPrivate = canal.isPrivate == true;

    // Vérifier si l'utilisateur suit déjà le canal
    if (isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).canalAlreadyFollowing,
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.warning,
        ),
      );
      return;
    }

    // Vérifier si le canal est privé
    if (isPrivate) {
      await _handlePrivateCanalSubscription(canal);
    } else {
      await _followPublicCanal(canal);
    }
  }

  Future<void> _handlePrivateCanalSubscription(Canal canal) async {
    final subscriptionPrice = canal.subscriptionPrice ?? 0;
    final isAlreadySubscribed = canal.usersSuiviId!.contains(authProvider.loginUserData.id);

    // Vérifier si l'utilisateur est déjà abonné (cas où le canal est devenu privé après)
    if (isAlreadySubscribed && !_requirePaymentForExistingSubscribers) {
      // L'utilisateur garde l'accès gratuit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vous avez déjà accès à ce canal!',
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
        ),
      );
      return;
    }

    // Vérifier le solde de l'utilisateur

    final userDoc = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
    final currentBalance = userDoc.data()?['votre_solde_principal'] ?? 0;

    if (currentBalance < subscriptionPrice) {
      _showInsufficientBalanceDialog(userBalance: currentBalance, subscriptionPrice: subscriptionPrice);
      return;
    }

    // Message de confirmation différent selon la configuration
    String confirmationMessage = '';
    if (isAlreadySubscribed && _requirePaymentForExistingSubscribers) {
      confirmationMessage = 'Ce canal est devenu privé. Pour continuer à y accéder, '
          'vous devez payer l\'abonnement de ${subscriptionPrice}FCFA.\n\n'
          // '50% ira au créateur et 50% à l\'application.\n\n'
          'Confirmez-vous le paiement?';
    } else {
      confirmationMessage = 'Ce canal est privé. L\'abonnement coûte ${subscriptionPrice}FCFA.\n\n'
          // '50% ira au créateur et 50% à l\'application.\n\n'
          'Confirmez-vous l\'abonnement?';
    }

    // Demander confirmation pour l'abonnement payant
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _colors.surface,
          title: Text(
            isAlreadySubscribed && _requirePaymentForExistingSubscribers
                ? 'Mise à jour d\'abonnement'
                : 'Abonnement Privé',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            confirmationMessage,
            style: TextStyle(color: _colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: _colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _colors.primary),
              child: Text('Confirmer', style: TextStyle(color: _colors.onPrimary)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _processPrivateSubscription(canal, subscriptionPrice, isAlreadySubscribed);
    }
  }

  Future<void> _processPrivateSubscription(Canal canal, double price, bool isAlreadySubscribed) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Déduire le montant du solde utilisateur
      final bool deductionSuccess = await authProvider.deductFromBalance(context, price);

      if (!deductionSuccess) {
        throw Exception('Échec de la déduction du solde');
      }

      // // Diviser le montant (50% créateur, 50% application)
      // final double creatorShare = price / 2;
      // final double appShare = price / 2;
      //
      // // Créditer le créateur du canal
      // await _creditCreator(canal.userId!, creatorShare, canal.id!);
      //
      // // Créditer l'application
      // await authProvider.incrementAppGain(appShare);

      // Diviser le montant (70% créateur, 30% application)
      final double creatorShare = price * 0.7;
      double appShare = price * 0.3;

      // Créditer le créateur du canal
      await _creditCreator(canal.userId!, creatorShare, canal.id!);
      if(authProvider.loginUserData!.codeParrain!=null){
        appShare = price * 0.25;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCadeauCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: price);
        authProvider.ajouterCommissionParrainViaUserId(userId: canal.userId!, montant: price);

      }else{
        appShare = price * 0.75;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCommissionParrainViaUserId(userId: canal.userId!, montant: price);

      }

      // Enregistrer les transactions
      await _recordTransactions(canal, price, creatorShare, appShare, isAlreadySubscribed);

      // Suivre le canal (ou maintenir l'abonnement)
      if (!isAlreadySubscribed) {
        await _followCanal(canal);
      }

      String successMessage = isAlreadySubscribed && _requirePaymentForExistingSubscribers
          ? '✅ Paiement accepté! Vous conservez l\'accès au canal.'
          : '✅ Abonnement réussi! Canal privé ajouté.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      printVm('Erreur abonnement privé: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de l\'abonnement',
            style: TextStyle(color: _colors.onPrimary),
          ),
          backgroundColor: _colors.danger,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _creditCreator(String creatorId, double amount, String canalId) async {
    try {
      await firestore.collection('Users').doc(creatorId).update({
        'votre_solde_principal': FieldValue.increment(amount),
      });

      // Enregistrer la transaction pour le créateur
      await firestore.collection('TransactionSoldes').add({
        'user_id': creatorId,
        'montant': amount,
        'type': TypeTransaction.GAIN.name,
        'description': 'Revenu abonnement canal $canalId',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'canal_id': canalId,
      });
    } catch (e) {
      printVm('Erreur crédit créateur: $e');
      throw e;
    }
  }

  Future<void> _recordTransactions(Canal canal, double totalAmount, double creatorShare, double appShare, bool isAlreadySubscribed) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String description = isAlreadySubscribed && _requirePaymentForExistingSubscribers
        ? 'Maintien accès canal privé devenu payant: ${canal.titre}'
        : 'Abonnement canal privé: ${canal.titre}';

    // Transaction pour l'utilisateur qui paye
    await firestore.collection('TransactionSoldes').add({
      'user_id': authProvider.loginUserData.id!,
      'montant': totalAmount,
      'type': TypeTransaction.DEPENSE.name,
      'description': description,
      'createdAt': timestamp,
      'statut': StatutTransaction.VALIDER.name,
      'canal_id': canal.id,
      'is_existing_subscriber': isAlreadySubscribed,
    });

    // Transaction pour l'application
    await firestore.collection('AppTransactions').add({
      'montant': appShare,
      'type': 'GAIN_ABONNEMENT',
      'description': 'Commission $description',
      'user_id': authProvider.loginUserData.id!,
      'canal_id': canal.id,
      'createdAt': timestamp,
      'is_existing_subscriber': isAlreadySubscribed,
    });
  }

  Future<void> _followPublicCanal(Canal canal) async {
    await _followCanal(canal);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ ${AppLocalizations.of(context).canalNowFollowing}!',
          style: TextStyle(color: _colors.onPrimary),
        ),
        backgroundColor: _colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _followCanal(Canal canal) async {
    final String userId = authProvider.loginUserData.id!;

    if (canal.usersSuiviId!.contains(userId)) {
      return;
    }

    // Ajouter l'utilisateur aux abonnés
    canal.usersSuiviId!.add(userId);
    await Future.wait([
      firestore.collection('Canaux').doc(canal.id).update({
        'usersSuiviId': canal.usersSuiviId,
      }),
      firestore.collection('Users').doc(userId).update({
        'canauxSuivisIds': FieldValue.arrayUnion([canal.id]),
      }),
    ]);

    // Créer la notification
    final NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoyer notification push
    if (canal.user != null && canal.user!.oneIgnalUserid != null) {
      await authProvider.sendNotification(
        userIds: [canal.user!.oneIgnalUserid!],
        smallImage: canal.urlImage!,
        send_user_id: userId,
        recever_user_id: canal.userId!,
        message: "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
        type_notif: NotificationType.ACCEPTINVITATION.name,
        post_id: "",
        post_type: "",
        chat_id: "",
      );
    }

    setState(() {});
  }

  void _showInsufficientBalanceDialog({
    required double userBalance,
    required double subscriptionPrice,
  }) {
    final double missingAmount = (subscriptionPrice - userBalance).clamp(0, double.infinity);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colors = AppColors.of(context);
        final l10n = AppLocalizations.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: colors.background,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [colors.background, colors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🟡 Icône en haut
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: colors.onAccent, size: 40),
                ),
                const SizedBox(height: 16),

                // Titre
                Text(
                  l10n.canalInsufficientBalance,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'Votre solde actuel est de ${userBalance.toStringAsFixed(0)} FCFA.\n'
                      'Il vous manque ${missingAmount.toStringAsFixed(0)} FCFA pour vous abonner '
                      'à ce canal privé coûtant ${subscriptionPrice.toStringAsFixed(0)} FCFA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, height: 1.5, fontSize: 15),
                ),
                const SizedBox(height: 20),

                // Boutons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.canalLater,
                        style: TextStyle(color: colors.accent, fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 3,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: colors.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            l10n.canalRecharge,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanalCard(Canal canal) {
    final isFollowing = canal.usersSuiviId!.contains(authProvider.loginUserData.id);
    final isPrivate = canal.isPrivate == true;
    final subscribersCount = canal.usersSuiviId?.length ?? 0;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: canal),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar du canal
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: canal.urlImage != null
                              ? NetworkImage(canal.urlImage!)
                              : AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
                        if (isPrivate)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _colors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock,
                                color: _colors.onAccent,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 12),

                    // Contenu principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête avec titre et badge vérifié
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "#${(canal.titre != null && canal.titre!.length > 12) ? '${canal.titre!.substring(0, 12)}...' : canal.titre ?? ''}",
                                  style: TextStyle(
                                    color: _colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (canal.isVerify == true)
                                Icon(Icons.verified, color: _colors.primary, size: 16),
                              if (isPrivate)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(Icons.attach_money, color: _colors.accent, size: 14),
                                ),
                            ],
                          ),

                          SizedBox(height: 4),

                          // Description
                          if (canal.description != null && canal.description!.isNotEmpty)
                            Text(
                              canal.description!,
                              style: TextStyle(
                                color: _colors.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          SizedBox(height: 8),

                          // Statistiques
                          Row(
                            children: [
                              Icon(Icons.people, color: _colors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '$subscribersCount',
                                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.post_add, color: _colors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${canal.publication ?? 0}',
                                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                              ),
                              if (isPrivate) ...[
                                SizedBox(width: 16),
                                Icon(Icons.attach_money, color: _colors.accent, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '${canal.subscriptionPrice?.toStringAsFixed(0) ?? '0'} FCFA',
                                  style: TextStyle(color: _colors.accent, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Bouton Suivre/Abonner
                    if (!isFollowing)
                      Container(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleFollowCanal(canal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPrivate ? _colors.accent : _colors.primary,
                            foregroundColor: isPrivate ? _colors.onAccent : _colors.onPrimary,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isPrivate ? l10n.canalSubscribe : l10n.canalFollow,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _colors.textSecondary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            l10n.canalFollowing,
                            style: TextStyle(
                              color: _colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchCanals,
        style: TextStyle(color: _colors.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.canalSearch,
          hintStyle: TextStyle(color: _colors.textSecondary),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _colors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: _colors.textSecondary),
            onPressed: () {
              _searchController.clear();
              _searchCanals('');
            },
          )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _colors.textPrimary),
        automaticallyImplyLeading: true,
        title: Text(
          l10n.canalExplore,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _colors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.primary),
            onPressed: _loadInitialCanals,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),

          // Liste des canaux
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(color: _colors.primary),
            )
                : _filteredCanals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    color: _colors.textSecondary,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? l10n.canalNone
                        : l10n.canalNotFound,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _colors.primary,
              backgroundColor: _colors.background,
              onRefresh: _loadInitialCanals,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: _filteredCanals.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredCanals.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: _colors.primary),
                      ),
                    );
                  }
                  return _buildCanalCard(_filteredCanals[index]);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewCanal()),
          );
        },
        backgroundColor: _colors.primary,
        child: Icon(Icons.add, color: _colors.onPrimary),
      ),
    );
  }
}