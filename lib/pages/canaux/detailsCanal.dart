import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/canalPostNew.dart';
import 'package:afrotok/pages/canaux/editCanal.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import 'package:afrotok/models/model_data.dart';
import '../component/showImage.dart';
import '../home/slive/utils.dart';
import '../paiement/newDepot.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'listCanalfollowers.dart';


import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/canalPostNew.dart';
import 'package:afrotok/pages/canaux/editCanal.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import 'package:afrotok/models/model_data.dart';
import '../component/showImage.dart';
import '../home/slive/utils.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'listCanalfollowers.dart';


import 'dart:async';
import 'package:afrotok/pages/canaux/canalPostNew.dart';
import 'package:afrotok/pages/canaux/editCanal.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import 'package:afrotok/models/model_data.dart';
import '../component/showImage.dart';
import '../home/slive/utils.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'listCanalfollowers.dart';

class CanalDetails extends StatefulWidget {
  final Canal canal;

  CanalDetails({required this.canal});

  @override
  _CanalDetailsState createState() => _CanalDetailsState();
}

class _CanalDetailsState extends State<CanalDetails> {
  // Couleurs du thème
  final Color _backgroundColor = Color(0xFF0A0A0A);
  final Color _cardColor = Color(0xFF1A1A1A);
  final Color _primaryGreen = Color(0xFF2E7D32);
  final Color _primaryYellow = Color(0xFFFFD600);
  final Color _accentGreen = Color(0xFF4CAF50);
  final Color _accentYellow = Color(0xFFFFEB3B);
  final Color _textColor = Colors.white;
  final Color _subtextColor = Colors.grey[400]!;
  final Color _verifiedColor = Color(0xFF1DA1F2);

  // CONFIGURATION - Paiement pour abonnés existants
  final bool _requirePaymentForExistingSubscribers = false;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  final ScrollController _scrollController = ScrollController();

  List<Post> _allPosts = [];
  int _currentPostLimit = 10;
  final int _postsLoadMoreLimit = 5;
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;

