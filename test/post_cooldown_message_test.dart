import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/audit_errors.dart';
import 'package:afrotok/widgets/api_error_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Délai de 5 minutes entre deux publications : le message dit le temps RESTANT, et la bannière n'a pas de « Réessayer » (inutile avant la fin de l'attente).
ApiException cooldown({Map<String, dynamic> details = const {}}) => ApiException(status: 429, code: 'post_cooldown', message: 'message de l\'API', details: details);

void main() {
  test('le message dit combien de minutes il reste (arrondi au-dessus), « 1 minute » au singulier', () {
    expect(AuditErrors.known(cooldown(details: {'retry_after': 300, 'remaining_seconds': 290})), contains('encore 5 minutes'));
    expect(AuditErrors.known(cooldown(details: {'retry_after': 300, 'remaining_seconds': 61})), contains('encore 2 minutes'));
    expect(AuditErrors.known(cooldown(details: {'retry_after': 300, 'remaining_seconds': 40})), contains('encore 1 minute'));
    expect(AuditErrors.known(cooldown(details: {'retry_after': 300, 'remaining_seconds': 1})), isNot(contains('minutes')));
  });

  test('ancien serveur (sans temps restant) : le message de l\'API est gardé tel quel', () {
    expect(AuditErrors.known(cooldown()), isNull);
    expect(apiErrorText(cooldown()), 'message de l\'API');
  });

  testWidgets('délai de publication : bannière sans « Réessayer » ; autre erreur : « Réessayer » proposé', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    showApiError(ctx, cooldown(details: {'remaining_seconds': 120}), onRetry: () {});
    await tester.pump();
    expect(find.textContaining('encore 2 minutes'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);

    showApiError(ctx, ApiException(status: 500, code: 'http_500', message: 'Le serveur rencontre un problème.'), onRetry: () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
