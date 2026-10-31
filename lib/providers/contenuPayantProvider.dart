import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/services/api/contenu_payant_api.dart';
import 'package:afrotok/utils/platform_guard.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../pages/contenuPayant/contentDetails.dart';
import '../pages/paiement/newDepot.dart';
import 'authProvider.dart';

/// Contenus payants : tout passe par l'API (catalogue, achat, réactions, création). Prix en FCFA.
/// Les ÉPISODES (séries) n'ont pas encore de point d'accès dans l'API : voir lacunes_api_canaux.md (les méthodes d'épisodes renvoient « vide » / false).
class ContentProvider with ChangeNotifier {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  List<ContentPaie> _featuredContentPaies = [];
  Map<String, List<ContentPaie>> _contentPaiesByCategory = {};
  UserData? _otherUserData;
  List<ContentPaie> _otherUserContentPaies = [];

  UserData? get otherUserData => _otherUserData;
  List<ContentPaie> get otherUserContentPaies => _otherUserContentPaies;

  Future<void> loadOtherUserContentPaies(String userId) async {
    try {
      _otherUserContentPaies = (await ContenuPayantApi.list(ownerId: userId, limit: 50)).items;
      notifyListeners();
    } catch (e) {
      printVm('Error loading other user ContentPaies: $e');
    }
  }

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
      name: 'Formation',
      description: 'Formations professionnelles et apprentissages 💼📘',
      imageUrl: 'https://example.com/formation.jpg',
    ),
    ContentCategory(
      id: '4',
      name: 'Éducation',
      description: 'Cours, tutos et apprentissage 📚',
      imageUrl: 'https://example.com/education.jpg',
    ),
    ContentCategory(
      id: '5',
      name: 'Divertissement',
      description: 'Humour, films et distractions 😂🎬',
      imageUrl: 'https://example.com/divertissement.jpg',
    ),
    ContentCategory(
      id: '6',
      name: 'Actualités',
      description: 'Infos, débats et tendances 🌍',
      imageUrl: 'https://example.com/actualites.jpg',
    ),
    ContentCategory(
      id: '7',
      name: 'Mode',
      description: 'Styles, looks et tendances 👗👟',
      imageUrl: 'https://example.com/mode.jpg',
    ),
    ContentCategory(
      id: '8',
      name: 'Vidéos Virales',
      description: 'Les vidéos qui font le buzz 🔥😂',
      imageUrl: 'https://example.com/virales.jpg',
    ),
    ContentCategory(
      id: '9',
      name: 'Fuites & Exclus',
      description: 'Contenus inédits et coulisses 🤫🎥',
      imageUrl: 'https://example.com/fuites.jpg',
    ),
    ContentCategory(
      id: '10',
      name: 'Challenges',
      description: 'Défis amusants et moments viraux 🎉💪',
      imageUrl: 'https://example.com/challenges.jpg',
    ),
    ContentCategory(
      id: '11',
      name: 'Cartoon',
      description: 'Dessins animés et créations ludiques 🐭🎨',
      imageUrl: 'https://example.com/cartoon.jpg',
    ),
    ContentCategory(
      id: '12',
      name: 'Manga',
      description: 'Bandes dessinées japonaises et animés 🇯🇵📖',
      imageUrl: 'https://example.com/manga.jpg',
    ),

    // 🆕 --- Catégories eBook et lecture ---
    ContentCategory(
      id: '13',
      name: 'Romans',
      description: 'Histoires captivantes et aventures littéraires 📖❤️',
      imageUrl: 'https://example.com/roman.jpg',
    ),
    ContentCategory(
      id: '14',
      name: 'Contes',
      description: 'Récits traditionnels et histoires culturelles africaines 🪘📜',
      imageUrl: 'https://example.com/conte.jpg',
    ),
    ContentCategory(
      id: '15',
      name: 'Histoire',
      description: 'Civilisations, biographies et faits marquants du passé 🏛️📜',
      imageUrl: 'https://example.com/histoire.jpg',
    ),
    ContentCategory(
      id: '16',
      name: 'Livres pour Enfants',
      description: 'Contes et apprentissages ludiques pour les petits 👶📘',
      imageUrl: 'https://example.com/enfant.jpg',
    ),
    ContentCategory(
      id: '17',
      name: 'Développement Personnel',
      description: 'Motivation, confiance et bien-être 🌱💭',
      imageUrl: 'https://example.com/dev_perso.jpg',
    ),
    ContentCategory(
      id: '18',
      name: 'Sciences & Technologie',
      description: 'Découvertes, innovations et savoir moderne 🔬💡',
      imageUrl: 'https://example.com/science.jpg',
    ),
    ContentCategory(
      id: '19',
      name: 'Culture Africaine',
      description: 'Littérature, traditions et savoirs du continent 🌍🪘',
      imageUrl: 'https://example.com/culture_africaine.jpg',
    ),
    ContentCategory(
      id: '20',
      name: 'Religions & Spiritualité',
      description: 'Textes sacrés, méditation et croyances ✨🙏',
      imageUrl: 'https://example.com/spiritualite.jpg',
    ),
    ContentCategory(
      id: '21',
      name: 'Business & Finance',
      description: 'Entrepreneuriat, argent et gestion 💼💰',
      imageUrl: 'https://example.com/business.jpg',
    ),
    ContentCategory(
      id: '22',
      name: 'Santé & Bien-être',
      description: 'Corps, esprit et équilibre 🍃💪',
      imageUrl: 'https://example.com/sante.jpg',
    ),
    ContentCategory(
      id: '23',
      name: 'Poésie & Arts',
      description: 'Textes poétiques, art et inspiration 🎨🖋️',
      imageUrl: 'https://example.com/poesie.jpg',
    ),
    ContentCategory(
      id: '24',
      name: 'Magazines',
      description: 'Revues, journaux et publications modernes 📰📔',
      imageUrl: 'https://example.com/magazine.jpg',
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

  ContentProvider({required UserAuthProvider authProvider}) : _authProvider = authProvider;
  List<ContentPaie> _allContentPaies = [];

  List<ContentPaie> get allContentPaies => _allContentPaies;

  Future<List<ContentPaie>> getRecentContentPaies({int limit = 5}) async {
    try {
      return (await ContenuPayantApi.list(limit: limit)).items;
    } catch (e) {
      printVm('Erreur chargement récents contenus : $e');
      return [];
    }
  }

  /// Le compteur de partages n'a pas de point d'accès dans l'API (voir lacunes_api_canaux.md) : sans effet pour l'instant.
  Future<void> incrementShares(String contentId, {bool isEpisode = false}) async {}

  // ── Réactions (une seule par personne : j'aime OU je n'aime pas) ──
  Future<void> _reactAndReload(Future<void> Function() action, String label) async {
    try {
      await action();
      await loadUserContentPaies();
      await loadFeaturedContentPaies();
      notifyListeners();
    } catch (e) {
      printVm('Error $label: $e');
    }
  }

  Future<void> likeContent(String contentId, String userId) => _reactAndReload(() => ContenuPayantApi.react(contentId, 'like'), 'liking content');

  Future<void> dislikeContent(String contentId, String userId) => _reactAndReload(() => ContenuPayantApi.react(contentId, 'dislike'), 'disliking content');

  Future<void> removeLikeContent(String contentId, String userId) => _reactAndReload(() => ContenuPayantApi.unreact(contentId), 'removing like');

  Future<void> removeDislikeContent(String contentId, String userId) => _reactAndReload(() => ContenuPayantApi.unreact(contentId), 'removing dislike');

  Future<bool> isContentLikedByUser(String contentId, String userId) async {
    try {
      return (await ContenuPayantApi.get(contentId))?.content.likedBy.contains(userId) == true;
    } catch (e) {
      printVm('Error checking if content is liked: $e');
      return false;
    }
  }

  Future<bool> isContentDislikedByUser(String contentId, String userId) async {
    try {
      return (await ContenuPayantApi.get(contentId))?.content.dislikedBy.contains(userId) == true;
    } catch (e) {
      printVm('Error checking if content is disliked: $e');
      return false;
    }
  }

  // ── Épisodes : pas encore dans l'API ──
  Future<void> likeEpisode(String episodeId, String userId) async {}
  Future<void> dislikeEpisode(String episodeId, String userId) async {}
  Future<void> removeLikeEpisode(String episodeId, String userId) async {}
  Future<void> removeDislikeEpisode(String episodeId, String userId) async {}
  Future<bool> isEpisodeLikedByUser(String episodeId, String userId) async => false;
  Future<bool> isEpisodeDislikedByUser(String episodeId, String userId) async => false;
  Future<void> loadEpisodes() async {}
  Future<List<Episode>> getEpisodesForSeries(String seriesId) async => [];
  Future<bool> addEpisode(Episode episode) async => false;
  Future<bool> updateEpisode(Episode episode) async => false;
  Future<bool> deleteEpisode(String episodeId) async => false;
  Future<Episode?> getEpisodeById(String episodeId) async => null;

  Future<void> loadAllContentPaies() async {
    try {
      final page = await ContenuPayantApi.list(limit: 50);
      if (_isDisposed) return;
      _allContentPaies = page.items;
      notifyListeners();
    } catch (e) {
      if (!_isDisposed) printVm('Error loading all ContentPaies: $e');
    }
  }

  // Récupération sécurisée de l'utilisateur courant
  UserData? get currentUser => _authProvider?.loginUserData;
  // Méthode pour définir l'utilisateur courant
  void setCurrentUser() {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    loadUserPurchases();
    loadAllContentPaies();
    await loadFeaturedContentPaies();
    await loadCategories();
    await loadContentPaiesByCategory();
    await loadUserContentPaies();
  }

  // Nouveautés (gratuites ET payantes) : les contenus mis en avant d'abord, puis les plus récents
  Future<void> loadFeaturedContentPaies() async {
    try {
      final page = await ContenuPayantApi.list(limit: 10);
      if (_isDisposed) return;
      _featuredContentPaies = page.items;
      notifyListeners();
    } catch (e) {
      if (!_isDisposed) printVm('Error loading featured ContentPaies: $e');
    }
  }

  Future<void> loadFeaturedContentPaies2() async => loadFeaturedContentPaies();

  Future<void> loadCategories() async {
    try {
      _categories.shuffle();
      notifyListeners();
    } catch (e) {
      printVm('Erreur chargement catégories: $e');
    }
  }

  /// Les catégories sont fixes dans l'application (plus de collection Firebase).
  Future<void> loadCategories2() async => loadCategories();

  Future<void> loadContentPaiesByCategory() async {
    try {
      final cats = _categories.where((c) => c.id != null).toList();
      final results = await Future.wait(cats.map((c) async {
        try {
          return (await ContenuPayantApi.list(category: c.id, limit: 10)).items;
        } catch (_) {
          return <ContentPaie>[];
        }
      }));
      for (var i = 0; i < cats.length; i++) {
        _contentPaiesByCategory[cats[i].id!] = results[i];
      }
      notifyListeners();
    } catch (e) {
      printVm('Error loading ContentPaies by category: $e');
    }
  }

  Future<void> loadUserContentPaies() async {
    if (currentUser == null) return;
    try {
      _userContentPaies = (await ContenuPayantApi.list(mine: true, limit: 50)).items;
      notifyListeners();
    } catch (e) {
      printVm('Error loading user ContentPaies: $e');
    }
  }

  Future<void> loadUserPurchases() async {
    if (currentUser == null) return;
    try {
      final page = await ContenuPayantApi.list(purchased: true, limit: 50);
      _userPurchases = page.items
          .map((c) => ContentPurchase(userId: currentUser!.id!, contentId: c.id!, amountPaid: c.price, ownerEarnings: 0, platformEarnings: 0, purchaseDate: c.createdAt))
          .toList();
      notifyListeners();
    } catch (e) {
      printVm('Error loading user purchases: $e');
    }
  }

  /// Achat : l'API calcule le prix (vente flash, code promo), vérifie les soldes et répartit. Gains à retirer en FCFA, ou pièces sur iPhone.
  Future<PurchaseResult> purchaseContentPaie(UserData currentUser, ContentPaie contentPaie, BuildContext context, {String? promoCode, String? affiliateId}) async {
    try {
      await ContenuPayantApi.buy(contentPaie.id!, promoCode: promoCode, affiliateId: affiliateId, withCoins: kIsAppleStore);
      await loadUserPurchases();
      return PurchaseResult.success;
    } on ApiException catch (e) {
      if (e.status == 409 && e.code == 'already_purchased') return PurchaseResult.alreadyPurchased;
      if (e.code == 'insufficient_funds' || e.isInsufficientCoins) {
        if (context.mounted) _showInsufficientBalanceModal(context, contentPaie.price);
        return PurchaseResult.insufficientBalance;
      }
      printVm('Error purchasing ContentPaie: $e');
      if (context.mounted) _showErrorModal(context, ContenuPayantApi.message(e));
      return PurchaseResult.error;
    } catch (e) {
      printVm('Error purchasing ContentPaie: $e');
      if (context.mounted) _showErrorModal(context, ContenuPayantApi.message(e));
      return PurchaseResult.error;
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





  static bool _isUploadId(String? v) => v != null && v.length == 26 && !v.startsWith('http') && v != 'private';

  /// Corps de l'API à partir d'un contenu de l'application : les champs « url » contiennent ici des IDENTIFIANTS D'ENVOI (26 caractères)
  /// pour les fichiers qui viennent d'être envoyés ; « private » / une adresse = fichier déjà en ligne, inchangé.
  Map<String, dynamic> _body(ContentPaie c, {required bool creating}) {
    final files = <String, String>{
      if (_isUploadId(c.videoUrl)) 'video': c.videoUrl!,
      if (_isUploadId(c.pdfUrl)) 'pdf': c.pdfUrl!,
      if (_isUploadId(c.fileUrl)) 'file': c.fileUrl!,
      if (_isUploadId(c.tutorialVideoUrl)) 'tutorial': c.tutorialVideoUrl!,
    };
    return {
      'title': c.title,
      'description': c.description,
      'content_type': contentTypeToApi(c.contentType),
      'price_xof': c.isFree ? 0 : c.price.round(),
      'is_free': c.isFree,
      'affiliation_enabled': c.affiliationEnabled,
      'affiliation_rate': c.affiliationEnabled ? c.affiliationRate.clamp(0.0, 0.4) : 0.0,
      'categories': c.categories,
      'hashtags': c.hashtags,
      'page_count': c.pageCount,
      'duration_sec': c.duration,
      'is_series': c.isSeries,
      if (c.flashSalePrice != null && c.flashSaleEndDate != null) ...{
        'flash_price_xof': c.flashSalePrice!.round(),
        'flash_ends_at': DateTime.fromMillisecondsSinceEpoch(c.flashSaleEndDate!).toUtc().toIso8601String(),
      } else if (!creating) ...{'flash_price_xof': null, 'flash_ends_at': null},
      if (_isUploadId(c.thumbnailUrl)) 'thumbnail_upload_id': c.thumbnailUrl,
      if (files.isNotEmpty) 'files': files,
    };
  }

  /// Création par l'API. Lève l'erreur de l'API (message en français) pour que l'écran l'affiche ; true si créé.
  Future<bool> addContentPaie(ContentPaie contentPaie) async {
    try {
      final created = await ContenuPayantApi.create(_body(contentPaie, creating: true));
      contentPaie.id = created.id;
      return true;
    } catch (e) {
      printVm('Error adding ContentPaie: $e');
      rethrow;
    }
  }

  Future<bool> updateContentPaie(ContentPaie contentPaie) async {
    try {
      await ContenuPayantApi.update(contentPaie.id!, _body(contentPaie, creating: false));
      await loadUserContentPaies();
      return true;
    } catch (e) {
      printVm('Error updating ContentPaie: $e');
      rethrow;
    }
  }

  Future<bool> deleteContentPaie(String contentPaieId) async {
    try {
      await ContenuPayantApi.delete(contentPaieId);
      await loadUserContentPaies();
      return true;
    } catch (e) {
      printVm('Error deleting ContentPaie: $e');
      return false;
    }
  }

  Future<List<ContentPaie>> searchContentPaies(String query) async {
    try {
      return (await ContenuPayantApi.list(search: query, limit: 30)).items;
    } catch (e) {
      printVm('Error searching ContentPaies: $e');
      return [];
    }
  }

  Future<void> incrementViews(String contentId, {bool isEpisode = false}) async {
    if (isEpisode) return;
    await ContenuPayantApi.view(contentId); // une vue par personne, comptée par le serveur
  }

  Future<void> toggleLike(String contentId, {bool isEpisode = false}) async {
    if (isEpisode || currentUser == null) return;
    await likeContent(contentId, currentUser!.id!);
  }

  Future<ContentPaie?> getContentPaieById(String contentId) async {
    try {
      return (await ContenuPayantApi.get(contentId))?.content;
    } catch (e) {
      printVm('Error getting ContentPaie by ID: $e');
      return null;
    }
  }
}
