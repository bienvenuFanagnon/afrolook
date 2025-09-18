import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../pages/contenuPayant/contentDetails.dart';
import '../pages/paiement/newDepot.dart';
import 'authProvider.dart';

class ContentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // UserData? currentUser;

  List<ContentPaie> _featuredContentPaies = [];
  Map<String, List<ContentPaie>> _contentPaiesByCategory = {};
  // List<ContentCategory> _categories
  // = [
  // ContentCategory(
  // id: '1',
  // name: 'Musique',
  // description: 'Clips, concerts et tout ce qui bouge 🎶',
  // imageUrl: 'https://example.com/musique.jpg',
  // ),
  // ContentCategory(
  // id: '2',
  // name: 'Sport',
  // description: 'Football, basket, fitness et plus 🏀⚽',
  // imageUrl: 'https://example.com/sport.jpg',
  // ),
  // ContentCategory(
  // id: '3',
  // name: 'Éducation',
  // description: 'Cours, tutos et apprentissage 📚',
  // imageUrl: 'https://example.com/education.jpg',
  // ),
  // ContentCategory(
  // id: '4',
  // name: 'Divertissement',
  // description: 'Humour, films et distractions 😂🎬',
  // imageUrl: 'https://example.com/divertissement.jpg',
  // ),
  // ContentCategory(
  // id: '5',
  // name: 'Actualités',
  // description: 'Infos, débats et tendances 🌍',
  // imageUrl: 'https://example.com/actualites.jpg',
  // ),
  // ContentCategory(
  // id: '6',
  // name: 'Mode',
  // description: 'Styles, looks et tendances 👗👟',
  // imageUrl: 'https://example.com/mode.jpg',
  // ),
  // ];

  List<ContentCategory> _categories = [
    ContentCategory(
      id: '1',
      name: 'Musique',
      description: 'Clips, concerts et tout ce qui bouge 🎶',
      imageUrl: 'https://example.com/musique.jpg',
    ),
    ContentCategory(
      id: '2',
      name: 'Sport',
      description: 'Football, basket, fitness et plus 🏀⚽',
      imageUrl: 'https://example.com/sport.jpg',
    ),
    ContentCategory(
      id: '3',
      name: 'Éducation',
      description: 'Cours, tutos et apprentissage 📚',
      imageUrl: 'https://example.com/education.jpg',
    ),
    ContentCategory(
      id: '4',
      name: 'Divertissement',
      description: 'Humour, films et distractions 😂🎬',
      imageUrl: 'https://example.com/divertissement.jpg',
    ),
    ContentCategory(
      id: '5',
      name: 'Actualités',
      description: 'Infos, débats et tendances 🌍',
      imageUrl: 'https://example.com/actualites.jpg',
    ),
    ContentCategory(
      id: '6',
      name: 'Mode',
      description: 'Styles, looks et tendances 👗👟',
      imageUrl: 'https://example.com/mode.jpg',
    ),
    ContentCategory(
      id: '7',
      name: 'Vidéos Virales',
      description: 'Les vidéos qui font le buzz 🔥😂',
      imageUrl: 'https://example.com/virales.jpg',
    ),
    ContentCategory(
      id: '8',
      name: 'Fuites & Exclus',
      description: 'Contenus inédits et coulisses 🤫🎥',
      imageUrl: 'https://example.com/fuites.jpg',
    ),
    ContentCategory(
      id: '9',
      name: 'Challenges',
      description: 'Moments amusants et nostalgie 🎉👶',
      imageUrl: 'https://example.com/jeunesse.jpg',
    ),
    ContentCategory(
      id: '10',
      name: 'Cartoon',
      description: 'Animations 🐭🎨',
      imageUrl: 'https://example.com/cartoon.jpg',
    ),
    ContentCategory(
      id: '11',
      name: 'Manga',
      description: 'Bandes dessinées japonaises et animés 🇯🇵📖',
      imageUrl: 'https://example.com/manga.jpg',
    ),
  ];

  List<ContentPaie> _userContentPaies = [];
  List<ContentPurchase> _userPurchases = [];
  List<Episode> _episodes = [];

  List<ContentPaie> get featuredContentPaies => _featuredContentPaies;
  Map<String, List<ContentPaie>> get contentPaiesByCategory => _contentPaiesByCategory;
  List<ContentCategory> get categories => _categories;
  List<ContentPaie> get userContentPaies => _userContentPaies;
  List<ContentPurchase> get userPurchases => _userPurchases;
  List<Episode> get episodes => _episodes;
  final UserAuthProvider? _authProvider; // Référence vers le provider auth

  ContentProvider({required UserAuthProvider authProvider}) : _authProvider = authProvider {
    // Charger les données initiales dès la création du provider
    loadInitialData();
  }
  List<ContentPaie> _allContentPaies = [];

  List<ContentPaie> get allContentPaies => _allContentPaies;

  Future<void> loadAllContentPaies() async {
    try {
      final snapshot = await _firestore
          .collection('ContentPaies')
          .orderBy('createdAt', descending: true)
          .get(); // On ne met pas de limit pour récupérer tout

      _allContentPaies = snapshot.docs
          .map((doc) => ContentPaie.fromJson({
        ...doc.data(),
        'id': doc.id, // Assure que l'id du document est inclus
      }))
          .toList();

      notifyListeners();
      print("All ContentPaies loaded: ${_allContentPaies.length}");
    } catch (e) {
      print('Error loading all ContentPaies: $e');
    }
  }

  // Récupération sécurisée de l'utilisateur courant
  UserData? get currentUser => _authProvider?.loginUserData;
  // Méthode pour définir l'utilisateur courant
  void setCurrentUser() {
    // currentUser = user;
    loadInitialData();
  }

  Future<void> loadInitialData() async {
     loadUserPurchases();
     loadAllContentPaies();
    await loadFeaturedContentPaies();

    await loadCategories();

    await loadContentPaiesByCategory();

    await loadUserContentPaies();

    await loadEpisodes();
  }
