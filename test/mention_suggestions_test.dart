import 'package:afrotok/widgets/mention_suggestions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mentions @pseudo (15/11/2026) : suggestions pendant la frappe, remplacement, couleur et toucher du pseudo.
void main() {
  test('détection : mêmes règles que le serveur (adresse e-mail ignorée, point final retiré, 3 caractères minimum)', () {
    final names = [for (final m in kMentionRegex.allMatches('salut @Ana_01, @bob.ok. et mail a@b.com @@x @ab')) mentionName(m)];
    expect(names, ['Ana_01', 'bob.ok']);
  });

  testWidgets('taper « @am » propose des personnes ; en toucher une remplace « @am » par « @pseudo »', (t) async {
    final c = TextEditingController();
    final asked = <String>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          MentionSuggestions(controller: c, search: (q) async {
            asked.add(q);
            return [
              {'id': '1', 'username': 'amadou', 'display_name': 'Amadou K.', 'is_following': true},
              {'id': '2', 'username': 'amy', 'display_name': ''},
            ];
          }),
          TextField(controller: c),
        ]),
      ),
    ));
    c.value = const TextEditingValue(text: 'Bravo @am', selection: TextSelection.collapsed(offset: 9));
    await t.pump(const Duration(milliseconds: 300));   // délai avant la recherche
    await t.pump();
    expect(asked, ['am']);
    expect(find.text('@amadou'), findsOneWidget);
    expect(find.text('Amadou K.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mention_pick_amadou')));
    await t.pump();
    expect(c.text, 'Bravo @amadou ');
    expect(c.selection.baseOffset, 'Bravo @amadou '.length);
    expect(find.byKey(const ValueKey('mention_suggestions')), findsNothing);

    // hors d'une mention (après un espace) : rien n'est proposé
    c.value = const TextEditingValue(text: 'Bravo @amadou et', selection: TextSelection.collapsed(offset: 16));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('mention_suggestions')), findsNothing);
  });

  testWidgets('texte avec mentions : pseudo en couleur, le toucher ouvre son profil', (t) async {
    String? opened;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MentionText('Merci @ama.k. et @zed !', style: const TextStyle(color: Colors.black), mentionColor: Colors.green, onMention: (n) => opened = n),
      ),
    ));
    final rich = t.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final mentions = [for (final s in rich.children!) if (s is TextSpan && (s.text ?? '').startsWith('@')) s];
    expect(mentions.map((s) => s.text), ['@ama.k', '@zed']);   // le point final reste du texte normal
    (mentions.first.recognizer! as TapGestureRecognizer).onTap!();
    expect(opened, 'ama.k');
  });
}
