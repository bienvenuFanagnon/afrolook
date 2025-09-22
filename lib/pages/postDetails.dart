


import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/paiement/depotPaiment.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/socialVideos/afrovideos/afrovideo.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postCadeau.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu/popup_menu.dart';

import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/listItemsCarousel.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/authProvider.dart';
import 'canaux/detailsCanal.dart';


class DetailsPost extends StatefulWidget {
  final Post post;

  DetailsPost({Key? key, required this.post}) : super(key: key);

  @override
  _DetailsPostState createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost> with SingleTickerProviderStateMixin {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  int _selectedGiftIndex = 0;
  int _selectedRepostPrice = 25;
  List<double> giftPrices = [100, 200, 500, 1000, 2000, 5000];
  List<String> giftIcons = ['🎁', '💝', '💎', '💰', '💵', '🎉'];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Stream pour les mises à jour en temps réel
  late Stream<DocumentSnapshot> _postStream;

  @override
  void initState() {
    super.initState();

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Initialiser le stream pour les mises à jour en temps réel
    _postStream = firestore.collection('Posts').doc(widget.post.id).snapshots();

    // Incrémenter les vues
    _incrementViews();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _incrementViews() async {
    try {
      if (!widget.post.users_vue_id!.contains(authProvider.loginUserData.id)) {
        // Mettre à jour localement
        setState(() {
          widget.post.vues = (widget.post.vues ?? 0) + 1;
          widget.post.users_vue_id!.add(authProvider.loginUserData.id!);
        });

        // Mettre à jour dans Firestore
        await firestore.collection('Posts').doc(widget.post.id).update({
          'vues': FieldValue.increment(1),
          'users_vue_id': FieldValue.arrayUnion([authProvider.loginUserData.id])
        });
      }
    } catch (e) {
      print("Erreur incrémentation vues: $e");
    }
  }

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return "il y a quelques secondes";
        } else {
          return "il y a ${difference.inMinutes} min";
        }
      } else {
        return "il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Future<void> _handleLike() async {
    try {
      if (!isIn(widget.post.users_love_id!, authProvider.loginUserData.id!)) {
        // Mettre à jour localement
        setState(() {
          widget.post.loves = widget.post.loves! + 1;
          widget.post.users_love_id!.add(authProvider.loginUserData.id!);
        });

        // Mettre à jour dans Firestore
        await firestore.collection('Posts').doc(widget.post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id])
        });
        await authProvider.sendNotification(
            userIds: [widget.post.user!.oneIgnalUserid!],
            smallImage:
            "${authProvider.loginUserData.imageUrl!}",
            send_user_id:
            "${authProvider.loginUserData.id!}",
            recever_user_id: "${widget.post.user_id!}",
            message:
            "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
            type_notif:
            NotificationType.POST.name,
            post_id: "${widget.post!.id!}",
            post_type: PostDataType.IMAGE.name,
            chat_id: '');
        // Incrémenter le solde de l'utilisateur qui aime
        await postProvider.interactWithPostAndIncrementSolde(
            widget.post.id!,
            authProvider.loginUserData.id!,
            "like",
            widget.post.user_id!
        );