// Modifiez votre fonction pour charger les nouveautés (gratuites ET payantes)
  Future<void> loadFeaturedContentPaies() async {
    try {
      final snapshot = await _firestore
          .collection('ContentPaies')
          .orderBy('createdAt', descending: true) // Trier par date de création
          .limit(10)
          .get();

      _featuredContentPaies = snapshot.docs
          .map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading featured ContentPaies: $e');
    }
  }
  Future<void> loadFeaturedContentPaies2() async {
    try {
      final snapshot = await _firestore
          .collection('ContentPaies')
          .where('isFree', isEqualTo: true)
          .orderBy('views', descending: true)
          .limit(10)
          .get();

      _featuredContentPaies = snapshot.docs
          .map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading featured ContentPaies: $e');
    }
  }
  Future<void> loadCategories() async {
    try {
      _categories.shuffle();

      notifyListeners();
    } catch (e) {
      print('Erreur chargement catégories: $e');
    }
  }

  Future<void> loadCategories2() async {
    try {
      final snapshot = await _firestore.collection('categories').get();
      _categories = snapshot.docs
          .map((doc) => ContentCategory.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> loadContentPaiesByCategory() async {
    try {
      for (var category in _categories) {
        final snapshot = await _firestore
            .collection('ContentPaies')
            .where('categories', arrayContains: category.id)
            .orderBy('views', descending: true)
            .limit(10)
            .get();

        _contentPaiesByCategory[category.id!] = snapshot.docs
            .map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      print('Error loading ContentPaies by category: $e');
    }
  }

  Future<void> loadUserContentPaies() async {
    if (currentUser == null) return;

    try {
      final snapshot = await _firestore
          .collection('ContentPaies')
          .where('ownerId', isEqualTo: currentUser!.id)
          .orderBy('createdAt', descending: true)
          .get();

      _userContentPaies = snapshot.docs
          .map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading user ContentPaies: $e');
    }
  }

  Future<void> loadUserPurchases() async {
    printVm("content current user : ${_authProvider!.loginUserData!.toJson()}");
    printVm("content current user : ${currentUser!.toJson()}");

    if (currentUser == null) return;
    try {
      final snapshot = await _firestore
          .collection('ContentPaie_purchases')
          .where('userId', isEqualTo: currentUser!.id)
          .orderBy('purchaseDate', descending: true)
          .get();

      _userPurchases = snapshot.docs
          .map((doc) => ContentPurchase.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading user purchases: $e');
    }
  }

  Future<void> loadEpisodes() async {
    try {
      final snapshot = await _firestore
          .collection('episodes')
          .orderBy('episodeNumber', descending: false)
          .get();

      _episodes = snapshot.docs
          .map((doc) => Episode.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading episodes: $e');
    }
  }

  Future<List<Episode>> getEpisodesForSeries(String seriesId) async {
    try {
      final snapshot = await _firestore
          .collection('episodes')
          .where('seriesId', isEqualTo: seriesId)
          .orderBy('episodeNumber', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Episode.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting episodes for series: $e');
      return [];
    }
  }
  Future<PurchaseResult> purchaseContentPaie(UserData currentUser, ContentPaie contentPaie, BuildContext context) async {
    try {
      // Vérifier si l'utilisateur a déjà acheté ce contenu
      final existingPurchase = await _firestore
          .collection('ContentPaie_purchases')
          .where('userId', isEqualTo: currentUser.id)
          .where('contentId', isEqualTo: contentPaie.id)
          .get();

      if (existingPurchase.docs.isNotEmpty) {
        return PurchaseResult.alreadyPurchased;
      }

      // 🔹 Récupérer le solde en temps réel depuis Firestore
      final userDoc =
      await _firestore.collection('Users').doc(currentUser.id).get();

      if (!userDoc.exists) {
        _showErrorModal(context, "Utilisateur introuvable !");
        return PurchaseResult.error;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final double soldeActuel =
      (userData['votre_solde_principal'] ?? 0).toDouble();

      // Vérifier le solde
      if (soldeActuel < contentPaie.price) {
        _showInsufficientBalanceModal(context, contentPaie.price - soldeActuel);
        return PurchaseResult.insufficientBalance;
      }

      // Processus d'achat...
      final ownerEarnings = contentPaie.price * 0.5;
      final platformEarnings = contentPaie.price * 0.5;

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('Users').doc(currentUser.id);
        final ownerRef = _firestore.collection('Users').doc(contentPaie.ownerId);
        final appDataRef =
        _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');

        // 🔹 Débiter l'acheteur
        transaction.update(userRef, {
          'votre_solde_principal': FieldValue.increment(-contentPaie.price),
        });

        // 🔹 Créditer le créateur
        transaction.update(ownerRef, {
          'votre_solde_principal': FieldValue.increment(ownerEarnings),
        });

        // 🔹 Créditer la plateforme
        transaction.update(appDataRef, {
          'solde_gain': FieldValue.increment(platformEarnings),
        });

        // 🔹 Enregistrer l’achat
        final purchase = ContentPurchase(
          userId: currentUser.id!,
          contentId: contentPaie.id!,
          amountPaid: contentPaie.price,
          ownerEarnings: ownerEarnings,
          platformEarnings: platformEarnings,
          purchaseDate: DateTime.now().millisecondsSinceEpoch,
        );
        transaction.set(
          _firestore.collection('ContentPaie_purchases').doc(),
          purchase.toJson(),
        );

        // 🔹 Créer la transaction "DEPENSE" pour l’acheteur
        final depenseRef = _firestore.collection("TransactionSoldes").doc();
        transaction.set(depenseRef, {
          "id": depenseRef.id,
          "user_id": currentUser.id,
          "type": "DEPENSE",
          "statut": "VALIDER",
          "description": "Achat contenu ${contentPaie.id}",
          "montant": contentPaie.price,
          "numero_depot": "",
          "createdAt": DateTime.now().millisecondsSinceEpoch,
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
          "frais": 0.0,
          "montant_total": contentPaie.price,
          "methode_paiement": "SOLDE",
          "id_transaction_cinetpay": "",
        });

        // 🔹 Créer la transaction "GAIN" pour le créateur
        final gainRef = _firestore.collection("TransactionSoldes").doc();
        transaction.set(gainRef, {
          "id": gainRef.id,
          "user_id": contentPaie.ownerId,
          "type": "GAIN",
          "statut": "VALIDER",
          "description": "Vente contenu ${contentPaie.id}",
          "montant": ownerEarnings,
          "numero_depot": "",
          "createdAt": DateTime.now().millisecondsSinceEpoch,
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
          "frais": 0.0,
          "montant_total": ownerEarnings,
          "methode_paiement": "SOLDE",
          "id_transaction_cinetpay": "",
        });
      });


// 🔹 Envoyer la notification au créateur
      final ownerDoc = await _firestore.collection('Users').doc(contentPaie.ownerId).get();
      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data()!;
        await _authProvider?.sendNotification(
          userIds: [ownerData['oneIgnalUserid']],
          smallImage: currentUser.imageUrl!,
          send_user_id: currentUser.id!,
          recever_user_id: contentPaie.ownerId!,
          message: "📢 Votre vidéo a été achetée pour ${ownerEarnings.toStringAsFixed(2)} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: contentPaie.id!,
          post_type: "video",
          chat_id: '',
        );
      }
      await loadUserPurchases();

      return PurchaseResult.success;
    } catch (e) {
      print('Error purchasing ContentPaie: $e');
      _showErrorModal(context, e.toString());
      return PurchaseResult.error;
    }
  }
  Future<bool> purchaseContentPaie2(UserData currentUser, ContentPaie contentPaie, BuildContext context) async {
    if (currentUser == null) return false;

    try {
      // Vérifier si l'utilisateur a déjà acheté ce contenu
      final existingPurchase = await _firestore
          .collection('ContentPaie_purchases')
          .where('userId', isEqualTo: currentUser!.id)
          .where('contentId', isEqualTo: contentPaie.id)
          .get();

      if (existingPurchase.docs.isNotEmpty) {
        return true; // Déjà acheté
      }

      // Vérifier le solde de l'utilisateur
      if (currentUser!.votre_solde_principal! < contentPaie.price) {
        print('Afficher le modal pour solde insuffisant: ${currentUser!.votre_solde_principal!}');

        // Afficher le modal pour solde insuffisant
        _showInsufficientBalanceModal(context, contentPaie.price - currentUser!.votre_solde_principal!);
        return false; // Solde insuffisant
      }

      // Calculer les gains (50% pour le propriétaire, 50% pour la plateforme)
      final ownerEarnings = contentPaie.price * 0.5;
      final platformEarnings = contentPaie.price * 0.5;

      // Mettre à jour le solde de l'utilisateur
      await _firestore.collection('Users').doc(currentUser!.id).update({
        'votre_solde_principal': FieldValue.increment(-contentPaie.price),
      });

      // Mettre à jour le solde du propriétaire du contenu
      await _firestore.collection('Users').doc(contentPaie.ownerId).update({
        'votre_solde_contenu': FieldValue.increment(ownerEarnings),
      });

      // Mettre à jour le solde de la plateforme
      final appDataDoc = await _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT').get();
      if (appDataDoc.exists) {
        await _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT').update({
          'solde_gain': FieldValue.increment(platformEarnings),
        });
      }

      // Créer l'achat
      final purchase = ContentPurchase(
        userId: currentUser!.id!,
        contentId: contentPaie.id!,
        amountPaid: contentPaie.price,
        ownerEarnings: ownerEarnings,
        platformEarnings: platformEarnings,
        purchaseDate: DateTime.now().millisecondsSinceEpoch,
      );

      await _firestore.collection('ContentPaie_purchases').add(purchase.toJson());

      // Ajouter le contenu à la liste des vidéos vues par l'utilisateur
      await _firestore.collection('Users').doc(currentUser!.id).update({
        'viewedVideos': FieldValue.arrayUnion([contentPaie.id]),
      });

      // Recharger les données
      await loadUserPurchases();

      return true;
    } catch (e) {
      print('Error purchasing ContentPaie: $e');
      // Afficher le modal d'erreur
      _showErrorModal(context, e.toString());
      return false;
    }
  }

  void _showInsufficientBalanceModal(BuildContext context, double missingAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Titre
                  Text(
                    'Solde Insuffisant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),

                  // Message
                  Text(
                    'Il vous manque ${missingAmount.toStringAsFixed(0)} FCFA pour débloquer cette vidéo.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),

                  Text(
                    'Rechargez votre compte pour continuer.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),

                  // Boutons
                  Row(
                    children: [
                      // Bouton Annuler
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Plus tard'),
                        ),
                      ),
                      SizedBox(width: 12),

                      // Bouton Recharger
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Fermer le modal
                            // Naviguer vers la page de rechargement
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => DepositScreen()));
                          },
                          child: Text('Recharger'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorModal(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône d'erreur
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Titre
                  Text(
                    'Erreur de Paiement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),

                  // Message d'erreur
                  Text(
                    'Une erreur s\'est produite lors du traitement de votre paiement.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),

                  Text(
                    'Veuillez réessayer ou contacter le support.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // Détails de l'erreur (optionnel)
                  if (errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Erreur: ${errorMessage.length > 100 ? errorMessage.substring(0, 100) + '...' : errorMessage}',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: 24),

                  // Bouton de fermeture
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Compris'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Future<bool> purchaseContentPaie3(ContentPaie contentPaie) async {
    if (currentUser == null) return false;

    try {
      // Vérifier si l'utilisateur a déjà acheté ce contenu
      final existingPurchase = await _firestore
          .collection('ContentPaie_purchases')
          .where('userId', isEqualTo: currentUser!.id)
          .where('contentId', isEqualTo: contentPaie.id)
          .get();

      if (existingPurchase.docs.isNotEmpty) {
        return true; // Déjà acheté
      }

      // Vérifier le solde de l'utilisateur
      if (currentUser!.votre_solde_principal! < contentPaie.price) {
        return false; // Solde insuffisant
      }

      // Calculer les gains (50% pour le propriétaire, 50% pour la plateforme)
      final ownerEarnings = contentPaie.price * 0.5;
      final platformEarnings = contentPaie.price * 0.5;

      // Mettre à jour le solde de l'utilisateur
      await _firestore.collection('Users').doc(currentUser!.id).update({
        'votre_solde_principal': FieldValue.increment(-contentPaie.price),
      });

      // Mettre à jour le solde du propriétaire du contenu
      await _firestore.collection('Users').doc(contentPaie.ownerId).update({
        'votre_solde_contenu': FieldValue.increment(ownerEarnings),
      });

      // Mettre à jour le solde de la plateforme
      final appDataDoc = await _firestore.collection('app_data').doc('default').get();
      if (appDataDoc.exists) {
        await _firestore.collection('app_data').doc('default').update({
          'solde_principal': FieldValue.increment(platformEarnings),
        });
      }

      // Créer l'achat
      final purchase = ContentPurchase(
        userId: currentUser!.id!,
        contentId: contentPaie.id!,
        amountPaid: contentPaie.price,
        ownerEarnings: ownerEarnings,
        platformEarnings: platformEarnings,
        purchaseDate: DateTime.now().millisecondsSinceEpoch,
      );

      await _firestore.collection('ContentPaie_purchases').add(purchase.toJson());

      // Ajouter le contenu à la liste des vidéos vues par l'utilisateur
      await _firestore.collection('Users').doc(currentUser!.id).update({
        'viewedVideos': FieldValue.arrayUnion([contentPaie.id]),
      });

      // Recharger les données
      await loadUserPurchases();

      return true;
    } catch (e) {
      print('Error purchasing ContentPaie: $e');
      return false;
    }
  }

  Future<bool> addContentPaie(ContentPaie contentPaie) async {

    printVm("ContentPaies add : ${contentPaie.toJson()}");
    try {
      final docRef = await _firestore.collection('ContentPaies').add(contentPaie.toJson());
      contentPaie.id = docRef.id;
      printVm("docRef.id : ${docRef.id}");

      // Si c'est une série, créer le premier épisode
      if (contentPaie.isSeries) {
        final episode = Episode(
          seriesId: docRef.id,
          title: 'Épisode 1: ${contentPaie.title}',
          description: contentPaie.description,
          videoUrl: contentPaie.videoUrl!,
          thumbnailUrl: contentPaie.thumbnailUrl,
          duration: contentPaie.duration,
          episodeNumber: 1,
          price: contentPaie.price,
          isFree: contentPaie.isFree,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        printVm("episodes add : ${episode.toJson()}");

        await _firestore.collection('episodes').add(episode.toJson());
      }

      // await loadUserContentPaies();
      return true;
    } catch (e) {
      print('Error adding ContentPaie: $e');
      return false;
    }
  }

  Future<bool> addEpisode(Episode episode) async {
    try {
      // Vérifier si un épisode avec le même numéro existe déjà
      final existingEpisode = await _firestore
          .collection('episodes')
          .where('seriesId', isEqualTo: episode.seriesId)
          .where('episodeNumber', isEqualTo: episode.episodeNumber)
          .get();

      if (existingEpisode.docs.isNotEmpty) {
        print('Un épisode avec ce numéro existe déjà pour cette série');
        return false;
      }

      final docRef = await _firestore.collection('episodes').add(episode.toJson());
      episode.id = docRef.id;

      // Mettre à jour la date de modification de la série
      await _firestore.collection('ContentPaies').doc(episode.seriesId).update({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Recharger les épisodes
      await loadEpisodes();

      return true;
    } catch (e) {
      print('Error adding episode: $e');
      return false;
    }
  }

  Future<bool> updateContentPaie(ContentPaie contentPaie) async {
    try {
      await _firestore.collection('ContentPaies').doc(contentPaie.id).update(contentPaie.toJson());
      await loadUserContentPaies();
      return true;
    } catch (e) {
      print('Error updating ContentPaie: $e');
      return false;
    }
  }

  Future<bool> updateEpisode(Episode episode) async {
    try {
      await _firestore.collection('episodes').doc(episode.id).update(episode.toJson());

      // Mettre à jour la date de modification de la série
      await _firestore.collection('ContentPaies').doc(episode.seriesId).update({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await loadEpisodes();
      return true;
    } catch (e) {
      print('Error updating episode: $e');
      return false;
    }
  }

  Future<bool> deleteContentPaie(String contentPaieId) async {
    try {
      await _firestore.collection('ContentPaies').doc(contentPaieId).delete();

      // Supprimer aussi les épisodes si c'est une série
      final episodes = await _firestore
          .collection('episodes')
          .where('seriesId', isEqualTo: contentPaieId)
          .get();

      for (var doc in episodes.docs) {
        await doc.reference.delete();
      }

      await loadUserContentPaies();
      await loadEpisodes();
      return true;
    } catch (e) {
      print('Error deleting ContentPaie: $e');
      return false;
    }
  }

  Future<bool> deleteEpisode(String episodeId) async {
    try {
      final doc = await _firestore.collection('episodes').doc(episodeId).get();
      if (doc.exists) {
        final episode = Episode.fromJson({...doc.data()!, 'id': doc.id});

        await _firestore.collection('episodes').doc(episodeId).delete();

        // Mettre à jour la date de modification de la série
        await _firestore.collection('ContentPaies').doc(episode.seriesId).update({
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        await loadEpisodes();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting episode: $e');
      return false;
    }
  }

  Future<List<ContentPaie>> searchContentPaies(String query) async {
    try {
      // Recherche par titre
      final titleSnapshot = await _firestore
          .collection('ContentPaies')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .get();

      // Recherche par hashtags
      final hashtagSnapshot = await _firestore
          .collection('ContentPaies')
          .where('hashtags', arrayContains: query)
          .get();

      final results = [
        ...titleSnapshot.docs.map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id})),
        ...hashtagSnapshot.docs.map((doc) => ContentPaie.fromJson({...doc.data(), 'id': doc.id})),
      ];

      // Éliminer les doublons
      return results.toSet().toList();
    } catch (e) {
      print('Error searching ContentPaies: $e');
      return [];
    }
  }

  // Future<List<Episode>> searchEpisodes(String query, {String? seriesId}) async {
  //   try {
  //     QuerySnapshot snapshot;
  //
  //     if (seriesId != null) {
  //       // Recherche dans une série spécifique
  //       snapshot = await _firestore
  //           .collection('episodes')
  //           .where('seriesId', isEqualTo: seriesId)
  //           .where('title', isGreaterThanOrEqualTo: query)
  //           .where('title', isLessThan: query + 'z')
  //           .get();
  //     } else {
  //       // Recherche globale
  //       snapshot = await _firestore
  //           .collection('episodes')
  //           .where('title', isGreaterThanOrEqualTo: query)
  //           .where('title', isLessThan: query + 'z')
  //           .get();
  //     }
  //
  //     return snapshot.docs
  //         .map((doc) => Episode.fromJson({...doc.data(), 'id': doc.id}))
  //         .toList();
  //   } catch (e) {
  //     print('Error searching episodes: $e');
  //     return [];
  //   }
  // }

  Future<void> incrementViews(String contentId, {bool isEpisode = false}) async {
    try {
      if (isEpisode) {
        await _firestore.collection('episodes').doc(contentId).update({
          'views': FieldValue.increment(1),
        });
        await _firestore.collection('ContentPaies').doc(contentId).update({
          'views': FieldValue.increment(1),
        });
      } else {
        await _firestore.collection('ContentPaies').doc(contentId).update({
          'views': FieldValue.increment(1),
        });
      }

      // Recharger les données
      if (isEpisode) {
        await loadEpisodes();
      } else {
        await loadUserContentPaies();
        await loadFeaturedContentPaies();
        await loadContentPaiesByCategory();
      }
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  Future<void> toggleLike(String contentId, {bool isEpisode = false}) async {
    try {
      if (currentUser == null) return;

      if (isEpisode) {
        await _firestore.collection('episodes').doc(contentId).update({
          'likes': FieldValue.increment(1),
        });
      } else {
        await _firestore.collection('ContentPaies').doc(contentId).update({
          'likes': FieldValue.increment(1),
        });
      }

      // Recharger les données
      if (isEpisode) {
        await loadEpisodes();
      } else {
        await loadUserContentPaies();
        await loadFeaturedContentPaies();
        await loadContentPaiesByCategory();
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<ContentPaie?> getContentPaieById(String contentId) async {
    try {
      final doc = await _firestore.collection('ContentPaies').doc(contentId).get();
      if (doc.exists) {
        return ContentPaie.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting ContentPaie by ID: $e');
      return null;
    }
  }

  Future<Episode?> getEpisodeById(String episodeId) async {
    try {
      final doc = await _firestore.collection('episodes').doc(episodeId).get();
      if (doc.exists) {
        return Episode.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting episode by ID: $e');
      return null;
    }
  }
}