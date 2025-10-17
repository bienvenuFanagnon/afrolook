import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/story/afroStory/repository.dart';
import 'chatmodels/message.dart';

import 'package:json_annotation/json_annotation.dart';
part 'model_data.g.dart'; // Generated file name based on the class name
/* flutter pub run build_runner build */

class UserDatas {
  UserData? user;
  String? accessToken;
  String? tokenType;
  bool? error;

  UserDatas({this.user, this.accessToken, this.tokenType, this.error});

  UserDatas.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? new UserData.fromJson(json['user']) : null;
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    error = json['error'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    data['access_token'] = this.accessToken;
    data['token_type'] = this.tokenType;
    data['error'] = this.error;
    return data;
  }
}

class Role {
  int? id;
  String? titre;
  String? description;
  String? createdAt;
  String? updatedAt;

  Role({this.id, this.titre, this.description, this.createdAt, this.updatedAt});

  Role.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    titre = json['titre'];
    description = json['description'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['titre'] = this.titre;
    data['description'] = this.description;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class Tags {
  int? id;
  int? tagId;
  int? userId;
  String? createdAt;
  String? updatedAt;
  Tag? tag;

  Tags(
      {this.id,
      this.tagId,
      this.userId,
      this.createdAt,
      this.updatedAt,
      this.tag});

  Tags.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    tagId = json['tag_id'];
    userId = json['user_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    tag = json['tag'] != null ? new Tag.fromJson(json['tag']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['tag_id'] = this.tagId;
    data['user_id'] = this.userId;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.tag != null) {
      data['tag'] = this.tag!.toJson();
    }
    return data;
  }
}

class Tag {
  int? id;
  String? titre;
  String? description;
  int? popularite;
  String? createdAt;
  String? updatedAt;

  Tag(
      {this.id,
      this.titre,
      this.description,
      this.popularite,
      this.createdAt,
      this.updatedAt});

