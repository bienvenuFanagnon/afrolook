import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/app_messaging.dart';

int _ms(dynamic iso) => DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Convertit la réponse de `GET /v1/bootstrap` en `UserData` (les écrans existants ne changent pas).
/// Les soldes viennent TOUJOURS de l'API : pièces de dépôt (non convertibles) + pièces gagnées (convertibles).
UserData userFromBootstrap(Map<String, dynamic> b) {
  final u = userFromApi(Map<String, dynamic>.from(b['user'] as Map));
  // Parrainage : code personnel et nombre de filleuls (l'écran « Inviter des amis » ne lit que ces deux informations)
  final bu = Map<String, dynamic>.from(b['user'] as Map);
  if ('${bu['referral_code'] ?? ''}'.isNotEmpty) u.codeParrainage = '${bu['referral_code']}';
  final referrals = _i(bu['referrals_count']);
  if (referrals > 0) u.usersParrainer = List<String>.filled(referrals, '');
  ApiIdentity.set(u.id); // les convertisseurs de publications comparent « j'aime / favori » à cet identifiant
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
  // super-administrateur et administrateur = rôle « ADM » de l'application (tableau de bord admin, gestion d'équipe…) ; collaborateur et stagiaire gardent leur type (Hub Équipe)
  if (staff is Map && staff['type'] != null) {
    final t = '${staff['type']}';
    u.role = (t == 'super_admin' || t == 'admin') ? UserRole.ADM.name : t;
  }

  // Série de commentaires
  final st = (b['comment_streak'] as Map?) ?? const {};
  u.commentStreak = _i(st['streak']);
  u.bestCommentStreak = _i(st['best']);
  u.streakShields = _i(st['shields']);
  u.todayCommentCount = _i(st['today_count']);
  final now = DateTime.now();
  u.todayCommentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  u.interests = ((b['interests'] as List?) ?? const []).map((e) => '$e').toList();
  // ciblage des messages dans l'application (console Firebase) : pays, langue, abonnement, équipe ; aucune donnée personnelle
  final plan = u.abonnement?.estActif == true ? '${u.abonnement!.type}' : 'free';
  AppMessaging.syncUser(country: bu['country_code'] as String?, language: bu['language'] as String?, plan: plan == 'gold' || plan == 'premium' ? plan : 'free', team: staff is Map && staff['type'] != null);
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
  // chiffres du modal de profil : popularité (rang parmi les comptes qui ont des abonnés, en %) et filleuls (comptes parrainés)
  if (j['popularity'] is num) u.popularite = (j['popularity'] as num).toDouble();
  if (j['referrals_count'] != null) {
    final r = _i(j['referrals_count']);
    u.usersParrainer = List<String>.filled(r, '');
  }
  // La personne connectée suit-elle ce compte ? (champ `is_following` du profil public)
  if (viewerId != null && j['is_following'] == true) u.userAbonnesIds = [viewerId];
  u.completeData = true;
  final status = j['status'] as String?;
  if (status == 'pending_deletion') {
    u.accountStatus = 'PENDING_DELETION';
    if (j['deletion_scheduled_at'] != null) u.deletionScheduledAt = _ms(j['deletion_scheduled_at']);
  } else if (status == 'restore_fee_due') {
    // Compte restauré : bloqué jusqu'au paiement du déblocage (écran des frais de restauration). Le montant en pièces est fourni par
    // `/bootstrap` (`user.restore_fee_coins`) et par `GET /me` (`restore_fee_coins`), dès l'ouverture de l'écran.
    u.accountStatus = 'RESTORE_FEE_DUE';
    u.restoreFeeDue = _i(j['restore_fee_coins'] ?? j['fee_coins']);
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

/// Nature de la transaction de l'API → type connu de l'écran « Transactions » (libellé, couleur, onglet). Inconnu : gardé tel quel.
String _legacyTransactionType(String kind, String descriptionKey) {
  switch (kind) {
    case 'deposit':
      return 'DEPOT';
    case 'withdrawal':
      return 'RETRAIT';
    case 'view_cashout':
    case 'shop_sale':
      return 'GAIN';
    case 'shop_payment':
      return 'DEPENSE';
    case 'conversion':
      return 'CONVERSION_PIECES';
    case 'coin_purchase':
      return 'ACHAT_PIECES';
    case 'like':
      return 'LIKE_PIECES';
    case 'reward':
      return 'GAIN_PIECES';
    case 'coin_spend':
      return 'DEPENSE_PIECES';
    case 'gift':
      return descriptionKey == 'wallet.coin_gift_received' ? 'CADEAU_PIECES_RECU' : 'CADEAU_PIECES';
    // natures reprises de l'ancien système (import) : sans cette table, tout apparaissait comme une dépense
    case 'opening':
    case 'earning':
      return 'GAIN';
    case 'coin_earned':
      return 'GAIN_PIECES';
    case 'gift_sent':
      return 'CADEAU_PIECES';
    case 'gift_received':
      return 'CADEAU_PIECES_RECU';
    case 'spend':
      return 'DEPENSE';
    case 'refund':
      return const {'wallet.offerwall_reversal', 'wallet.share_clawback'}.contains(descriptionKey) ? 'GAIN_ANNULE' : 'REMBOURSEMENT';
  }
  return kind.toUpperCase();
}

/// Libellé d'une transaction reprise de l'ancien système quand son texte d'origine est vide.
String _legacyKindLabel(String kind) {
  switch (kind) {
    case 'coin_earned':
      return tr('Gain en pièces');
    case 'gift_sent':
      return tr('Cadeau envoyé');
    case 'gift_received':
      return tr('Cadeau reçu');
    case 'like':
      return tr("J'aime envoyé");
    case 'spend':
      return tr('Dépense');
    case 'coin_spend':
      return tr('Paiement en pièces');
    case 'conversion':
      return tr('Conversion de pièces gagnées en argent');
    case 'earning':
      return tr('Gain');
    case 'deposit':
      return tr('Dépôt');
    case 'coin_purchase':
      return tr('Achat de pièces');
    case 'view_cashout':
      return tr('Gains des vues encaissés');
    case 'opening':
      return tr("Solde d'ouverture (repris de l'ancien système)");
  }
  return tr('Transaction');
}

/// Phrase claire pour la clé de description envoyée par l'API (clé inconnue : affichée telle quelle).
String _transactionDescription(String key, Map<String, dynamic> params) {
  final offer = '${params['offer'] ?? ''}'.trim();
  switch (key) {
    case 'wallet.offerwall_reward':
      return offer.isEmpty ? tr("Tâche d'un partenaire terminée") : tr('Tâche terminée : {o}', {'o': offer});
    case 'wallet.offerwall_sponsor':
      return tr("Gain de parrainage : tâche d'un filleul");
    case 'wallet.offerwall_reversal':
      return tr('Tâche annulée par le partenaire');
    case 'wallet.share_reward':
      return tr('Partage et gagne : gains versés');
    case 'wallet.share_sponsor':
      return tr("Gain de parrainage : partage d'un filleul");
    case 'wallet.share_clawback':
      return tr('Partage et gagne : gains retirés');
    case 'wallet.weekly_reward':
      return tr('Récompense de la semaine');
    case 'wallet.ad_reward':
      return tr('Pièces gagnées avec une publicité');
    case 'wallet.coin_gift_received':
      return tr('Pièces reçues en cadeau');
    case 'wallet.deposit':
      return tr('Dépôt');
    case 'wallet.conversion':
      return tr('Conversion de pièces gagnées en argent');
    case 'wallet.coin_purchase':
      return tr('Achat de pièces');
    case 'wallet.shop_payment':
      final t = '${params['title'] ?? ''}'.trim();
      return t.isEmpty ? tr("Achat en direct (argent protégé jusqu'à la réception)") : tr("Achat en direct : {t} (argent protégé jusqu'à la réception)", {'t': t});
    case 'wallet.shop_sale':
      return tr('Vente en direct : fonds reçus après confirmation de réception');
    case 'wallet.shop_refund':
      return tr('Commande annulée : remboursement');
    case 'wallet.shop_refund_penalty':
      return tr("Commande annulée : remboursement moins la pénalité d'annulation");
    case 'wallet.gift_sent':
      return tr('Cadeau envoyé');
    case 'wallet.credit_manual':
      return tr("Crédit par l'équipe");
    case 'wallet.admin_adjustment':
      final why = '${params['reason'] ?? ''}'.trim();
      return why.isEmpty ? tr("Ajustement par l'équipe") : tr("Ajustement par l'équipe : {r}", {'r': why});
    case 'wallet.withdrawal':
      return tr('Retrait');
    case 'wallet.boost_refund':
      return tr('Publicité refusée : pièces remboursées');
    case 'wallet.withdrawal_refund':
      return tr('Retrait annulé : remboursement');
    case 'wallet.view_cashout':
      return tr('Gains des vues encaissés');
    case 'wallet.quiz_hearts':
      return tr('Cœurs du quiz');
    case 'wallet.opening':
      return tr("Solde d'ouverture (repris de l'ancien système)");
    case 'wallet.like':
      return tr("J'aime envoyé");
    case 'wallet.comment_like':
      return tr("J'aime sur un commentaire");
    case 'wallet.comment':
      return tr('Commentaire en pièces');
    case 'wallet.etude':
      return tr('Étude : accès débloqué');
    case 'wallet.contes':
      return tr('Contes : accès débloqué');
    case 'wallet.debt_repayment':
      return tr('Remboursement de dette (tâche annulée)');
    case 'wallet.coin_purchase_refunded':
      return tr('Achat de pièces remboursé');
    case 'wallet.coin_purchase_gift':
      return tr("Pièces offertes à l'achat");
    case 'wallet.card':
      return tr('Cartes : achat');
    case 'wallet.ad_support':
      return tr("Soutien d'une publicité regardée");
  }
  // clé inconnue : jamais le code brut à l'écran, une phrase lisible tirée du code (« wallet.some_thing » → « Some thing »)
  final plain = key.replaceFirst(RegExp(r'^wallet\.'), '').replaceAll('_', ' ').trim();
  return plain.isEmpty ? '' : plain[0].toUpperCase() + plain.substring(1);
}

/// Transaction du portefeuille de l'API → `TransactionSolde` (type = nature, pièces et montants lus tels quels).
TransactionSolde transactionFromApi(Map<String, dynamic> j, String userId) {
  final t = TransactionSolde();
  t.id = j['id'] as String?;
  t.user_id = userId;
  t.type = _legacyTransactionType('${j['kind'] ?? ''}', '${j['description_key'] ?? ''}');
  t.statut = switch ('${j['status']}') { 'completed' || 'done' || 'success' => 'VALIDER', 'pending' => 'ENCOURS', 'failed' || 'cancelled' => 'ANNULER', final o => o.toUpperCase() };
  final descParams = j['description_params'] is Map ? Map<String, dynamic>.from(j['description_params'] as Map) : const <String, dynamic>{};
  t.description = '${j['description_key']}' == 'legacy.description'
      ? (('${descParams['text'] ?? ''}'.trim().isNotEmpty) ? '${descParams['text']}'.trim() : _legacyKindLabel('${j['kind'] ?? ''}'))
      : _transactionDescription('${j['description_key'] ?? ''}', descParams);
  // Les écrans lisent `montant` : en FCFA pour l'argent, en PIÈCES pour les opérations en pièces (cadeaux, achats, gains…). Sinon « 0 pièces » partout.
  final xof = _i(j['amount_xof']);
  final coinsN = _i(j['coins']);
  final inCoins = coinsN > 0 && (xof == 0 || '${j['kind']}' == 'coin_purchase');
  t.montant = (inCoins ? coinsN : xof).toDouble();
  t.montant_total = t.montant;
  t.frais = 0.0;
  t.numero_depot = '';
  t.methode_paiement = '${j['payment_method'] ?? ''}';
  t.createdAt = _ms(j['created_at']);
  t.updatedAt = t.createdAt;
  t.coins = inCoins ? coinsN : null;   // null = montant en FCFA (une valeur 0 ferait lire un montant en FCFA comme des pièces)
  t.paymentMethod = j['payment_method'] as String?;
  return t;
}
