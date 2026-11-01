import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/l10n/tr_audit.dart';
import 'package:afrotok/services/api/audit_errors.dart';
import 'package:afrotok/services/api/retrait_mapper.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrotok/widgets/email_verification_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correctifs de l'audit de sécurité du 01/11/2026 côté application : conversion par lots de 25 pièces, e-mail non vérifié,
/// nouveaux codes d'erreur, validation à deux des retraits, traductions.
ApiException err(String code, {int status = 403, Map<String, dynamic> details = const {}}) =>
    ApiException(status: status, code: code, message: 'message API en français', details: details);

class FakeVerifier implements EmailVerifier {
  FakeVerifier({this.confirmed = true, this.mail = 'ama@example.com'});
  bool confirmed;
  final String? mail;
  int sent = 0;
  int checks = 0;

  @override
  String? get email => mail;

  @override
  Future<void> sendLink() async => sent++;

  @override
  Future<bool> checkConfirmed() async {
    checks++;
    return confirmed;
  }
}

Widget host(Future<void> Function(BuildContext) onTap) => MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => Center(child: ElevatedButton(onPressed: () => onTap(context), child: const Text('go')))),
      ),
    );

void main() {
  tearDown(() {
    trCurrentLanguage = 'fr';
    EmailVerificationGate.verifier = const FirebaseEmailVerifier();
  });

  group('Conversion par lots de 25 pièces', () {
    test('arrondi vers le bas au multiple de 25', () {
      expect(AuditErrors.conversionStep, 25);
      expect(AuditErrors.roundDownToStep(0), 0);
      expect(AuditErrors.roundDownToStep(24), 0);
      expect(AuditErrors.roundDownToStep(25), 25);
      expect(AuditErrors.roundDownToStep(130), 125);
      expect(AuditErrors.roundDownToStep(1999), 1975);
      expect(AuditErrors.roundDownToStep(-5), 0);
    });

    test('un nombre qui n\'est pas un multiple de 25 n\'est jamais envoyé à l\'API', () async {
      for (final bad in [0, 1, 24, 130, 101]) {
        await expectLater(
          WalletApi.instance.convert(bad),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'coins_not_multiple').having((e) => e.status, 'status', 422)),
        );
      }
    });

    test('coins_not_multiple est traduit et mentionne le lot', () {
      final e = err('coins_not_multiple', status: 422, details: {'step': 25});
      expect(AuditErrors.message(e, scope: ErrorScope.conversion), contains('lots de 25'));
      trCurrentLanguage = 'en';
      expect(AuditErrors.message(e, scope: ErrorScope.conversion), contains('batches of 25'));
    });
  });

  group('Erreurs de l\'API traduites', () {
    const codes = {
      'email_unverified': ErrorScope.generic,
      'coins_not_multiple': ErrorScope.conversion,
      'below_minimum': ErrorScope.withdrawal,
      'account_too_young': ErrorScope.withdrawal,
      'daily_cap_reached': ErrorScope.withdrawal,
      'weekly_cap_reached': ErrorScope.withdrawal,
      'creator_cannot_participate': ErrorScope.defi,
      'self_withdrawal': ErrorScope.admin,
      'second_validation_required': ErrorScope.admin,
      'payment_reference_required': ErrorScope.share,
      'second_approver_required': ErrorScope.share,
      'self_decision': ErrorScope.share,
    };

    test('chaque code a un message français et une traduction dans les 7 autres langues', () {
      for (final entry in codes.entries) {
        trCurrentLanguage = 'fr';
        final fr = AuditErrors.known(err(entry.key), scope: entry.value);
        expect(fr, isNotNull, reason: entry.key);
        expect(fr, isNot(contains('message API')), reason: entry.key);
        for (final lang in ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw']) {
          trCurrentLanguage = lang;
          final t = AuditErrors.known(err(entry.key), scope: entry.value);
          expect(t, isNotNull);
          expect(t, isNot(fr), reason: '${entry.key} en $lang');
        }
      }
    });

    test('le contexte change le message du plafond et du compte récent', () {
      final cap = err('daily_cap_reached', status: 429);
      expect(AuditErrors.known(cap, scope: ErrorScope.withdrawal), contains('retrait'));
      expect(AuditErrors.known(cap, scope: ErrorScope.views), contains('encaissement'));
      final young = err('account_too_young');
      expect(AuditErrors.known(young, scope: ErrorScope.withdrawal), contains('retirer'));
      expect(AuditErrors.known(young, scope: ErrorScope.views), contains('gains de vues'));
    });

    test('un code inconnu garde le message de l\'API, l\'erreur réseau donne le message de connexion', () {
      expect(AuditErrors.message(err('autre_code', status: 409)), 'message API en français');
      expect(WalletApi.message(err('daily_cap_reached', status: 429), scope: ErrorScope.withdrawal), contains('24 heures'));
      final net = ApiException(status: 0, code: 'network', message: 'Pas de connexion.');
      expect(AuditErrors.message(net), contains('Connexion impossible'));
      expect(AuditErrors.message(StateError('x')), 'Une erreur est survenue. Réessaie.');
    });
  });

  group('Retraits : validation à deux et signaux de risque', () {
    final big = {
      'id': 'w1', 'user_id': 'u1', 'amount_xof': 150000, 'method': 'MTN', 'country_code': 'TG', 'account_number': '+22890000000',
      'status': 'pending', 'created_at': '2026-11-01T10:00:00+00:00',
      'needs_second_validation': true, 'validated_by': null,
      'meta': {'risk': ['new_account', 'recent_gains', 'second_validation_required'], 'currency': 'XOF'},
    };

    test('lecture de needs_second_validation, validated_by et meta.risk', () {
      final w = WithdrawalRow(big);
      expect(w.needsSecondValidation, isTrue);
      expect(w.validatedBy, isNull);
      expect(w.risk, ['new_account', 'recent_gains', 'second_validation_required']);
      final r = retraitFromApi(w);
      expect(r.needsSecondValidation, isTrue);
      expect(r.risk, hasLength(3));
      expect(r.isWaitingSecondApprover, isFalse);
      expect(r.statutText, contains('deux approbateurs'));
    });

    test('sans signal ni seuil : retrait ordinaire', () {
      final w = WithdrawalRow({'id': 'w2', 'amount_xof': 5000, 'status': 'pending', 'needs_second_validation': false, 'meta': null});
      expect(w.needsSecondValidation, isFalse);
      expect(w.risk, isEmpty);
      expect(retraitFromApi(w).statutText, 'En attente');
    });

    test('après la 1re validation : en attente d\'un second approbateur', () {
      final r = retraitFromApi(WithdrawalRow({...big, 'validated_by': 'staff1'}));
      expect(r.validatedBy, 'staff1');
      expect(r.isWaitingSecondApprover, isTrue);
      expect(r.statutText, contains('second approbateur'));
    });

    test('étapes : valider, attendre, payer', () {
      expect(withdrawalStep(needsSecondValidation: false, validatedBy: null, me: 'a'), WithdrawalStep.payable);
      expect(withdrawalStep(needsSecondValidation: true, validatedBy: null, me: 'a'), WithdrawalStep.needsFirstValidation);
      expect(withdrawalStep(needsSecondValidation: true, validatedBy: 'a', me: 'a'), WithdrawalStep.waitingSecondApprover);
      expect(withdrawalStep(needsSecondValidation: true, validatedBy: 'b', me: 'a'), WithdrawalStep.payable);
    });

    test('libellés des signaux de risque', () {
      expect(AuditErrors.riskLabel('new_account'), contains('30 jours'));
      expect(AuditErrors.riskLabel('recent_gains'), contains('24 h'));
      expect(AuditErrors.riskLabel('second_validation_required'), contains('deux personnes'));
      expect(AuditErrors.riskLabel('inconnu'), 'inconnu');
      trCurrentLanguage = 'en';
      expect(AuditErrors.riskLabel('new_account'), 'Account less than 30 days old');
    });
  });

  group('Confirme ton e-mail (composant unique)', () {
    testWidgets('e-mail confirmé : le jeton est rechargé puis l\'action est rejouée', (tester) async {
      final v = FakeVerifier(confirmed: true);
      EmailVerificationGate.verifier = v;
      var calls = 0;
      String? result;
      await tester.pumpWidget(host((context) async {
        result = await EmailVerificationGate.run<String>(context, () async {
          calls++;
          if (calls == 1) throw err('email_unverified');
          return 'ok';
        });
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme ton e-mail'), findsOneWidget);
      expect(find.textContaining('ama@example.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('email_gate_resend')));
      await tester.pumpAndSettle();
      expect(v.sent, 1);
      expect(find.textContaining('Lien envoyé'), findsOneWidget);

      await tester.tap(find.byKey(const Key('email_gate_confirmed')));
      await tester.pumpAndSettle();
      expect(v.checks, 1);
      expect(result, 'ok');
      expect(calls, 2);
      expect(find.text('Confirme ton e-mail'), findsNothing);
    });

    testWidgets('e-mail pas encore confirmé : la fenêtre reste ouverte avec une explication', (tester) async {
      final v = FakeVerifier(confirmed: false);
      EmailVerificationGate.verifier = v;
      var calls = 0;
      await tester.pumpWidget(host((context) async {
        try {
          await EmailVerificationGate.run<void>(context, () async {
            calls++;
            throw err('email_unverified');
          });
        } catch (_) {}
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('email_gate_confirmed')));
      await tester.pumpAndSettle();
      expect(find.text('Confirme ton e-mail'), findsOneWidget);
      expect(find.textContaining('pas encore confirmé'), findsOneWidget);
      expect(calls, 1);
    });

    testWidgets('« Plus tard » : l\'erreur d\'origine est relancée, l\'action n\'est pas rejouée', (tester) async {
      EmailVerificationGate.verifier = FakeVerifier();
      var calls = 0;
      Object? caught;
      await tester.pumpWidget(host((context) async {
        try {
          await EmailVerificationGate.run<void>(context, () async {
            calls++;
            throw err('email_unverified');
          });
        } catch (e) {
          caught = e;
        }
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(caught, isA<ApiException>().having((e) => e.code, 'code', 'email_unverified'));
    });

    testWidgets('une autre erreur n\'ouvre pas la fenêtre', (tester) async {
      var calls = 0;
      Object? caught;
      await tester.pumpWidget(host((context) async {
        try {
          await EmailVerificationGate.run<void>(context, () async {
            calls++;
            throw err('daily_cap_reached', status: 429);
          });
        } catch (e) {
          caught = e;
        }
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme ton e-mail'), findsNothing);
      expect(calls, 1);
      expect(caught, isA<ApiException>());
    });

    testWidgets('fenêtre traduite (anglais)', (tester) async {
      trCurrentLanguage = 'en';
      EmailVerificationGate.verifier = FakeVerifier();
      await tester.pumpWidget(host((context) async {
        await EmailVerificationGate.confirm(context);
      }));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.text('Resend the link'), findsOneWidget);
      expect(find.text('I have confirmed'), findsOneWidget);
    });
  });

  group('Dictionnaire tr_audit', () {
    test('chaque entrée est traduite dans les 7 langues et garde ses variables', () {
      final holes = <String>[];
      kTrAudit.forEach((fr, langs) {
        for (final lang in ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw']) {
          final t = langs[lang];
          if (t == null || t.trim().isEmpty) {
            holes.add('$lang : $fr');
            continue;
          }
          for (final v in RegExp(r'\{[a-z]\}').allMatches(fr).map((m) => m.group(0)!)) {
            if (!t.contains(v)) holes.add('$lang : variable $v perdue dans « $fr »');
          }
        }
      });
      expect(holes, isEmpty);
    });

    test('tous les textes tr(...) ajoutés par ces correctifs ont une traduction', () {
      const files = [
        'lib/services/api/audit_errors.dart',
        'lib/widgets/email_verification_gate.dart',
        'lib/pages/user/profile/retraitAdmin/retraitAdminDetails.dart',
        'lib/pages/defi/defi_ui.dart',
        'lib/pages/user/coin_conversion_page.dart',
        'lib/pages/user/mes_gains_post_page.dart',
        'lib/pages/admin/ads_regie_admin_page.dart',
        'lib/services/share/share_service.dart',
      ];
      // Anciens textes déjà traduits (ou volontairement laissés en français dans l'administration) : seuls les textes de l'audit sont contrôlés.
      final audit = kTrAudit.keys.toSet();
      final lit = RegExp(r'''\btr\(\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''');
      final missing = <String>[];
      for (final f in files) {
        final src = File(f).readAsStringSync();
        for (final m in lit.allMatches(src)) {
          var key = m.group(1) ?? m.group(2)!;
          key = key.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
          final translated = trFor('en', key) != key;
          if (!translated) missing.add('$f : $key');
        }
      }
      // Les textes de l'audit doivent tous être traduits ; les anciens de ces fichiers sont déjà dans d'autres dictionnaires.
      final auditMissing = missing.where((m) => audit.any((a) => m.endsWith(': $a'))).toList();
      expect(auditMissing, isEmpty);
      // Seules exceptions : libellés identiques dans toutes les langues (sigle RPM).
      missing.removeWhere((m) => m.endsWith(': {a} RPM') || m.endsWith(': {a}  (score ≥ {b})'));
      expect(missing, isEmpty, reason: missing.join('\n'));
    });
  });
}
