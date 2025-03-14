// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserShopData _$UserShopDataFromJson(Map<String, dynamic> json) => UserShopData()
  ..id = json['id'] as String?
  ..nombre_pub = (json['nombre_pub'] as num?)?.toInt()
  ..montant = (json['montant'] as num?)?.toDouble()
  ..nom = json['nom'] as String?
  ..nom_magasin = json['nom_magasin'] as String?
  ..magasin_status = json['magasin_status'] as String?
  ..logo_magasin = json['logo_magasin'] as String?
  ..phone = json['phone'] as String?
  ..pwd = json['pwd'] as String?
  ..role = json['role'] as String?
  ..createdAt = (json['createdAt'] as num?)?.toInt()
  ..updatedAt = (json['updatedAt'] as num?)?.toInt()
  ..nbr_aticle_annonce = (json['nbr_aticle_annonce'] as num?)?.toInt();

Map<String, dynamic> _$UserShopDataToJson(UserShopData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre_pub': instance.nombre_pub,
      'montant': instance.montant,
      'nom': instance.nom,
      'nom_magasin': instance.nom_magasin,
      'magasin_status': instance.magasin_status,
      'logo_magasin': instance.logo_magasin,
      'phone': instance.phone,
      'pwd': instance.pwd,
      'role': instance.role,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'nbr_aticle_annonce': instance.nbr_aticle_annonce,
    };

