import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';


import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';

class CanalListPage extends StatefulWidget {
  final bool isUserCanals;

  CanalListPage({required this.isUserCanals});

  @override
  _CanalListPageState createState() => _CanalListPageState();
}

class _CanalListPageState extends State<CanalListPage> {
  // Couleurs du thème Twitter-like
  final Color _backgroundColor = Color(0xFF15202B);
  final Color _cardColor = Color(0xFF192734);
  final Color _primaryColor = Color(0xFF1DA1F2);
  final Color _textColor = Colors.white;
  final Color _subtextColor = Colors.grey[400]!;
  final Color _verifiedColor = Color(0xFF1DA1F2);
  final Color _privateColor = Color(0xFFFFD600);
  final Color _successColor = Color(0xFF00BA7C);

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
      print('Erreur chargement initial: $e');
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
      print('Erreur chargement supplémentaire: $e');
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
            'Vous suivez déjà ce canal.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
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
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _successColor,
        ),
      );
      return;
    }

    // Vérifier le solde de l'utilisateur
    if (authProvider.loginUserData.votre_solde_principal! < subscriptionPrice) {
      _showInsufficientBalanceDialog();
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
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              child: Text('Confirmer', style: TextStyle(color: Colors.white)),
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

      // Diviser le montant (50% créateur, 50% application)
      final double creatorShare = price / 2;
      final double appShare = price / 2;

      // Créditer le créateur du canal
      await _creditCreator(canal.userId!, creatorShare, canal.id!);

      // Créditer l'application
      await authProvider.incrementAppGain(appShare);

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
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _successColor,
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
      print('Erreur crédit créateur: $e');
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
          '✅ Vous suivez maintenant ce canal!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _successColor,
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
    await firestore.collection('Canaux').doc(canal.id).update({
      'usersSuiviId': canal.usersSuiviId,
    });

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

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Votre solde est insuffisant pour vous abonner à ce canal privé.',
            style: TextStyle(color: _subtextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanalCard(Canal canal) {
    final isFollowing = canal.usersSuiviId!.contains(authProvider.loginUserData.id);
    final isPrivate = canal.isPrivate == true;
    final subscribersCount = canal.usersSuiviId?.length ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor,
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
                                color: _privateColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock,
                                color: Colors.black,
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
                                  "#${canal.titre ?? ''}",
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (canal.isVerify == true)
                                Icon(Icons.verified, color: _verifiedColor, size: 16),
                              if (isPrivate)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(Icons.attach_money, color: _privateColor, size: 14),
                                ),
                            ],
                          ),

                          SizedBox(height: 4),

                          // Description
                          if (canal.description != null && canal.description!.isNotEmpty)
                            Text(
                              canal.description!,
                              style: TextStyle(
                                color: _subtextColor,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          SizedBox(height: 8),

                          // Statistiques
                          Row(
                            children: [
                              Icon(Icons.people, color: _subtextColor, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '$subscribersCount',
                                style: TextStyle(color: _subtextColor, fontSize: 12),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.post_add, color: _subtextColor, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${canal.publication ?? 0}',
                                style: TextStyle(color: _subtextColor, fontSize: 12),
                              ),
                              if (isPrivate) ...[
                                SizedBox(width: 16),
                                Icon(Icons.attach_money, color: _privateColor, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '${canal.subscriptionPrice?.toStringAsFixed(0) ?? '0'} FCFA',
                                  style: TextStyle(color: _privateColor, fontSize: 12),
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
                            backgroundColor: isPrivate ? _privateColor : _primaryColor,
                            foregroundColor: isPrivate ? Colors.black : Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isPrivate ? 'S\'abonner' : 'Suivre',
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
                            side: BorderSide(color: _subtextColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Suivi',
                            style: TextStyle(
                              color: _subtextColor,
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
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchCanals,
        style: TextStyle(color: _textColor),
        decoration: InputDecoration(
          hintText: 'Rechercher un canal...',
          hintStyle: TextStyle(color: _subtextColor),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _subtextColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: _subtextColor),
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        title: Text(
          'Explorer les Canaux',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
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
              child: CircularProgressIndicator(color: _primaryColor),
            )
                : _filteredCanals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    color: _subtextColor,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Aucun canal disponible'
                        : 'Aucun canal trouvé',
                    style: TextStyle(
                      color: _subtextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _primaryColor,
              backgroundColor: _backgroundColor,
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
                        child: CircularProgressIndicator(color: _primaryColor),
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
        backgroundColor: _primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}