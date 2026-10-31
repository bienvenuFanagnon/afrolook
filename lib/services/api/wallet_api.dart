import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Soldes de la personne, tels que l'API les renvoie (jamais calculés dans l'application).
class WalletSnapshot {
  const WalletSnapshot({
    this.depositCoins = 0,
    this.earnedCoins = 0,
    this.totalCoins = 0,
    this.convertibleCoins = 0,
    this.depositXof = 0,
    this.payoutXof = 0,
    this.debtCoins = 0,
  });

  /// « Pièces de dépôt » : dépensables, non convertibles.
  final int depositCoins;

  /// « Pièces gagnées » : dépensables et convertibles.
  final int earnedCoins;
  final int totalCoins;
  final int convertibleCoins;

  /// « Dépôt FCFA » (Mobile Money).
  final int depositXof;

  /// « Gains à retirer » (FCFA).
  final int payoutXof;
  final int debtCoins;

  factory WalletSnapshot.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return WalletSnapshot(
      depositCoins: n('deposit_coins'),
      earnedCoins: n('earned_coins'),
      totalCoins: n('total_coins'),
      convertibleCoins: n('convertible_coins'),
      depositXof: n('deposit_xof'),
      payoutXof: n('payout_xof'),
      debtCoins: n('debt_coins'),
    );
  }

  /// Recopie les soldes lus sur l'API dans le profil affiché (le profil partagé garde ses anciens champs ; ici ils ne servent
  /// que d'affichage : dépôt = pièces « verrouillées », reste = pièces gagnées).
  void applyTo(UserData u) {
    u.giftCoinsBalance = totalCoins;
    u.lockedCoins = depositCoins;
    u.lockedCoinsSpentBaseline = u.totalGiftCoinsSpent ?? 0;
    u.votre_solde_depot = depositXof.toDouble();
    u.votre_solde_principal = payoutXof.toDouble();
  }
}

/// Une demande de retrait telle que l'API la renvoie (côté personne : seuls les 4 derniers chiffres du compte).
class WithdrawalRow {
  WithdrawalRow(this.json);
  final Map<String, dynamic> json;
  String get id => '${json['id']}';
  String? get userId => json['user_id'] as String?;
  int get amountXof => (json['amount_xof'] as num?)?.toInt() ?? 0;
  String get method => '${json['method'] ?? ''}';
  String get countryCode => '${json['country_code'] ?? ''}';
  String get account => '${json['account_number'] ?? json['account_hint'] ?? ''}';
  String get status => '${json['status'] ?? 'pending'}';
  String? get note => json['note'] as String?;
  Map<String, dynamic> get meta => json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : const {};
  DateTime? get createdAt => DateTime.tryParse('${json['created_at']}')?.toLocal();
}