  bool isFollowing = false;
  bool _isProcessingSubscription = false;
  bool _isProcessingUnfollow = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    checkIfFollowing();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _streamController.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        _hasMorePosts &&
        !_isLoadingMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final posts = await postProvider.getCanalPostsLimited(_currentPostLimit, widget.canal);
      setState(() {
        _allPosts = posts;
        _hasMorePosts = posts.length == _currentPostLimit;
        _isLoadingPosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      print('Erreur chargement posts: $e');
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final newLimit = _currentPostLimit + _postsLoadMoreLimit;
      final morePosts = await postProvider.getCanalPostsLimited(newLimit, widget.canal);

      setState(() {
        _allPosts = morePosts;
        _currentPostLimit = newLimit;
        _hasMorePosts = morePosts.length == newLimit;
        _isLoadingMorePosts = false;
      });
      _streamController.add(_allPosts);
    } catch (e) {
      print('Erreur chargement posts supplémentaires: $e');
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  void checkIfFollowing() {
    if (widget.canal.usersSuiviId!.contains(authProvider.loginUserData.id)) {
      setState(() {
        isFollowing = true;
      });
    }
  }

  Future<void> _handleFollowAction() async {
    final isPrivate = widget.canal.isPrivate == true;

    if (isFollowing) {
      // Si déjà abonné, proposer de se désabonner
      await _handleUnfollowCanal();
    } else {
      // Si pas abonné, proposer de s'abonner
      if (isPrivate) {
        await _handlePrivateCanalSubscription();
      } else {
        await _followPublicCanal();
      }
    }
  }

  Future<void> _handleUnfollowCanal() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isPrivate = widget.canal.isPrivate == true;
        final subscriptionPrice = widget.canal.subscriptionPrice ?? 0;

        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(
            'Se désabonner',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir vous désabonner de ce canal?',
                style: TextStyle(color: _subtextColor),
              ),
              SizedBox(height: 8),
              if (isPrivate)
                Text(
                  '⚠️ Attention: Si vous vous désabonnez, vous devrez repayer l\'abonnement de ${subscriptionPrice}FCFA pour y accéder à nouveau.',
                  style: TextStyle(
                    color: _primaryYellow,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: _subtextColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Se désabonner', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _processUnfollow();
    }
  }

  Future<void> _processUnfollow() async {
    setState(() {
      _isProcessingUnfollow = true;
    });

    try {
      final String userId = authProvider.loginUserData.id!;

      // Retirer l'utilisateur des abonnés
      widget.canal.usersSuiviId!.remove(userId);
      await firestore.collection('Canaux').doc(widget.canal.id).update({
        'usersSuiviId': widget.canal.usersSuiviId,
      });

      // Mettre à jour l'état local
      setState(() {
        isFollowing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vous vous êtes désabonné de ce canal.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      print('Erreur désabonnement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors du désabonnement',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingUnfollow = false;
      });
    }
  }

  Future<void> _handlePrivateCanalSubscription() async {
    final subscriptionPrice = widget.canal.subscriptionPrice ?? 0;
    final isAlreadySubscribed = widget.canal.usersSuiviId!.contains(authProvider.loginUserData.id);

    // Vérifier si l'utilisateur est déjà abonné (cas où le canal est devenu privé après)
    if (isAlreadySubscribed && !_requirePaymentForExistingSubscribers) {
      // L'utilisateur garde l'accès gratuit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vous avez déjà accès à ce canal privé!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _accentGreen,
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
          'Confirmez-vous le paiement?';
    } else {
      confirmationMessage = 'Ce canal est privé. L\'abonnement coûte ${subscriptionPrice}FCFA.\n\n'
          'Confirmez-vous l\'abonnement?';
    }

    // Demander confirmation pour l'abonnement payant
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(
            isAlreadySubscribed && _requirePaymentForExistingSubscribers
                ? 'Mise à jour d\'abonnement'
                : 'Abonnement Privé',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            confirmationMessage,
            style: TextStyle(color: _subtextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler', style: TextStyle(color: _subtextColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
              child: Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _processPrivateSubscription(subscriptionPrice, isAlreadySubscribed);
    }
  }

  Future<void> _processPrivateSubscription(double price, bool isAlreadySubscribed) async {
    setState(() {
      _isProcessingSubscription = true;
    });

    try {
      // Déduire le montant du solde utilisateur
      final bool deductionSuccess = await authProvider.deductFromBalance(context, price);

      if (!deductionSuccess) {
        throw Exception('Échec de la déduction du solde');
      }

      // Diviser le montant (70% créateur, 30% application)
      final double creatorShare = price * 0.7;
       double appShare = price * 0.3;

      // Créditer le créateur du canal
      await _creditCreator(creatorShare);
      if(authProvider.loginUserData!.codeParrain!=null){
         appShare = price * 0.25;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCadeauCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: price);
        authProvider.ajouterCommissionParrainViaUserId(userId: widget.canal.userId!, montant: price);

      }else{
         appShare = price * 0.75;
        authProvider.incrementAppGain(appShare);
        authProvider.ajouterCommissionParrainViaUserId(userId: widget.canal.userId!, montant: price);

      }



      // // Créditer l'application
      // await authProvider.incrementAppGain(appShare);

      // Enregistrer les transactions
      await _recordTransactions(price, creatorShare, appShare, isAlreadySubscribed);

      // Suivre le canal (ou maintenir l'abonnement)
      if (!isAlreadySubscribed) {
        await _followCanal();
      }

      String successMessage = isAlreadySubscribed && _requirePaymentForExistingSubscribers
          ? '✅ Paiement accepté! Vous conservez l\'accès au canal privé.'
          : '✅ Abonnement réussi! Canal privé ajouté.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      print('Erreur abonnement privé: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de l\'abonnement',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingSubscription = false;
      });
    }
  }

  Future<void> _creditCreator(double amount) async {
    try {
      await firestore.collection('Users').doc(widget.canal.userId).update({
        'votre_solde_principal': FieldValue.increment(amount),
      });

      // Enregistrer la transaction pour le créateur
      await firestore.collection('TransactionSoldes').add({
        'user_id': widget.canal.userId!,
        'montant': amount,
        'type': TypeTransaction.GAIN.name,
        'description': 'Revenu abonnement canal ${widget.canal.id}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'canal_id': widget.canal.id,
      });
    } catch (e) {
      print('Erreur crédit créateur: $e');
      throw e;
    }
  }

  Future<void> _recordTransactions(double totalAmount, double creatorShare, double appShare, bool isAlreadySubscribed) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String description = isAlreadySubscribed && _requirePaymentForExistingSubscribers
        ? 'Maintien accès canal privé devenu payant: ${widget.canal.titre}'
        : 'Abonnement canal privé: ${widget.canal.titre}';

    // Transaction pour l'utilisateur qui paye
    await firestore.collection('TransactionSoldes').add({
      'user_id': authProvider.loginUserData.id!,
      'montant': totalAmount,
      'type': TypeTransaction.DEPENSE.name,
      'description': description,
      'createdAt': timestamp,
      'statut': StatutTransaction.VALIDER.name,
      'canal_id': widget.canal.id,
      'is_existing_subscriber': isAlreadySubscribed,
    });

    // Transaction pour l'application
    await firestore.collection('AppTransactions').add({
      'montant': appShare,
      'type': 'GAIN_ABONNEMENT',
      'description': 'Commission $description',
      'user_id': authProvider.loginUserData.id!,
      'canal_id': widget.canal.id,
      'createdAt': timestamp,
      'is_existing_subscriber': isAlreadySubscribed,
    });
  }

