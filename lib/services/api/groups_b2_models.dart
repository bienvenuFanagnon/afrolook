import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';

/// Lecture des réponses du lot B2 « groupes » (gains d'un groupe payant, groupes de l'administration, droits fins) et messages d'erreur traduits.
/// Aucune dépendance à Firebase : ces fonctions se testent seules. Pièces en entiers ; jamais la part de la plateforme ni celle des parrains.

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Une entrée payante (abonnement ou renouvellement) d'un groupe : MA part de créateur, en pièces gagnées.
class GroupEarningEntry {
  const GroupEarningEntry({required this.id, required this.coins, required this.at, required this.buyerId, required this.buyerName, required this.buyerAvatar});

  final String id;
  final int coins;
  final DateTime? at;
  final String buyerId;
  final String buyerName;
  final String buyerAvatar;

  factory GroupEarningEntry.fromJson(Map<String, dynamic> j) {
    final b = j['buyer'] is Map ? Map<String, dynamic>.from(j['buyer'] as Map) : <String, dynamic>{};
    return GroupEarningEntry(
      id: '${j['id']}',
      coins: _int(j['coins']),
      at: DateTime.tryParse('${j['at']}'),
      buyerId: '${b['id'] ?? ''}',
      buyerName: '${b['username'] ?? ''}',
      buyerAvatar: '${b['avatar_url'] ?? ''}',
    );
  }
}

/// Réponse de `GET /groups/{id}/earnings` : `{data:{coins, entries_count, entries:[…]}, next_cursor}`.
/// [coins] = total de la part du créateur (70 %) ; un groupe gratuit renvoie 0 et une liste vide.
class GroupEarnings {
  const GroupEarnings({required this.coins, required this.entriesCount, required this.entries, required this.next});

  final int coins;
  final int entriesCount;
  final List<GroupEarningEntry> entries;
  final String? next;

  factory GroupEarnings.fromResponse(dynamic r) {
    final d = ApiClient.data(r);
    final m = d is Map ? d : const {};
    return GroupEarnings(
      coins: _int(m['coins']),
      entriesCount: _int(m['entries_count']),
      entries: (m['entries'] as List? ?? const []).whereType<Map>().map((e) => GroupEarningEntry.fromJson(Map<String, dynamic>.from(e))).toList(),
      next: r is Map ? r['next_cursor'] as String? : null,
    );
  }
}

/// Une ligne de `GET /admin/groups` (équipe, permission `content.moderate`).
class AdminGroupRow {
  const AdminGroupRow({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.ownerId,
    required this.ownerName,
    required this.isOfficial,
    required this.isPrivate,
    required this.priceCoins,
    required this.memberCount,
    required this.isBlocked,
    required this.blockedAt,
    required this.blockReason,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String ownerId;
  final String ownerName;
  final bool isOfficial;
  final bool isPrivate;
  final int priceCoins;
  final int memberCount;
  final bool isBlocked;
  final DateTime? blockedAt;
  final String blockReason;

  factory AdminGroupRow.fromJson(Map<String, dynamic> j) {
    final o = j['owner'] is Map ? Map<String, dynamic>.from(j['owner'] as Map) : <String, dynamic>{};
    return AdminGroupRow(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      imageUrl: '${j['image_url'] ?? ''}',
      ownerId: '${o['id'] ?? ''}',
      ownerName: '${o['username'] ?? ''}',
      isOfficial: j['is_official'] == true,
      isPrivate: j['is_private'] == true,
      priceCoins: _int(j['price_coins']),
      memberCount: _int(j['member_count']),
      isBlocked: j['is_blocked'] == true,
      blockedAt: DateTime.tryParse('${j['blocked_at']}'),
      blockReason: '${j['block_reason'] ?? ''}',
    );
  }

  static List<AdminGroupRow> listFromResponse(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => AdminGroupRow.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

/// Droits fins d'un membre de groupe (faux par défaut ; un administrateur ou le propriétaire les a toujours). Coupés pour tous quand
/// le groupe est gelé ou bloqué, ou que l'abonnement du membre est échu.
class GroupMemberRights {
  const GroupMemberRights({this.canDeleteOthers = false, this.canPin = false, this.canInvite = false});

  final bool canDeleteOthers;
  final bool canPin;
  final bool canInvite;

  /// Lit les trois booléens d'un membre (`GET /groups/{id}/members`) ou du bloc `me` de `GET /groups/{id}`.
  factory GroupMemberRights.fromJson(Map<dynamic, dynamic>? j) => GroupMemberRights(
        canDeleteOthers: j?['can_delete_others'] == true,
        canPin: j?['can_pin'] == true,
        canInvite: j?['can_invite'] == true,
      );
}

/// Messages (dans la langue de l'application) des erreurs des groupes du lot B2 ; un code inconnu garde le message du serveur.
class GroupMessages {
  GroupMessages._();

  static String of(Object e) {
    if (e is! ApiException) return tr('Une erreur est survenue. Réessaie.');
    if (e.isNetwork) return tr('Connexion impossible. Vérifie ta connexion puis réessaie.');
    return switch (e.code) {
      'reason_required' => tr('Indique le motif du blocage.'),
      'group_blocked' => tr('Ce groupe est bloqué par l\'équipe Afrolook.'),
      'not_found' => tr('Ce groupe n\'est plus disponible.'),
      _ => e.status == 403 ? tr('Tu n\'as pas le droit de faire cela.') : (e.message.isNotEmpty ? e.message : tr('Une erreur est survenue. Réessaie.')),
    };
  }
}
