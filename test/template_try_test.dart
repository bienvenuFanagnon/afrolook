import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/cards/card_models.dart';
import 'package:afrotok/services/template_link.dart';
import 'package:afrotok/widgets/studio/post_template_try.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('référence de template', () {
    test('template du Studio', () {
      final r = TemplateRef.parse('m:noel')!;
      expect(r.isMontage, isTrue);
      expect(r.code, 'm:noel');
      expect(r.label, isNotEmpty);
    });

    test('carte : style seul, et style avec modèle', () {
      expect(TemplateRef.parse('c:music')!.label, 'Carte Musique');
      final r = TemplateRef.parse('c:neon:birthday')!;
      expect(r.cardStyle, CardStyleId.neon);
      expect(r.cardTemplate, CardTemplateId.birthday);
      expect(r.label, 'Anniversaire · Néon');
      expect(TemplateRef.fromCard(CardStyleId.wax, null).code, 'c:wax');
      expect(TemplateRef.fromCard(CardStyleId.wax, CardTemplateId.promo).code, 'c:wax:promo');
    });

    test('références invalides ou inconnues : pas de bouton', () {
      for (final bad in [null, '', 'm:', 'm:nimportequoi', 'c:inconnu', 'c:neon:inconnu', 'x:noel', 'm:noel:extra', 'c:a:b:c']) {
        expect(TemplateRef.parse(bad), isNull, reason: '$bad');
      }
    });

    test('résultat du Studio : montage_x → m:x ; pas pour « Ma vidéo avec ce son »', () {
      expect(TemplateRef.fromStudioId('montage_noel')?.code, 'm:noel');
      expect(TemplateRef.fromStudioId('montage_plain'), isNull);
      expect(TemplateRef.fromStudioId('autre'), isNull);
      expect(TemplateRef.fromStudioId(null), isNull);
    });
  });

  group('lien post → template', () {
    tearDown(PostTemplateLink.clear);

    test('champs du post seulement quand un template est choisi', () {
      expect(PostTemplateLink.fields(), isEmpty);
      PostTemplateLink.set('m:noel');
      expect(PostTemplateLink.fields(), {'studioTemplate': 'm:noel'});
      PostTemplateLink.set(null);
      expect(PostTemplateLink.fields(), isEmpty);
    });

    test('le modèle de post lit studioTemplate et templateTries', () {
      final p = Post.fromJson({'studioTemplate': 'm:noel', 'templateTries': 12});
      expect(p.studioTemplate, 'm:noel');
      expect(p.templateTries, 12);
      expect(Post.fromJson({}).studioTemplate, isNull);
    });
  });

  group('bouton « Essayer ce template »', () {
    Future<void> show(WidgetTester t, TemplateRef r, {int tries = 0, VoidCallback? onTap}) async {
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Localizations.override(context: ctx, locale: const Locale('fr'), child: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: TemplateTryPill(ref: r, tries: tries, onTap: onTap ?? () {})))))));
    }

    testWidgets('template du Studio', (t) async {
      var taps = 0;
      await show(t, TemplateRef.parse('m:noel')!, tries: 3, onTap: () => taps++);
      expect(find.textContaining('Essayer ce template', findRichText: true), findsOneWidget);
      expect(find.textContaining('3 essais', findRichText: true), findsOneWidget);
      await t.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('carte : « modèle », un seul essai au singulier, aucun compteur à zéro', (t) async {
      await show(t, TemplateRef.parse('c:neon:birthday')!, tries: 1);
      expect(find.textContaining('Essayer ce modèle', findRichText: true), findsOneWidget);
      expect(find.textContaining('1 essai', findRichText: true), findsOneWidget);
      expect(find.textContaining('1 essais', findRichText: true), findsNothing);
      await show(t, TemplateRef.parse('c:neon')!);
      expect(find.textContaining('essai', findRichText: true), findsNothing);
    });

    testWidgets('sans template ou référence inconnue : rien du tout', (t) async {
      final p = Post()..studioTemplate = 'm:nimportequoi';
      await t.pumpWidget(MaterialApp(home: Scaffold(body: PostTemplateTry(post: p))));
      expect(find.byType(TemplateTryPill), findsNothing);
    });

    testWidgets('PostCtaRow : rien sans son ni template ; la pastille apparaît avec un template (clair et sombre)', (t) async {
      Future<void> show(Post p, {bool dark = false}) => t.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: PostCtaRow(post: p, dark: dark)))));
      await show(Post());
      expect(find.byType(TemplateTryPill), findsNothing);
      await show(Post()..studioTemplate = 'm:noel');
      expect(find.byType(TemplateTryPill), findsOneWidget);
      await show(Post()..studioTemplate = 'm:noel', dark: true); // posé sans largeur imposée sur la vidéo : pas d'erreur de mise en page
      expect(find.byType(TemplateTryPill), findsOneWidget);
      expect(t.takeException(), isNull);
      await show(Post()..studioTemplate = 'm:noel'..isAdvertisement = true);
      expect(find.byType(TemplateTryPill), findsNothing);
    });
  });
}