  Future<void> _followPublicCanal() async {
    await _followCanal();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Vous suivez maintenant ce canal!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _followCanal() async {
    final String userId = authProvider.loginUserData.id!;

    if (widget.canal.usersSuiviId!.contains(userId)) {
      return;
    }

    // Ajouter l'utilisateur aux abonnés
    widget.canal.usersSuiviId!.add(userId);
    await firestore.collection('Canaux').doc(widget.canal.id).update({
      'usersSuiviId': widget.canal.usersSuiviId,
    });
    addPointsForAction(UserAction.abonne);
    addPointsForOtherUserAction(widget.canal.userId!, UserAction.autre);

    // Créer la notification
    final NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${widget.canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: widget.canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoyer notification push
    if (widget.canal.user != null && widget.canal.user!.oneIgnalUserid != null) {
      await authProvider.sendNotification(
        userIds: [widget.canal.user!.oneIgnalUserid!],
        smallImage: widget.canal.urlImage!,
        send_user_id: userId,
        recever_user_id: widget.canal.userId!,
        message: "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${widget.canal.titre!} 📺!",
        type_notif: NotificationType.ACCEPTINVITATION.name,
        post_id: "",
        post_type: "",
        chat_id: "",
      );
    }

    setState(() {
      isFollowing = true;
    });
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.black,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey.shade900],
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
                    color: Colors.yellow.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.black, size: 40),
                ),
                const SizedBox(height: 16),