/// Accès à l'API : argent et pièces (portefeuille, achats, cadeaux, retraits, dépôts, cartes).
/// Aucun retour à Firebase : une erreur est transmise telle quelle ([ApiException], message en français).
class WalletApi {
  WalletApi._();
  static final WalletApi instance = WalletApi._();

  ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> list(dynamic r) =>
      ((r is Map ? r['data'] : r) as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Clés d'idempotence : conservées tant que l'action n'est ni confirmée ni refusée, pour qu'un second appui ou une reprise
  //    réseau réutilise la MÊME clé (jamais de double débit). ──
  static final Map<String, String> _keys = {};

  /// Clé de l'action [slot] (créée au premier appel, identique ensuite).
  static String keyFor(String slot) => _keys.putIfAbsent(slot, ApiClient.newIdempotencyKey);

  /// À appeler quand l'action est terminée (succès) ou définitivement refusée.
  static void release(String slot) => _keys.remove(slot);

  /// Paiement avec clé conservée sous [slot]. La clé est libérée sauf en cas d'erreur réseau (on réutilisera la même au nouvel essai).
  Future<Map<String, dynamic>> pay(String slot, String path, {Object? body}) async {
    final key = keyFor(slot);
    try {
      final r = await _c.pay(path, body: body, idempotencyKey: key);
      release(slot);
      return map(r);
    } on ApiException catch (e) {
      if (!e.isNetwork && e.status < 500) release(slot);
      rethrow;
    }
  }

  // ── Soldes ──
  Future<WalletSnapshot> wallet() async => WalletSnapshot.fromJson(map(await _c.get('/wallet')));

  /// Relit les soldes sur l'API et les recopie dans [user] pour l'affichage.
  Future<WalletSnapshot> syncInto(UserData? user) async {
    final w = await wallet();
    if (user != null) w.applyTo(user);
    return w;
  }

  /// Mouvements : [scope] = all | coins | money.
  Future<({List<Map<String, dynamic>> items, String? next})> transactions({String scope = 'all', String? cursor, int limit = 30}) async {
    final r = await _c.get('/wallet/transactions', query: {'scope': scope, 'limit': limit, if (cursor != null) 'cursor': cursor});
    return (items: list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Conversion de pièces gagnées en FCFA à retirer.
  Future<Map<String, dynamic>> convert(int coins) => pay('convert:$coins', '/wallet/convert', body: {'coins': coins});

  /// Gains des vues : {pending_views, rate_xof_per_view, tier, available_xof, min_cash_xof}.
  Future<Map<String, dynamic>> viewEarnings() async => map(await _c.get('/wallet/earnings/views'));

  Future<Map<String, dynamic>> cashViews(int amountXof) => pay('cashviews:$amountXof', '/wallet/earnings/views/cash', body: {'amount_xof': amountXof});

  // ── Achats en pièces ──
  Map<String, dynamic> _purchaseBody(String kind, String? refId, {int? months, int? days, int? weeks, bool? combined, String? jobId}) => {
        'kind': kind,
        if (refId != null) 'ref_id': refId,
        if (months != null) 'months': months,
        if (days != null) 'days': days,
        if (weeks != null) 'weeks': weeks,
        if (combined != null) 'combined': combined,
        if (jobId != null) 'job_id': jobId,
      };

  /// Prix en pièces calculé par le serveur.
  Future<int> quote(String kind, {String? refId, int? months, int? days, int? weeks, bool? combined, String? jobId}) async {
    final r = await _c.get('/purchases/quote', query: _purchaseBody(kind, refId, months: months, days: days, weeks: weeks, combined: combined, jobId: jobId));
    return (map(r)['coins'] as num?)?.toInt() ?? 0;
  }

  /// Achète avec des pièces (402 `insufficient_coins` si le solde ne suffit pas).
  Future<Map<String, dynamic>> buy(String kind, {String? refId, int? months, int? days, int? weeks, bool? combined, String? jobId}) =>
      pay('buy:$kind:${refId ?? ''}:${months ?? ''}:${days ?? ''}:${weeks ?? ''}:${combined ?? ''}:${jobId ?? ''}', '/purchases',
          body: _purchaseBody(kind, refId, months: months, days: days, weeks: weeks, combined: combined, jobId: jobId));

  /// Mes abonnements en cours : [{plan, started_at, expires_at}].
  Future<List<Map<String, dynamic>>> subscriptions() async => list(await _c.get('/me/subscriptions'));

  /// Achat de pièces avec un solde FCFA (`deposit` ou `payout`), pour soi ou en cadeau.
  Future<Map<String, dynamic>> buyCoinsWithBalance({required int coins, required String balance, String? beneficiaryId}) =>
      pay('coinbal:$coins:$balance:${beneficiaryId ?? ''}', '/coins/purchases/balance', body: {
        'coins': coins,
        'balance': balance,
        if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      });

  // ── Reçus des boutiques d'applications (validés par l'API) ──
  Future<Map<String, dynamic>> verifyApple(String transactionId) async => map(await _c.post('/coins/purchases/apple', body: {'transaction_id': transactionId}));

  Future<Map<String, dynamic>> verifyGoogle(String productId, String purchaseToken) async =>
      map(await _c.post('/coins/purchases/google', body: {'product_id': productId, 'purchase_token': purchaseToken}));

  // ── Cadeaux ──
  Future<Map<String, dynamic>> giftPost(String postId, {required int coins, String? icon, String? label, String? slot}) =>
      pay(slot ?? 'gift:post:$postId:$coins', '/posts/$postId/gifts', body: {'coins': coins, if (icon != null) 'icon': icon, if (label != null) 'label': label});

  /// Cadeau en live (la part de l'hôte et les parrainages sont calculés par l'API).
  Future<Map<String, dynamic>> giftLive(String liveId, {required int coins, String? icon, String? label}) =>
      pay('gift:live:$liveId:$coins', '/lives/$liveId/gifts', body: {'coins': coins, if (icon != null) 'icon': icon, if (label != null) 'label': label});

  Future<Map<String, dynamic>> giftComment(String commentId, {required int coins, String? icon, String? label}) =>
      pay('gift:comment:$commentId:$coins', '/comments/$commentId/gifts', body: {'coins': coins, if (icon != null) 'icon': icon, if (label != null) 'label': label});

  // ── Retraits ──
  Future<Map<String, dynamic>> requestWithdrawal({
    required int amountXof,
    required String method,
    required String accountNumber,
    String? countryCode,
    Map<String, dynamic>? meta,
  }) =>
      pay('withdraw:$amountXof:$method:$accountNumber', '/withdrawals', body: {
        'amount_xof': amountXof,
        'method': method,
        'account_number': accountNumber,
        if (countryCode != null && countryCode.length == 2) 'country_code': countryCode,
        if (meta != null && meta.isNotEmpty) 'meta': meta,
      });

  Future<List<WithdrawalRow>> myWithdrawals() async => list(await _c.get('/withdrawals')).map(WithdrawalRow.new).toList();

  /// Équipe : [status] = pending | paid | rejected.
  Future<List<WithdrawalRow>> adminWithdrawals({String status = 'pending'}) async =>
      list(await _c.get('/admin/withdrawals', query: {'status': status})).map(WithdrawalRow.new).toList();

  Future<void> payWithdrawal(String id, {String? note}) => _c.post('/admin/withdrawals/$id/pay', body: {if (note != null) 'note': note});

  Future<void> rejectWithdrawal(String id, String note) => _c.post('/admin/withdrawals/$id/reject', body: {'note': note});

  // ── Dépôt Mobile Money (FeexPay) ──
  Future<Map<String, dynamic>> depositQuote(int amountXof, String operatorCode) async =>
      map(await _c.get('/payments/deposits/quote', query: {'amount_xof': amountXof, 'operator_code': operatorCode}));

  Future<Map<String, dynamic>> createDeposit(int amountXof, String operatorCode) =>
      pay('deposit:$amountXof:$operatorCode', '/payments/deposits', body: {'amount_xof': amountXof, 'operator_code': operatorCode});

  Future<Map<String, dynamic>> executeDeposit(String id, {required String phone, String? operatorCode, String? operatorName, String? country, String? otp}) async =>
      map(await _c.post('/payments/deposits/$id/execute', body: {
        'phone': phone,
        if (operatorCode != null) 'operator_code': operatorCode,
        if (operatorName != null) 'operator_name': operatorName,
        if (country != null) 'country': country,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
      }));

  Future<Map<String, dynamic>> depositStatus(String id) async => map(await _c.get('/payments/deposits/$id'));

  // ── Carte bancaire (site web seulement) ──
  Future<Map<String, dynamic>> cardQuote() async => map(await _c.get('/payments/cards/quote'));

  Future<Map<String, dynamic>> startCard(Map<String, dynamic> body) => pay('card:${body['coins']}', '/payments/cards', body: body);

  Future<Map<String, dynamic>> cardStatus(String orderId) async => map(await _c.get('/payments/cards/$orderId'));
}
