// Modèle des chroniques (Chronique, ChroniqueMessage, ChroniqueType). La création passe désormais par le Studio : lib/pages/create/chronique_flow.dart.

import 'package:afrotok/services/account_gate.dart';
import 'package:afrotok/models/post_widget.dart';
import 'chronique_commerce.dart';
import 'chronique_preview.dart';
import 'package:afrotok/l10n/tr.dart';
import 'dart:async';
import 'package:afrotok/ads/ad_config.dart';
import 'package:afrotok/ads/admob_service.dart';

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:afrotok/services/authentic_video_check.dart';
import 'package:provider/provider.dart';
// models/chronique_model.dart
// Timestamp : simple type de date (les chroniques sont lues et écrites par l'API) ; les commentaires restent sur Firebase.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/new_content_bus.dart';
import '../../providers/chroniqueProvider.dart';
import '../../theme/app_colors.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiClient, ApiException;
import '../../services/api/chroniques_api.dart';
import '../../widgets/api_error_dialogs.dart' show showRechargeDialog;
import 'chronique_music.dart';
import 'chronique_overlay_text.dart';
import 'chronique_music_sheet.dart';

enum ChroniqueType { TEXT, IMAGE, VIDEO, AUDIO }

class Chronique {
  String? id;
  /// Chronique business : carte de vente (produit, prix, lieu, WhatsApp, téléphone, lien), null = chronique ordinaire.
  Map<String, dynamic>? commerce;
  /// Widgets vivants posés sur la chronique (sondage, question, lien…).
  List<PostWidget> widgets;
  String userId;
  String userPseudo;
  String userImageUrl;
  ChroniqueType type;
  String? textContent;
  String? mediaUrl;
  String? coverImageUrl; // Pochette pour audio, image de fond pour texte
  String? posterUrl; // Aperçu d'une vidéo, tiré à la création (affiché avant que la vidéo soit prête)
  String? backgroundColor;
  String? templateId; // Template Studio utilisé
  int duration; // en secondes
  int viewCount;
  int likeCount;
  int loveCount;
  List<String> viewers;
  List<String> likers;
  List<String> lovers;
  Timestamp createdAt;
  Timestamp expiresAt;
  double? fileSize; // en MB
  int commentCount = 0;
  List<String> likes;
  int totalReactions;
  int? audioStartMs; // début du clip audio (trim)
  int? audioEndMs;   // fin du clip audio (trim)

  // Dernier commentaire, recopié ici pour l'afficher sans lire la liste des commentaires
  String? lastCommentPseudo;
  String? lastCommentText;

  // Musique de la chronique (texte, image, vidéo) : extrait de 5 à 30 s lu en boucle pendant l'affichage
  String? musicKind; // 'free' | 'artist'
  String? musicId;
  String? musicTitle;
  String? musicArtist;
  String? musicUrl; // extrait public (jamais l'original)
  int? musicStartMs;
  int? musicEndMs;
  double musicVolume = 0.7;
  bool videoSoundKept = false; // vidéo : le son d'origine est gardé et mélangé à la musique (sinon la musique le remplace)

  // Texte posé sur une image ou une vidéo : centre du texte (0 à 1) dans l'écran, choisi par l'auteur
  double? textX;
  double? textY;

  bool get hasMusic => (musicUrl ?? '').isNotEmpty;