                // 🟢 Titre
                Text(
                  'Solde insuffisant 💰',
                  style: TextStyle(
                    color: Colors.greenAccent.shade400,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 🖤 Message
                Text(
                  'Votre solde actuel est de ${userBalance.toStringAsFixed(0)} FCFA.\n'
                      'Il vous manque ${missingAmount.toStringAsFixed(0)} FCFA pour vous abonner '
                      'à ce canal privé coûtant ${subscriptionPrice.toStringAsFixed(0)} FCFA.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 15),
                ),
                const SizedBox(height: 20),

                // 🔘 Boutons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Plus tard',
                        style: TextStyle(color: Colors.yellow.shade600, fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 3,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Recharger',
                            style: TextStyle(
                              color: Colors.black,
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
  Widget _buildHeaderSection() {
    final isPrivate = widget.canal.isPrivate == true;
    final isOwner = authProvider.loginUserData.id == widget.canal.userId;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      sliver: SliverToBoxAdapter(
        child: Stack(
          children: [
            // Image de couverture
            GestureDetector(
              onTap: () {
                showImageDetailsModalDialog(widget.canal.urlCouverture!,
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                    context
                );
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: widget.canal.urlCouverture != null
                        ? NetworkImage(widget.canal.urlCouverture!)
                        : AssetImage('assets/default_cover.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Avatar du canal
            Positioned(
              bottom: 10,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  showImageDetailsModalDialog(widget.canal.urlImage!,
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height,
                      context
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: widget.canal.urlImage != null
                            ? NetworkImage(widget.canal.urlImage!)
                            : AssetImage('assets/default_profile.png') as ImageProvider,
                      ),
                    ),
                    if (isPrivate)
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _primaryYellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            color: Colors.black,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Badge propriétaire
            if (isOwner)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Propriétaire',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final isPrivate = widget.canal.isPrivate == true;
    final isOwner = authProvider.loginUserData.id == widget.canal.userId;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final subscribersCount = widget.canal.usersSuiviId?.length ?? 0;
    final postsCount = widget.canal.publication ?? 0;

    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre et badges
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "#${widget.canal.titre!}",
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (widget.canal.isVerify == true)
                            Icon(Icons.verified, color: _verifiedColor, size: 24),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Statistiques
                      Row(
                        children: [
                          _buildStatItem(
                            icon: Icons.people,
                            value: subscribersCount.toString(),
                            label: 'Abonnés',
                          ),
                          SizedBox(width: 16),
                          _buildStatItem(
                            icon: Icons.post_add,
                            value: postsCount.toString(),
                            label: 'Publications',
                          ),
                          if (isPrivate) ...[
                            SizedBox(width: 16),
                            _buildStatItem(
                              icon: Icons.attach_money,
                              value: '${widget.canal.subscriptionPrice?.toStringAsFixed(0) ?? '0'}',
                              label: 'FCFA',
                              color: _primaryYellow,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Boutons d'action
            Row(
              children: [
                if (!isOwner)
                  Expanded(
                    child: Container(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: (_isProcessingSubscription || _isProcessingUnfollow) ? null : _handleFollowAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.red // Rouge pour se désabonner
                              : (isPrivate ? _primaryYellow : _primaryGreen),
                          foregroundColor: isFollowing
                              ? Colors.white // Blanc pour le texte de désabonnement
                              : (isPrivate ? Colors.black : Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: (_isProcessingSubscription || _isProcessingUnfollow)
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isFollowing ? Colors.white : (isPrivate ? Colors.black : Colors.white),
                          ),
                        )
                            : Text(
                          isFollowing
                              ? 'SE DÉSABONNER'
                              : (isPrivate ? 'S\'ABONNER' : 'SUIVRE'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (isOwner) ...[
                  Expanded(
                    child: Container(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditCanal(canal: widget.canal)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cardColor,
                          foregroundColor: _textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: BorderSide(color: _primaryGreen),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 6),
                            Text('MODIFIER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CanalPostForm(canal: widget.canal)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 6),
                            Text('POSTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // if (isOwner || isAdmin) ...[
            if (isAdmin) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChannelFollowersPage(userIds: widget.canal.usersSuiviId!, channelName: widget.canal.titre!,)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18),
                      SizedBox(width: 6),
                      Text('VOIR MES ABONNÉS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 16),

            // Description
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: _primaryGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Description',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.canal.description ?? 'Aucune description',
                    style: TextStyle(
                      color: _subtextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Section Posts
            Row(
              children: [
                Icon(Icons.dynamic_feed, color: _primaryYellow, size: 24),
                SizedBox(width: 8),
                Text(
                  'Publications',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color ?? _subtextColor, size: 16),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            color: _subtextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    return StreamBuilder<List<Post>>(
      stream: _streamController.stream,
      builder: (context, snapshot) {
        if (_isLoadingPosts) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: _primaryGreen),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 50),
                    SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: TextStyle(color: _subtextColor),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.feed, color: _subtextColor, size: 50),
                    SizedBox(height: 16),
                    Text(
                      'Aucune publication',
                      style: TextStyle(color: _subtextColor, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Soyez le premier à publier dans ce canal!',
                      style: TextStyle(color: _subtextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final posts = snapshot.data!;
          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                if (index == posts.length) {
                  return _buildLoadMoreIndicator();
                }

                final post = posts[index];
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: HomePostUsersWidget(
                    post: post,
                    color: _primaryGreen,
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                  ),
                );
              },
              childCount: posts.length + (_isLoadingMorePosts ? 1 : 0),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: _isLoadingMorePosts
            ? CircularProgressIndicator(color: _primaryGreen)
            : _hasMorePosts
            ? Text(
          'Charger plus...',
          style: TextStyle(color: _subtextColor),
        )
            : Container(
          padding: EdgeInsets.all(16),
          child: Text(
            '🎉 Vous avez vu toutes les publications!',
            style: TextStyle(
              color: _subtextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
        iconTheme: IconThemeData(color: _textColor),
        title: Text(
          'Détails du Canal',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryGreen),
            onPressed: _loadInitialPosts,
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeaderSection(),
          _buildInfoSection(),
          _buildPostsSection(),
        ],
      ),
    );
  }
}


