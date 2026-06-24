// services/utils/group_permission_utils.dart
//
// Point de contrôle unique pour toutes les permissions liées aux groupes Gold.
// Appelé depuis group_chat_page, group_info_page, et toutes les pages qui
// permettent de partager vers un groupe (post, produit, live, contenu payant).
//
// Structure Firestore attendue dans GroupChats :
//   is_frozen            : bool  — groupe gelé (proprio plus Gold)
//   is_read_only         : bool  — lecture seule admin (Premium)
//   default_can_write    : bool  — écriture autorisée par défaut (Gold)
//   default_can_share    : bool  — partage autorisé par défaut (Gold)
//   member_permissions   : Map<userId, {can_write: bool, can_share: bool}>
//   allow_hidden_msgs    : bool  — messages invisibles activés (Gold)

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupPermissionUtils {
  // ── Règles de base ────────────────────────────────────────────────────────

  /// Groupe gelé → personne n'écrit, ni partage — pas d'exception.
  static bool isGroupFrozen(Map<String, dynamic> groupData) =>
      groupData['is_frozen'] == true;

  /// Groupe en lecture seule (Premium) → seuls admins/owner écrivent.
  static bool isReadOnly(Map<String, dynamic> groupData) =>
      groupData['is_read_only'] == true;

  // ── Permissions d'écriture ────────────────────────────────────────────────

  static bool canWrite({
    required Map<String, dynamic> groupData,
    required String userId,
    required String userRole,
  }) {
    // Règle absolue : gelé = personne n'écrit
    if (isGroupFrozen(groupData)) return false;

    // Owner et admin peuvent toujours écrire (lecture seule, default_can_write=false, etc.)
    if (userRole == 'owner' || userRole == 'admin') return true;

    // Mode lecture seule : membres bloqués
    if (isReadOnly(groupData)) return false;

    // Permission individuelle (priorité sur le défaut)
    final perms = _memberPerms(groupData, userId);
    if (perms != null) return perms['can_write'] != false;

    // Défaut du groupe (true si pas défini)
    return groupData['default_can_write'] != false;
  }

  // ── Permissions de partage ────────────────────────────────────────────────

  static bool canShare({
    required Map<String, dynamic> groupData,
    required String userId,
    required String userRole,
  }) {
    // Gelé = personne ne partage (seule règle absolue)
    if (isGroupFrozen(groupData)) return false;

    // Owner et admin ne sont jamais bloqués par les restrictions de partage
    if (userRole == 'owner' || userRole == 'admin') return true;

    // Permission individuelle
    final perms = _memberPerms(groupData, userId);
    if (perms != null) return perms['can_share'] != false;

    // Défaut du groupe
    return groupData['default_can_share'] != false;
  }

  // ── Messages invisibles ───────────────────────────────────────────────────

  /// Les messages invisibles sont activés pour ce groupe (Gold).
  static bool hiddenMessagesEnabled(Map<String, dynamic> groupData) =>
      groupData['allow_hidden_msgs'] == true;

  /// Un message est-il visible pour cet utilisateur ?
  ///
  /// Priorité :
  /// 1. `visible_to` (liste explicite) — visible seulement aux membres listés + expéditeur
  /// 2. `is_hidden` — visible seulement à l'expéditeur
  /// 3. Sinon → visible à tous
  static bool isMessageVisibleTo(Map<String, dynamic> msgData, String userId) {
    final sendBy = msgData['send_by'] as String?;
    final visibleTo = (msgData['visible_to'] as List<dynamic>?)?.cast<String>();

    // Liste de destinataires explicite → priorité absolue
    if (visibleTo != null && visibleTo.isNotEmpty) {
      return visibleTo.contains(userId) || sendBy == userId;
    }

    // Masqué → seulement l'expéditeur
    if (msgData['is_hidden'] == true) return sendBy == userId;

    return true;
  }

  /// Indique si un message a une visibilité restreinte (masqué ou destinataires limités).
  static bool isMessageRestricted(Map<String, dynamic> msgData) {
    final visibleTo = (msgData['visible_to'] as List<dynamic>?)?.cast<String>();
    if (visibleTo != null && visibleTo.isNotEmpty) return true;
    return msgData['is_hidden'] == true;
  }

  // ── Chargement depuis Firestore ───────────────────────────────────────────

  /// Charge les données d'un groupe pour vérifier les permissions.
  /// À utiliser depuis les pages externes (post details, produit, live, etc.)
  static Future<Map<String, dynamic>> loadGroupData(String groupId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(groupId)
          .get();
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Vérifie rapidement si un utilisateur peut partager dans un groupe donné.
  /// Utiliser depuis les pages externes qui permettent le partage vers un groupe.
  static Future<bool> canShareToGroup({
    required String groupId,
    required String userId,
    required String userRole,
  }) async {
    final data = await loadGroupData(groupId);
    return canShare(groupData: data, userId: userId, userRole: userRole);
  }

  // ── Mise à jour des permissions ───────────────────────────────────────────

  /// Modifier la permission d'écriture d'un membre.
  static Future<void> setMemberCanWrite({
    required String groupId,
    required String targetUserId,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
      'member_permissions.$targetUserId.can_write': value,
    });
  }

  /// Modifier la permission de partage d'un membre.
  static Future<void> setMemberCanShare({
    required String groupId,
    required String targetUserId,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
      'member_permissions.$targetUserId.can_share': value,
    });
  }

  /// Modifier la permission d'écriture par défaut (pour tous les membres).
  static Future<void> setDefaultCanWrite({
    required String groupId,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
      'default_can_write': value,
    });
  }

  /// Modifier la permission de partage par défaut (pour tous les membres).
  static Future<void> setDefaultCanShare({
    required String groupId,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
      'default_can_share': value,
    });
  }

  /// Activer/désactiver les messages invisibles.
  static Future<void> setHiddenMessages({
    required String groupId,
    required bool value,
  }) async {
    await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
      'allow_hidden_msgs': value,
    });
  }

  // ── Interne ───────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _memberPerms(Map<String, dynamic> groupData, String userId) {
    final allPerms = groupData['member_permissions'] as Map<String, dynamic>?;
    if (allPerms == null) return null;
    final userPerms = allPerms[userId];
    if (userPerms is! Map) return null;
    return Map<String, dynamic>.from(userPerms);
  }
}
