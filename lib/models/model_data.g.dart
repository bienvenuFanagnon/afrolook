// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserShopData _$UserShopDataFromJson(Map<String, dynamic> json) => UserShopData()
  ..id = json['id'] as String?
  ..nombre_pub = json['nombre_pub'] as int?
  ..montant = (json['montant'] as num?)?.toDouble()
  ..nom = json['nom'] as String?
  ..logo = json['logo'] as String?
  ..phone = json['phone'] as String?
  ..pwd = json['pwd'] as String?
  ..role = json['role'] as String?
  ..createdAt = json['createdAt'] as int?
  ..updatedAt = json['updatedAt'] as int?;

Map<String, dynamic> _$UserShopDataToJson(UserShopData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre_pub': instance.nombre_pub,
      'montant': instance.montant,
      'nom': instance.nom,
      'logo': instance.logo,
      'phone': instance.phone,
      'pwd': instance.pwd,
      'role': instance.role,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

ArticleData _$ArticleDataFromJson(Map<String, dynamic> json) => ArticleData()
  ..id = json['id'] as String?
  ..user_id = json['user_id'] as String?
  ..categorie_id = json['categorie_id'] as String?
  ..description = json['description'] as String?
  ..titre = json['titre'] as String?
  ..prix = json['prix'] as int?
  ..popularite = json['popularite'] as int?
  ..vues = json['vues'] as int?
  ..disponible = json['disponible'] as bool?
  ..contact = json['contact'] as int?
  ..jaime = json['jaime'] as int?
  ..createdAt = json['createdAt'] as int?
  ..updatedAt = json['updatedAt'] as int?
  ..images =
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();

Map<String, dynamic> _$ArticleDataToJson(ArticleData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.user_id,
      'categorie_id': instance.categorie_id,
      'description': instance.description,
      'titre': instance.titre,
      'prix': instance.prix,
      'popularite': instance.popularite,
      'vues': instance.vues,
      'disponible': instance.disponible,
      'contact': instance.contact,
      'jaime': instance.jaime,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'images': instance.images,
    };

Categorie _$CategorieFromJson(Map<String, dynamic> json) => Categorie()
  ..id = json['id'] as String?
  ..nom = json['nom'] as String?
  ..logo = json['logo'] as String?
  ..createdAt = json['createdAt'] as int?
  ..updatedAt = json['updatedAt'] as int?;

Map<String, dynamic> _$CategorieToJson(Categorie instance) => <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'logo': instance.logo,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

Commande _$CommandeFromJson(Map<String, dynamic> json) => Commande()
  ..id = json['id'] as String?
  ..user_client_id = json['user_client_id'] as String?
  ..user_magasin_id = json['user_magasin_id'] as String?
  ..article_id = json['article_id'] as String?
  ..code = json['code'] as String?
  ..status = json['status'] as String?
  ..user_client_status = json['user_client_status'] as String?
  ..user_magasin_status = json['user_magasin_status'] as String?
  ..dernierprix = json['dernierprix'] as int?
  ..createdAt = json['createdAt'] as int?
  ..updatedAt = json['updatedAt'] as int?;

Map<String, dynamic> _$CommandeToJson(Commande instance) => <String, dynamic>{
      'id': instance.id,
      'user_client_id': instance.user_client_id,
      'user_magasin_id': instance.user_magasin_id,
      'article_id': instance.article_id,
      'code': instance.code,
      'status': instance.status,
      'user_client_status': instance.user_client_status,
      'user_magasin_status': instance.user_magasin_status,
      'dernierprix': instance.dernierprix,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

CommandeCode _$CommandeCodeFromJson(Map<String, dynamic> json) => CommandeCode()
  ..id = json['id'] as String?
  ..code = json['code'] as String?;

Map<String, dynamic> _$CommandeCodeToJson(CommandeCode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
    };

UserIACompte _$UserIACompteFromJson(Map<String, dynamic> json) => UserIACompte(
      ia_url_avatar: json['ia_url_avatar'] as String?,
      ia_name: json['ia_name'] as String?,
      jetons: json['jetons'] as int? ?? 0,
      userId: json['userId'] as String?,
      id: json['id'] as String?,
    )
      ..createdAt = json['createdAt'] as int?
      ..updatedAt = json['updatedAt'] as int?;

Map<String, dynamic> _$UserIACompteToJson(UserIACompte instance) =>
    <String, dynamic>{
      'ia_name': instance.ia_name,
      'ia_url_avatar': instance.ia_url_avatar,
      'id': instance.id,
      'jetons': instance.jetons,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'userId': instance.userId,
    };
