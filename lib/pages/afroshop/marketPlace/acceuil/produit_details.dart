import 'dart:io';
import 'dart:math';


import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:insta_image_viewer/insta_image_viewer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/custom_theme.dart';
import '../../../../constant/sizeText.dart';
import '../../../../constant/textCustom.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../component/consoleWidget.dart';
import '../../../entreprise/produit/component.dart';
import '../../../entreprise/profile/ProfileEntreprise.dart';
import '../../../user/conponent.dart';

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:flutter/services.dart'; // Pour Clipboard

import '../../../../constant/constColors.dart';
import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../user/conponent.dart'; // Pour countryFlag

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:flutter/services.dart'; // Pour Clipboard

import '../../../../constant/constColors.dart';
import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../user/conponent.dart'; // Pour countryFlag

class ProduitDetail extends StatefulWidget {
  final String productId;
  ProduitDetail({super.key, required this.productId});

  @override
  State<ProduitDetail> createState() => _ProduitDetailState();
}

class _ProduitDetailState extends State<ProduitDetail> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  ArticleData? article;
  EntrepriseData? entrepriseData;
  UserData? proprietaire;

  bool isLoading = true;
  bool onSaveTap = false;
  bool onSupTap = false;
  bool abonneTap = false;
  int imageIndex = 0;
  bool showBoostModal = false;
  int selectedBoostDays = 20;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    _loadProductData();
    _incrementViews();
  }

  Future<void> _loadProductData() async {
    try {
      // Charger l'article
      final articles = await categorieProduitProvider.getArticleById(widget.productId);
      if (articles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Produit non trouvé")),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        article = articles.first;
      });

      // Vérifier si l'utilisateur a déjà liké
      if (article!.user != null && article!.user!.id != null) {
        final userDoc = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
        final userData = userDoc.data();
        if (userData != null && userData['articles_likes'] != null) {
          final articlesLikes = List<String>.from(userData['articles_likes'] ?? []);
          setState(() {
            isLiked = articlesLikes.contains(article!.id);
          });
        }
      }

      // Charger le propriétaire
      final users = await authProvider.getUserById(article!.user_id!);
      if (users.isNotEmpty) {
        setState(() {
          proprietaire = users.first;
          article!.user = proprietaire;
        });
      }

      // Charger l'entreprise
      final entreprises = await postProvider.getEntreprise(article!.user_id!);
      if (entreprises.isNotEmpty) {
        setState(() {
          entrepriseData = entreprises.first;
        });
      }

    } catch (e) {
      print("Erreur chargement données: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _incrementViews() async {
    try {
      await firestore.collection('Articles').doc(widget.productId).update({
        'vues': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Erreur incrémentation vues: $e");
    }
  }

  Future<void> _incrementContacts() async {
    try {
      await firestore.collection('Articles').doc(article!.id!).update({
        'contact': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        article!.contact = (article!.contact ?? 0) + 1;
      });
    } catch (e) {
      print("Erreur incrémentation contacts: $e");
    }
  }

// Remplacer uniquement la fonction _shareProduct par celle-ci :
  Future<void> _shareProduct2() async {
    if (article == null) return;

    try {
      await authProvider.createArticleLink(true, article!).then((url) async {
        final box = context.findRenderObject() as RenderBox?;

        await Share.shareUri(
          Uri.parse('$url'),
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );

        setState(() {
          article!.partage = (article!.partage ?? 0) + 1;
        });

        // Incrémenter les partages dans Firestore
        await firestore.collection('Articles').doc(article!.id!).update({
          'partage': FieldValue.increment(1),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Notification au propriétaire
        if (article!.user != null) {
          final userCollect = firestore.collection('Users');
          final querySnapshotUser = await userCollect
              .where("id", isEqualTo: article!.user!.id!)
              .get();

          final listUsers = querySnapshotUser.docs
              .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
              .toList();

          if (listUsers.isNotEmpty) {
            if (article!.user!.oneIgnalUserid != null &&
                article!.user!.oneIgnalUserid!.length > 5) {
              await authProvider.sendNotification(
                userIds: [article!.user!.oneIgnalUserid!],
                smallImage: article!.images?.isNotEmpty == true
                    ? article!.images!.first
                    : "",
                send_user_id: authProvider.loginUserData.id!,
                recever_user_id: article!.user!.id!,
                message: "📢 🛒 Un afrolookeur a partagé votre produit 🛒",
                type_notif: NotificationType.ARTICLE.name,
                post_id: article!.id!,
                post_type: PostDataType.IMAGE.name,
                chat_id: '',
              );

              final notif = NotificationData();
              notif.id = firestore.collection('Notifications').doc().id;
              notif.titre = " 🛒Boutique 🛒";
              notif.media_url = article!.images?.isNotEmpty == true
                  ? article!.images!.first
                  : "";
              notif.type = NotificationType.ARTICLE.name;
              notif.description = "Un afrolookeur a partagé votre produit 🛒";
              notif.users_id_view = [];
              notif.user_id = authProvider.loginUserData.id;
              notif.receiver_id = article!.user!.id!;
              notif.post_id = article!.id!;
              notif.post_data_type = PostDataType.IMAGE.name!;
              notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
              notif.createdAt = DateTime.now().microsecondsSinceEpoch;
              notif.status = PostStatus.VALIDE.name;

              await firestore.collection('Notifications')
                  .doc(notif.id)
                  .set(notif.toJson());
            }
          }
        }

        // Mettre à jour l'article localement
        final updatedArticles = await categorieProduitProvider.getArticleById(article!.id!);
        if (updatedArticles.isNotEmpty) {
          setState(() {
            article!.partage = updatedArticles.first.partage;
          });
        }
      });

    } catch (e) {
      print("Erreur partage: $e");
      // Fallback simple en cas d'erreur
      final fallbackText = 'Découvrez "${article!.titre}" à ${article!.prix} FCFA sur Afroshop Afrolook!';
      await Share.share(fallbackText);
    }
  }

// Remplacer uniquement la fonction _launchWhatsApp par celle-ci :
  Future<void> _launchWhatsApp() async {
    if (article == null) return;

    try {
      await authProvider.createArticleLink(true, article!).then((url) async {
        await _incrementContacts();

        final phone = article!.phone!;

        String urlWhatsApp = "whatsapp://send?phone=" + phone + "&text="
            + "Bonjour *${proprietaire?.nom ?? ''}*,\n\n"
            + "Je m'appelle *@${authProvider.loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
            + "J'ai vu votre produit sur *${"Afroshop d'afrolook".toUpperCase()}* et je suis très intéressé(e).\n"
            + "Voici les détails de l'article :\n\n"
            + "*Titre* : *${article!.titre!.toUpperCase()}*\n"
            + "*Prix* : *${article!.prix}* FCFA\n\n"
            + "Vous pouvez voir l'article ici : $url\n\n"
            + "Merci et à bientôt !";

        if (!await launchUrl(Uri.parse(urlWhatsApp))) {
          // Fallback: essayer avec une URL https standard
          String urlFallback = "https://wa.me/$phone?text=" + Uri.encodeComponent(
              "Bonjour, je suis intéressé(e) par votre produit \"${article!.titre}\" "
                  "au prix de ${article!.prix} FCFA sur Afroshop Afrolook. "
                  "Pouvez-vous me donner plus d'informations ?"
          );

          if (!await launchUrl(Uri.parse(urlFallback))) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Impossible d'ouvrir WhatsApp", textAlign: TextAlign.center)),
            );
          }
        }

        // Notification au propriétaire
        if (article!.user != null) {
          final userCollect = firestore.collection('Users');
          final querySnapshotUser = await userCollect
              .where("id", isEqualTo: article!.user!.id!)
              .get();

          final listUsers = querySnapshotUser.docs
              .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
              .toList();

          if (listUsers.isNotEmpty) {
            if (article!.user!.oneIgnalUserid != null &&
                article!.user!.oneIgnalUserid!.length > 5) {

              final notif = NotificationData();
              notif.id = firestore.collection('Notifications').doc().id;
              notif.titre = " 🛒Boutique 🛒";
              notif.media_url = authProvider.loginUserData.imageUrl;
              notif.type = NotificationType.ARTICLE.name;
              notif.description = "@${authProvider.loginUserData.pseudo!} veut votre produit 🛒";
              notif.users_id_view = [];
              notif.user_id = authProvider.loginUserData.id;
              notif.receiver_id = article!.user!.id!;
              notif.post_id = article!.id!;
              notif.post_data_type = PostDataType.IMAGE.name!;
              notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
              notif.createdAt = DateTime.now().microsecondsSinceEpoch;
              notif.status = PostStatus.VALIDE.name;

              await firestore.collection('Notifications')
                  .doc(notif.id)
                  .set(notif.toJson());

              await authProvider.sendNotification(
                userIds: [article!.user!.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl ?? "",
                send_user_id: authProvider.loginUserData.id!,
                recever_user_id: article!.user!.id!,
                message: "📢 🛒 @${authProvider.loginUserData.pseudo!} veut votre produit 🛒",
                type_notif: NotificationType.ARTICLE.name,
                post_id: article!.id!,
                post_type: PostDataType.IMAGE.name,
                chat_id: '',
              );
            }
          }
        }
      });

    } catch (e) {
      print("Erreur WhatsApp: $e");
      // Fallback simple en cas d'erreur
      final phone = article!.phone!;
      String urlFallback = "https://wa.me/$phone?text=" + Uri.encodeComponent(
          "Bonjour, je suis intéressé(e) par votre produit \"${article!.titre}\" "
              "au prix de ${article!.prix} FCFA sur Afroshop Afrolook."
      );

      if (!await launchUrl(Uri.parse(urlFallback))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'ouvrir WhatsApp", textAlign: TextAlign.center)),
        );
      }
    }
  }

// Remplacer le widget _buildStatItem pour le partage par celui-ci :
  Widget _buildStatItem(IconData icon, int count, double size, Function()? onTap) {
    final isHeart = icon == FontAwesome.heart;
    final isShare = icon == FontAwesome.share;

    if (isShare) {
      // Widget LikeButton pour le partage (comme dans votre code original)
      return LikeButton(
        onTap: (isLiked) async {
          await _shareProduct();
          return Future.value(true);
        },
        isLiked: false,
        size: size,
        circleColor: CircleColor(start: Color(0xffffc400), end: Color(0xffcc7a00)),
        bubblesColor: BubblesColor(
          dotPrimaryColor: Color(0xffffc400),
          dotSecondaryColor: Color(0xff07f629),
        ),
        countPostion: CountPostion.bottom,
        likeBuilder: (bool isLiked) {
          return Icon(
            Entypo.share,
            color: isLiked ? Colors.blue : Colors.blueAccent,
            size: size,
          );
        },
        likeCount: count,
        countBuilder: (int? count, bool isLiked, String text) {
          var color = isLiked ? Colors.black : Colors.white;
          Widget result;
          if (count == 0) {
            result = Text(
              "0",
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 12),
            );
          } else {
            result = Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            );
          }
          return result;
        },
      );
    } else {
      // Pour les autres icônes (vue, whatsapp, like)
      return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon,
                size: size,
                color: isHeart && isLiked ? Colors.red : Colors.grey),
            SizedBox(height: 4),
            Text("$count",
                style: TextStyle(
                    color: isHeart && isLiked ? Colors.red : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      );
    }
  }
  Future<void> _deleteProduct() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmation"),
        content: Text("Voulez-vous vraiment supprimer définitivement ce produit ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() { onSupTap = true; });

      try {
        // Suppression réelle du produit
        await firestore.collection('Articles').doc(article!.id!).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('Produit supprimé avec succès')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erreur de suppression')),
        );
      } finally {
        setState(() { onSupTap = false; });
      }
    }
  }
  Future<void> _boostProduct() async {
    if (article == null) return;

    // Vérifications en temps réel avec Firestore
    final userDoc = await firestore.collection('Users').doc(authProvider.loginUserData.id!).get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Utilisateur non trouvé")),
      );
      return;
    }

    final userData = UserData.fromJson(userDoc.data()!);

    final entrepriseDoc = entrepriseData?.id != null
        ? await firestore.collection('Entreprises').doc(entrepriseData!.id!).get()
        : null;

    final entrepriseDataReal = entrepriseDoc?.exists == true
        ? EntrepriseData.fromJson(entrepriseDoc!.data()! as Map<String, dynamic>)
        : null;

    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final hasPremiumSubscription = entrepriseDataReal?.abonnement?.type == TypeAbonement.PREMIUM.name;
    final canBoostPremium = hasPremiumSubscription &&
        (entrepriseDataReal?.abonnement?.produistIdBoosted?.length ?? 0) < 5;

    // FORCER 10 jours pour les abonnements premium
    if (hasPremiumSubscription && canBoostPremium) {
      selectedBoostDays = 10;
    }

    // Calculer le coût réel basé sur la durée sélectionnée
    final boostCost = _calculateBoostCost(selectedBoostDays);
    final hasEnoughBalance = (userData.votre_solde_principal ?? 0.0) >= boostCost;

    // Vérifications de sécurité
    if (!isAdmin && !hasEnoughBalance && !(hasPremiumSubscription && canBoostPremium)) {
      _showRechargeModal();
      return;
    }

    if (hasPremiumSubscription && !canBoostPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Limite de boost atteinte pour votre abonnement")),
      );
      return;
    }

    try {
      // Transaction de boost
      final boostEndDate = DateTime.now().add(Duration(days: selectedBoostDays));

      if (!isAdmin && !hasPremiumSubscription) {
        // Déduction du solde avec le montant calculé
        await firestore.collection('Users').doc(authProvider.loginUserData.id!).update({
          'votre_solde_principal': FieldValue.increment(-boostCost),
        });

        // Ajout au gain de l'app avec le montant calculé
        await authProvider.incrementAppGain(boostCost);

        // Enregistrement transaction avec le montant calculé
        await firestore.collection('TransactionSoldes').add({
          'user_id': authProvider.loginUserData.id,
          'montant': boostCost,
          'type': TypeTransaction.DEPENSE.name,
          'description': 'Boost produit ($selectedBoostDays jours)',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'statut': StatutTransaction.VALIDER.name,
        });
      }

      // Mise à jour du produit
      await firestore.collection('Articles').doc(article!.id!).update({
        'booster': 1,
        'boostEndDate': boostEndDate.millisecondsSinceEpoch,
        'isBoosted': true,
        'boostDays': selectedBoostDays,
        'boostCost': hasPremiumSubscription ? 0.0 : boostCost, // 0 pour les premium
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Mise à jour de l'abonnement premium si applicable
      if (hasPremiumSubscription && entrepriseDataReal != null) {
        final updatedBoostedProducts = [...(entrepriseDataReal.abonnement?.produistIdBoosted ?? []), article!.id!];
        await firestore.collection('Entreprises').doc(entrepriseDataReal.id!).update({
          'abonnement.produistIdBoosted': updatedBoostedProducts,
        });
      }

      setState(() {
        showBoostModal = false;
        article!.booster = 1;
        article!.isBoosted = true;
        article!.boostEndDate = boostEndDate.millisecondsSinceEpoch;
        article!.boostDays = selectedBoostDays;
        article!.boostCost = hasPremiumSubscription ? 0.0 : boostCost;
      });

      // Message de confirmation adapté
      if (hasPremiumSubscription) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Produit boosté GRATUITEMENT pour 10 jours (Abonnement Premium)'),
          ),
        );
      } else if (isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Produit boosté ADMIN pour $selectedBoostDays jours'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Produit boosté pour $selectedBoostDays jours (${boostCost.toInt()} FCFA)'),
          ),
        );
      }
    } catch (e) {
      print("Erreur boost: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors du boost: ${e.toString()}'),
        ),
      );
    }
  }
  void _showRechargeModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Solde insuffisant"),
        content: Text("Votre solde est insuffisant pour booster ce produit. Voulez-vous recharger votre compte ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Plus tard", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Naviguer vers la page de recharge
              Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen()));
            },
            child: Text("Recharger", style: TextStyle(color: CustomConstants.kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    try {
      final userRef = firestore.collection('Users').doc(authProvider.loginUserData.id);
      final articleRef = firestore.collection('Articles').doc(article!.id);

      if (isLiked) {
        // Retirer le like
        await userRef.update({
          'articles_likes': FieldValue.arrayRemove([article!.id])
        });
        await articleRef.update({
          'jaime': FieldValue.increment(-1),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        setState(() {
          isLiked = false;
          article!.jaime = (article!.jaime ?? 1) - 1;
        });
      } else {
        // Ajouter le like
        await userRef.update({
          'articles_likes': FieldValue.arrayUnion([article!.id])
        });
        await articleRef.update({
          'jaime': FieldValue.increment(1),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        setState(() {
          isLiked = true;
          article!.jaime = (article!.jaime ?? 0) + 1;
        });

        // Envoyer notification au propriétaire
        if (article!.user != null && article!.user!.oneIgnalUserid != null) {
          await authProvider.sendNotification(
            userIds: [article!.user!.oneIgnalUserid!],
            smallImage: article!.images?.isNotEmpty == true ? article!.images!.first : "",
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: article!.user!.id!,
            message: "❤️ @${authProvider.loginUserData.pseudo!} aime votre produit",
            type_notif: NotificationType.ARTICLE.name,
            post_id: article!.id!,
            post_type: "PRODUIT",
            chat_id: '',
          );
        }
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _shareProduct() async {
    if (article == null) return;

    try {
      final urlArticle = await authProvider.createArticleLink(true, article!);

      await Share.share(
        'Découvrez ce produit sur Afroshop: ${article!.titre}\nPrix: ${article!.prix} FCFA\n$urlArticle',
        subject: 'Produit Afroshop - ${article!.titre}',
      );

      // Incrémenter les partages
      await firestore.collection('Articles').doc(article!.id!).update({
        'partage': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        article!.partage = (article!.partage ?? 0) + 1;
      });

    } catch (e) {
      print("Erreur partage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du partage")),
      );
    }
  }

  Future<void> _toggleFollowEntreprise() async {
    if (entrepriseData == null) return;

    setState(() {
      abonneTap = true;
    });

    try {
      final isFollowing = entrepriseData!.usersSuiviId?.contains(authProvider.loginUserData.id!) ?? false;
      final entrepriseRef = firestore.collection('Entreprises').doc(entrepriseData!.id);

      if (isFollowing) {
        // Se désabonner
        await entrepriseRef.update({
          'usersSuiviId': FieldValue.arrayRemove([authProvider.loginUserData.id!]),
          'suivi': FieldValue.increment(-1),
        });
        setState(() {
          entrepriseData!.usersSuiviId?.remove(authProvider.loginUserData.id!);
          entrepriseData!.suivi = (entrepriseData!.suivi ?? 1) - 1;
        });
      } else {
        // S'abonner
        await entrepriseRef.update({
          'usersSuiviId': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
          'suivi': FieldValue.increment(1),
        });
        setState(() {
          entrepriseData!.usersSuiviId?.add(authProvider.loginUserData.id!);
          entrepriseData!.suivi = (entrepriseData!.suivi ?? 0) + 1;
        });

        // Envoyer notification
        if (entrepriseData!.user != null && entrepriseData!.user!.oneIgnalUserid != null) {
          await authProvider.sendNotification(
            userIds: [entrepriseData!.user!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl ?? "",
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: entrepriseData!.user!.id!,
            message: "🔔 @${authProvider.loginUserData.pseudo!} suit votre entreprise",
            type_notif: NotificationType.ABONNER.name,
            post_id: entrepriseData!.id!,
            post_type: "ENTREPRISE",
            chat_id: '',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Vous suivez maintenant ${entrepriseData!.titre}")),
        );
      }
    } catch (e) {
      // print("Erreur abonnement: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Erreur lors de l'abonnement")),
      // );
    } finally {
      setState(() {
        abonneTap = false;
      });
    }
  }

  Widget _buildImageGallery() {
    if (article?.images?.isEmpty ?? true) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }

    return Column(
      children: [
        // Image principale avec zoom
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.black12,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: InstaImageViewer(
                  child: CachedNetworkImage(
                    imageUrl: article!.images![imageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.black12,
                      child: Center(child: CircularProgressIndicator(color: CustomConstants.kPrimaryColor)),
                    ),
                    errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
              // Bouton suppression pour admin/proprio
              if (authProvider.loginUserData.id == article!.user_id || authProvider.loginUserData.role == UserRole.ADM.name)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: onSupTap
                        ? CircularProgressIndicator(color: Colors.red, strokeWidth: 2)
                        : Icon(Icons.delete, color: Colors.red, size: 30),
                    onPressed: _deleteProduct,
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 10),

        // Miniatures des images
        if (article!.images!.length > 1)
          Container(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: article!.images!.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => setState(() => imageIndex = index),
                child: Container(
                  width: 80,
                  height: 60,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: imageIndex == index ? CustomConstants.kPrimaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: article!.images![index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.black12),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoostSection() {
    final isOwner = authProvider.loginUserData.id == article?.user_id;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    if (!isOwner && !isAdmin) return SizedBox();

    final isBoosted = article?.estBoosted == true;
    final boostEndDate = article?.boostEndDate != null
        ? DateTime.fromMillisecondsSinceEpoch(article!.boostEndDate!)
        : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBoosted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isBoosted ? Colors.green : Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isBoosted ? Icons.rocket_launch : Icons.trending_up,
                  color: isBoosted ? Colors.green : Colors.orange),
              SizedBox(width: 8),
              Text(
                isBoosted ? "Produit Boosté 🚀" : "Boostez votre produit",
                style: TextStyle(fontWeight: FontWeight.bold, color: isBoosted ? Colors.green : Colors.orange),
              ),
            ],
          ),

          if (isBoosted && boostEndDate != null) ...[
            SizedBox(height: 4),
            Text("Boost actif jusqu'au ${boostEndDate.day}/${boostEndDate.month}/${boostEndDate.year}",
                style: TextStyle(fontSize: 12, color: Colors.green)),
            if (article!.joursRestantsBoost > 0)
              Text("${article!.joursRestantsBoost} jours restants",
                  style: TextStyle(fontSize: 11, color: Colors.green)),
          ] else if (!isBoosted) ...[
            SizedBox(height: 8),
            Text("Augmentez la visibilité de votre produit et multipliez vos ventes !",
                style: TextStyle(fontSize: 12,color: Colors.white)),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => showBoostModal = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomConstants.kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text("Booster le produit - 500 FCFA/20j"),
            ),
          ],
        ],
      ),
    );
  }

  // Ajouter ces fonctions dans la classe _ProduitDetailState
  Widget _buildBoostModal() {
    final hasPremiumSubscription = entrepriseData?.abonnement?.type == TypeAbonement.PREMIUM.name;
    final canBoostPremium = hasPremiumSubscription &&
        (entrepriseData?.abonnement?.produistIdBoosted?.length ?? 0) < 5;


// 🔍 Affichage dans la console
    print('hasPremiumSubscription: $hasPremiumSubscription');
    print('canBoostPremium: $canBoostPremium');

// Pour plus de détails sur le contenu de l’abonnement
    print('Type abonnement: ${entrepriseData?.abonnement?.type}');
    print('Produits boostés: ${entrepriseData?.abonnement?.produistIdBoosted?.length}');

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, color: CustomConstants.kPrimaryColor),
                SizedBox(width: 8),
                Text(
                  hasPremiumSubscription ? "Booster GRATUIT (Premium)" : "Booster le produit",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16),

            if (hasPremiumSubscription) ...[
              Text(
                "Votre abonnement Premium vous permet de booster gratuitement !",
                style: TextStyle(color: Colors.green, fontSize: 14),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.yellow),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Boost gratuit de 10 jours inclus dans votre abonnement",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ] else ...[
              Text("Durée du boost:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: selectedBoostDays,
                  isExpanded: true,
                  dropdownColor: Colors.grey[800],
                  style: TextStyle(color: Colors.white),
                  items: [
                    {'days': 10, 'reduction': 0},
                    {'days': 20, 'reduction': 10},
                    {'days': 30, 'reduction': 15},
                    {'days': 40, 'reduction': 20},
                  ].map((item) {
                    final days = item['days'] as int;
                    final reduction = item['reduction'] as int;
                    final baseCost = (days / 10 * 500).toDouble();
                    final finalCost = baseCost - (baseCost * reduction / 100);

                    String displayText = "$days jours - ${finalCost.toInt()} FCFA";
                    if (reduction > 0) {
                      displayText += " (-$reduction%)";
                    }

                    return DropdownMenuItem(
                      value: days,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayText, style: TextStyle(color: Colors.white, fontSize: 14)),
                          if (reduction > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "Économisez ${(baseCost - finalCost).toInt()} FCFA",
                                style: TextStyle(color: Colors.green, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedBoostDays = value!),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CustomConstants.kPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.money, color: CustomConstants.kPrimaryColor),
                        SizedBox(width: 8),
                        Text(
                          "Coût: ${_calculateBoostCost(selectedBoostDays).toInt()} FCFA",
                          style: TextStyle(fontWeight: FontWeight.bold, color: CustomConstants.kPrimaryColor),
                        ),
                      ],
                    ),
                    if (_getReductionPercentage(selectedBoostDays) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Économie de ${_calculateSavings(selectedBoostDays).toInt()} FCFA (${_getReductionPercentage(selectedBoostDays)}% de réduction)",
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    SizedBox(height: 4),
                    Text(
                      "Soit ${_calculateCostPerDay(selectedBoostDays).toStringAsFixed(2)} FCFA/jour",
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => showBoostModal = false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Annuler", style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _boostProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasPremiumSubscription ? Colors.green : CustomConstants.kPrimaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      hasPremiumSubscription ? "Booster Gratuit" : "Confirmer",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBoostModal2() {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, color: CustomConstants.kPrimaryColor),
                SizedBox(width: 8),
                Text("Booster le produit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            SizedBox(height: 16),
            Text("Durée du boost:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: selectedBoostDays,
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                style: TextStyle(color: Colors.white),
                items: [
                  {'days': 10, 'reduction': 0},   // 10 jours = 500 FCFA
                  {'days': 20, 'reduction': 10},  // 20 jours = 900 FCFA (-10%)
                  {'days': 30, 'reduction': 15},  // 30 jours = 1275 FCFA (-15%)
                  {'days': 40, 'reduction': 20},  // 40 jours = 1600 FCFA (-20%)
                ].map((item) {
                  final days = item['days'] as int;
                  final reduction = item['reduction'] as int;
                  final baseCost = (days / 10 * 500).toDouble(); // 10 jours = 500 FCFA
                  final finalCost = baseCost - (baseCost * reduction / 100);

                  String displayText = "$days jours - ${finalCost.toInt()} FCFA";
                  if (reduction > 0) {
                    displayText += " (-$reduction%)";
                  }

                  return DropdownMenuItem(
                    value: days,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(displayText, style: TextStyle(color: Colors.white, fontSize: 14)),
                        if (reduction > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "Économisez ${(baseCost - finalCost).toInt()} FCFA",
                              style: TextStyle(color: Colors.green, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedBoostDays = value!),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CustomConstants.kPrimaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.money, color: CustomConstants.kPrimaryColor),
                      SizedBox(width: 8),
                      Text(
                        "Coût: ${_calculateBoostCost(selectedBoostDays).toInt()} FCFA",
                        style: TextStyle(fontWeight: FontWeight.bold, color: CustomConstants.kPrimaryColor),
                      ),
                    ],
                  ),
                  if (_getReductionPercentage(selectedBoostDays) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Économie de ${_calculateSavings(selectedBoostDays).toInt()} FCFA (${_getReductionPercentage(selectedBoostDays)}% de réduction)",
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    "Soit ${_calculateCostPerDay(selectedBoostDays).toStringAsFixed(2)} FCFA/jour",
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => showBoostModal = false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Annuler", style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _boostProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomConstants.kPrimaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Confirmer", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Mettre à jour les fonctions utilitaires
  int _getReductionPercentage(int days) {
    switch (days) {
      case 20: return 10;
      case 30: return 15;
      case 40: return 20;
      default: return 0;
    }
  }

  double _calculateBoostCost(int days) {
    final baseCost = (days / 10 * 500).toDouble(); // 10 jours = 500 FCFA
    final reduction = _getReductionPercentage(days);
    return baseCost - (baseCost * reduction / 100);
  }

  double _calculateSavings(int days) {
    final baseCost = (days / 10 * 500).toDouble(); // 10 jours = 500 FCFA
    final finalCost = _calculateBoostCost(days);
    return baseCost - finalCost;
  }

  double _calculateCostPerDay(int days) {
    final cost = _calculateBoostCost(days);
    return cost / days;
  }

  Widget _buildEntrepriseHeader() {
    final isFollowing = entrepriseData?.usersSuiviId?.contains(authProvider.loginUserData.id!) ?? false;

    return GestureDetector(
      onTap: () {
        // Navigation vers la page de l'entreprise
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EntrepriseProfil(userId: entrepriseData!.userId!),
          ),
        );       },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(entrepriseData!.urlImage!),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entrepriseData!.titre!,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("${entrepriseData!.suivi} abonnés",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: abonneTap ? null : _toggleFollowEntreprise,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey : CustomConstants.kPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: abonneTap
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isFollowing ? "Abonné" : "Suivre", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pays du produit
        if (article!.countryData != null && article!.countryData!['country'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                countryFlag(article!.countryData!['countryCode'] ?? "TG", size: 20),
                SizedBox(width: 8),
                Text(article!.countryData!['country'] ?? "Togo",
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              ],
            ),
          ),

        Text(article!.titre!,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),

        SizedBox(height: 8),

        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CustomConstants.kPrimaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text("${article!.prix} FCFA",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),

        SizedBox(height: 12),

        Text(article!.description!,
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildStats() {
    final iconSize = 20.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(FontAwesome.eye, article!.vues ?? 0, iconSize, null),
          _buildStatItem(FontAwesome.whatsapp, article!.contact ?? 0, iconSize, null),
          _buildStatItem(FontAwesome.heart, article!.jaime ?? 0, iconSize, _toggleLike),
          _buildStatItem(FontAwesome.share, article!.partage ?? 0, iconSize, _shareProduct),
        ],
      ),
    );
  }


  Widget _buildOwnerContact() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Contact du vendeur",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),

          SizedBox(height: 12),

          Row(
            children: [
              Icon(Icons.phone, color: CustomConstants.kPrimaryColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(article!.phone!,
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              IconButton(
                icon: Icon(Icons.content_copy, size: 20, color: Colors.grey),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: article!.phone!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Numéro copié dans le presse-papier")),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: LoadingAnimationWidget.flickr(
            size: 50,
            leftDotColor: CustomConstants.kPrimaryColor,
            rightDotColor: Colors.yellow,
          ),
        ),
      );
    }

    if (article == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Produit non trouvé")),
        body: Center(child: Text("Ce produit n'existe pas")),
      );
    }

    final isOwner = authProvider.loginUserData.id == article!.user_id;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text("Détails du produit", style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageGallery(),

                SizedBox(height: 20),

                _buildBoostSection(),

                SizedBox(height: 20),

                if (entrepriseData != null) _buildEntrepriseHeader(),

                SizedBox(height: 20),

                _buildProductInfo(),

                SizedBox(height: 20),

                _buildStats(),

                SizedBox(height: 20),

                _buildOwnerContact(),

                SizedBox(height: 100),
              ],
            ),
          ),

          // Bouton d'action fixe
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9), Colors.black],
                ),
              ),
              child: ElevatedButton(
                onPressed: _launchWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesome.whatsapp, size: 24),
                    SizedBox(width: 12),
                    Text("Contacter sur WhatsApp", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // Modal de boost - DOIT ÊTRE DANS LE STACK
          if (showBoostModal)
            Container(
              color: Colors.black54, // Fond semi-transparent
              child: _buildBoostModal(),
            ),
        ],
      ),
    );
  }}

// class ProduitDetail extends StatefulWidget {
//   final ArticleData article;
//     EntrepriseData entrepriseData;
//    ProduitDetail({super.key, required this.article, required this.entrepriseData});
//
//   @override
//   State<ProduitDetail> createState() => _ProduitDetailState();
// }
//
// class _ProduitDetailState extends State<ProduitDetail> {
//
//   late UserAuthProvider authshopProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   String _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
//   int _length = 100; // Remplacez par la longueur souhaitée
//   bool onSaveTap=false;
//   bool onSupTap=false;
//
//   late CategorieProduitProvider categorieProduitProvider =
//   Provider.of<CategorieProduitProvider>(context, listen: false);
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   late UserShopAuthProvider authShopProvider =
//   Provider.of<UserShopAuthProvider>(context, listen: false);
//
//
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//
//
//
//   String getRandomString() {
//     final _rnd = Random();
//     return String.fromCharCodes(Iterable.generate(_length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
//   }
//
//   bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
//     return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
//   }
//
//   late PostProvider postProvider =
//   Provider.of<PostProvider>(context, listen: false);
//
//   Future<void> launchWhatsApp(String phone,ArticleData articleData,String urlArticle) async {
//     //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
//     // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
//     String url = "whatsapp://send?phone=" + phone + "&text="
//         + "Bonjour *${articleData.user!.nom!}*,\n\n"
//         + "Je m'appelle *@${authProvider.loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
//         + "J'ai vu votre produit sur *${"Afroshop d 'afrolook".toUpperCase()}* et je suis très intéressé(e).\n"
//         + "Voici les détails de l'article :\n\n"
//         + "*Titre* : *${articleData.titre!.toUpperCase()}*\n"
//         + "*Prix* : *${articleData.prix}* FCFA\n\n"
//         + "Vous pouvez voir l'article ici : ${urlArticle}\n\n"
//         + "Merci et à bientôt !";
//     // String url = "whatsapp://send?phone="+phone+"&text=Salut *${articleData.user!.nom!}*,\n*Moi c'est*: *@${authProvider.loginUserData!.pseudo!.toUpperCase()} Sur Afrolook*,\n j'ai vu votre produit sur *${"Afroshop".toUpperCase()}*\n à propos de l'article:\n\n*Titre*:  *${articleData.titre!.toUpperCase()}*\n *Prix*: *${articleData.prix}* fcfa\n *Voir l'article* ${urlArticle}";
//     if (!await launchUrl(Uri.parse(url))) {
//       final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));
//
//       // Afficher le SnackBar en bas de la page
//       ScaffoldMessenger.of(context).showSnackBar(snackBar);
//       throw Exception('Impossible d\'ouvrir WhatsApp');
//     }
//   }
//
//   int imageIndex=0;
//
//   bool abonneTap=false;
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//     double iconSize = 20;
//     return Scaffold(
//         appBar: AppBar(
//           title: Text('Details produit'),
//           actions: [
//             Container(
//               // color: Colors.black12,
//               height: 150,
//               width: 150,
//               alignment: Alignment.center,
//               child: Image.asset(
//                 "assets/icons/afroshop_logo-removebg-preview.png",
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ],
//         ),
//         body: SingleChildScrollView(
//
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Column(
//             children: <Widget>[
//               SizedBox(height: 20,),
//               ClipRRect(
//                 borderRadius: BorderRadius.all(Radius.circular(10)),
//                 child: Column(
//                   children: [
//                     // entrepriseSimpleHeader(widget.entrepriseData,context),
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 8.0),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               Padding(
//                                 padding: const EdgeInsets.only(right: 15.0),
//                                 child: CircleAvatar(
//                                   radius: 30,
//                                   backgroundImage: NetworkImage(
//                                       '${widget.entrepriseData.urlImage}'),
//                                 ),
//                               ),
//                               SizedBox(
//                                 height: 2,
//                               ),
//                               Row(
//                                 children: [
//                                   Column(
//                                     children: [
//                                       SizedBox(
//                                         //width: 100,
//                                         child: TextCustomerUserTitle(
//                                           titre: "#${widget.entrepriseData.titre}",
//                                           fontSize: SizeText.homeProfileTextSize,
//                                           couleur: ConstColors.textColors,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                       TextCustomerUserTitle(
//                                         titre: "${widget.entrepriseData.suivi} suivi(e)s",
//                                         fontSize: SizeText.homeProfileTextSize,
//                                         couleur: ConstColors.textColors,
//                                         fontWeight: FontWeight.w400,
//                                       ),
//                                     ],
//                                   ),
//
//                                 ],
//                               ),
//                             ],
//                           ),
//                           Visibility(
//                             visible:!isUserAbonne(
//                                 widget.entrepriseData.usersSuiviId!,
//                                 authProvider.loginUserData.id!),
//
//                             child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green, // Couleur de fond du bouton
//                                 ),
//                                 onPressed: abonneTap
//                                     ? () {}
//                                     : () async {
//                                   if (!isUserAbonne(
//                                       widget.entrepriseData.usersSuiviId!,
//                                       authProvider
//                                           .loginUserData
//                                           .id!))
//                                   {
//                                     setState(() {
//                                       abonneTap = true;
//                                     });
//                                     await    postProvider.getEntreprise(widget.entrepriseData.userId!).then((entreprises) {
//                                       if(entreprises.isNotEmpty){
//                                         widget.entrepriseData= entreprises.first;
//                                         widget.entrepriseData.usersSuiviId!.add(authProvider.loginUserData!.id!);
//                                         widget.entrepriseData.suivi=entreprises.first.usersSuiviId!.length;
//                                         setState(() {
//                                           // abonneTap = true;
//                                         });
//                                         // entreprise=entreprises.first;
//                                         authProvider.updateEntreprise(entreprises.first);
//                                       }
//                                     },);
//
//
//
//                                     if (widget.entrepriseData .user!
//                                         .oneIgnalUserid !=
//                                         null &&
//                                         widget.entrepriseData
//                                             .user!
//                                             .oneIgnalUserid!
//                                             .length >
//                                             5) {
//                                       await authProvider.sendNotification(
//                                           userIds: [
//                                             widget.entrepriseData.user!
//                                                 .oneIgnalUserid!
//                                           ],
//                                           smallImage:
//                                           "${authProvider.loginUserData.imageUrl!}",
//                                           send_user_id:
//                                           "${authProvider.loginUserData.id!}",
//                                           recever_user_id:
//                                           "${widget.entrepriseData.user!.id!}",
//                                           message:
//                                           "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢",
//                                           type_notif:
//                                           NotificationType
//                                               .ABONNER
//                                               .name,
//                                           post_id:
//                                           "",
//                                           post_type:
//                                           PostDataType
//                                               .IMAGE
//                                               .name,
//                                           chat_id: '');
//                                       NotificationData
//                                       notif =
//                                       NotificationData();
//                                       notif.id = firestore
//                                           .collection(
//                                           'Notifications')
//                                           .doc()
//                                           .id;
//                                       notif.titre =
//                                       "Nouveau Abonnement ✅";
//                                       notif.media_url =
//                                           authProvider
//                                               .loginUserData
//                                               .imageUrl;
//                                       notif.type =
//                                           NotificationType
//                                               .ABONNER
//                                               .name;
//                                       notif.description =
//                                       "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢";
//                                       notif.users_id_view =
//                                       [];
//                                       notif.user_id =
//                                           authProvider
//                                               .loginUserData
//                                               .id;
//                                       notif.receiver_id =
//                                       widget.entrepriseData.user!
//                                           .id!;
//                                       notif.post_id =
//                                       widget.entrepriseData.id!;
//                                       notif.post_data_type =
//                                       PostDataType
//                                           .IMAGE
//                                           .name!;
//                                       notif.updatedAt =
//                                           DateTime.now()
//                                               .microsecondsSinceEpoch;
//                                       notif.createdAt =
//                                           DateTime.now()
//                                               .microsecondsSinceEpoch;
//                                       notif.status =
//                                           PostStatus
//                                               .VALIDE
//                                               .name;
//
//                                       // users.add(pseudo.toJson());
//
//                                       await firestore
//                                           .collection(
//                                           'Notifications')
//                                           .doc(notif.id)
//                                           .set(notif
//                                           .toJson());
//                                     }
//                                     SnackBar snackBar =
//                                     SnackBar(
//                                       content: Text(
//                                         'suivi, Bravo ! Vous avez gagné 2 points.',
//                                         textAlign:
//                                         TextAlign
//                                             .center,
//                                         style: TextStyle(
//                                             color: Colors
//                                                 .green),
//                                       ),
//                                     );
//                                     ScaffoldMessenger
//                                         .of(context)
//                                         .showSnackBar(
//                                         snackBar);
//                                     setState(() {
//                                       abonneTap = false;
//                                     });
//                                   } else {
//                                     SnackBar snackBar =
//                                     SnackBar(
//                                       content: Text(
//                                         'une erreur',
//                                         textAlign:
//                                         TextAlign
//                                             .center,
//                                         style: TextStyle(
//                                             color: Colors
//                                                 .red),
//                                       ),
//                                     );
//                                     ScaffoldMessenger
//                                         .of(context)
//                                         .showSnackBar(
//                                         snackBar);
//                                     setState(() {
//                                       abonneTap = false;
//                                     });
//
//                                     // setState(() {
//                                     //   abonneTap = false;
//                                     // });
//                                   }
//                                 },
//                                 child: abonneTap
//                                     ? Center(
//                                   child:
//                                   LoadingAnimationWidget
//                                       .flickr(
//                                     size: 20,
//                                     leftDotColor:
//                                     Colors.green,
//                                     rightDotColor:
//                                     Colors.black,
//                                   ),
//                                 )
//                                     : Text(
//                                   "Suivre",
//                                   style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight:
//                                       FontWeight.w900,
//                                       color: Colors.white),
//                                 )),
//                           )
//
//                           // StatefulBuilder(builder: (BuildContext context,
//                           //       void Function(void Function()) setState) {
//                           //     return Visibility(
//                           //     visible:!isUserAbonne(
//                           //     entreprise.usersSuiviId!,
//                           //     authProvider.loginUserData.id!),
//                           //
//                           //       child: ElevatedButton(
//                           //           style: ElevatedButton.styleFrom(
//                           //             backgroundColor: Colors.green, // Couleur de fond du bouton
//                           //           ),
//                           //           onPressed: abonneTap
//                           //               ? () {}
//                           //               : () async {
//                           //             if (!isUserAbonne(
//                           //                 entreprise.usersSuiviId!,
//                           //                 authProvider
//                           //                     .loginUserData
//                           //                     .id!))
//                           //             {
//                           //               setState(() {
//                           //                 abonneTap = true;
//                           //               });
//                           //               await    postProvider.getEntreprise(entreprise.userId!).then((entreprises) {
//                           //                 if(entreprises.isNotEmpty){
//                           //                   entreprises.first.usersSuiviId!.add(authProvider.loginUserData!.id!);
//                           //                   entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
//                           //                   entreprise.usersSuiviId!.add(authProvider.loginUserData!.id!);
//                           //                   setState(() {
//                           //                     // abonneTap = true;
//                           //                   });
//                           //                   // entreprise=entreprises.first;
//                           //                   authProvider.updateEntreprise(entreprises.first);
//                           //                 }
//                           //               },);
//                           //
//                           //
//                           //
//                           //               if (entreprise .user!
//                           //                   .oneIgnalUserid !=
//                           //                   null &&
//                           //                   entreprise
//                           //                       .user!
//                           //                       .oneIgnalUserid!
//                           //                       .length >
//                           //                       5) {
//                           //                 await authProvider.sendNotification(
//                           //                     userIds: [
//                           //                       entreprise.user!
//                           //                           .oneIgnalUserid!
//                           //                     ],
//                           //                     smallImage:
//                           //                     "${authProvider.loginUserData.imageUrl!}",
//                           //                     send_user_id:
//                           //                     "${authProvider.loginUserData.id!}",
//                           //                     recever_user_id:
//                           //                     "${entreprise.user!.id!}",
//                           //                     message:
//                           //                     "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢",
//                           //                     type_notif:
//                           //                     NotificationType
//                           //                         .ABONNER
//                           //                         .name,
//                           //                     post_id:
//                           //                     "",
//                           //                     post_type:
//                           //                     PostDataType
//                           //                         .IMAGE
//                           //                         .name,
//                           //                     chat_id: '');
//                           //                 NotificationData
//                           //                 notif =
//                           //                 NotificationData();
//                           //                 notif.id = firestore
//                           //                     .collection(
//                           //                     'Notifications')
//                           //                     .doc()
//                           //                     .id;
//                           //                 notif.titre =
//                           //                 "Nouveau Abonnement ✅";
//                           //                 notif.media_url =
//                           //                     authProvider
//                           //                         .loginUserData
//                           //                         .imageUrl;
//                           //                 notif.type =
//                           //                     NotificationType
//                           //                         .ABONNER
//                           //                         .name;
//                           //                 notif.description =
//                           //                 "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢";
//                           //                 notif.users_id_view =
//                           //                 [];
//                           //                 notif.user_id =
//                           //                     authProvider
//                           //                         .loginUserData
//                           //                         .id;
//                           //                 notif.receiver_id =
//                           //                 entreprise.user!
//                           //                     .id!;
//                           //                 notif.post_id =
//                           //                 entreprise.id!;
//                           //                 notif.post_data_type =
//                           //                 PostDataType
//                           //                     .IMAGE
//                           //                     .name!;
//                           //                 notif.updatedAt =
//                           //                     DateTime.now()
//                           //                         .microsecondsSinceEpoch;
//                           //                 notif.createdAt =
//                           //                     DateTime.now()
//                           //                         .microsecondsSinceEpoch;
//                           //                 notif.status =
//                           //                     PostStatus
//                           //                         .VALIDE
//                           //                         .name;
//                           //
//                           //                 // users.add(pseudo.toJson());
//                           //
//                           //                 await firestore
//                           //                     .collection(
//                           //                     'Notifications')
//                           //                     .doc(notif.id)
//                           //                     .set(notif
//                           //                     .toJson());
//                           //               }
//                           //               SnackBar snackBar =
//                           //               SnackBar(
//                           //                 content: Text(
//                           //                   'suivi, Bravo ! Vous avez gagné 2 points.',
//                           //                   textAlign:
//                           //                   TextAlign
//                           //                       .center,
//                           //                   style: TextStyle(
//                           //                       color: Colors
//                           //                           .green),
//                           //                 ),
//                           //               );
//                           //               ScaffoldMessenger
//                           //                   .of(context)
//                           //                   .showSnackBar(
//                           //                   snackBar);
//                           //               setState(() {
//                           //                 abonneTap = false;
//                           //               });
//                           //             } else {
//                           //               SnackBar snackBar =
//                           //               SnackBar(
//                           //                 content: Text(
//                           //                   'une erreur',
//                           //                   textAlign:
//                           //                   TextAlign
//                           //                       .center,
//                           //                   style: TextStyle(
//                           //                       color: Colors
//                           //                           .red),
//                           //                 ),
//                           //               );
//                           //               ScaffoldMessenger
//                           //                   .of(context)
//                           //                   .showSnackBar(
//                           //                   snackBar);
//                           //               setState(() {
//                           //                 abonneTap = false;
//                           //               });
//                           //
//                           //               // setState(() {
//                           //               //   abonneTap = false;
//                           //               // });
//                           //             }
//                           //           },
//                           //           child: abonneTap
//                           //               ? Center(
//                           //             child:
//                           //             LoadingAnimationWidget
//                           //                 .flickr(
//                           //               size: 20,
//                           //               leftDotColor:
//                           //               Colors.green,
//                           //               rightDotColor:
//                           //               Colors.black,
//                           //             ),
//                           //           )
//                           //               : Text(
//                           //             "Suivre",
//                           //             style: TextStyle(
//                           //                 fontSize: 12,
//                           //                 fontWeight:
//                           //                 FontWeight.w900,
//                           //                 color: Colors.white),
//                           //           )),
//                           //     );
//                           //   }),
//                         ],
//                       ),
//                     ),
//                     Stack(
//                       children: [
//                         SizedBox(
//
//                           child: InstaImageViewer(
//                             child: Image(
//                               image: Image.network('${widget.article.images![imageIndex]}')
//                                   .image,
//                             ),
//                           ),
//                         ),
//                         Positioned(
//                           top: 0,
//                           right: 0,
//
//                           child:onSupTap?Container(
//                               height: 20,
//                               width: 20,
//
//                               child: CircularProgressIndicator()):
//                           Visibility(
//                             visible:authProvider.loginUserData.id==widget.article.user_id||authProvider.loginUserData.role==UserRole.ADM.name?true:false,
//
//                             child: IconButton(onPressed: () async {
//                               widget.article.disponible=false;
//                               setState(() {
//                                 onSupTap=true;
//                               });
//                               await categorieProduitProvider.updateArticle(widget.article, context).then(
//                                     (value) {
//                                   if (value) {
//
//                                     ScaffoldMessenger.of(context).showSnackBar(
//
//                                       SnackBar(
//                                         backgroundColor: Colors.green,
//                                         content: Text('L\'article a été supprimé avec succès'),
//                                       ),
//                                     );
//                                     setState(() {
//                                       onSupTap=false;
//                                     });
//                                     Navigator.pop(context);
//                                   }  else{
//                                     setState(() {
//                                       onSupTap=false;
//                                     });
//                                     ScaffoldMessenger.of(context).showSnackBar(
//
//                                       SnackBar(
//                                         backgroundColor: Colors.red,
//                                         content: Text('Erreur de suppression'),
//                                       ),
//                                     );
//                                   }
//                                 },
//                               );
//
//                             }, icon: Icon(Icons.delete,color: Colors.red,size: 40,)),
//                           ),
//                         )
//                       ],
//                     ),
//
//                     // SizedBox(
//                     //
//                     //   child: InstaImageViewer(
//                     //     child: Image(
//                     //       image: Image.network('${widget.article.images![imageIndex]}')
//                     //           .image,
//                     //     ),
//                     //   ),
//                     // ),
//
//                     /*
//                     Container(
//                       //width: width,
//                       //height: height*0.55,
//                       child: CachedNetworkImage(
//                         fit: BoxFit.cover,
//
//                         imageUrl: '${widget.article.images![imageIndex]}',
//                         progressIndicatorBuilder: (context, url, downloadProgress) =>
//                         //  LinearProgressIndicator(),
//
//                         Skeletonizer(
//                             child: SizedBox(     width: width,
//                                 height: height*0.5, child:  ClipRRect(
//                                     borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${widget.article.images![imageIndex]}')))),
//                         errorWidget: (context, url, error) =>  Container(    width: width,
//                           height: height*0.5,child: Image.network('${widget.article.images![imageIndex]}',fit: BoxFit.cover,)),
//                       ),
//                     ),
//
//                      */
//                   ],
//                 ),
//               ),
//               SizedBox(height: 10,),
//               Container(
//                 alignment: Alignment.center,
//                 width: width,
//                 height: 60,
//                 child: ListView.builder(
//
//                   scrollDirection: Axis.horizontal,
//                 itemCount: widget.article.images!.length,
//                 itemBuilder: (BuildContext context, int index) {
//                   return    GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         imageIndex=index;
//                       });
//                     },
//                     child: Padding(
//                       padding: const EdgeInsets.all(2.0),
//                       child: Container(
//
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.all(Radius.circular(10)),
//                           border: Border.all(color: CustomConstants.kPrimaryColor)
//                         ),
//
//                         width: 110,
//                         height: 60,
//                         child: Image.network(
//                           widget.article.images![index],
//
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//                           ),
//               ),
//               // SizedBox(height: 20,),
//               Divider(height: 20,indent: 20,endIndent: 20,),
//               Padding(
//                 padding: const EdgeInsets.all(4.0),
//                 child: Center(
//                   child: Row(
//                     spacing: 5,
//                     children: [
//                       countryFlag(widget.article.countryData!['countryCode']??"TG"!, size: 30),
//                       Text(widget.article.countryData!['country']??"Togo"!,overflow: TextOverflow.ellipsis,style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15),),
//
//                     ],
//                   ),
//                 ),
//               ),
//
//               Divider(height: 20,indent: 20,endIndent: 20,),
//
//               Padding(
//                 padding: const EdgeInsets.only(left: 2.0,right: 2,top: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//
//                   children: [
//                     LikeButton(
//                       isLiked: false,
//                       size: iconSize,
//                       circleColor:
//                       CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
//                       bubblesColor: BubblesColor(
//                         dotPrimaryColor: Color(0xff3b9ade),
//                         dotSecondaryColor: Color(0xff027f19),
//                       ),
//                       countPostion: CountPostion.bottom,
//                       likeBuilder: (bool isLiked) {
//                         return Icon(
//                           FontAwesome.eye,
//                           color: isLiked ? Colors.black : Colors.brown,
//                           size: iconSize,
//                         );
//                       },
//                       likeCount:  widget.article.vues,
//                       countBuilder: (int? count, bool isLiked, String text) {
//                         var color = isLiked ? Colors.black : Colors.black;
//                         Widget result;
//                         if (count == 0) {
//                           result = Text(
//                             "0",textAlign: TextAlign.center,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         } else
//                           result = Text(
//                             text,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         return result;
//                       },
//
//                     ),
//                     LikeButton(
//                       isLiked: false,
//                       size: iconSize,
//                       circleColor:
//                       CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
//                       bubblesColor: BubblesColor(
//                         dotPrimaryColor: Color(0xff3b9ade),
//                         dotSecondaryColor: Color(0xff027f19),
//                       ),
//                       countPostion: CountPostion.bottom,
//                       likeBuilder: (bool isLiked) {
//                         return Icon(
//                           FontAwesome.whatsapp,
//                           color: isLiked ? Colors.green : Colors.green,
//                           size: iconSize,
//                         );
//                       },
//                       likeCount:  widget.article.contact,
//                       countBuilder: (int? count, bool isLiked, String text) {
//                         var color = isLiked ? Colors.black : Colors.black;
//                         Widget result;
//                         if (count == 0) {
//                           result = Text(
//                             "0",textAlign: TextAlign.center,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         } else
//                           result = Text(
//                             text,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         return result;
//                       },
//
//                     ),
//                     LikeButton(
//                       onTap: (isLiked) async {
//                         await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
//                           if (value.isNotEmpty) {
//                             value.first.jaime=value.first.jaime!+1;
//                             widget.article.jaime=value.first.jaime!+1;
//                             categorieProduitProvider.updateArticle(value.first,context).then((value) async {
//                               if (value) {
//                                 await authProvider.sendNotification(
//                                     userIds: [widget.article.user!.oneIgnalUserid!],
//                                     smallImage:
//                                     "${widget.article.images!.first}",
//                                     send_user_id:
//                                     "${authProvider.loginUserData.id!}",
//                                     recever_user_id: "${widget.article.user!.id!}",
//                                     message:
//                                     "📢 🛒 Un afrolookeur aime ❤️ votre produit 🛒",
//                                     type_notif:
//                                     NotificationType.ARTICLE.name,
//                                     post_id: "${widget.article!.id!}",
//                                     post_type: PostDataType.IMAGE.name,
//                                     chat_id: '');
//
//                                 NotificationData notif =
//                                 NotificationData();
//                                 notif.id = firestore
//                                     .collection('Notifications')
//                                     .doc()
//                                     .id;
//                                 notif.titre = " 🛒Boutique 🛒";
//                                 notif.media_url =
//                                     authProvider.loginUserData.imageUrl;
//                                 notif.type = NotificationType.ARTICLE.name;
//                                 notif.description =
//                                 "Un afrolookeur aime ❤️ votre produit 🛒";
//                                 notif.users_id_view = [];
//                                 notif.user_id =
//                                     authProvider.loginUserData.id;
//                                 notif.receiver_id = widget.article.user!.id!;
//                                 notif.post_id = widget.article.id!;
//                                 notif.post_data_type =
//                                 PostDataType.IMAGE.name!;
//
//                                 notif.updatedAt =
//                                     DateTime.now().microsecondsSinceEpoch;
//                                 notif.createdAt =
//                                     DateTime.now().microsecondsSinceEpoch;
//                                 notif.status = PostStatus.VALIDE.name;
//
//                                 // users.add(pseudo.toJson());
//
//                                 await firestore
//                                     .collection('Notifications')
//                                     .doc(notif.id)
//                                     .set(notif.toJson());
//
//                               }
//                             },);
//
//                           }
//                         },);
//
//                         return Future.value(true);
//
//                       },
//                       isLiked: false,
//                       size: iconSize,
//                       circleColor:
//                       CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
//                       bubblesColor: BubblesColor(
//                         dotPrimaryColor: Color(0xff3b9ade),
//                         dotSecondaryColor: Color(0xff027f19),
//                       ),
//                       countPostion: CountPostion.bottom,
//                       likeBuilder: (bool isLiked) {
//                         return Icon(
//                           FontAwesome.heart,
//                           color: isLiked ? Colors.red : Colors.redAccent,
//                           size: iconSize,
//                         );
//                       },
//                       likeCount:   widget.article.jaime,
//                       countBuilder: (int? count, bool isLiked, String text) {
//                         var color = isLiked ? Colors.black : Colors.black;
//                         Widget result;
//                         if (count == 0) {
//                           result = Text(
//                             "0",textAlign: TextAlign.center,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         } else
//                           result = Text(
//                             text,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         return result;
//                       },
//
//                     ),
//                     LikeButton(
//                       onTap: (isLiked) async {
//
//                         await authProvider.createArticleLink(true,widget.article).then((url) async {
//                           final box = context.findRenderObject() as RenderBox?;
//
//                           await Share.shareUri(
//                             Uri.parse(
//                                 '${url}'),
//                             sharePositionOrigin:
//                             box!.localToGlobal(Offset.zero) & box.size,
//                           );
//
//                           // printVm("article : ${article.toJson()}");
//                           setState(() {
//                            widget.article.partage = widget.article.partage! + 1;
//                             // post.users_love_id!
//                             //     .add(authProvider!.loginUserData.id!);
//                             // love = post.loves!;
//                             // //loves.add(idUser);
//                           });
//                           CollectionReference userCollect =
//                           FirebaseFirestore.instance
//                               .collection('Users');
//                           // Get docs from collection reference
//                           QuerySnapshot querySnapshotUser =
//                           await userCollect
//                               .where("id",
//                               isEqualTo: widget.article.user!.id!)
//                               .get();
//                           // Afficher la liste
//                           List<UserData> listUsers = querySnapshotUser
//                               .docs
//                               .map((doc) => UserData.fromJson(
//                               doc.data() as Map<String, dynamic>))
//                               .toList();
//                           if (listUsers.isNotEmpty) {
//                             // listUsers.first!.partage =
//                             //     listUsers.first!.partage! + 1;
//                             printVm("user trouver");
//                             if (widget.article.user!.oneIgnalUserid != null &&
//                                 widget.article.user!.oneIgnalUserid!.length > 5) {
//                               await authProvider.sendNotification(
//                                   userIds: [widget.article.user!.oneIgnalUserid!],
//                                   smallImage:
//                                   "${widget.article.images!.first}",
//                                   // "${authProvider.loginUserData.imageUrl!}",
//                                   send_user_id:
//                                   "${authProvider.loginUserData.id!}",
//                                   recever_user_id: "${widget.article.user!.id!}",
//                                   message:
//                                   "📢 🛒 Un afrolookeur a partagé votre produit 🛒",
//                                   type_notif:
//                                   NotificationType.ARTICLE.name,
//                                   post_id: "${widget.article!.id!}",
//                                   post_type: PostDataType.IMAGE.name,
//                                   chat_id: '');
//
//                               NotificationData notif =
//                               NotificationData();
//                               notif.id = firestore
//                                   .collection('Notifications')
//                                   .doc()
//                                   .id;
//                               notif.titre = " 🛒Boutique 🛒";
//                               notif.media_url =
//                               "${widget.article.images!.first}";
//                               notif.type = NotificationType.ARTICLE.name;
//                               notif.description =
//                               "Un afrolookeur a partagé votre produit 🛒";
//                               notif.users_id_view = [];
//                               notif.user_id =
//                                   authProvider.loginUserData.id;
//                               notif.receiver_id = widget.article.user!.id!;
//                               notif.post_id = widget.article.id!;
//                               notif.post_data_type =
//                               PostDataType.IMAGE.name!;
//
//                               notif.updatedAt =
//                                   DateTime.now().microsecondsSinceEpoch;
//                               notif.createdAt =
//                                   DateTime.now().microsecondsSinceEpoch;
//                               notif.status = PostStatus.VALIDE.name;
//
//                               // users.add(pseudo.toJson());
//
//                               await firestore
//                                   .collection('Notifications')
//                                   .doc(notif.id)
//                                   .set(notif.toJson());
//                             }
//                             // postProvider.updateVuePost(post, context);
//
//                             //userProvider.updateUser(listUsers.first);
//                             // SnackBar snackBar = SnackBar(
//                             //   content: Text(
//                             //     '+2 points.  Voir le classement',
//                             //     textAlign: TextAlign.center,
//                             //     style: TextStyle(color: Colors.green),
//                             //   ),
//                             // );
//                             // ScaffoldMessenger.of(context)
//                             //     .showSnackBar(snackBar);
//                             categorieProduitProvider.updateArticle(
//                                 widget.article, context);
//                             // await authProvider.getAppData();
//                             // authProvider.appDefaultData.nbr_loves =
//                             //     authProvider.appDefaultData.nbr_loves! +
//                             //         2;
//                             // authProvider.updateAppData(
//                             //     authProvider.appDefaultData);
//
//
//                           }
//                           await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
//                             if (value.isNotEmpty) {
//                               value.first.partage=value.first.partage!+1;
//                               // widget.article.partage=value.first.partage!+1;
//                               categorieProduitProvider.updateArticle(value.first,context).then((value) {
//                                 if (value) {
//                                   setState(() {
//
//                                   });
//
//                                 }
//                               },);
//
//                             }
//                           },);
//
//                         },);
//
//
//                         return Future.value(true);
//
//                       },
//                       isLiked: false,
//                       size: iconSize,
//                       circleColor:
//                       CircleColor(start: Color(0xffffc400), end: Color(
//                           0xffcc7a00)),
//                       bubblesColor: BubblesColor(
//                         dotPrimaryColor: Color(0xffffc400),
//                         dotSecondaryColor: Color(0xff07f629),
//                       ),
//                       countPostion: CountPostion.bottom,
//                       likeBuilder: (bool isLiked) {
//                         return Icon(
//                           Entypo.share,
//                           color: isLiked ? Colors.blue : Colors.blueAccent,
//                           size: iconSize,
//                         );
//                       },
//                       likeCount:   widget.article.partage,
//                       countBuilder: (int? count, bool isLiked, String text) {
//                         var color = isLiked ? Colors.black : Colors.black;
//                         Widget result;
//                         if (count == 0) {
//                           result = Text(
//                             "0",textAlign: TextAlign.center,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         } else
//                           result = Text(
//                             text,
//                             style: TextStyle(color: color,fontSize: 8),
//                           );
//                         return result;
//                       },
//
//                     ),
//
//                   ],
//                 ),
//               ),
//               Divider(height: 20,indent: 20,endIndent: 20,),
//
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 8.0,top: 8),
//                 child: Text("${widget.article.titre}",overflow: TextOverflow.ellipsis,style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15),),
//               ),
//               // Text(article.description),
//               Container(
//
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                       borderRadius: BorderRadius.all(Radius.circular(5)),
//                       color:  CustomConstants.kPrimaryColor
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Text('Prix: ${widget.article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600),),
//                   )),
//                SizedBox(height: 20,),
//                Text("${widget.article.description}"),
//
//               SizedBox(height: height*0.1,),
//
//             ]
//       ),
//           ),
//         ),
//
//
//       bottomSheet:     Container(
//         height: 80,
//         width: width,
//
//         child: TextButton(
//           onPressed: () async {
//             await authProvider.createArticleLink(true,widget.article).then((url) async {
//
// // printVm("widget.article : ${widget.article.toJson()}");
//
//               setState(() {
//                 widget.article.contact = widget.article.contact! + 1;
//                 launchWhatsApp(widget.article.phone!, widget!.article!,url);
//
//                 // post.users_love_id!
//                 //     .add(authProvider!.loginUserData.id!);
//                 // love = post.loves!;
//                 // //loves.add(idUser);
//               });
//               CollectionReference userCollect =
//               FirebaseFirestore.instance
//                   .collection('Users');
//               // Get docs from collection reference
//               QuerySnapshot querySnapshotUser =
//               await userCollect
//                   .where("id",
//                   isEqualTo: widget.article.user!.id!)
//                   .get();
//               // Afficher la liste
//               List<UserData> listUsers = querySnapshotUser
//                   .docs
//                   .map((doc) => UserData.fromJson(
//                   doc.data() as Map<String, dynamic>))
//                   .toList();
//               if (listUsers.isNotEmpty) {
//                 // listUsers.first!.partage =
//                 //     listUsers.first!.partage! + 1;
//                 printVm("user trouver");
//                 if (widget.article.user!.oneIgnalUserid != null &&
//                     widget.article.user!.oneIgnalUserid!.length > 5) {
//
//
//                   NotificationData notif =
//                   NotificationData();
//                   notif.id = firestore
//                       .collection('Notifications')
//                       .doc()
//                       .id;
//                   notif.titre = " 🛒Boutique 🛒";
//                   notif.media_url =
//                       authProvider.loginUserData.imageUrl;
//                   notif.type = NotificationType.ARTICLE.name;
//                   notif.description =
//                   "@${authProvider.loginUserData.pseudo!} veut votre produit 🛒";
//                   notif.users_id_view = [];
//                   notif.user_id =
//                       authProvider.loginUserData.id;
//                   notif.receiver_id = widget.article.user!.id!;
//                   notif.post_id = widget.article.id!;
//                   notif.post_data_type =
//                   PostDataType.IMAGE.name!;
//
//                   notif.updatedAt =
//                       DateTime.now().microsecondsSinceEpoch;
//                   notif.createdAt =
//                       DateTime.now().microsecondsSinceEpoch;
//                   notif.status = PostStatus.VALIDE.name;
//
//                   // users.add(pseudo.toJson());
//
//                   await firestore
//                       .collection('Notifications')
//                       .doc(notif.id)
//                       .set(notif.toJson());
//
//                   await authProvider.sendNotification(
//                       userIds: [widget.article.user!.oneIgnalUserid!],
//                       smallImage:
//                       "${authProvider.loginUserData.imageUrl!}",
//                       send_user_id:
//                       "${authProvider.loginUserData.id!}",
//                       recever_user_id: "${widget.article.user!.id!}",
//                       message:
//                       "📢 🛒 @${authProvider.loginUserData.pseudo!} veut votre produit 🛒",
//                       type_notif:
//                       NotificationType.ARTICLE.name,
//                       post_id: "${widget.article!.id!}",
//                       post_type: PostDataType.IMAGE.name,
//                       chat_id: '');
//                 }
//                 // postProvider.updateVuePost(post, context);
//
//                 //userProvider.updateUser(listUsers.first);
//                 // SnackBar snackBar = SnackBar(
//                 //   content: Text(
//                 //     '+2 points.  Voir le classement',
//                 //     textAlign: TextAlign.center,
//                 //     style: TextStyle(color: Colors.green),
//                 //   ),
//                 // );
//                 // ScaffoldMessenger.of(context)
//                 //     .showSnackBar(snackBar);
//                 categorieProduitProvider.updateArticle(
//                     widget.article, context);
//                 // await authProvider.getAppData();
//                 // authProvider.appDefaultData.nbr_loves =
//                 //     authProvider.appDefaultData.nbr_loves! +
//                 //         2;
//                 // authProvider.updateAppData(
//                 //     authProvider.appDefaultData);
//
//
//               }
//
//             },);
//
//
//
//           },
//           child:onSaveTap?Container(
//               height: 20,
//               width: 20,
//
//               child: CircularProgressIndicator()): Container(
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                   color: Colors.brown,
//                   borderRadius: BorderRadius.all(Radius.circular(5))
//               ),
//               height: 40,
//               width: width*0.8,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   Text('Contacter le vendeur',style: TextStyle(color: Colors.white),),
//                   IconButton(
//                     icon: Icon(FontAwesome.whatsapp,color: Colors.green,size: 30,),
//                     onPressed: () async {
//
//                       // Fonction pour ouvrir WhatsApp
//                     },
//                   ),
//                 ],
//               )),
//         ),
//       ),
//     );
//
//
//
//   }
//
// }