ArticleData _$ArticleDataFromJson(Map<String, dynamic> json) => ArticleData()
  ..id = json['id'] as String?
  ..user_id = json['user_id'] as String?
  ..categorie_id = json['categorie_id'] as String?
  ..description = json['description'] as String?
  ..phone = json['phone'] as String?
  ..titre = json['titre'] as String?
  ..prix = (json['prix'] as num?)?.toInt()
  ..popularite = (json['popularite'] as num?)?.toInt()
  ..booster = (json['booster'] as num?)?.toInt()
  ..countryData = (json['countryData'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  )
  ..vues = (json['vues'] as num?)?.toInt()
  ..disponible = json['disponible'] as bool?
  ..contact = (json['contact'] as num?)?.toInt()
  ..jaime = (json['jaime'] as num?)?.toInt()
  ..partage = (json['partage'] as num?)?.toInt()
  ..createdAt = (json['createdAt'] as num?)?.toInt()
  ..updatedAt = (json['updatedAt'] as num?)?.toInt()
  ..dispo_annonce_afrolook = json['dispo_annonce_afrolook'] as bool?
  ..annonce_time = (json['annonce_time'] as num?)?.toInt()
  ..images =
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();

Map<String, dynamic> _$ArticleDataToJson(ArticleData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.user_id,
      'categorie_id': instance.categorie_id,
      'description': instance.description,
      'phone': instance.phone,
      'titre': instance.titre,
      'prix': instance.prix,
      'popularite': instance.popularite,
      'booster': instance.booster,
      'countryData': instance.countryData,
      'vues': instance.vues,
      'disponible': instance.disponible,
      'contact': instance.contact,
      'jaime': instance.jaime,
      'partage': instance.partage,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'dispo_annonce_afrolook': instance.dispo_annonce_afrolook,
      'annonce_time': instance.annonce_time,
      'images': instance.images,
    };

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => Challenge()
  ..id = json['id'] as String?
  ..user_id = json['user_id'] as String?
  ..postChallengeId = json['postChallengeId'] as String?
  ..titre = json['titre'] as String?
  ..statut = json['statut'] as String?
  ..description = json['description'] as String?
  ..typeCadeaux = json['typeCadeaux'] as String?
  ..descriptionCadeaux = json['descriptionCadeaux'] as String?
  ..prix = (json['prix'] as num?)?.toInt()
  ..countryData = (json['countryData'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  )
  ..vues = (json['vues'] as num?)?.toInt()
  ..disponible = json['disponible'] as bool?
  ..isAprouved = json['isAprouved'] as bool?
  ..jaime = (json['jaime'] as num?)?.toInt()
  ..partage = (json['partage'] as num?)?.toInt()
  ..createdAt = (json['createdAt'] as num?)?.toInt()
  ..updatedAt = (json['updatedAt'] as num?)?.toInt()
  ..startAt = (json['startAt'] as num?)?.toInt()
  ..finishedAt = (json['finishedAt'] as num?)?.toInt()
  ..postsWinnerIds = (json['postsWinnerIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..postsIds =
      (json['postsIds'] as List<dynamic>?)?.map((e) => e as String).toList()
  ..usersInscritsIds = (json['usersInscritsIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..usersChallengersIds = (json['usersChallengersIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList();

Map<String, dynamic> _$ChallengeToJson(Challenge instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.user_id,
      'postChallengeId': instance.postChallengeId,
      'titre': instance.titre,
      'statut': instance.statut,
      'description': instance.description,
      'typeCadeaux': instance.typeCadeaux,
      'descriptionCadeaux': instance.descriptionCadeaux,
      'prix': instance.prix,
      'countryData': instance.countryData,
      'vues': instance.vues,
      'disponible': instance.disponible,
      'isAprouved': instance.isAprouved,
      'jaime': instance.jaime,
      'partage': instance.partage,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'startAt': instance.startAt,
      'finishedAt': instance.finishedAt,
      'postsWinnerIds': instance.postsWinnerIds,
      'postsIds': instance.postsIds,
      'usersInscritsIds': instance.usersInscritsIds,
      'usersChallengersIds': instance.usersChallengersIds,
    };

LookChallenge _$LookChallengeFromJson(Map<String, dynamic> json) =>
    LookChallenge()
      ..id = json['id'] as String?
      ..user_id = json['user_id'] as String?
      ..challenge_id = json['challenge_id'] as String?
      ..postChallengeId = json['postChallengeId'] as String?
      ..titre = json['titre'] as String?
      ..statut = json['statut'] as String?
      ..popularite = (json['popularite'] as num?)?.toDouble()
      ..prix = (json['prix'] as num?)?.toInt()
      ..vues = (json['vues'] as num?)?.toInt()
      ..disponible = json['disponible'] as bool?
      ..isAprouved = json['isAprouved'] as bool?
      ..jaime = (json['jaime'] as num?)?.toInt()
      ..partage = (json['partage'] as num?)?.toInt()
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt()
      ..usersLovesIds = (json['usersLovesIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..usersVuesIds = (json['usersVuesIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..usersPartagesIds = (json['usersPartagesIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList();

Map<String, dynamic> _$LookChallengeToJson(LookChallenge instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.user_id,
      'challenge_id': instance.challenge_id,
      'postChallengeId': instance.postChallengeId,
      'titre': instance.titre,
      'statut': instance.statut,
      'popularite': instance.popularite,
      'prix': instance.prix,
      'vues': instance.vues,
      'disponible': instance.disponible,
      'isAprouved': instance.isAprouved,
      'jaime': instance.jaime,
      'partage': instance.partage,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'usersLovesIds': instance.usersLovesIds,
      'usersVuesIds': instance.usersVuesIds,
      'usersPartagesIds': instance.usersPartagesIds,
    };

Categorie _$CategorieFromJson(Map<String, dynamic> json) => Categorie()
  ..id = json['id'] as String?
  ..nom = json['nom'] as String?
  ..logo = json['logo'] as String?
  ..createdAt = (json['createdAt'] as num?)?.toInt()
  ..updatedAt = (json['updatedAt'] as num?)?.toInt();

Map<String, dynamic> _$CategorieToJson(Categorie instance) => <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'logo': instance.logo,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

TransactionSolde _$TransactionSoldeFromJson(Map<String, dynamic> json) =>
    TransactionSolde()
      ..id = json['id'] as String?
      ..user_id = json['user_id'] as String?
      ..type = json['type'] as String?
      ..statut = json['statut'] as String?
      ..description = json['description'] as String?
      ..montant = (json['montant'] as num?)?.toDouble()
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt();

Map<String, dynamic> _$TransactionSoldeToJson(TransactionSolde instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.user_id,
      'type': instance.type,
      'statut': instance.statut,
      'description': instance.description,
      'montant': instance.montant,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

Canal _$CanalFromJson(Map<String, dynamic> json) => Canal(
      titre: json['titre'] as String?,
      type: json['type'] as String?,
      description: json['description'] as String?,
      urlImage: json['urlImage'] as String?,
      usersSuiviId: (json['usersSuiviId'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      userId: json['userId'] as String?,
      suivi: (json['suivi'] as num?)?.toInt() ?? 0,
      publicash: (json['publicash'] as num?)?.toDouble() ?? 0.0,
      publication: (json['publication'] as num?)?.toInt() ?? 0,
      id: json['id'] as String?,
    )
      ..urlCouverture = json['urlCouverture'] as String?
      ..isVerify = json['isVerify'] as bool?
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt();

Map<String, dynamic> _$CanalToJson(Canal instance) => <String, dynamic>{
      'usersSuiviId': instance.usersSuiviId,
      'titre': instance.titre,
      'type': instance.type,
      'id': instance.id,
      'description': instance.description,
      'suivi': instance.suivi,
      'publication': instance.publication,
      'publicash': instance.publicash,
      'urlImage': instance.urlImage,
      'urlCouverture': instance.urlCouverture,
      'isVerify': instance.isVerify,
      'userId': instance.userId,
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
  ..dernierprix = (json['dernierprix'] as num?)?.toInt()
  ..createdAt = (json['createdAt'] as num?)?.toInt()
  ..updatedAt = (json['updatedAt'] as num?)?.toInt();

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
      jetons: (json['jetons'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String?,
      id: json['id'] as String?,
    )
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt();

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

EntrepriseAbonnement _$EntrepriseAbonnementFromJson(
        Map<String, dynamic> json) =>
    EntrepriseAbonnement()
      ..type = json['type'] as String?
      ..id = json['id'] as String?
      ..entrepriseId = json['entrepriseId'] as String?
      ..description = json['description'] as String?
      ..nombre_pub = (json['nombre_pub'] as num?)?.toInt()
      ..nombre_image_pub = (json['nombre_image_pub'] as num?)?.toInt()
      ..nbr_jour_pub_afrolook = (json['nbr_jour_pub_afrolook'] as num?)?.toInt()
      ..nbr_jour_pub_annonce_afrolook =
          (json['nbr_jour_pub_annonce_afrolook'] as num?)?.toInt()
      ..userId = json['userId'] as String?
      ..afroshop_user_magasin_id = json['afroshop_user_magasin_id'] as String?
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt()
      ..star = (json['star'] as num?)?.toInt()
      ..end = (json['end'] as num?)?.toInt()
      ..isFinished = json['isFinished'] as bool?
      ..dispo_afrolook = json['dispo_afrolook'] as bool?
      ..produistIdBoosted = (json['produistIdBoosted'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList();

Map<String, dynamic> _$EntrepriseAbonnementToJson(
        EntrepriseAbonnement instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'entrepriseId': instance.entrepriseId,
      'description': instance.description,
      'nombre_pub': instance.nombre_pub,
      'nombre_image_pub': instance.nombre_image_pub,
      'nbr_jour_pub_afrolook': instance.nbr_jour_pub_afrolook,
      'nbr_jour_pub_annonce_afrolook': instance.nbr_jour_pub_annonce_afrolook,
      'userId': instance.userId,
      'afroshop_user_magasin_id': instance.afroshop_user_magasin_id,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'star': instance.star,
      'end': instance.end,
      'isFinished': instance.isFinished,
      'dispo_afrolook': instance.dispo_afrolook,
      'produistIdBoosted': instance.produistIdBoosted,
    };

UserServiceData _$UserServiceDataFromJson(Map<String, dynamic> json) =>
    UserServiceData()
      ..id = json['id'] as String?
      ..userId = json['userId'] as String?
      ..titre = json['titre'] as String?
      ..description = json['description'] as String?
      ..disponible = json['disponible'] as bool?
      ..contact = json['contact'] as String?
      ..imageCourverture = json['imageCourverture'] as String?
      ..vues = (json['vues'] as num?)?.toInt()
      ..like = (json['like'] as num?)?.toInt()
      ..contactWhatsapp = (json['contactWhatsapp'] as num?)?.toInt()
      ..partage = (json['partage'] as num?)?.toInt()
      ..usersViewId = (json['usersViewId'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..usersLikeId = (json['usersLikeId'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..usersPartageId = (json['usersPartageId'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..usersContactId = (json['usersContactId'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..createdAt = (json['createdAt'] as num?)?.toInt()
      ..updatedAt = (json['updatedAt'] as num?)?.toInt();

Map<String, dynamic> _$UserServiceDataToJson(UserServiceData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'titre': instance.titre,
      'description': instance.description,
      'disponible': instance.disponible,
      'contact': instance.contact,
      'imageCourverture': instance.imageCourverture,
      'vues': instance.vues,
      'like': instance.like,
      'contactWhatsapp': instance.contactWhatsapp,
      'partage': instance.partage,
      'usersViewId': instance.usersViewId,
      'usersLikeId': instance.usersLikeId,
      'usersPartageId': instance.usersPartageId,
      'usersContactId': instance.usersContactId,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