        // Animation
        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+2 points ajoutés à votre solde',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _createTransaction(String type, double montant, String description,String userid) async {
    try {
      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id =userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
    } catch (e) {
      print("Erreur création transaction: $e");
    }
  }


  Future<void> _sendGift(double amount) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();
      // Récupérer l'utilisateur expéditeur à jour
      final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }
      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      // Vérifier le solde
      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.5;
        final double gainApplication = amount * 0.5;

        // Débiter l’expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
         String appDataId = authProvider.appDefaultData.id!;
        await firestore.collection('AppData').doc(appDataId).update({
          'solde_gain': FieldValue.increment(gainApplication),
        });

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id])
        });

        // Créer les transactions
        // Créer les transactions
        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.post.user!.pseudo}",authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.post.user_id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        await authProvider.sendNotification(
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: "", // pas besoin de montrer l'image de l'expéditeur
          send_user_id: "", // pas besoin de l'expéditeur
          recever_user_id: "${widget.post.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${widget.post!.id!}",
          post_type: PostDataType.IMAGE.name,
          chat_id: '',
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'envoi du cadeau',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _repostForCash() async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;

      // Récupérer l'utilisateur connecté à jour
      final userDoc = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
      final userData = userDoc.data();
      if (userData == null) throw Exception("Utilisateur introuvable !");
      final double soldeActuel = (userData['votre_solde_principal'] ?? 0.0).toDouble();

      if (soldeActuel >= _selectedRepostPrice) {


        // Débiter l’expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-_selectedRepostPrice),
        });

        // Créditer l’application
        await firestore.collection('AppData').doc(authProvider.appDefaultData.id!).update({
          'solde_gain': FieldValue.increment(_selectedRepostPrice),
        });

        // Mettre à jour le post : ajouter l’utilisateur et remettre à jour la date
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_republier_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'created_at':DateTime.now().millisecondsSinceEpoch,
          // remet le post en haut du fil
          'updated_at': DateTime.now().millisecondsSinceEpoch, // remet le post en haut du fil
        });

        // Créer la transaction
        await _createTransaction(
          TypeTransaction.DEPENSE.name,
          _selectedRepostPrice.toDouble(),
          "Republication du post ${widget.post.id}",authProvider.loginUserData.id!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '🔝 Post republié pour $_selectedRepostPrice FCFA!',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur republication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de la republication',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Naviguer vers la page de recharge
                Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Recharger', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showGiftDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
              title: Text(
                'Envoyer un Cadeau',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(giftPrices.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedGiftIndex = index);
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedGiftIndex == index
                                  ? Colors.green
                                  : Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedGiftIndex == index
                                    ? Colors.yellow
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  giftIcons[index],
                                  style: TextStyle(fontSize: 24),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '${giftPrices[index].toInt()} FCFA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendGift(giftPrices[_selectedGiftIndex]);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Envoyer',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRepostDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Republier le Post',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Republier ce post le mettra en avant dans le fil d\'actualité. Coût: 25 FCFA.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _repostForCash();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Republier', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserHeader(Post post) {
    final canal = post.canal; // si ton modèle Post contient canal
    final user = post.user;

    // Debug log pour vérifier ce qui est présent
    print("📌 Canal: ${canal != null ? canal.toJson() : 'Aucun'}");
    print("👤 User: ${user != null ? user.toJson() : 'Aucun'}");

    return GestureDetector(
      onTap: () {
        if(canal!=null){
          Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post.canal!),));

        }else{
          double w= MediaQuery.of(context).size.width;
          double h= MediaQuery.of(context).size.height;
          showUserDetailsModalDialog(user!, w, h, context);
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(
              canal?.urlImage ?? user?.imageUrl ?? '',
            ),
            radius: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canal != null) ...[
                  Text(
                    '#${canal.titre ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${canal.usersSuiviId!.length ?? 0} abonnés',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ] else if (user != null) ...[
                  Text(
                    '@${user.pseudo ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${user.userAbonnesIds!.length ?? 0} abonnés',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formaterDateTime(
                      DateTime.fromMillisecondsSinceEpoch(post.createdAt ?? 0),
                    ),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.description != null && post.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              post.description!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        if (post.images != null && post.images!.isNotEmpty)
          Container(
            height: 300,
            margin: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: ImageSlideshow(
                initialPage: 0,
                indicatorColor: Colors.green,
                indicatorBackgroundColor: Colors.grey,
                onPageChanged: (value) {
                  print('Page changed: $value');
                },
                isLoop: true,
                children: post!.images!.map((imageUrl) =>
                    GestureDetector(
                      onTap: () {
                        // Ouvrir l'image en plein écran avec Hero
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(imageUrl: imageUrl),
                          ),
                        );
                      },
                      child: Hero(
                        tag: imageUrl,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain, // pour voir toute l'image sans débordement
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: Center(child: CircularProgressIndicator(color: Colors.yellow)),
                          ),
                          errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    )
                ).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow(Post post) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.remove_red_eye,
          count: post.vues ?? 0,
          label: 'Vues',
        ),
        _buildStatItem(
          icon: Icons.favorite,
          count: post.loves ?? 0,
          label: 'Likes',
          isLiked: isIn(post.users_love_id!, authProvider.loginUserData.id!),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostComments(post: widget.post),
              ),
            );
          },
          child: _buildStatItem(
            icon: Icons.comment,
            count: widget.post.comments ?? 0,
            label: 'Comments',
          ),
        ),
        _buildStatItem(
          icon: Icons.card_giftcard,
          count: post.users_cadeau_id?.length ?? 0,
          label: 'Cadeaux',
        ),
        _buildStatItem(
          icon: Icons.repeat,
          count: post.users_republier_id?.length ?? 0,
          label: 'Reposts',
        ),
      ],
    );
  }

  Widget _buildStatItem({required IconData icon, required int count, required String label, bool isLiked = false}) {
    return Column(
      children: [
        Icon(icon, color: isLiked ? Colors.red : Colors.yellow, size: 20),
        SizedBox(height: 5),
        Text(
          formatNumber(count),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Post post) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 15),
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Bouton Like
          ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: Icon(
                isIn(post.users_love_id!, authProvider.loginUserData.id!)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: isIn(post.users_love_id!, authProvider.loginUserData.id!)
                    ? Colors.red
                    : Colors.white,
                size: 30,
              ),
              onPressed: _handleLike,
            ),
          ),

          // Bouton Commentaire
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostComments(post: widget.post),
                ),
              );
            },
          ),

          // Bouton Cadeau
          IconButton(
            icon: Icon(Icons.card_giftcard, color: Colors.yellow, size: 30),
            onPressed: _showGiftDialog,
          ),

          // Bouton Republier
          IconButton(
            icon: Icon(Icons.repeat, color: Colors.green, size: 30),
            onPressed: _showRepostDialog,
          ),

          // Bouton Partager
          IconButton(
            icon: Icon(Icons.share, color: Colors.white, size: 30),
            onPressed: () {
              // Logique de partage
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Détails du Post',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: 20
          ),
        ),
        actions: [
          Text(
            'Afrolook',
            style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 20
            ),
          )
        ],
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.yellow));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Post non trouvé', style: TextStyle(color: Colors.white)));
          }

          // Mettre à jour le post avec les données du stream
          final updatedPost = Post.fromJson(snapshot.data!.data() as Map<String, dynamic>);
          updatedPost.user = widget.post.user; // Conserver les données utilisateur

          return _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.yellow))
              : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(widget.post),
                // _buildUserHeader(updatedPost),
                SizedBox(height: 20),
                _buildPostContent(updatedPost),
                SizedBox(height: 20),
                Divider(color: Colors.grey[700]),
                _buildStatsRow(updatedPost),
                Divider(color: Colors.grey[700]),
                _buildActionButtons(updatedPost),

                // Section des cadeaux récents
                if (updatedPost.users_cadeau_id != null && updatedPost.users_cadeau_id!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Derniers cadeaux',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: updatedPost.users_cadeau_id!.length,
                            itemBuilder: (context, index) {
                              return FutureBuilder<DocumentSnapshot>(
                                future: firestore
                                    .collection('Users')
                                    .doc(updatedPost.users_cadeau_id![index])
                                    .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    var userData = UserData.fromJson(snapshot.data!.data() as Map<String, dynamic>);
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: NetworkImage(userData.imageUrl ?? ''),
                                            radius: 15,
                                          ),
                                          SizedBox(height: 2),
                                          Text('🎁', style: TextStyle(fontSize: 8)),
                                        ],
                                      ),
                                    );
                                  }
                                  return SizedBox();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => CircularProgressIndicator(color: Colors.yellow),
                errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
