import 'package:afrotok/models/model_data.dart';

/// Convertit un canal de la nouvelle API en modèle `Canal` de l'application (les écrans existants ne changent pas).
Canal canalFromApi(Map<String, dynamic> j) {
  final isPrivate = j['is_private'] == true;
  final type = switch (j['subscription_type']) {
    'monthly' => 'mensuel',
    'one_time' => 'unique',
    _ => isPrivate ? 'unique' : 'gratuit',
  };
  final created = DateTime.tryParse('${j['created_at']}')?.millisecondsSinceEpoch ?? 0;
  final canal = Canal(
    id: j['id'] as String?,
    userId: j['owner_id'] as String?,
    titre: j['title'] as String?,
    description: j['description'] as String?,
    urlImage: j['image_url'] as String?,
    urlCouverture: (j['cover_url'] as String?) ?? '',
    isVerify: j['is_verified'] == true,
    isPrivate: isPrivate,
    subscriptionType: type,
    subscriptionPriceCoinsRaw: (j['price_coins'] as num?)?.toInt() ?? 0,
    suivi: (j['followers_count'] as num?)?.toInt() ?? 0,
    publication: (j['posts_count'] as num?)?.toInt() ?? 0,
    mainCategory: j['main_category'] as String?,
    categories: (j['categories'] as List?)?.map((e) => '$e').toList(),
    allowAllMembersToPost: j['allow_all_members_to_post'] == true,
    canalScore: (j['score'] as num?)?.toDouble() ?? 0.0,
    createdAt: created,
    updatedAt: created,
  );
  canal.isBlocked = j['is_blocked'] == true;
  return canal;
}
