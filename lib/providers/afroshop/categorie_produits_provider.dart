import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/cupertino.dart';

import 'dart:async';

import '../../models/model_data.dart';
import '../../services/api/shop_api.dart';
import '../../services/api/users_api.dart';
import '../../services/api/users_mapper.dart';

/// Données de la boutique Afroshop, lues et écrites par l'API (aucun accès à Firebase).
/// Les commandes et codes de commande n'existent pas encore dans l'API : les méthodes concernées renvoient une liste vide ou `false`
/// (voir lacunes_api_argent_creations.md).
class CategorieProduitProvider extends ChangeNotifier {
  List<Categorie> listCategorie = [];
  List<ArticleData> listArticles = [];

  final Map<String, UserData?> _authors = {};

  /// Auteur d'un article (mis en mémoire).
  Future<UserData?> _author(String? id) async {
    if (id == null || id.isEmpty) return null;
    if (_authors.containsKey(id)) return _authors[id];
    try {
      return _authors[id] = userFromApi(await UsersApi.publicProfile(id));
    } catch (_) {
      return _authors[id] = null;
    }
  }

  Future<List<ArticleData>> _withAuthors(List<ArticleData> list) async {
    await Future.wait(list.map((a) async => a.user = await _author(a.user_id)));
    return list;
  }

  Future<List<Categorie>> getCategories() async {
    try {
      listCategorie = await ShopApi.categories();
      printVm('list categorie ${listCategorie.length}');
      return listCategorie;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  Stream<ArticleData> getAllArticlesStream() async* {
    final r = await ShopApi.articles(limit: 50);
    for (final article in r.items) {
      article.user = await _author(article.user_id);
      yield article;
    }
  }

  Future<List<ArticleData>> getAllArticlesByUser(String user_id) async {
    try {
      listArticles = await _withAuthors((await ShopApi.articles(ownerId: user_id, limit: 50)).items);
      return listArticles;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  /// Produits boostés actifs (l'API marque `is_boosted` ; le filtre se fait ici faute de filtre dédié).
  Future<List<ArticleData>> getArticleBooster(String userCountryCode) async {
    try {
      final all = (await ShopApi.articles(limit: 50)).items.where((a) => a.isBoosted == true).toList();
      return await _withAuthors(all);
    } catch (e) {
      printVm("❌ Erreur produits boostés: $e");
      return [];
    }
  }

  Future<List<ArticleData>> getPureBoostedArticles(String userCountryCode) => getArticleBooster(userCountryCode);

  /// Annonces Afrolook : pas encore de point d'accès dans l'API.
  Future<List<ArticleData>> getAnnoncesArticles() async => [];

  Future<List<ArticleData>> getSearhArticles(String titre, int item_selected, String categorie_id) async {
    try {
      final r = await ShopApi.articles(categoryId: item_selected == -1 ? null : categorie_id, search: titre, limit: 50);
      listArticles = await _withAuthors(r.items);
      return listArticles;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  Future<List<ArticleData>> getSearhArticlesByEntreprise(String titre, int item_selected, String categorie_id, String user_id) async {
    try {
      final r = await ShopApi.articles(ownerId: user_id, categoryId: item_selected == -1 ? null : categorie_id, search: titre, limit: 50);
      listArticles = await _withAuthors(r.items);
      return listArticles;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  Stream<ArticleData> getArticlesByCategorieStream(String categorie_id) async* {
    final r = await ShopApi.articles(categoryId: categorie_id, limit: 50);
    for (final article in r.items) {
      article.user = await _author(article.user_id);
      yield article;
    }
  }

  Future<List<ArticleData>> getArticlesByCategorie2(String categorie_id) async {
    try {
      listArticles = await _withAuthors((await ShopApi.articles(categoryId: categorie_id, limit: 50)).items);
      return listArticles;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  Future<List<ArticleData>> getArticlesByCategorieByUser(String categorie_id, String user_id) async {
    try {
      listArticles = await _withAuthors((await ShopApi.articles(categoryId: categorie_id, ownerId: user_id, limit: 50)).items);
      return listArticles;
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  /// Modifie un article : seuls les champs que l'API accepte sont envoyés.
  Future<bool> updateArticle(ArticleData data, BuildContext context) async {
    try {
      await ShopApi.updateArticle(data.id!, {
        if (data.titre != null) 'title': data.titre,
        if (data.description != null) 'description': data.description,
        if (data.prix != null) 'price': data.prix,
        if (data.categorie_id != null) 'category_id': data.categorie_id,
        if (data.phone != null) 'phone': data.phone,
        if (data.disponible != null) 'is_available': data.disponible,
        if (data.negociable != null) 'negotiable': data.negociable,
      });
      return true;
    } catch (e) {
      printVm("erreur update  : ${e}");
      return false;
    }
  }

  Future<List<ArticleData>> getArticleById(String id) async {
    try {
      final a = await ShopApi.articleById(id);
      if (a == null) return [];
      a.user = await _author(a.user_id);
      return [a];
    } catch (e) {
      printVm("erreur ${e}");
      return [];
    }
  }

  // ── Commandes : pas encore dans l'API ──
  Future<bool> getCodeCommande(String code, CommandeCode cmdcode) async => false;
  Future<List<Commande>> getClientCommande(String user_id, BuildContext context) async => [];
  Future<List<Commande>> getMagasinCommande(String user_id, BuildContext context) async => [];
  Future<List<Commande>> getClientCommandeByCode(String code, BuildContext context) async => [];
  Future<bool> updateCommande(Commande data, BuildContext context) async => false;
  Future<List<Commande>> getCommandeById(String user_id, String article_id) async => [];
  Future<List<Commande>> getCommandeByCode(String code) async => [];
  Future<bool> createCommande(Commande data) async => false;

  /// Création d'un article. Les images et la vidéo doivent être envoyées avec [ShopApi.createArticle] ; cette méthode ne sert plus
  /// que de repli et refuse (l'écran d'ajout appelle l'API directement).
  Future<bool> createArticle(ArticleData data) async => false;
}