  Tag.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    titre = json['titre'];
    description = json['description'];
    popularite = json['popularite'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['titre'] = this.titre;
    data['description'] = this.description;
    data['popularite'] = this.popularite;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class UserAbonnes {
  String? id;
  String? compteUserId;
  String? abonneUserId;
  int? createdAt;
  int? updatedAt;

  UserAbonnes(
      {this.id,
      this.compteUserId,
      this.abonneUserId,
      this.createdAt,
      this.updatedAt});

  UserAbonnes.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    compteUserId = json['compte_user_id'];
    abonneUserId = json['abonne_user_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['compte_user_id'] = this.compteUserId;
    data['abonne_user_id'] = this.abonneUserId;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class Friends {
  String? id;
  String? friendId;
  String? currentUserId;
  bool? isBlocked;
  int? createdAt;
  int? updatedAt;
  UserData? friend;

  Friends(
      {this.id,
      this.friendId,
      this.currentUserId,
      this.createdAt,
      this.updatedAt,
      this.isBlocked = false,
      this.friend});

  Friends.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    friendId = json['friend_id'];
    currentUserId = json['current_user_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    isBlocked = json['isBlocked'];
    friend =
        json['friend'] != null ? new UserData.fromJson(json['friend']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['friend_id'] = this.friendId;
    data['current_user_id'] = this.currentUserId;
    data['isBlocked'] = this.isBlocked;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.friend != null) {
      data['friend'] = this.friend!.toJson();
    }
    return data;
  }
}

class Invitation {
  String? id;
  String? senderId;
  String? message;
  String? status;
  String? receiverId;
  int? createdAt;
  int? updatedAt;
  UserData? inviteUser;
  final DocumentReference? reference;

  Invitation(
      {this.reference,
      this.id,
      this.senderId,
      this.message = 'invitation',
      this.status,
      this.receiverId,
      this.createdAt,
      this.updatedAt,
      this.inviteUser});
  Invitation.fromMap(Map<String, dynamic> map, {this.reference})
      : inviteUser = map['user_invite'];

  Invitation.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot!.data()! as Map<String, dynamic>,
            reference: snapshot.reference);
  Invitation.fromJson(Map<String, dynamic> json, {this.reference}) {
    id = json['id'];
    senderId = json['sender_id'];
    message = json['message'];
    status = json['status'];
    receiverId = json['receiver_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];

    inviteUser = json['user_invite'] != null
        ? new UserData.fromJson(json['user_invite'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['sender_id'] = this.senderId;
    data['message'] = this.message;
    data['status'] = this.status;
    data['receiver_id'] = this.receiverId;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.inviteUser != null) {
      data['user_invite'] = this.inviteUser!.toJson();
    }

    return data;
  }
}

class UserPays {
  String? id;
  String? name;
  String? placeName;
  String? subAdministrativeArea;
  String? createdAt;
  String? updatedAt;
  // "country": countryValue,
  // "state": stateValue,
  // "city": cityValue,

  UserPays(
      {this.id,
      this.name,
      this.placeName,
      this.subAdministrativeArea,
      this.createdAt,
      this.updatedAt});

  UserPays.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    placeName = json['place_name'];
    subAdministrativeArea = json['subAdministrativeArea'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['place_name'] = this.placeName;
    data['subAdministrativeArea'] = this.subAdministrativeArea;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class UserPhoneNumber {
  int? id;
  String? completNumber;

  UserPhoneNumber({this.id, this.completNumber});

  UserPhoneNumber.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    completNumber = json['complet_number'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['complet_number'] = this.completNumber;
    return data;
  }
}

class UserPseudo {
  String? id;
  String? name;

  UserPseudo({this.id, this.name});

  UserPseudo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;

    return data;
  }
}

class AppDefaultData {
  String? id;
  String? app_link;
  String? geminiapiKey;
  List<String>? users_id = [];
  int? nbr_abonnes = 0;
  int? app_version_code = 0;
  int? app_version_code_officiel = 0;
  int? nbr_likes = 0;
  bool? googleVerification = false;
  int? nbr_comments = 0;
  String? ia_instruction = "";
  late String app_logo = "";
  late String one_signal_api_key = "";
  late String one_signal_app_id = "";
  late String one_signal_app_url = "";
  double? tarifPubliCash = 2.5;
  double? tarifImage = 0.5;
  double? tarifPubliCash_to_xof = 250.0;
  double? tarifVideo = 1.0;
  double? tarifjour = 0.5;
  double? solde_principal = 0.0;
  double? solde_gain = 0.0;
  int? nbr_loves = 0;
  int? default_point_new_user = 5;
  int? default_point_new_like = 1;
  int? default_point_new_love = 1;
  // int? default_point_new_comment=2;
  List<String>? allPostIds = []; // Nouveau champ pour stocker les IDs de tous les posts

  AppDefaultData(
      {this.id,
      this.users_id,
      this.allPostIds,
      this.nbr_abonnes = 0,
      this.ia_instruction = "",
      this.geminiapiKey = "",
      this.app_link,
      this.googleVerification,
      this.app_version_code = 0,
      this.app_version_code_officiel = 0,
      this.tarifPubliCash_to_xof = 250.0,
      this.tarifPubliCash = 2.5,
      this.tarifjour = 0.5,
      this.tarifImage = 0.5,
      this.tarifVideo = 1.0,
      this.nbr_likes = 0,
      this.solde_principal = 0.0,
      this.solde_gain = 0.0,
      this.nbr_comments = 0,
      this.nbr_loves = 0,
      this.default_point_new_user = 5,
      this.default_point_new_like = 1,
      this.default_point_new_love = 1});

  AppDefaultData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    nbr_comments = json['nbr_comments'];
    nbr_likes = json['nbr_likes'];
    nbr_comments = json['nbr_comments'];
    app_link = json['app_link'] == null ? "" : json['app_link'];
    geminiapiKey = json['geminiapiKey'] == null ? "" : json['geminiapiKey'];
    ia_instruction =
        json['ia_instruction'] == null ? "" : json['ia_instruction'];
    app_version_code_officiel =
        json['app_version_code_officiel'] == null ? 0 : json['app_version_code_officiel'];
    solde_principal =
        json['solde_principal'] == null ? 0.0 : json['solde_principal'];
    solde_gain =
        json['solde_gain'] == null ? 0.0 : json['solde_gain'];
    app_version_code =
        json['app_version_code'] == null ? 0 : json['app_version_code'];
    googleVerification =
        json['googleVerification'] == null ? false : json['googleVerification'];
    nbr_loves = json['nbr_loves'];
    nbr_abonnes = json['nbr_abonnes'];
    tarifPubliCash = json['tarifPubliCash'];
    tarifImage = json['tarifImage'];
    tarifVideo = json['tarifVideo'];
    tarifjour = json['tarifjour'];
    tarifPubliCash_to_xof = json['tarifPubliCash_to_xof'];
    default_point_new_user = json['default_point_new_user'];
    default_point_new_like = json['default_point_new_like'];
    default_point_new_love = json['default_point_new_love'];

    app_logo = json['app_logo'];
    one_signal_api_key = json['one_signal_api_key'];
    one_signal_app_id = json['one_signal_app_id'];
    one_signal_app_url = json['one_signal_app_url'];
    if (json['users_id'] != null) {
      users_id = <String>[];
      json['users_id'].forEach((v) {
        users_id!.add(v);
      });
    }
    allPostIds = (json['allPostIds'] as List<dynamic>?)?.map((v) => v.toString()).toList() ?? [];

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['nbr_comments'] = this.nbr_comments;
    data['allPostIds'] = this.allPostIds;

    data['nbr_likes'] = this.nbr_likes;
    data['nbr_comments'] = this.nbr_comments;
    data['nbr_abonnes'] = this.nbr_abonnes;
    data['app_version_code'] = this.app_version_code;
    data['ia_instruction'] = this.ia_instruction;
    data['geminiapiKey'] = this.geminiapiKey;

    data['tarifPubliCash'] = this.tarifPubliCash;
    data['googleVerification'] = this.googleVerification;
    data['tarifImage'] = this.tarifImage;
    data['tarifVideo'] = this.tarifVideo;
    data['app_link'] = this.app_link;
    data['tarifjour'] = this.tarifjour;
    data['solde_principal'] = this.solde_principal;
    data['solde_gain'] = this.solde_gain;
    data['app_version_code_officiel'] = this.app_version_code_officiel;
    data['tarifPubliCash_to_xof'] = this.tarifPubliCash_to_xof;
    data['users_id'] = users_id!.map((alphabets) => alphabets).toList();

    data['nbr_loves'] = this.nbr_loves;
    data['default_point_new_user'] = this.default_point_new_user;
    data['default_point_new_like'] = this.default_point_new_like;
    data['default_point_new_love'] = this.default_point_new_love;

    data['app_logo'] = this.app_logo;
    data['one_signal_app_url'] = this.one_signal_app_url;
    data['one_signal_app_id'] = this.one_signal_app_id;
    data['one_signal_api_key'] = this.one_signal_api_key;

    return data;
  }
}

class UserData {
  String? id;
  String? pseudo = "";
  late String? oneIgnalUserid = "";

  String? nom;
  String? prenom;
  String? imageUrl = "";

  String? numeroDeTelephone;
  String? adresse = "";
  String? email = "";
  String? genre = "";
  String? codeParrainage;
  String? codeParrain;
  String? state;
  UserPays? userPays;

  double? publi_cash = 0.0;
  double? votre_solde = 0.0;
  double? votre_solde_contenu = 0.0;
  double? votre_solde_principal = 0.0;
  double? votre_solde_cadeau = 0.0;
  double? tiktokviewerSolde = 0.0;
  int? pubEntreprise = 0;
  int? mesPubs = 0;
  int? mesTiktokPubs = 0;
  int? partage = 0;
  int? last_time_active = 0;
  int? pointContribution = 0;
  int? userlikes = 0;
  int? userjaimes = 0;
  int? likes = 0;
  int? jaimes = 0;
  int? comments = 0;
  int? abonnes = 0;
  double? compteTarif = 0.0;
  double? popularite = 0.0;
  double? latitude;
  double? longitude;
  String? apropos;
  bool? isConnected = false;
  bool? isBlocked = false;
  bool? completeData = false;
  bool? hasEntreprise = false;
  bool? isVerify = false;
  File? image;
  String? password;
  //int? genreId;
  String? role;
  int? createdAt;
  int? updatedAt;
  List<int>? userGlobalTags;
  List<UserAbonnes>? userAbonnes = [];
  List<String>? userAbonnesIds = [];
  List<String>? usersParrainer = [];
  List<String>? friendsIds = [];
  List<Friends>? friends = [];

  List<Invitation>? mesInvitationsEnvoyer = [];
  List<Invitation>? autreInvitationsEnvoyer = [];
  List<String>? mesInvitationsEnvoyerId = [];
  List<String>? autreInvitationsEnvoyerId = [];
  DocumentReference? reference;
  Map<String, String>? countryData;
  // List<Map<String, dynamic>>? stories = [];
  List<WhatsappStory>? stories = [];
  List<String> viewedVideos = []; // Liste des vidéos déjà vues
  List<String>? viewedPostIds = []; // Nouveau champ pour stocker les posts vus
  int? lastNotificationTime;

  UserData(
      {this.reference,
      this.pseudo,
      this.viewedPostIds,
      this.nom,
      this.prenom,
      this.email,
      this.numeroDeTelephone,
      this.adresse,
      this.genre,
      this.codeParrainage,
      this.oneIgnalUserid = "",
      this.userPays,
      this.publi_cash = 0,
      this.pubEntreprise = 0,
      this.mesPubs = 0,
      this.mesTiktokPubs,
      this.pointContribution = 0,
      this.lastNotificationTime = 0,
      this.likes = 0,
      this.jaimes = 0,
      this.userlikes = 0,
      this.partage = 0,
      this.userjaimes = 0,
      this.votre_solde_contenu = 0.0,
      this.votre_solde_principal = 0.0,
      this.votre_solde_cadeau = 0.0,
      this.tiktokviewerSolde = 0.0,
      this.comments = 0,
      this.createdAt = 0,
      this.updatedAt = 0,
      this.abonnes = 0,
      this.compteTarif = 0,
      this.popularite = 0.0,
      this.votre_solde = 0.0,
      this.latitude = 0.0,
      this.longitude = 0.0,
      this.isBlocked = false,
      this.isVerify = false,
      this.isConnected = false,
      this.completeData = false,
      this.hasEntreprise = false,
      this.apropos,
      this.password = "",
      this.codeParrain,
      this.countryData,
      this.usersParrainer,
      this.stories,
      this.state = "OFFLINE",
        this.viewedVideos = const [],
        this.userAbonnesIds = const [],

      //this.genreId,
      this.role,
      this.userGlobalTags});
  UserData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    pseudo = json['pseudo']?.toString() ?? '';
    oneIgnalUserid = json['oneIgnalUserid']?.toString() ?? '';

    nom = json['nom']?.toString() ?? '';
    prenom = json['prenom']?.toString() ?? '';
    imageUrl = json['imageUrl']?.toString() ?? '';

    numeroDeTelephone = json['numero_de_telephone']?.toString() ?? '';
    adresse = json['adresse']?.toString() ?? '';
    email = json['email']?.toString() ?? '';
    genre = json['genre']?.toString() ?? '';
    codeParrainage = json['code_parrainage']?.toString() ?? '';
    codeParrain = json['code_parrain']?.toString() ?? '';
    state = json['state']?.toString() ?? '';

    userPays = json['user_pays'] != null
        ? UserPays.fromJson(json['user_pays'] as Map<String, dynamic>)
        : null;

    publi_cash = (json['publi_cash'] as num?)?.toDouble() ?? 0.0;
    votre_solde = (json['votre_solde'] as num?)?.toDouble() ?? 0.0;
    votre_solde_contenu = (json['votre_solde_contenu'] as num?)?.toDouble() ?? 0.0;
    votre_solde_principal = (json['votre_solde_principal'] as num?)?.toDouble() ?? 0.0;
    votre_solde_cadeau = (json['votre_solde_cadeau'] as num?)?.toDouble() ?? 0.0;
    tiktokviewerSolde = double.tryParse(json['tiktokviewerSolde']?.toString() ?? '0') ?? 0.0;

    pubEntreprise = json['pub_entreprise'] ?? 0;
    mesPubs = json['mesPubs'] ?? 0;
    mesTiktokPubs = json['mesTiktokPubs'] ?? 0;
    partage = json['partage'] ?? 0;
    last_time_active = json['last_time_active'] ?? 0;
    pointContribution = json['pointContribution'] ?? 0;
    userlikes = json['userlikes'] ?? 0;
    userjaimes = json['userjaimes'] ?? 0;
    likes = json['likes'] ?? 0;
    jaimes = json['jaimes'] ?? 0;
    comments = json['comments'] ?? 0;
    abonnes = json['abonnes'] ?? 0;

    compteTarif = (json['compte_tarif'] as num?)?.toDouble() ?? 0.0;
    popularite = double.tryParse(json['popularite']?.toString() ?? '0') ?? 0.0;
    latitude = double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0;
    longitude = double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0;

    apropos = json['apropos']?.toString() ?? '';
    isConnected = json['isConnected'] ?? false;
    isBlocked = json['isBlocked'] ?? false;
    completeData = json['completeData'] ?? false;
    hasEntreprise = json['hasEntreprise'] ?? false;
    isVerify = json['isVerify'] ?? false;

    password = json['password']?.toString() ?? '';
    role = json['role']?.toString() ?? '';
    createdAt = json['createdAt'] ?? 0;
    updatedAt = json['updatedAt'] ?? 0;

    userGlobalTags = (json['userGlobalTags'] as List<dynamic>?)
        ?.map((e) => int.tryParse(e.toString()) ?? 0)
        .toList() ?? [];

    userAbonnesIds = (json['userAbonnesIds'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    usersParrainer = (json['usersParrainer'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    friendsIds = (json['friendsIds'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    stories = (json['stories'] as List<dynamic>?)
        ?.map((v) => WhatsappStory.fromJson(v as Map<String, dynamic>))
        .toList() ?? [];

    mesInvitationsEnvoyerId = (json['mesInvitationsEnvoyerId'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    autreInvitationsEnvoyerId = (json['autreInvitationsEnvoyerId'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];

    countryData = json['countryData'] != null
        ? Map<String, String>.from(json['countryData'])
        : {};

    viewedVideos = List<String>.from(json['viewedVideos'] ?? []);
    viewedPostIds = (json['viewedPostIds'] as List<dynamic>?)
        ?.map((v) => v.toString())
        .toList() ?? [];
    lastNotificationTime = json['lastNotificationTime'] ?? 0;

  }


  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['pseudo'] = this.pseudo;
    data['nom'] = this.nom;
    data['prenom'] = this.prenom;
    data['email'] = this.email;
    data['imageUrl'] = this.imageUrl;
    data['numero_de_telephone'] = this.numeroDeTelephone;
    data['adresse'] = this.adresse;
    // data['isVerify'] = this.isVerify;
    data['state'] = this.state;
    data['mesPubs'] = this.mesPubs;
    // data['mesTiktokPubs'] = this.mesTiktokPubs;
    data['code_parrainage'] = this.codeParrainage;
    data['usersParrainer'] = this.usersParrainer;
    // data['publi_cash'] = this.publi_cash;
    // data['votre_solde'] = this.votre_solde;
    // data['votre_solde_contenu'] = this.votre_solde_contenu;
    // data['votre_solde_principal'] = this.votre_solde_principal;
    // data['votre_solde_cadeau'] = this.votre_solde_cadeau;
    // data['code_parrain'] = this.codeParrain;
    // autres données
      data['countryData'] = this.countryData;
    if (stories != null) {
      data['stories'] = stories!.map((story) => story.toJson()).toList();
    } else {
      data['stories'] = [];
    }

    if (this.userPays != null) {
      data['user_pays'] = this.userPays!.toJson();
    }

    // data['isBlocked'] = this.isBlocked;
    data['complete_data'] = this.completeData;
    data['has_entreprise'] = this.hasEntreprise;

    data['latitude'] = this.latitude;
    data['oneIgnalUserid'] = this.oneIgnalUserid;
    // data['image'] = this.image;
    data['longitude'] = this.longitude;
    data['apropos'] = this.apropos;
    // data['password'] = this.password;
    data['genre'] = this.genre;
    // data['userlikes'] = this.userlikes;
    // data['partage'] = this.partage;
    // data['userjaimes'] = this.userjaimes;
    // data['genre_id'] = this.genreId;
    data['isConnected'] = this.isConnected;
    data['role'] = this.role;
    // data['tiktokviewerSolde'] = this.tiktokviewerSolde;

    data['pub_entreprise'] = this.pubEntreprise;
    data['point_contribution'] = this.pointContribution;
    // data['likes'] = this.likes;
    // data['jaimes'] = this.jaimes;
    data['updatedAt'] = this.updatedAt;
    data['createdAt'] = this.createdAt;
    data['comments'] = this.comments;
    data['abonnes'] = this.abonnes;
    data['compte_tarif'] = this.compteTarif;
    data['popularite'] = this.popularite;
    // data['userAbonnesIds'] = this.userAbonnesIds;
    data['friendsIds'] = this.friendsIds;
    data['mesInvitationsEnvoyerId'] = this.mesInvitationsEnvoyerId;
    data['autreInvitationsEnvoyerId'] = this.autreInvitationsEnvoyerId;
    // data['password'] = this.password;
    data['last_time_active'] = this.last_time_active;
    //data['user_global_tags'] = this.userGlobalTags;
    data['viewedVideos'] = this.viewedVideos;
    data['lastNotificationTime'] = lastNotificationTime;

    return data;
  }
}

class PendingTransaction {
  String? id;
  String? userId;
  double? montant;
  double? frais;
  double? montant_net;
  String? statut; // 'pending', 'processing', 'completed', 'failed'
  String? provider; // 'CinetPay'
  String? provider_transaction_id;
  String? payment_url;
  int? createdAt;
  int? expiresAt; // Date d'expiration du lien de paiement
  Map<String, dynamic>? metadata;

  PendingTransaction({
    this.id,
    this.userId,
    this.montant,
    this.frais,
    this.montant_net,
    this.statut,
    this.provider,
    this.provider_transaction_id,
    this.payment_url,
    this.createdAt,
    this.expiresAt,
    this.metadata,
  });

// Methods fromJson and toJson similar to Transaction
}

@JsonSerializable()
class UserShopData {
  String? id;
  int? nombre_pub;
  double? montant;

  String? nom;
  String? nom_magasin;
  String? magasin_status;
  String? logo_magasin;
  String? phone;
  String? pwd;

  String? role;
  int? createdAt;
  int? updatedAt;
  int? nbr_aticle_annonce = 0;

  UserShopData();

  // Add a factory constructor that creates a new instance from a JSON map
  factory UserShopData.fromJson(Map<String, dynamic> json) =>
      _$UserShopDataFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$UserShopDataToJson(this);
}

class ArticleData {
  String? id;
  String? user_id;
  String? categorie_id;
  String? description;
  String? phone;
  String? titre;
  int? prix;
  int? popularite = 1;
  int? booster = 0;
  Map<String, String>? countryData;
  int? vues;
  bool? disponible = true;
  int? contact;
  int? jaime;
  int? partage;
  int? createdAt;
  int? updatedAt;
  UserData? user;
  bool? dispo_annonce_afrolook;
  int? annonce_time;
  List<String>? images = [];

  // Nouveaux attributs pour le boost
  int? boostEndDate; // Timestamp de fin du boost
  bool? isBoosted; // Si le produit est actuellement boosté
  String? boostTransactionId; // ID de la transaction de boost
  double? boostCost; // Coût du boost
  int? boostDays; // Nombre de jours de boost

  // Attributs pour les catégories et tags
  String? sousCategorie;
  List<String>? tags = [];
  String? condition; // Nouveau, occasion, etc.
  String? etat; // Excellent, bon, moyen

  // Attributs pour la localisation
  String? ville;
  String? quartier;
  double? latitude;
  double? longitude;

  // Attributs pour la négociation
  bool? negociable;
  int? prixOriginal; // Prix avant réduction
  int? reduction; // Pourcentage de réduction

  // Attributs pour les statistiques avancées
  int? vuesSemaine;
  int? vuesMois;
  int? contactsSemaine;
  int? contactsMois;

  // Attributs pour la modération
  String? status; // en_attente, approuve, rejete
  String? modReason; // Raison de modération
  String? modBy; // Modérateur
  int? modDate;

  ArticleData({
    this.id,
    this.user_id,
    this.categorie_id,
    this.description,
    this.phone,
    this.titre,
    this.prix,
    this.popularite = 1,
    this.booster = 0,
    this.countryData,
    this.vues,
    this.disponible = true,
    this.contact,
    this.jaime,
    this.partage,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.dispo_annonce_afrolook,
    this.annonce_time,
    this.images,
    this.boostEndDate,
    this.isBoosted,
    this.boostTransactionId,
    this.boostCost,
    this.boostDays,
    this.sousCategorie,
    this.tags,
    this.condition,
    this.etat,
    this.ville,
    this.quartier,
    this.latitude,
    this.longitude,
    this.negociable,
    this.prixOriginal,
    this.reduction,
    this.vuesSemaine,
    this.vuesMois,
    this.contactsSemaine,
    this.contactsMois,
    this.status,
    this.modReason,
    this.modBy,
    this.modDate,
  });

  factory ArticleData.fromJson(Map<String, dynamic> json) {
    return ArticleData(
      id: json['id'] as String?,
      user_id: json['user_id'] as String?,
      categorie_id: json['categorie_id'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      titre: json['titre'] as String?,
      prix: (json['prix'] as num?)?.toInt(),
      popularite: (json['popularite'] as num?)?.toInt() ?? 1,
      booster: (json['booster'] as num?)?.toInt() ?? 0,
      countryData: (json['countryData'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
      ),
      vues: (json['vues'] as num?)?.toInt(),
      disponible: json['disponible'] as bool? ?? true,
      contact: (json['contact'] as num?)?.toInt(),
      jaime: (json['jaime'] as num?)?.toInt(),
      partage: (json['partage'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      dispo_annonce_afrolook: json['dispo_annonce_afrolook'] as bool?,
      annonce_time: (json['annonce_time'] as num?)?.toInt(),
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),

      // Nouveaux attributs
      boostEndDate: (json['boostEndDate'] as num?)?.toInt(),
      isBoosted: json['isBoosted'] as bool?,
      boostTransactionId: json['boostTransactionId'] as String?,
      boostCost: (json['boostCost'] as num?)?.toDouble(),
      boostDays: (json['boostDays'] as num?)?.toInt(),
      sousCategorie: json['sousCategorie'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      condition: json['condition'] as String?,
      etat: json['etat'] as String?,
      ville: json['ville'] as String?,
      quartier: json['quartier'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      negociable: json['negociable'] as bool?,
      prixOriginal: (json['prixOriginal'] as num?)?.toInt(),
      reduction: (json['reduction'] as num?)?.toInt(),
      vuesSemaine: (json['vuesSemaine'] as num?)?.toInt(),
      vuesMois: (json['vuesMois'] as num?)?.toInt(),
      contactsSemaine: (json['contactsSemaine'] as num?)?.toInt(),
      contactsMois: (json['contactsMois'] as num?)?.toInt(),
      status: json['status'] as String?,
      modReason: json['modReason'] as String?,
      modBy: json['modBy'] as String?,
      modDate: (json['modDate'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': user_id,
      'categorie_id': categorie_id,
      'description': description,
      'phone': phone,
      'titre': titre,
      'prix': prix,
      'popularite': popularite,
      'booster': booster,
      'countryData': countryData,
      'vues': vues,
      'disponible': disponible,
      'contact': contact,
      'jaime': jaime,
      'partage': partage,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dispo_annonce_afrolook': dispo_annonce_afrolook,
      'annonce_time': annonce_time,
      'images': images,

      // Nouveaux attributs
      'boostEndDate': boostEndDate,
      'isBoosted': isBoosted,
      'boostTransactionId': boostTransactionId,
      'boostCost': boostCost,
      'boostDays': boostDays,
      'sousCategorie': sousCategorie,
      'tags': tags,
      'condition': condition,
      'etat': etat,
      'ville': ville,
      'quartier': quartier,
      'latitude': latitude,
      'longitude': longitude,
      'negociable': negociable,
      'prixOriginal': prixOriginal,
      'reduction': reduction,
      'vuesSemaine': vuesSemaine,
      'vuesMois': vuesMois,
      'contactsSemaine': contactsSemaine,
      'contactsMois': contactsMois,
      'status': status,
      'modReason': modReason,
      'modBy': modBy,
      'modDate': modDate,
    };
  }

  // Méthodes utilitaires
  bool get estBoosted {
    if (boostEndDate == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return boostEndDate! > now;
  }

  int get joursRestantsBoost {
    if (boostEndDate == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = boostEndDate! - now;
    final jours = (difference / (1000 * 60 * 60 * 24)).ceil();
    return jours > 0 ? jours : 0;
  }

  double get prixAvecReduction {
    if (reduction == null || reduction == 0) return prix?.toDouble() ?? 0;
    final reductionMontant = (prix! * reduction! / 100);
    return prix! - reductionMontant;
  }

  bool get estEnPromotion {
    return reduction != null && reduction! > 0;
  }

  // Méthode pour mettre à jour les vues
  void incrementerVues() {
    vues = (vues ?? 0) + 1;
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  // Méthode pour mettre à jour les contacts
  void incrementerContacts() {
    contact = (contact ?? 0) + 1;
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  // Méthode pour booster le produit
  void boosterProduit(int jours, double cout) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: jours));

    boostEndDate = endDate.millisecondsSinceEpoch;
    isBoosted = true;
    booster = 1;
    boostDays = jours;
    boostCost = cout;
    updatedAt = now.millisecondsSinceEpoch;
  }

  // Méthode pour arrêter le boost
  void arreterBoost() {
    isBoosted = false;
    booster = 0;
    boostEndDate = null;
    updatedAt = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  String toString() {
    return 'ArticleData{id: $id, titre: $titre, prix: $prix, boosté: $estBoosted}';
  }
}

// challenge_model.dart
class Challenge {
  String? id;
  String? user_id;
  String? titre;
  String? statut; // 'en_attente', 'en_cours', 'termine', 'annule'
  String? description;
  String? typeCadeaux;
  String? descriptionCadeaux;
  int? prix;
  Map<String, String>? countryData;
  int? vues;
  bool? disponible = true;
  bool? isAprouved = true;
  int? jaime;
  int? partage;

  // Nouveaux champs pour la gestion des frais
  bool? participationGratuite = true;
  int? prixParticipation = 0;
  bool? voteGratuit = true;
  int? prixVote = 0;

  // Gestion des dates
  int? createdAt;
  int? updatedAt;
  int? startInscriptionAt; // Date début inscription
  int? endInscriptionAt;   // Date fin inscription = date début challenge
  int? finishedAt;         // Date fin challenge

  // Type de contenu autorisé
  String? typeContenu; // 'image', 'video', 'les_deux'

  // Statistiques
  int? totalVotes = 0;
  int? totalParticipants = 0;

  // Références
  UserData? user;
  Post? postWinner;
  List<String>? postsWinnerIds = [];
  List<String>? postsIds = [];
  List<String>? usersInscritsIds = [];
  List<String>? usersVotantsIds = [];

  String? postChallengeId; // Utilisateurs qui ont voté

  // NOUVEAUX CHAMPS POUR GESTION PRIX
  String? userGagnantId; // ID de l'utilisateur qui a gagné
  bool? prixDejaEncaisser = false; // Si le prix a déjà été encaissé
  int? dateEncaissement; // Date d'encaissement

  Challenge();

  Challenge.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    user_id = json['user_id'];
    titre = json['titre'];
    statut = json['statut'] ?? 'en_attente';
    postChallengeId = json['postChallengeId'];
    description = json['description'];
    typeCadeaux = json['typeCadeaux'];
    descriptionCadeaux = json['descriptionCadeaux'];
    prix = json['prix'];
    countryData = json['countryData'] != null ? Map<String, String>.from(json['countryData']) : null;
    vues = json['vues'];
    disponible = json['disponible'];
    isAprouved = json['isAprouved'];
    jaime = json['jaime'];
    partage = json['partage'];

    participationGratuite = json['participationGratuite'] ?? true;
    prixParticipation = json['prixParticipation'] ?? 0;
    voteGratuit = json['voteGratuit'] ?? true;
    prixVote = json['prixVote'] ?? 0;

    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    startInscriptionAt = json['start_inscription_at'];
    endInscriptionAt = json['end_inscription_at'];
    finishedAt = json['finished_at'];

    typeContenu = json['type_contenu'] ?? 'les_deux';
    totalVotes = json['total_votes'] ?? 0;
    totalParticipants = json['total_participants'] ?? 0;

    postsWinnerIds = json['posts_winner_ids'] != null ? List<String>.from(json['posts_winner_ids']) : [];
    postsIds = json['posts_ids'] != null ? List<String>.from(json['posts_ids']) : [];
    usersInscritsIds = json['users_inscrits_ids'] != null ? List<String>.from(json['users_inscrits_ids']) : [];
    usersVotantsIds = json['users_votants_ids'] != null ? List<String>.from(json['users_votants_ids']) : [];

    // NOUVEAUX CHAMPS
    userGagnantId = json['user_gagnant_id'];
    prixDejaEncaisser = json['prix_deja_encaisser'] ?? false;
    dateEncaissement = json['date_encaissement'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['user_id'] = user_id;
    data['titre'] = titre;
    data['statut'] = statut;
    data['postChallengeId'] = postChallengeId;
    data['description'] = description;
    data['typeCadeaux'] = typeCadeaux;
    data['descriptionCadeaux'] = descriptionCadeaux;
    data['prix'] = prix;
    data['countryData'] = countryData;
    data['vues'] = vues;
    data['disponible'] = disponible;
    data['isAprouved'] = isAprouved;
    data['jaime'] = jaime;
    data['partage'] = partage;

    data['participationGratuite'] = participationGratuite;
    data['prixParticipation'] = prixParticipation;
    data['voteGratuit'] = voteGratuit;
    data['prixVote'] = prixVote;

    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['start_inscription_at'] = startInscriptionAt;
    data['end_inscription_at'] = endInscriptionAt;
    data['finished_at'] = finishedAt;

    data['type_contenu'] = typeContenu;
    data['total_votes'] = totalVotes;
    data['total_participants'] = totalParticipants;

    data['posts_winner_ids'] = postsWinnerIds;
    data['posts_ids'] = postsIds;
    data['users_inscrits_ids'] = usersInscritsIds;
    data['users_votants_ids'] = usersVotantsIds;

    // NOUVEAUX CHAMPS
    data['user_gagnant_id'] = userGagnantId;
    data['prix_deja_encaisser'] = prixDejaEncaisser;
    data['date_encaissement'] = dateEncaissement;

    return data;
  }

  // Méthodes utilitaires
  bool get isEnAttente => statut == 'en_attente';
  bool get isEnCours => statut == 'en_cours';
  bool get isTermine => statut == 'termine';
  bool get isAnnule => statut == 'annule';

  bool get inscriptionsOuvertes {
    final now = DateTime.now().microsecondsSinceEpoch;
    return isEnAttente &&
        now >= (startInscriptionAt ?? 0) &&
        now <= (endInscriptionAt ?? 0);
  }


  bool get peutParticiper {
    final now = DateTime.now().microsecondsSinceEpoch;
    return isEnCours &&
        now >= (endInscriptionAt ?? 0) &&
        now <= (finishedAt ?? 0);
  }

  // bool get peutParticiper {
  //   // return inscriptionsOuvertes && !isInscrit(null); // null sera remplacé par l'user ID réel
  //   return inscriptionsOuvertes; // null sera remplacé par l'user ID réel
  // }

  bool isInscrit(String? userId) {
    if (userId == null) return false;
    return usersInscritsIds?.contains(userId) ?? false;
  }

  bool aVote(String? userId) {
    if (userId == null) return false;
    return usersVotantsIds?.contains(userId) ?? false;
  }
}

@JsonSerializable()
class LookChallenge {
  String? id;
  String? user_id;
  String? challenge_id;
  String? postChallengeId;
  String? titre;
  String? statut;
  double? popularite;
  int? prix;
  int? vues;
  bool? disponible = true;
  bool? isAprouved = true;
  int? jaime;
  int? partage;

  int? createdAt;
  int? updatedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  UserData? user;
  @JsonKey(includeFromJson: false, includeToJson: false)
  Post? post;

  // List<String>? postsWinnerIds = [];
  // List<String>? postsIds = [];
  List<String>? usersLovesIds = [];
  List<String>? usersVuesIds = [];
  List<String>? usersPartagesIds = [];
  // List<String>? usersChallengersIds = [];
  LookChallenge();

  // Add a factory constructor that creates a new instance from a JSON map
  factory LookChallenge.fromJson(Map<String, dynamic> json) =>
      _$LookChallengeFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$LookChallengeToJson(this);
}

class EntrepriseData {
  List<EntrepriseAbonnement>? abonnements = [];
  List<String>? produitsIds = [];

  List<String>? usersSuiviId = [];
  EntrepriseAbonnement? abonnement;
  String? titre;
  String? type;
  String? id;
  String? description;
  int? suivi = 0;
  int? publication = 0;
  double? publicash = 0;
  String? urlImage;
  String? userId;
  bool? haveSubscription;
  UserData? user;

  EntrepriseData({
    this.user,
    this.titre,
    this.type,
    this.description,
    this.urlImage,
    this.abonnements,
    this.usersSuiviId,
    this.userId,
    this.suivi = 0,
    this.publicash = 0.0,
    this.publication = 0,
    this.id,
  });

  EntrepriseData.fromJson(Map<String, dynamic> json) {
    titre = json['titre'];
    type = json['type'];
    id = json['id'];
    publicash = json['publicash'];
    publication = json['publication'];
    if (json['abonnements'] != null) {
      abonnements = <EntrepriseAbonnement>[];
      json['abonnements'].forEach((v) {
        abonnements!.add(new EntrepriseAbonnement.fromJson(v));
      });
    }
    if (json['usersSuiviId'] != null) {
      usersSuiviId = <String>[];
      json['usersSuiviId'].forEach((v) {
        usersSuiviId!.add(v);
      });
    }
    if (json['produitsIds'] != null) {
      produitsIds = <String>[];
      json['produitsIds'].forEach((v) {
        produitsIds!.add(v);
      });
    }
    if (json['abonnement'] != null) {
      abonnement =  EntrepriseAbonnement.fromJson(json['abonnement']);
    }

    description = json['description'];
    urlImage = json['urlImage'];
    suivi = json['suivi'];
    userId = json['userId'];
    user = UserData();
  }

  Map<String, dynamic> toJson() => {
        'titre': titre,
        'description': description,
        'urlImage': urlImage,
        'userId': userId,
        'suivi': suivi,
        'type': type,
        'publication': publication,
        'abonnement': abonnement!.toJson(),
        'abonnements':
            abonnements!.map((abonnement) => abonnement.toJson()).toList(),
    'usersSuiviId':
    usersSuiviId!.map((userSuiviId) => userSuiviId).toList(),
    'produitsIds':
    produitsIds!.map((produitsId) => produitsId).toList(),
        'publicash': publicash,
        'id': id,
      };
}
@JsonSerializable()
class EntrepriseAbonnement {
  String? type;
  String? id;
  String? entrepriseId;
  String? description;
  int? nombre_pub;
  int? nombre_image_pub;
  int? nbr_jour_pub_afrolook;
  int? nbr_jour_pub_annonce_afrolook;

  String? userId;
  String? afroshop_user_magasin_id;
  int? createdAt;
  int? updatedAt;
  int? star;
  int? end;
  bool? isFinished;
  bool? dispo_afrolook;
  List<String>? produistIdBoosted = [];


  EntrepriseAbonnement();

  factory EntrepriseAbonnement.fromJson(Map<String, dynamic> json) =>
      _$EntrepriseAbonnementFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$EntrepriseAbonnementToJson(this);
}
enum TypeAbonement{
  GRATUIT,STANDARD,PREMIUM
}

@JsonSerializable()
class Categorie {
  late String? id = "";
  late String? nom = "";
  late String? logo = "";
  int? createdAt;
  int? updatedAt;

  Categorie();

  // Add a factory constructor that creates a new instance from a JSON map
  factory Categorie.fromJson(Map<String, dynamic> json) =>
      _$CategorieFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$CategorieToJson(this);
}

@JsonSerializable()
class TransactionSolde {
  late String? id = "";
  late String? user_id = "";
  late String? type = "";
  late String? statut = "";
  late String? description = "";
  late double? montant = 0.0;
  late String? numero_depot = "";
  late double? frais = 0.0;
  late double? montant_total = 0.0;
  late String? methode_paiement = "";
  late String? id_transaction_cinetpay = "";
  int? createdAt;
  int? updatedAt;

  TransactionSolde();

  // Add a factory constructor that creates a new instance from a JSON map
  factory TransactionSolde.fromJson(Map<String, dynamic> json) =>
      _$TransactionSoldeFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$TransactionSoldeToJson(this);
}


class Transaction {
  String? id;
  String? userId;
  String? type; // 'dépôt', 'retrait', 'achat', 'transfert'
  String? statut; // 'en_attente', 'réussi', 'échoué', 'annulé'
  double? montant;
  double? frais;
  double? montant_net; // montant - frais
  String? methode_paiement; // 'CinetPay', 'MobileMoney', 'CarteBancaire'
  String? description;
  String? numero_transaction;
  String? numero_depot; // Numéro de référence unique
  int? createdAt;
  int? updatedAt;
  Map<String, dynamic>? metadata; // Données supplémentaires

  Transaction({
    this.id,
    this.userId,
    this.type,
    this.statut,
    this.montant,
    this.frais,
    this.montant_net,
    this.methode_paiement,
    this.description,
    this.numero_transaction,
    this.numero_depot,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['userId'],
      type: json['type'],
      statut: json['statut'],
      montant: double.tryParse(json['montant']?.toString() ?? '0'),
      frais: double.tryParse(json['frais']?.toString() ?? '0'),
      montant_net: double.tryParse(json['montant_net']?.toString() ?? '0'),
      methode_paiement: json['methode_paiement'],
      description: json['description'],
      numero_transaction: json['numero_transaction'],
      numero_depot: json['numero_depot'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'statut': statut,
      'montant': montant,
      'frais': frais,
      'montant_net': montant_net,
      'methode_paiement': methode_paiement,
      'description': description,
      'numero_transaction': numero_transaction,
      'numero_depot': numero_depot,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'metadata': metadata,
    };
  }
}

// @JsonSerializable()
// class Canal {
//   @JsonKey(includeFromJson: false, includeToJson: false)
//   List<UserData>? usersSuivi = [];
//
//   List<String>? usersSuiviId = [];
//   String? titre;
//   String? type;
//   String? id;
//   String? description;
//   int? suivi = 0;
//   int? publication = 0;
//   double? publicash = 0;
//   String? urlImage;
//   String? urlCouverture;
//   bool? isVerify;
//   String? userId;
//   int? createdAt;
//   int? updatedAt;
//   @JsonKey(includeFromJson: false, includeToJson: false)
//
//   UserData? user;
//
//   Canal({
//     this.user,
//     this.titre,
//     this.type,
//     this.description,
//     this.urlImage,
//     this.usersSuiviId,
//     this.userId,
//     this.suivi = 0,
//     this.publicash = 0.0,
//     this.publication = 0,
//     this.id,
//   });
//
//   // Add a factory constructor that creates a new instance from a JSON map
//   factory Canal.fromJson(Map<String, dynamic> json) =>
//       _$CanalFromJson(json);
//
//   // Add a method that converts this instance to a JSON map
//   Map<String, dynamic> toJson() => _$CanalToJson(this);
//
// }

class Canal {
  List<UserData>? usersSuivi = [];
  List<String>? usersSuiviId = [];
  String? titre;
  String? type;
  String? id;
  String? description;
  int? suivi = 0;
  int? publication = 0;
  double? publicash = 0;
  String? urlImage;
  String? urlCouverture;
  bool? isVerify;
  String? userId;
  int? createdAt;
  int? updatedAt;
  UserData? user;

  // Nouveaux champs pour canal privé
  bool isPrivate;
  double subscriptionPrice;
  List<String>? subscribersId;

  Canal({
    this.user,
    this.titre,
    this.type,
    this.description,
    this.urlImage,
    this.usersSuiviId,
    this.userId,
    this.suivi = 0,
    this.publicash = 0.0,
    this.publication = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.id,
    this.isPrivate = false,
    this.isVerify = false,
    this.subscriptionPrice = 0.0,
    this.subscribersId,
    this.urlCouverture = "",
  });

  Map<String, dynamic> toJson() {
    return {
      'usersSuiviId': usersSuiviId,
      'titre': titre,
      'type': type,
      'id': id,
      'description': description,
      'suivi': suivi,
      'publication': publication,
      'publicash': publicash,
      'urlImage': urlImage,
      'urlCouverture': urlCouverture,
      'isVerify': isVerify,
      'userId': userId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isPrivate': isPrivate,
      'subscriptionPrice': subscriptionPrice,
      'subscribersId': subscribersId,
    };
  }

  factory Canal.fromJson(Map<String, dynamic> json) {
    return Canal(
      usersSuiviId: List<String>.from(json['usersSuiviId'] ?? []),
      titre: json['titre'],
      type: json['type'],
      id: json['id'],
      description: json['description'],
      suivi: json['suivi'],
      publication: json['publication'],
      publicash: (json['publicash'] ?? 0).toDouble(),
      urlImage: json['urlImage'],
      urlCouverture: json['urlCouverture'],
      isVerify: json['isVerify'],
      userId: json['userId'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isPrivate: json['isPrivate'] ?? false,
      subscriptionPrice: (json['subscriptionPrice'] ?? 0).toDouble(),
      subscribersId: List<String>.from(json['subscribersId'] ?? []),
    );
  }
}


@JsonSerializable()
class Commande {
  String? id;
  String? user_client_id;
  String? user_magasin_id;
  String? article_id;
  String? code;
  String? status;
  String? user_client_status;
  String? user_magasin_status;
  int? dernierprix = 0;

  int? createdAt;
  int? updatedAt;
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserShopData? user_client;
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserShopData? user_magasin;
  @JsonKey(includeFromJson: false, includeToJson: false)
  ArticleData? article;

  Commande();

  // Add a factory constructor that creates a new instance from a JSON map
  factory Commande.fromJson(Map<String, dynamic> json) =>
      _$CommandeFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$CommandeToJson(this);
}

@JsonSerializable()
class CommandeCode {
  String? id;
  String? code;

  CommandeCode();

  // Add a factory constructor that creates a new instance from a JSON map
  factory CommandeCode.fromJson(Map<String, dynamic> json) =>
      _$CommandeCodeFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$CommandeCodeToJson(this);
}

enum RoleUser { ADMIN, USER, SUPERADMIN }

enum UserCmdStatus { ENCOURS, ANNULER, VALIDER }



enum TypeTransaction{
  DEPOTADMIN,RETRAITADMIN,DEPOT,RETRAIT,GAIN,DEPENSE
}
enum StatutTransaction { ENCOURS, ANNULER, VALIDER }


@JsonSerializable()
class UserIACompte {
  String? ia_name;
  String? ia_url_avatar;
  String? id;

  int? jetons = 0;
  int? createdAt;
  int? updatedAt;

  String? userId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserData? user;

  UserIACompte({
    this.user,
    this.ia_url_avatar,
    this.ia_name,
    this.jetons = 0,
    this.userId,
    this.id,
  });

  // Add a factory constructor that creates a new instance from a JSON map
  factory UserIACompte.fromJson(Map<String, dynamic> json) =>
      _$UserIACompteFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$UserIACompteToJson(this);
}


class UserServiceData {
  String? id;
  String? userId;
  UserData? user;
  String? titre;
  String? description;
  String? category;
  String? country;
  String? city;
  bool? disponible = true;
  String? contact;
  String? imageCourverture;
  int? vues = 0;
  int? like = 0;
  int? contactWhatsapp = 0;
  int? partage = 0;
  List<String>? usersViewId = [];
  List<String>? usersLikeId = [];
  List<String>? usersPartageId = [];
  List<String>? usersContactId = [];
  int? createdAt;
  int? updatedAt;

  UserServiceData();

  factory UserServiceData.fromJson(Map<String, dynamic> json) {
    return UserServiceData()
    // Champs de base existants
      ..id = json['id'] as String?
      ..userId = _getStringValue(json, ['userId', 'user_id'])
      ..titre = json['titre'] as String?
      ..description = json['description'] as String?
      ..disponible = json['disponible'] as bool? ?? true

    // Nouveaux champs avec valeurs par défaut pour anciennes données
      ..category = json['category'] as String? ?? 'Autre'
      ..country = json['country'] as String? ?? 'Non spécifié'
      ..city = json['city'] as String? ?? ''

    // Contact
      ..contact = json['contact'] as String?

    // Image - gestion des deux noms possibles
      ..imageCourverture = _getStringValue(json, ['imageCourverture', 'image_courverture'])

    // Statistiques avec conversion sécurisée
      ..vues = _safeToInt(json['vues'])
      ..like = _safeToInt(json['like'])
      ..contactWhatsapp = _safeToInt(json['contactWhatsapp'])
      ..partage = _safeToInt(json['partage'])

    // Listes avec gestion des nulls
      ..usersViewId = _safeStringList(json['usersViewId'])
      ..usersLikeId = _safeStringList(json['usersLikeId'])
      ..usersPartageId = _safeStringList(json['usersPartageId'])
      ..usersContactId = _safeStringList(json['usersContactId'])

    // Timestamps avec conversion sécurisée
      ..createdAt = _safeToInt(json['createdAt'])
      ..updatedAt = _safeToInt(json['updatedAt']);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      // Champs de base
      'id': id,
      'userId': userId,
      'titre': titre,
      'description': description,
      'disponible': disponible,

      // Nouveaux champs
      'category': category,
      'country': country,
      'city': city,

      // Contact
      'contact': contact,

      // Image - utiliser le nom standard pour nouvelles données
      'imageCourverture': imageCourverture,

      // Statistiques
      'vues': vues,
      'like': like,
      'contactWhatsapp': contactWhatsapp,
      'partage': partage,

      // Listes
      'usersViewId': usersViewId,
      'usersLikeId': usersLikeId,
      'usersPartageId': usersPartageId,
      'usersContactId': usersContactId,

      // Timestamps
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Méthodes helpers pour la conversion sécurisée

  static String? _getStringValue(Map<String, dynamic> json, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key] as String?;
      }
    }
    return null;
  }

  static int? _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      try {
        return int.tryParse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  static List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List<String>) return value;
    if (value is List<dynamic>) {
      try {
        return value.whereType<String>().toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // Méthode pour migrer les anciennes données si nécessaire
  void migrateFromOldStructure() {
    // Si category n'est pas définie mais qu'on a des anciennes données, on peut essayer de déduire
    if ((category == null || category == 'Autre') && titre != null) {
      final titreLower = titre!.toLowerCase();

      if (titreLower.contains('menuisi') || titreLower.contains('bois')) {
        category = 'Menuiserie';
      } else if (titreLower.contains('plomb') || titreLower.contains('eau')) {
        category = 'Plomberie';
      } else if (titreLower.contains('électri') || titreLower.contains('electric')) {
        category = 'Électricité';
      } else if (titreLower.contains('maçon') || titreLower.contains('macon')) {
        category = 'Maçonnerie';
      } else if (titreLower.contains('peintre') || titreLower.contains('peinture')) {
        category = 'Peinture';
      } else if (titreLower.contains('décor') || titreLower.contains('decor')) {
        category = 'Décoration';
      } else if (titreLower.contains('informati') || titreLower.contains('informatique')) {
        category = 'Informatique';
      } else if (titreLower.contains('répar') || titreLower.contains('repar')) {
        category = 'Réparation';
      } else if (titreLower.contains('frigo') || titreLower.contains('climat')) {
        category = 'Frigoriste';
      }
      // ... autres catégories
    }
  }
}

class UserGlobalTag {
  int? id;
  String? titre;
  String? description;
  int? popularite;
  String? createdAt;
  String? updatedAt;

  UserGlobalTag(
      {this.id,
      this.titre,
      this.description,
      this.popularite,
      this.createdAt,
      this.updatedAt});

  UserGlobalTag.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    titre = json['titre'];
    description = json['description'];
    popularite = json['popularite'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['titre'] = this.titre;
    data['description'] = this.description;
    data['popularite'] = this.popularite;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class SendMessageData {
  String? message;
  int? senderId;
  int? receiverId;
  int? typeChatMessagesId;

  SendMessageData(
      {this.message, this.senderId, this.receiverId, this.typeChatMessagesId});

  SendMessageData.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    senderId = json['sender_id'];
    receiverId = json['receiver_id'];
    typeChatMessagesId = json['type_chat_messages_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['message'] = this.message;
    data['sender_id'] = this.senderId;
    data['receiver_id'] = this.receiverId;
    data['type_chat_messages_id'] = this.typeChatMessagesId;
    return data;
  }
}

class Chat {
  String? id;
  String? senderId;
  String? post_id;
  String? docId;
  String? receiverId;
  String? lastMessage;
  String? type;
  int? createdAt;
  int? updatedAt;
  bool? lastMessageIsRead = false;
  bool? isConnected = false;
  String? entreprise_id;
  int? my_msg_not_read = 0;
  int? your_msg_not_read = 0;
  String? send_sending;
  String? receiver_sending;
  UserData? sender;
  Post? post;
  EntrepriseData? entreprise;
  UserData? receiver;
  UserData? chatFriend;
  UserIACompte? chatIa;
  List<Message>? messages = [];

  Chat(
      {this.id,
      this.send_sending,
      this.receiver_sending,
      this.senderId,
      this.receiverId,
      this.post_id,
      this.entreprise_id,
      this.lastMessage,
      this.entreprise,
      this.lastMessageIsRead = false,
      this.isConnected = false,
      this.type,
      this.messages,
      this.docId,
      this.createdAt,
      this.updatedAt,
      this.my_msg_not_read = 0,
      this.your_msg_not_read = 0,
      this.sender,
      this.chatIa,
      this.receiver});

  Chat.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    senderId = json['sender_id'];
    post_id = json['post_id'];
    send_sending = json["send_sending"] == null ? "" : json["send_sending"];
    receiver_sending =
        json["receiver_sending"] == null ? "" : json["receiver_sending"];
    receiverId = json['receiver_id'];
    lastMessage = json['last_message'];
    type = json['type'];
    entreprise_id = json['entreprise_id'] == null ? '' : json['entreprise_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    my_msg_not_read = json['my_msg_not_read'];
    your_msg_not_read = json['your_msg_not_read'];
    docId = json['docId'];
    lastMessageIsRead = json['lastMessageIsRead'];

    /*
    sender =
    json['sender'] != null ? new UserData.fromJson(json['sender']) : null;
    receiver = json['receiver'] != null
        ? new UserData.fromJson(json['receiver'])
        : null;
    if (json['messages'] != null) {
      messages = <Message>[];
      json['messages'].forEach((v) {
        messages!.add(new Message.fromJson(v));
      });


    }

     */
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['sender_id'] = this.senderId;
    data['post_id'] = this.post_id;
    data['receiver_id'] = this.receiverId;
    data['last_message'] = this.lastMessage;
    data['type'] = this.type;
    data['entreprise_id'] = this.entreprise_id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['docId'] = this.docId;
    data['send_sending'] = this.send_sending;
    data['receiver_sending'] = this.receiver_sending;

    data['my_msg_not_read'] = this.my_msg_not_read;
    data['your_msg_not_read'] = this.your_msg_not_read;
    data['lastMessageIsRead'] = this.lastMessageIsRead;
    /*
    if (this.sender != null) {
      data['sender'] = this.sender!.toJson();
    }
    if (this.receiver != null) {
      data['receiver'] = this.receiver!.toJson();
    }
    if (this.messages != null) {
      data['messages'] = this.messages!.map((v) => v.toJson()).toList();
    }

     */

    return data;
  }
}

// class Post {
//   String? id;
//   String? user_id;
//   String? challenge_id;
//   String? entreprise_id;
//   String? canal_id;
//   String? type;
//   String? categorie;
//   String? status;
//   String? urlLink;
//   String? dataType;
//   String? typeTabbar;
//   String? colorDomine;
//   String? colorSecondaire;
//   String? description;
//   String? isPostLink;
//   String? contact_whatsapp;
//   int? nombreCollaborateur;
//   double? publiCashTotal;
//   int? nombreImage;
//   int? nombrePersonneParJour;
//   String? url_media;
//   int? createdAt;
//   int? updatedAt;
//
//   int? comments = 0;
//   int? loves = 0;
//   int? partage = 0;
//   int? vues = 0;
//   int? likes = 0;
//   int? seenByUsersCount = 0;
//   int? popularity = 0;
//
//   UserData? user;
//   EntrepriseData? entrepriseData;
//   Canal? canal;
//
//   List<PostComment>? commentaires = [];
//   List<String>? images = [];
//   List<String>? users_like_id = [];
//   List<String>? users_love_id = [];
//   List<String>? users_comments_id = [];
//   List<String>? users_partage_id = [];
//   List<String>? users_cadeau_id = [];
//   List<String>? users_republier_id = [];
//   List<String>? users_vue_id = [];
//
//   /// 🔥 Nouveau champ : Map avec userId => true/false
//   Map<String, bool>? seenByUsersMap = {};
//
//   bool? hasBeenSeenByCurrentUser;
//
//   Post({
//     this.id,
//     this.comments,
//     this.dataType,
//     this.user_id,
//     this.entreprise_id,
//     this.status,
//     this.url_media,
//     this.nombreCollaborateur = 0,
//     this.popularity = 0,
//     this.publiCashTotal = 0,
//     this.nombreImage = 0,
//     this.nombrePersonneParJour = 0,
//     this.type,
//     this.images,
//     this.isPostLink,
//     this.users_like_id,
//     this.users_love_id,
//     this.loves,
//     this.partage = 0,
//     this.users_vue_id,
//     this.challenge_id,
//     this.vues,
//     this.likes,
//     this.commentaires,
//     this.users_partage_id,
//     this.users_republier_id,
//     this.users_cadeau_id,
//     this.users_comments_id,
//     this.contact_whatsapp,
//     this.colorDomine,
//     this.colorSecondaire,
//     this.description,
//     this.typeTabbar,
//     this.urlLink,
//     this.createdAt,
//     this.updatedAt,
//     this.user,
//     this.seenByUsersCount = 0,
//     this.seenByUsersMap,
//     this.hasBeenSeenByCurrentUser = false,
//   });
//
//   int compareTo(Post other) {
//     return other.createdAt!.compareTo(createdAt!);
//   }
//
//   Post.fromJson(Map<String, dynamic> json) {
//     id = json['id'];
//     comments = json['comments'];
//     user_id = json['user_id'];
//     entreprise_id = json['entreprise_id'];
//     status = json['status'];
//     type = json['type'];
//     description = json['description'];
//     createdAt = json['created_at'];
//     updatedAt = json['updated_at'];
//     dataType = json['dataType'];
//     url_media = json['url_media'];
//     contact_whatsapp = json['contact_whatsapp'] ?? "";
//     typeTabbar = json['typeTabbar'] ?? "";
//     isPostLink = json['isPostLink'] ?? "NON";
//     colorSecondaire = json['colorSecondaire'];
//     colorDomine = json['colorDomine'];
//     challenge_id = json['challenge_id'] ?? "";
//     categorie = json['categorie'] ?? "LOOK";
//     loves = json['loves'];
//     images = json['images'] == null ? [] : List<String>.from(json['images']);
//     canal_id = json['canal_id'] ?? "";
//     likes = json['likes'];
//     vues = json['vues'] ?? 0;
//     popularity = json['popularity'] ?? 0;
//     partage = json['partage'] ?? 0;
//     urlLink = json['urlLink'] ?? "";
//     users_like_id = json['users_like_id'] == null ? [] : List<String>.from(json['users_like_id']);
//     users_cadeau_id = json['users_cadeau_id'] == null ? [] : List<String>.from(json['users_cadeau_id']);
//     users_republier_id = json['users_republier_id'] == null ? [] : List<String>.from(json['users_republier_id']);
//     users_love_id = json['users_love_id'] == null ? [] : List<String>.from(json['users_love_id']);
//     users_vue_id = json['users_vue_id'] == null ? [] : List<String>.from(json['users_vue_id']);
//     nombreCollaborateur = json['nombreCollaborateur'];
//     nombreImage = json['nombreImage'];
//     nombrePersonneParJour = json['nombrePersonneParJour'];
//
//     // 🔥 Nouveau champ : Map seenByUsersMap
//     seenByUsersCount = json['seen_by_users_count'] ?? 0;
//     if (json['seen_by_users_map'] != null) {
//       seenByUsersMap = Map<String, bool>.from(json['seen_by_users_map']);
//     } else {
//       seenByUsersMap = {};
//     }
//
//     hasBeenSeenByCurrentUser = false;
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = {};
//     data['id'] = id;
//     data['user_id'] = user_id;
//     data['entreprise_id'] = entreprise_id;
//     data['status'] = status;
//     data['popularity'] = popularity;
//     data['type'] = type;
//     data['description'] = description;
//     data['created_at'] = createdAt;
//     data['updated_at'] = updatedAt;
//     data['url_media'] = url_media;
//     data['colorDomine'] = colorDomine;
//     data['colorSecondaire'] = colorSecondaire;
//     data['loves'] = loves;
//     data['contact_whatsapp'] = contact_whatsapp;
//     data['challenge_id'] = challenge_id;
//     data['dataType'] = dataType;
//     data['categorie'] = categorie ?? 'LOOK';
//     data['urlLink'] = urlLink;
//     data['images'] = images;
//     data['isPostLink'] = isPostLink;
//     data['users_like_id'] = users_like_id;
//     data['users_love_id'] = users_love_id;
//     data['users_republier_id'] = users_republier_id;
//     data['likes'] = likes;
//     data['partage'] = partage;
//     data['users_vue_id'] = users_vue_id;
//     data['vues'] = vues;
//     data['typeTabbar'] = typeTabbar;
//     data['canal_id'] = canal_id;
//     data['nombreCollaborateur'] = nombreCollaborateur;
//     data['publiCashTotal'] = publiCashTotal;
//     data['nombreImage'] = nombreImage;
//     data['nombrePersonneParJour'] = nombrePersonneParJour;
//     data['comments'] = comments;
//
//     // 🔥 Nouveau champ : Map seenByUsersMap
//     data['seen_by_users_count'] = seenByUsersCount;
//     data['seen_by_users_map'] = seenByUsersMap ?? {};
//
//     return data;
//   }
// }


// post_model.dart (mis à jour)
class Post {
  String? id;
  String? user_id;
  String? challenge_id;
  String? entreprise_id;
  String? canal_id;
  String? type;
  String? categorie;
  String? status;
  String? urlLink;
  String? dataType;
  String? typeTabbar;
  String? colorDomine;
  String? colorSecondaire;
  String? description;
  String? isPostLink;
  String? contact_whatsapp;
  int? nombreCollaborateur;
  double? publiCashTotal;
  int? nombreImage;
  int? nombrePersonneParJour;
  String? url_media;
  int? createdAt;
  int? updatedAt;

  int? comments = 0;
  int? loves = 0;
  int? partage = 0;
  int? vues = 0;
  int? likes = 0;
  int? seenByUsersCount = 0;
  int? popularity = 0;

  // Nouveaux champs pour les challenges
  int? votesChallenge = 0; // Nombre de votes spécifiques au challenge
  List<String>? usersVotesIds = []; // Utilisateurs qui ont voté pour ce post

  UserData? user;
  EntrepriseData? entrepriseData;
  Canal? canal;

  List<PostComment>? commentaires = [];
  List<String>? images = [];
  List<String>? users_like_id = [];
  List<String>? users_love_id = [];
  List<String>? users_comments_id = [];
  List<String>? users_partage_id = [];
  List<String>? users_cadeau_id = [];
  List<String>? users_republier_id = [];
  List<String>? users_vue_id = [];

  Map<String, bool>? seenByUsersMap = {};
  bool? hasBeenSeenByCurrentUser;

  Post({
    this.id,
    this.comments,
    this.dataType,
    this.user_id,
    this.entreprise_id,
    this.status,
    this.url_media,
    this.nombreCollaborateur = 0,
    this.popularity = 0,
    this.publiCashTotal = 0,
    this.nombreImage = 0,
    this.nombrePersonneParJour = 0,
    this.type,
    this.images,
    this.isPostLink,
    this.users_like_id,
    this.users_love_id,
    this.loves,
    this.partage = 0,
    this.users_vue_id,
    this.challenge_id,
    this.vues,
    this.likes,
    this.commentaires,
    this.users_partage_id,
    this.users_republier_id,
    this.users_cadeau_id,
    this.users_comments_id,
    this.contact_whatsapp,
    this.colorDomine,
    this.colorSecondaire,
    this.description,
    this.typeTabbar,
    this.urlLink,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.seenByUsersCount = 0,
    this.seenByUsersMap,
    this.hasBeenSeenByCurrentUser = false,
    this.votesChallenge = 0,
    this.usersVotesIds,
  });

  int compareTo(Post other) {
    return other.createdAt!.compareTo(createdAt!);
  }

  Post.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    comments = json['comments'];
    user_id = json['user_id'];
    entreprise_id = json['entreprise_id'];
    status = json['status'];
    type = json['type'];
    description = json['description'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    dataType = json['dataType'];
    url_media = json['url_media'];
    contact_whatsapp = json['contact_whatsapp'] ?? "";
    typeTabbar = json['typeTabbar'] ?? "";
    isPostLink = json['isPostLink'] ?? "NON";
    colorSecondaire = json['colorSecondaire'];
    colorDomine = json['colorDomine'];
    challenge_id = json['challenge_id'] ?? "";
    categorie = json['categorie'] ?? "LOOK";
    loves = json['loves'];
    images = json['images'] == null ? [] : List<String>.from(json['images']);
    canal_id = json['canal_id'] ?? "";
    likes = json['likes'];
    vues = json['vues'] ?? 0;
    popularity = json['popularity'] ?? 0;
    partage = json['partage'] ?? 0;
    urlLink = json['urlLink'] ?? "";
    users_like_id = json['users_like_id'] == null ? [] : List<String>.from(json['users_like_id']);
    users_cadeau_id = json['users_cadeau_id'] == null ? [] : List<String>.from(json['users_cadeau_id']);
    users_republier_id = json['users_republier_id'] == null ? [] : List<String>.from(json['users_republier_id']);
    users_love_id = json['users_love_id'] == null ? [] : List<String>.from(json['users_love_id']);
    users_vue_id = json['users_vue_id'] == null ? [] : List<String>.from(json['users_vue_id']);
    nombreCollaborateur = json['nombreCollaborateur'];
    nombreImage = json['nombreImage'];
    nombrePersonneParJour = json['nombrePersonneParJour'];

    // Champs challenge
    votesChallenge = json['votes_challenge'] ?? 0;
    usersVotesIds = json['users_votes_ids'] == null ? [] : List<String>.from(json['users_votes_ids']);

    seenByUsersCount = json['seen_by_users_count'] ?? 0;
    if (json['seen_by_users_map'] != null) {
      seenByUsersMap = Map<String, bool>.from(json['seen_by_users_map']);
    } else {
      seenByUsersMap = {};
    }

    hasBeenSeenByCurrentUser = false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['id'] = id;
    data['user_id'] = user_id;
    data['entreprise_id'] = entreprise_id;
    data['status'] = status;
    data['popularity'] = popularity;
    data['type'] = type;
    data['description'] = description;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['url_media'] = url_media;
    data['colorDomine'] = colorDomine;
    data['colorSecondaire'] = colorSecondaire;
    data['loves'] = loves;
    data['contact_whatsapp'] = contact_whatsapp;
    data['challenge_id'] = challenge_id;
    data['dataType'] = dataType;
    data['categorie'] = categorie ?? 'LOOK';
    data['urlLink'] = urlLink;
    data['images'] = images;
    data['isPostLink'] = isPostLink;
    data['users_like_id'] = users_like_id;
    data['users_love_id'] = users_love_id;
    data['users_republier_id'] = users_republier_id;
    data['likes'] = likes;
    data['partage'] = partage;
    data['users_vue_id'] = users_vue_id;
    data['vues'] = vues;
    data['typeTabbar'] = typeTabbar;
    data['canal_id'] = canal_id;
    data['nombreCollaborateur'] = nombreCollaborateur;
    data['publiCashTotal'] = publiCashTotal;
    data['nombreImage'] = nombreImage;
    data['nombrePersonneParJour'] = nombrePersonneParJour;
    data['comments'] = comments;

    // Champs challenge
    data['votes_challenge'] = votesChallenge;
    data['users_votes_ids'] = usersVotesIds;

    data['seen_by_users_count'] = seenByUsersCount;
    data['seen_by_users_map'] = seenByUsersMap ?? {};

    return data;
  }

  // Méthode pour vérifier si un utilisateur a voté pour ce post
  bool aVote(String userId) {
    return usersVotesIds?.contains(userId) ?? false;
  }
}
class PostImage {
  String? id;
  String? post_id;
  String? url_media;
  int? createdAt;
  int? updatedAt;

  PostImage({
    this.id,
    this.url_media,
    this.post_id,
    this.createdAt,
    this.updatedAt,
  });

  PostImage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    url_media = json['url_media'];
    post_id = json['post_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['url_media'] = this.url_media;
    data['post_id'] = this.post_id;

    return data;
  }
}

class PostMonetiser {
  String? id;
  String? post_id;
  String? user_id;

  List<String>? users_like_id;
  List<String>? users_love_id;
  List<String>? users_comments_id;
  List<String>? users_partage_id;
  double? solde;
  Post? post;

  int? createdAt;
  String? dataType;
  int? updatedAt;

  PostMonetiser({
    this.id = '',
    required this.user_id,
    this.post_id = '',
    this.dataType = '',
    this.users_like_id,
    this.users_love_id,
    this.users_comments_id,
    this.users_partage_id,
    this.solde = 0.0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  PostMonetiser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    post_id = json['post_id'];
    user_id = json['user_id'];
    dataType = json['dataType']==null?'':json['dataType'];
    users_like_id = json['users_like_id']?.cast<String>() ?? [];
    users_love_id = json['users_love_id']?.cast<String>() ?? [];
    users_comments_id = json['users_comments_id']?.cast<String>() ?? [];
    users_partage_id = json['users_partage_id']?.cast<String>() ?? [];
    solde = json['solde']?.toDouble() ?? 0.0;
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['post_id'] = post_id;
    data['user_id'] = user_id;
    data['users_like_id'] = users_like_id;
    data['users_love_id'] = users_love_id;
    data['users_comments_id'] = users_comments_id;
    data['users_partage_id'] = users_partage_id;
    data['solde'] = solde;
    data['created_at'] = createdAt;
    data['dataType'] = dataType;
    data['updated_at'] = updatedAt;
    return data;
  }
}
class ResponsePostComment {
  String? id;
  String? post_comment_id;
  String? user_id;
  String? user_logo_url;
  String? user_pseudo;
  String? user_reply_pseudo;
  String? message;
  String? status;
  UserData? user;

  int? createdAt;
  int? updatedAt;

  ResponsePostComment({
    this.id = '',
    this.message = '',
    this.user_pseudo = '',
    this.user_logo_url = '',
    this.post_comment_id = '',
    this.user_reply_pseudo = '',
    this.status = '',
    required this.user_id,
    this.createdAt = 0,
    this.updatedAt = 0,
    // required this.user,
  });

  ResponsePostComment.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    message = json['message'];
    user_pseudo = json['user_pseudo'];
    user_logo_url = json['user_logo_url'];
    post_comment_id = json['post_comment_id'];
    user_reply_pseudo = json['user_reply_pseudo'] == null ? "" : json['user_reply_pseudo'];
    user_id = json['user_id'] == null ? "" : json['user_id'];
    status = json['status'] == null ? "" : json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['message'] = this.message;
    data['status'] = this.status;
    data['user_pseudo'] = this.user_pseudo;
    data['user_reply_pseudo'] = this.user_reply_pseudo;
    data['user_logo_url'] = this.user_logo_url;
    data['post_comment_id'] = this.post_comment_id;
    data['user_id'] = this.user_id;

    return data;
  }
}

class Information {
  String? id;
  String? media_url;
  String? type;
  String? titre;
  String? status;
  String? description;
  int? views;
  int? likes;
  bool? isFeatured;
  int? featuredAt;
  int? createdAt;
  int? updatedAt;

  Information({
    this.id = '',
    this.type = '',
    this.description = '',
    this.titre = '',
    this.status = '',
    this.media_url = '',
    this.views = 0,
    this.likes = 0,
    this.isFeatured = false,
    this.featuredAt = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  Information.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    type = json['type'];
    status = json['status'];
    description = json['description'];
    titre = json['titre'];
    media_url = json['media_url'];
    views = json['views'] ?? 0;
    likes = json['likes'] ?? 0;
    isFeatured = json['is_featured'] ?? false;
    featuredAt = json['featured_at'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['type'] = this.type;
    data['status'] = this.status;
    data['description'] = this.description;
    data['titre'] = this.titre;
    data['media_url'] = this.media_url;
    data['views'] = this.views;
    data['likes'] = this.likes;
    data['is_featured'] = this.isFeatured;
    data['featured_at'] = this.featuredAt;
    return data;
  }
}
class NotificationData {
  String? id;
  String? media_url;
  String? user_id;
  String? post_id;
  String? receiver_id;
  String? post_data_type;
  String? type;
  String? titre;
  String? status;
  UserData? userData;
  bool? is_open;
  String? description;
  List<String>? users_id_view = [];

  int? createdAt;
  int? updatedAt;

  NotificationData({
    this.id = '',
    this.type = '',
    this.description = '',
    this.titre = '',
    this.status = '',
    this.media_url = '',
    // this.lu=false,
    this.is_open = false,
    this.post_data_type = '',
    this.post_id = '',
    this.user_id = '',
    this.receiver_id = '',
    this.createdAt = 0,
    this.updatedAt = 0,
    this.users_id_view,
  });

  NotificationData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    type = json['type'];
    status = json['status'];
    user_id = json['user_id'];
    receiver_id = json['receiver_id'] == null ? "" : json['receiver_id'];
    is_open = json['is_open'] == null ? false : json['is_open'];
    post_data_type =
        json['post_data_type'] == null ? "" : json['post_data_type'];
    post_id = json['post_id'] == null ? "" : json['post_id'];
    users_id_view = json['users_id_view'] == null
        ? []
        : json['users_id_view'].cast<String>();

    description = json['description'];
    titre = json['titre'];
    media_url = json['media_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['type'] = this.type;
    data['user_id'] = this.user_id;
    data['receiver_id'] = this.receiver_id;
    data['status'] = this.status;
    data['is_open'] = this.is_open;
    data['users_id_view'] = this.users_id_view;
    data['post_data_type'] = this.post_data_type;

    data['description'] = this.description;
    data['post_id'] = this.post_id;
    data['titre'] = this.titre;
    data['media_url'] = this.media_url;

    return data;
  }
}

class Annonce {
  String? id;
  String? media_url;
  String? type;
  int? vues;
  int? jour;
  String? status;

  int? createdAt;
  int? updatedAt;

  Annonce({
    this.id = '',
    this.vues = 0,
    this.jour = 0,
    this.status = '',
    this.media_url = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  Annonce.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    type = json['type'];
    jour = json['jour'];
    status = json['status'];
    vues = json['vues'];
    media_url = json['media_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['type'] = this.type;
    data['jour'] = this.jour;
    data['status'] = this.status;
    data['vues'] = this.vues;
    data['media_url'] = this.media_url;

    return data;
  }
}

class PostComment {
  String? id;
  String? user_id;
  String? post_id;
  String? status;
  String? message;
  int? createdAt;
  int? updatedAt;
  List<int>? users_like_id = [];

  int? comments = 0;
  int? loves = 0;
  int? likes = 0;
  UserData? user;
  List<ResponsePostComment>? responseComments = [];
  List<Message>? replycommentaires = [];

  PostComment({
    this.id,
    this.comments,
    this.users_like_id,
    this.user_id,
    this.status,
    this.message,
    this.post_id,
    this.responseComments,
    this.loves,
    this.likes,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  PostComment.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    comments = json['comments'];
    user_id = json['user_id'];
    status = json['status'];
    post_id = json['post_id'];
    message = json['message'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    users_like_id =
        json['users_like_id'] == null ? [] : json['users_like_id'].cast<int>();
    loves = json['loves'];
    likes = json['likes'];
    if (json['responseComments'] != null) {
      responseComments = <ResponsePostComment>[];
      json['responseComments'].forEach((v) {
        responseComments!.add(new ResponsePostComment.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['comments'] = this.comments;
    data['user_id'] = this.user_id;
    data['status'] = this.status;
    data['message'] = this.message;
    data['users_like_id'] = this.users_like_id;
    data['post_id'] = this.post_id;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['responseComments'] =
        responseComments!.map((response) => response.toJson()).toList();

    data['loves'] = this.loves;
    data['likes'] = this.likes;

    return data;
  }
}

class Transactionunk {
  final DateTime date;
  final double montant;
  final String status;
  final String type;

  Transactionunk({
    required this.date,
    required this.montant,
    required this.status,
    required this.type,
  });
}


////////////////////////// contenu payant //////////////////////////////


// Modèle pour les catégories de contenu
class ContentCategory {
  String? id;
  String name;
  String? description;
  String? imageUrl;

  ContentCategory({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  factory ContentCategory.fromJson(Map<String, dynamic> json) {
    return ContentCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}

// Modèle pour les épisodes (pour les séries)
class Episode {
  String? id;
  String seriesId;
  String title;
  String description;
  String videoUrl;
  String? thumbnailUrl;
  int duration; // en secondes
  int episodeNumber;
  double price;
  bool isFree;
  int views;
  int likes;
  int createdAt;
  int updatedAt;

  Episode({
    this.id,
    required this.seriesId,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.episodeNumber,
    required this.price,
    required this.isFree,
    this.views = 0,
    this.likes = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      seriesId: json['seriesId'],
      title: json['title'],
      description: json['description'],
      videoUrl: json['videoUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: json['duration'],
      episodeNumber: json['episodeNumber'],
      price: json['price']?.toDouble() ?? 0.0,
      isFree: json['isFree'] ?? false,
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'episodeNumber': episodeNumber,
      'price': price,
      'isFree': isFree,
      'views': views,
      'likes': likes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

// Modèle pour le contenu (vidéos simples ou séries)
class ContentPaie {
  String? id;
  String ownerId;
  String title;
  String description;
  String? videoUrl; // Pour les vidéos simples
  String thumbnailUrl;
  List<String> categories;
  List<String> hashtags;
  bool isSeries;
  String? seriesId; // Pour les épisodes
  double price;
  bool isFree;
  int views;
  int likes;
  int comments;
  int duration; // en secondes
  int createdAt;
  int updatedAt;

  ContentPaie({
    this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    this.videoUrl,
    required this.thumbnailUrl,
    required this.categories,
    required this.hashtags,
    this.isSeries = false,
    this.seriesId,
    required this.price,
    required this.isFree,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.duration = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory ContentPaie.fromJson(Map<String, dynamic> json) {
    return ContentPaie(
      id: json['id'],
      ownerId: json['ownerId'],
      title: json['title'],
      description: json['description'],
      videoUrl: json['videoUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      categories: List<String>.from(json['categories'] ?? []),
      hashtags: List<String>.from(json['hashtags'] ?? []),
      isSeries: json['isSeries'] ?? false,
      seriesId: json['seriesId'],
      price: json['price']?.toDouble() ?? 0.0,
      isFree: json['isFree'] ?? false,
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      duration: json['duration'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'categories': categories,
      'hashtags': hashtags,
      'isSeries': isSeries,
      'seriesId': seriesId,
      'price': price,
      'isFree': isFree,
      'views': views,
      'likes': likes,
      'comments': comments,
      'duration': duration,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

// Modèle pour les achats de contenu
class ContentPurchase {
  String? id;
  String userId;
  String contentId;
  double amountPaid;
  double ownerEarnings;
  double platformEarnings;
  int purchaseDate;

  ContentPurchase({
    this.id,
    required this.userId,
    required this.contentId,
    required this.amountPaid,
    required this.ownerEarnings,
    required this.platformEarnings,
    this.purchaseDate = 0,
  });

  factory ContentPurchase.fromJson(Map<String, dynamic> json) {
    return ContentPurchase(
      id: json['id'],
      userId: json['userId'],
      contentId: json['contentId'],
      amountPaid: json['amountPaid']?.toDouble() ?? 0.0,
      ownerEarnings: json['ownerEarnings']?.toDouble() ?? 0.0,
      platformEarnings: json['platformEarnings']?.toDouble() ?? 0.0,
      purchaseDate: json['purchaseDate'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'contentId': contentId,
      'amountPaid': amountPaid,
      'ownerEarnings': ownerEarnings,
      'platformEarnings': platformEarnings,
      'purchaseDate': purchaseDate,
    };
  }
}

enum UserRole { ADM, USER }

enum RoleUserShop { ADMIN, USER, SUPERADMIN }

enum InvitationStatus { ENCOURS, ACCEPTER, REFUSER }

enum UserState { ONLINE, OFFLINE }

enum MessageState { LU, NONLU }

enum PostType { POST, PUB,ARTICLE,CHALLENGE,CHALLENGEPARTICIPATION,SERVICE }

enum PostDataType { IMAGE, VIDEO, TEXT, COMMENT }

enum PostStatus { VALIDE, SIGNALER, NONVALIDE, SUPPRIMER }

enum ChatType { USER, ENTREPRISE }

enum IsSendMessage { SENDING, NOTSENDING }

enum InfoType { APPINFO, GRATUIT }

enum NotificationType {
  MESSAGE,
  POST,
  INVITATION,
  ACCEPTINVITATION,
  ABONNER,
  PARRAINAGE,
  ARTICLE,
  CHALLENGE,
  CHRONIQUE,
  SERVICE,
  USER
}

enum TypeEntreprise { personnel, partenaire }
enum TypeAbonnement { GRATUIT, STANDART,PREMIUM }
enum StatutData { ENCOURS, TERMINER,ANNULER,ATTENTE }

enum TabBarType {
  ACTUALITES,
  LOOKS,
  SPORT,
  EVENEMENT,
  OFFRES,
  GAMER,
}


// models/transaction_retrait_model.dart
class TransactionRetrait {
  String? id;
  String? userId;
  String? userPseudo;
  String? userEmail;
  String? userPhone;
  double? montant;
  String? typeTransaction; // RETRAIT
  String? statut; // EN_ATTENTE, VALIDER, ANNULE
  String? description;
  String? motifAnnulation;
  String? numeroTransaction;
  int? createdAt;
  int? updatedAt;
  String? processedBy; // ID de l'admin qui a traité
  String? methodPaiement; // Orange Money, Wave, etc.
  String? numeroCompte; // Numéro de téléphone ou compte

  TransactionRetrait({
    this.id,
    required this.userId,
    this.userPseudo,
    this.userEmail,
    this.userPhone,
    required this.montant,
    this.typeTransaction = 'RETRAIT',
    this.statut = 'EN_ATTENTE',
    this.description = 'Demande de retrait',
    this.motifAnnulation,
    this.numeroTransaction,
    this.createdAt,
    this.updatedAt,
    this.processedBy,
    this.methodPaiement,
    this.numeroCompte,
  });

  TransactionRetrait.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    userPseudo = json['user_pseudo'];
    userEmail = json['user_email'];
    userPhone = json['user_phone'];
    montant = (json['montant'] as num?)?.toDouble() ?? 0.0;
    typeTransaction = json['type_transaction'];
    statut = json['statut'];
    description = json['description'];
    motifAnnulation = json['motif_annulation'];
    numeroTransaction = json['numero_transaction'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    processedBy = json['processed_by'];
    methodPaiement = json['method_paiement'];
    numeroCompte = json['numero_compte'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['user_id'] = userId;
    data['user_pseudo'] = userPseudo;
    data['user_email'] = userEmail;
    data['user_phone'] = userPhone;
    data['montant'] = montant;
    data['type_transaction'] = typeTransaction;
    data['statut'] = statut;
    data['description'] = description;
    data['motif_annulation'] = motifAnnulation;
    data['numero_transaction'] = numeroTransaction;
    data['created_at'] = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    data['updated_at'] = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    data['processed_by'] = processedBy;
    data['method_paiement'] = methodPaiement;
    data['numero_compte'] = numeroCompte;
    return data;
  }

  // Getters utiles
  bool get isEnAttente => statut == 'EN_ATTENTE';
  bool get isValide => statut == 'VALIDER';
  bool get isAnnule => statut == 'ANNULE';

  String get statutText {
    switch (statut) {
      case 'EN_ATTENTE': return 'En attente';
      case 'VALIDER': return 'Validé';
      case 'ANNULE': return 'Annulé';
      default: return 'Inconnu';
    }
  }

  Color get statutColor {
    switch (statut) {
      case 'EN_ATTENTE': return Colors.orange;
      case 'VALIDER': return Colors.green;
      case 'ANNULE': return Colors.red;
      default: return Colors.grey;
    }
  }
}