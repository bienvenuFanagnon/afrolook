import 'package:afrotok/models/model_data.dart';

int _ms(dynamic iso) => DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Convertit la réponse de `GET /v1/bootstrap` en `UserData` (les écrans existants ne changent pas).
/// Les soldes viennent TOUJOURS de l'API : pièces de dépôt (non convertibles) + pièces gagnées (convertibles).
UserData userFromBootstrap(Map<String, dynamic> b) {
  final u = userFromApi(Map<String, dynamic>.from(b['user'] as Map));
  final w = (b['wallet'] as Map?) ?? const {};
  final deposit = _i(w['deposit_coins']);
  final earned = _i(w['earned_coins']);
  // Deux soldes : tout est dépensable ; seules les pièces gagnées sont convertibles → les pièces de dépôt jouent le rôle de « pièces verrouillées ».
  u.giftCoinsBalance = deposit + earned;
  u.lockedCoins = deposit;
  u.lockedCoinsSpentBaseline = 0;
  u.totalGiftCoinsSpent = 0;
  u.votre_solde_depot = _i(w['deposit_xof']).toDouble();
  u.votre_solde_principal = _i(w['payout_xof']).toDouble();
  u.votre_solde = u.votre_solde_principal;

  // Abonnement : plan le plus élevé non échu (gold > premium).
  final subs = ((b['subscriptions'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (subs.isNotEmpty) {
    subs.sort((a, c) => (a['plan'] == 'gold' ? 1 : 0).compareTo(c['plan'] == 'gold' ? 1 : 0));
    final s = subs.last;
    final end = DateTime.tryParse('${s['expires_at']}') ?? DateTime.now();
    u.abonnement = AfrolookAbonnement(
      type: '${s['plan']}',
      prix: 0,
      dateDebut: end.subtract(const Duration(days: 30)),
      dateFin: end,
      estActif: end.isAfter(DateTime.now()),
      dureeMois: 1,
      montantPaye: 0,
      methodePaiement: 'solde',
      createdAt: end,
      updatedAt: end,
      avantagesActives: const [],
    );
  }

  // Pubs, rôle d'équipe
  final ads = (b['ads'] as Map?) ?? const {};
  final freeUntil = ads['free_until'];
  u.adFreeUntil = freeUntil == null ? null : _ms(freeUntil);
  final staff = b['staff'];
  if (staff is Map && staff['type'] != null) u.role = '${staff['type']}';

  // Série de commentaires
  final st = (b['comment_streak'] as Map?) ?? const {};
  u.commentStreak = _i(st['streak']);
  u.bestCommentStreak = _i(st['best']);
  u.streakShields = _i(st['shields']);
  u.todayCommentCount = _i(st['today_count']);
  final now = DateTime.now();
  u.todayCommentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  u.interests = ((b['interests'] as List?) ?? const []).map((e) => '$e').toList();
  return u;
}

/// Convertit un profil de l'API (`/me`, `/users/{id}`, résumé d'abonné/ami) en `UserData`.
UserData userFromApi(Map<String, dynamic> j, {String? viewerId}) {
  final u = UserData();
  u.id = j['id'] as String?;
  u.pseudo = (j['username'] ?? j['pseudo']) as String?;
  final display = j['display_name'] as String?;
  if (display != null && display.isNotEmpty) {
    final parts = display.split(' ');
    u.prenom = parts.first;
    u.nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }
  u.imageUrl = (j['avatar_url'] as String?) ?? '';
  u.email = (j['email'] as String?) ?? '';
  u.numeroDeTelephone = j['phone'] as String?;
  final profile = (j['profile'] as Map?) ?? const {};
  u.apropos = (profile['bio'] ?? j['bio']) as String?;
  u.genre = (profile['gender'] ?? j['gender']) as String?;
  u.adresse = (profile['city'] ?? j['city']) as String?;
  final cc = j['country_code'] as String?;
  if (cc != null) u.countryData = {'countryCode': cc};
  u.createdAt = _ms(j['created_at']);
  u.updatedAt = u.createdAt;
  if (j['followers_count'] != null) u.abonnes = _i(j['followers_count']);
  u.isVerify = j['is_verified'] == true;
  if (j['likes_count'] != null) u.userlikes = _i(j['likes_count']);
  // La personne connectée suit-elle ce compte ? (champ `is_following` du profil public)
  if (viewerId != null && j['is_following'] == true) u.userAbonnesIds = [viewerId];
  u.completeData = true;
  final status = j['status'] as String?;
  if (status == 'pending_deletion') {
    u.accountStatus = 'PENDING_DELETION';
    if (j['deletion_scheduled_at'] != null) u.deletionScheduledAt = _ms(j['deletion_scheduled_at']);
  }
  return u;
}

/// Résumé d'une personne (abonné, ami, invitation) → `UserData` minimal.
UserData userSummaryFromApi(Map<String, dynamic> j) => userFromApi(j);

/// Ami de l'API → `Friends` (avec le profil minimal de l'ami).
Friends friendFromApi(Map<String, dynamic> j, String currentUserId) => Friends(
      id: j['id'] as String?,
      friendId: j['id'] as String?,
      currentUserId: currentUserId,
      createdAt: _ms(j['since']),
      updatedAt: _ms(j['since']),
      friend: userSummaryFromApi(j),
    );

/// Invitation de l'API → `Invitation`. [mine] = true pour une invitation envoyée par la personne connectée.
Invitation invitationFromApi(Map<String, dynamic> j, String currentUserId, {required bool sent}) {
  final other = Map<String, dynamic>.from((j['user'] as Map?) ?? const {});
  final inv = Invitation(
    id: j['id'] as String?,
    senderId: sent ? currentUserId : other['id'] as String?,
    receiverId: sent ? other['id'] as String? : currentUserId,
    message: j['message'] as String?,
    status: switch (j['status']) { 'pending' => 'ENCOURS', 'accepted' => 'ACCEPTER', 'refused' => 'REFUSER', _ => '${j['status']}' },
    createdAt: _ms(j['created_at']),
    updatedAt: _ms(j['created_at']),
    inviteUser: userSummaryFromApi(other),
  );
  inv.chroniqueId = j['chronicle_id'] as String?;
  return inv;
}

/// Champs modifiables du profil envoyés à `PATCH /v1/me` (l'API refuse tout le reste : statut, soldes, droits, identifiant).
Map<String, dynamic> userUpdateBody(UserData u) {
  final display = [u.prenom, u.nom].where((e) => e != null && e.isNotEmpty).join(' ');
  final cc = u.countryData?['countryCode'] ?? u.countryData?['code'];
  return {
    if (display.isNotEmpty) 'display_name': display,
    if (u.imageUrl != null && u.imageUrl!.startsWith('http')) 'avatar_url': u.imageUrl,
    if (cc != null && cc.length == 2) 'country_code': cc.toUpperCase(),
    if (u.numeroDeTelephone != null) 'phone': u.numeroDeTelephone,
    if (u.apropos != null) 'bio': u.apropos,
    if (u.genre == 'male' || u.genre == 'female' || u.genre == 'other') 'gender': u.genre,
    if (u.adresse != null) 'city': u.adresse,
  };
}

/// Transaction du portefeuille de l'API → `TransactionSolde` (type = nature, pièces et montants lus tels quels).
TransactionSolde transactionFromApi(Map<String, dynamic> j, String userId) {
  final t = TransactionSolde();
  t.id = j['id'] as String?;
  t.user_id = userId;
  t.type = '${j['kind'] ?? ''}'.toUpperCase();
  t.statut = switch ('${j['status']}') { 'completed' || 'done' || 'success' => 'VALIDER', 'pending' => 'ENCOURS', 'failed' || 'cancelled' => 'ANNULER', final o => o.toUpperCase() };
  t.description = '${j['description_key'] ?? ''}';
  t.montant = _i(j['amount_xof']).toDouble();
  t.montant_total = t.montant;
  t.frais = 0.0;
  t.numero_depot = '';
  t.methode_paiement = '${j['payment_method'] ?? ''}';
  t.createdAt = _ms(j['created_at']);
  t.updatedAt = t.createdAt;
  t.coins = (j['coins'] as num?)?.toInt();
  t.paymentMethod = j['payment_method'] as String?;
  return t;
}
