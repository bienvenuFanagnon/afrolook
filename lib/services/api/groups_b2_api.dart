import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/groups_b2_models.dart';

export 'package:afrotok/services/api/groups_b2_models.dart';

/// Lot B2 « groupes » : gains d'un groupe payant, droits fins par membre, blocage d'un groupe par l'équipe.
/// Aucun retour à Firebase : une erreur est remontée à l'écran ([GroupMessages.of] + « Réessayer »).
class GroupsB2Api {
  GroupsB2Api._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Gains d'un groupe payant (propriétaire du groupe et équipe seulement ; 404 pour tout autre, même un administrateur du groupe).
  /// [GroupEarnings.coins] = part du créateur de chaque abonnement ou renouvellement payé en pièces (pièces gagnées).
  static Future<GroupEarnings> earnings(String groupId, {String? cursor, int limit = 30}) async =>
      GroupEarnings.fromResponse(await _c.get('/groups/$groupId/earnings', query: {'limit': limit, if (cursor != null) 'cursor': cursor}));

  /// Droits d'un membre. Seuls les champs donnés changent (booléens, jamais null) :
  /// `can_write`, `can_share`, `can_delete_others`, `can_pin`, `can_invite`, ainsi que `role` (admin ou member).
  static Future<void> setMemberRights(
    String groupId,
    String userId, {
    bool? canWrite,
    bool? canShare,
    bool? canDeleteOthers,
    bool? canPin,
    bool? canInvite,
  }) =>
      _c.patch('/groups/$groupId/members/$userId', body: {
        if (canWrite != null) 'can_write': canWrite,
        if (canShare != null) 'can_share': canShare,
        if (canDeleteOthers != null) 'can_delete_others': canDeleteOthers,
        if (canPin != null) 'can_pin': canPin,
        if (canInvite != null) 'can_invite': canInvite,
      });

  // ── Administration (équipe, permission `content.moderate`, introuvable pour les autres) ──

  /// Groupes pour la modération. [blocked] : seulement les bloqués (vrai) ou les non bloqués (faux).
  static Future<({List<AdminGroupRow> items, String? next})> adminList({String? q, bool? blocked, String? cursor, int limit = 30}) async {
    final r = await _c.get('/admin/groups', query: {
      'limit': limit,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (blocked != null) 'blocked': blocked ? 1 : 0,
      if (cursor != null) 'cursor': cursor,
    });
    return (items: AdminGroupRow.listFromResponse(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Bloque ou débloque un groupe. Motif OBLIGATOIRE pour bloquer (422 `reason_required`, 255 caractères au plus) ; on ne bloque pas son propre
  /// groupe (403) ; rejouable. Le propriétaire reçoit un message dans sa liste de notifications. Renvoie la ligne à jour.
  static Future<AdminGroupRow> adminSetBlocked(String groupId, bool blocked, {String? reason}) async {
    final r = await _c.patch('/admin/groups/$groupId', body: {
      'is_blocked': blocked,
      if (blocked && reason != null && reason.trim().isNotEmpty) 'reason': reason.trim().length > 255 ? reason.trim().substring(0, 255) : reason.trim(),
    });
    final d = ApiClient.data(r);
    return AdminGroupRow.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }
}