  Chronique({
    this.id,
    this.commerce,
    this.widgets = const [],
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.type,
    this.textContent,
    this.mediaUrl,
    this.coverImageUrl,
    this.posterUrl,
    this.backgroundColor,
    this.templateId,
    this.duration = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.loveCount = 0,
    this.commentCount = 0,
    this.viewers = const [],
    this.likers = const [],
    this.lovers = const [],
    required this.createdAt,
    required this.expiresAt,
    this.fileSize,
    this.likes = const [],
    this.totalReactions = 0,
    this.audioStartMs,
    this.audioEndMs,
    this.lastCommentPseudo,
    this.lastCommentText,
    this.musicKind,
    this.musicId,
    this.musicTitle,
    this.musicArtist,
    this.musicUrl,
    this.musicStartMs,
    this.musicEndMs,
    this.musicVolume = 0.7,
    this.videoSoundKept = false,
    this.textX,
    this.textY,
  });

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userPseudo': userPseudo,
      'userImageUrl': userImageUrl,
      'type': type.toString(),
      'textContent': textContent,
      'mediaUrl': mediaUrl,
      'coverImageUrl': coverImageUrl,
      'posterUrl': posterUrl,
      'backgroundColor': backgroundColor,
      'templateId': templateId,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'loveCount': loveCount,
      'viewers': viewers,
      'likers': likers,
      'lovers': lovers,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'fileSize': fileSize,
      'commentCount': commentCount,
      'likes': likes,
      'totalReactions': totalReactions,
      'audioStartMs': audioStartMs,
      'audioEndMs': audioEndMs,
      if (lastCommentText != null) 'lastCommentPseudo': lastCommentPseudo,
      if (lastCommentText != null) 'lastCommentText': lastCommentText,
      if (textX != null && textY != null) ...{'textX': textX, 'textY': textY},
      if (hasMusic) ...{
        'musicKind': musicKind,
        'musicId': musicId,
        'musicTitle': musicTitle,
        'musicArtist': musicArtist,
        'musicUrl': musicUrl,
        'musicStartMs': musicStartMs,
        'musicEndMs': musicEndMs,
        'musicVolume': musicVolume,
        'videoSoundKept': videoSoundKept,
      },
    };
  }

  // Créer depuis Firestore
  factory Chronique.fromMap(Map<String, dynamic> map, String id) {
    return Chronique(
      id: id,
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      type: _stringToChroniqueType(map['type']),
      textContent: map['textContent'],
      mediaUrl: map['mediaUrl'],
      coverImageUrl: map['coverImageUrl'],
      posterUrl: map['posterUrl'],
      backgroundColor: map['backgroundColor'],
      templateId: map['templateId'],
      duration: map['duration'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      loveCount: map['loveCount'] ?? 0,
      viewers: List<String>.from(map['viewers'] ?? []),
      likers: List<String>.from(map['likers'] ?? []),
      lovers: List<String>.from(map['lovers'] ?? []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      expiresAt: map['expiresAt'] ?? Timestamp.fromDate(DateTime.now().add(Duration(hours: 24))),
      fileSize: map['fileSize'],
      commentCount: map['commentCount'] ?? 0,
      likes: List<String>.from(map['likes'] ?? []),
      totalReactions: map['totalReactions'] ?? 0,
      audioStartMs: map['audioStartMs'],
      audioEndMs: map['audioEndMs'],
      lastCommentPseudo: map['lastCommentPseudo'],
      lastCommentText: map['lastCommentText'],
      musicKind: map['musicKind'],
      musicId: map['musicId'],
      musicTitle: map['musicTitle'],
      musicArtist: map['musicArtist'],
      musicUrl: map['musicUrl'],
      musicStartMs: (map['musicStartMs'] as num?)?.toInt(),
      musicEndMs: (map['musicEndMs'] as num?)?.toInt(),
      musicVolume: (map['musicVolume'] as num?)?.toDouble() ?? 0.7,
      videoSoundKept: map['videoSoundKept'] == true,
      textX: (map['textX'] as num?)?.toDouble(),
      textY: (map['textY'] as num?)?.toDouble(),
    );
  }

  static ChroniqueType _stringToChroniqueType(String type) {
    switch (type) {
      case 'ChroniqueType.TEXT':
        return ChroniqueType.TEXT;
      case 'ChroniqueType.IMAGE':
        return ChroniqueType.IMAGE;
      case 'ChroniqueType.VIDEO':
        return ChroniqueType.VIDEO;
      case 'ChroniqueType.AUDIO':
        return ChroniqueType.AUDIO;
      default:
        return ChroniqueType.TEXT;
    }
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt.toDate());
  }

  bool get hasReachedLimit {
    return fileSize != null && fileSize! > 20.0;
  }

  bool get isVideoTooLong {
    return type == ChroniqueType.VIDEO && duration > 10;
  }

  // Méthode pour calculer le total des réactions (likes + loves)
  int get calculatedTotalReactions {
    return likeCount + loveCount;
  }
}
class ChroniqueMessage {
  String? id;
  String chroniqueId;
  String userId;
  String userPseudo;
  String userImageUrl;
  String message;
  Timestamp createdAt;
  // Nouveaux champs pour les likes sur les commentaires
  int likeCount;
  List<String> likers;

  ChroniqueMessage({
    this.id,
    required this.chroniqueId,
    required this.userId,
    required this.userPseudo,
    required this.userImageUrl,
    required this.message,
    required this.createdAt,
    this.likeCount = 0,
    this.likers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'chroniqueId': chroniqueId,
      'userId': userId,
      'userPseudo': userPseudo,
      'userImageUrl': userImageUrl,
      'message': message,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'likers': likers,
    };
  }

  factory ChroniqueMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChroniqueMessage(
      id: id,
      chroniqueId: map['chroniqueId'] ?? '',
      userId: map['userId'] ?? '',
      userPseudo: map['userPseudo'] ?? '',
      userImageUrl: map['userImageUrl'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      likeCount: map['likeCount'] ?? 0,
      likers: List<String>.from(map['likers'] ?? []),
    );
  }
}
