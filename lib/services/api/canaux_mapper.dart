import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/canal_mapper.dart';

/// Type d'abonnement de l'application ('gratuit' | 'unique' | 'mensuel') -> API ('free' | 'one_time' | 'monthly').
String apiSubscriptionType(String local, bool isPrivate) {
  if (!isPrivate) return 'free';
  return switch (local) {
    'mensuel' => 'monthly',
    'gratuit' => 'one_time',
    _ => 'one_time',
  };
}

/// Convertit un canal de l'API en `Canal` de l'application et y reporte MA situation (bloc `me` de la fiche) dans les listes que les écrans
/// consultent déjà : abonnés (`usersSuiviId`), administrateurs, personnes autorisées à publier, abonnés payants, échéance mensuelle.
/// Les listes complètes de membres n'existent plus : seule ma propre appartenance est connue (la liste réelle passe par `/channels/{id}/members`).
Canal canalFromApiFull(Map<String, dynamic> j, String? myId) {
  final canal = canalFromApi(j);
  final me = j['me'] is Map ? Map<String, dynamic>.from(j['me'] as Map) : null;
  final isMember = me != null ? me['is_member'] == true : j['is_member'] == true;
  canal
    ..usersSuiviId = <String>[]
    ..adminIds = <String>[]
    ..allowedPostersIds = <String>[]
    ..subscribersId = <String>[]
    ..monthlySubscriptions = <String, dynamic>{};
  if (myId != null) {
    if (isMember) canal.usersSuiviId!.add(myId);
    if (me != null) {
      if (me['is_admin'] == true) canal.adminIds!.add(myId);
      if (me['can_post'] == true) canal.allowedPostersIds!.add(myId);
      if (isMember && canal.isPrivate) canal.subscribersId!.add(myId);
      final exp = DateTime.tryParse('${me['expires_at']}')?.millisecondsSinceEpoch;
      if (exp != null) canal.monthlySubscriptions![myId] = exp;
    }
  }
  if (canal.userId != null && !canal.adminIds!.contains(canal.userId) && myId == canal.userId) canal.adminIds!.add(canal.userId!);
  final owner = j['owner'];
  if (owner is Map) {
    canal.user = UserData()
      ..id = canal.userId
      ..pseudo = '${owner['username'] ?? ''}'
      ..imageUrl = '${owner['avatar_url'] ?? ''}';
  }
  final blockedAt = DateTime.tryParse('${j['blocked_at']}')?.millisecondsSinceEpoch;
  if (blockedAt != null) canal.blockedAt = blockedAt;
  return canal;
}
