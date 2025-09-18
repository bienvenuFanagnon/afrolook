import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  AppDefaultData(
      {this.id,
      this.users_id,
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
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['nbr_comments'] = this.nbr_comments;
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


  UserData(
      {this.reference,
      this.pseudo,
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
    data['isVerify'] = this.isVerify;
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

    data['isBlocked'] = this.isBlocked;
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

@JsonSerializable()
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
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserData? user;
  bool? dispo_annonce_afrolook;
  int? annonce_time;

  List<String>? images = [];
  ArticleData();

  // Add a factory constructor that creates a new instance from a JSON map
  factory ArticleData.fromJson(Map<String, dynamic> json) =>
      _$ArticleDataFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$ArticleDataToJson(this);
}

@JsonSerializable()
class Challenge {
  String? id;
  String? user_id;
  String? postChallengeId;
  String? titre;
  String? statut;
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

  int? createdAt;
  int? updatedAt;
  int? startAt;
  int? finishedAt;
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserData? user;
  @JsonKey(includeFromJson: false, includeToJson: false)
  Post? postWinner;

  @JsonKey(includeFromJson: false, includeToJson: false)
  Post? postChallenge;

  List<String>? postsWinnerIds = [];
  List<String>? postsIds = [];
  List<String>? usersInscritsIds = [];
  List<String>? usersChallengersIds = [];
  Challenge();

  // Add a factory constructor that creates a new instance from a JSON map
  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
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

@JsonSerializable()
class Canal {
  @JsonKey(includeFromJson: false, includeToJson: false)
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
  @JsonKey(includeFromJson: false, includeToJson: false)

  UserData? user;

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
    this.id,
  });

  // Add a factory constructor that creates a new instance from a JSON map
  factory Canal.fromJson(Map<String, dynamic> json) =>
      _$CanalFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$CanalToJson(this);
  //
  // Canal.fromJson(Map<String, dynamic> json) {
  //   titre = json['titre'];
  //   type = json['type'];
  //   id = json['id'];
  //   publicash = json['publicash'];
  //   publication = json['publication'];
  //
  //   if (json['usersSuiviId'] != null) {
  //     usersSuiviId = <String>[];
  //     json['usersSuiviId'].forEach((v) {
  //       usersSuiviId!.add(v);
  //     });
  //   }
  //
  //
  //   description = json['description'];
  //   urlImage = json['urlImage'];
  //   suivi = json['suivi'];
  //   userId = json['userId'];
  //   user = UserData();
  // }
  //
  // Map<String, dynamic> toJson() => {
  //   'titre': titre,
  //   'description': description,
  //   'urlImage': urlImage,
  //   'userId': userId,
  //   'suivi': suivi,
  //   'type': type,
  //   'publication': publication,
  //
  //   'publicash': publicash,
  //   'id': id,
  // };
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
  DEPOT,RETRAIT,GAIN,DEPENSE
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


@JsonSerializable()
class UserServiceData {
  String? id;
  String? userId;
  @JsonKey(includeFromJson: false, includeToJson: false)
  UserData? user;
  String? titre;
  String? description;
  bool? disponible=true;
  String? contact;
  String? imageCourverture;
  int? vues=0;
  int? like=0;
  int? contactWhatsapp=0;
  int? partage=0;
  List<String>? usersViewId = [];
  List<String>? usersLikeId = [];
  List<String>? usersPartageId = [];
  List<String>? usersContactId = [];
  int? createdAt;
  int? updatedAt;


  UserServiceData();

  factory UserServiceData.fromJson(Map<String, dynamic> json) =>
      _$UserServiceDataFromJson(json);

  // Add a method that converts this instance to a JSON map
  Map<String, dynamic> toJson() => _$UserServiceDataToJson(this);
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

  Post({
    this.id,
    this.comments,
    this.dataType,
    this.user_id,
    this.entreprise_id,
    this.status,
    this.url_media,
    this.nombreCollaborateur = 0,
    this.publiCashTotal = 0,
    this.nombreImage = 0,
    this.nombrePersonneParJour = 0,
    this.type,
    this.images,
    this.isPostLink,
    this.users_like_id,
    this.users_love_id,
    this.loves,
    this.partage=0,
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
    contact_whatsapp =
        json['contact_whatsapp'] == null ? "" : json['contact_whatsapp'];
    typeTabbar =
        json['typeTabbar'] == null ? "" : json['typeTabbar'];
    isPostLink =
        json['isPostLink'] == null ? "NON" : json['isPostLink'];

    colorSecondaire =
        json['colorSecondaire'] == null ? null : json['colorSecondaire'];

    colorDomine =
        json['colorDomine'] == null ? null : json['colorDomine'];
    challenge_id =
        json['challenge_id'] == null ? "" : json['challenge_id'];
    categorie =
        json['categorie'] == null ? "LOOK" : json['categorie'];
    loves = json['loves'];
    images = json['images'] == null ? [] : json['images'].cast<String>();
    canal_id = json['canal_id'] == null ? "" : json['canal_id'];
    likes = json['likes'];
    vues = json['vues'] == null ? 0 : json['vues'];
    partage = json['partage'] == null ? 0 : json['partage'];
    urlLink = json['urlLink'] == null ? "" : json['urlLink'];
    users_like_id = json['users_like_id'] == null
        ? []
        : json['users_like_id'].cast<String>();
    users_cadeau_id = json['users_cadeau_id'] == null
        ? []
        : json['users_cadeau_id'].cast<String>();
    users_republier_id = json['users_republier_id'] == null
        ? []
        : json['users_republier_id'].cast<String>();
    // users_comments_id = json['users_comments_id'] == null
    //     ? []
    //     : json['users_like_id'].cast<String>();
    users_love_id = json['users_love_id'] == null
        ? []
        : json['users_love_id'].cast<String>();
    // users_partage_id = json['users_partage_id'] == null
    //     ? []
    //     : json['users_partage_id'].cast<String>();
    users_vue_id =
        json['users_vue_id'] == null ? [] : json['users_vue_id'].cast<String>();
    nombreCollaborateur = json['nombreCollaborateur'];
    // publiCashTotal = json['publiCashTotal'];
    nombreImage = json['nombreImage'];
    nombrePersonneParJour = json['nombrePersonneParJour'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['comments'] = this.comments;
    data['user_id'] = this.user_id;
    data['entreprise_id'] = this.entreprise_id;
    data['status'] = this.status;
    data['type'] = this.type;
    data['description'] = this.description;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['url_media'] = this.url_media;
    data['colorDomine'] = this.colorDomine;
    data['colorSecondaire'] = this.colorSecondaire;

    data['loves'] = this.loves;
    data['contact_whatsapp'] = this.contact_whatsapp;
    data['challenge_id'] = this.challenge_id;
    data['dataType'] = this.dataType;
    data['categorie'] = this.categorie==null?'LOOK':"CANAL";
    data['urlLink'] = this.urlLink;
    data['images'] = this.images;
    data['isPostLink'] = this.isPostLink;
    data['users_like_id'] = this.users_like_id;
    data['users_love_id'] = this.users_love_id;
    data['users_republier_id'] = this.users_republier_id;
    data['users_cadeau_id'] = this.users_cadeau_id;
    data['users_comments_id'] = this.users_comments_id;
    data['users_partage_id'] = this.users_partage_id;
    data['likes'] = this.likes;
    data['partage'] = this.partage;
    data['users_vue_id'] = this.users_vue_id;
    data['vues'] = this.vues;
    data['typeTabbar'] = this.typeTabbar;
    data['canal_id'] = this.canal_id;
    data['nombreCollaborateur'] = this.nombreCollaborateur;
    data['publiCashTotal'] = this.publiCashTotal;
    data['nombreImage'] = this.nombreImage;
    data['nombrePersonneParJour'] = this.nombrePersonneParJour;

    return data;
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

  int? createdAt;
  int? updatedAt;

  Information({
    this.id = '',
    this.type = '',
    this.description = '',
    this.titre = '',
    this.status = '',
    this.media_url = '',
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

enum PostType { POST, PUB,ARTICLE,CHALLENGE,SERVICE }

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