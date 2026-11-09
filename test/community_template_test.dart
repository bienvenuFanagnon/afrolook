import 'package:afrotok/models/community_template.dart';
import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_gallery_page.dart';
import 'package:afrotok/services/template_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '01k9abcdefghjkmnpqrstvwxyz';

CommunityTemplate _tpl({int price = 20, bool mine = false, Map<String, dynamic>? recipe, String id = _id}) => CommunityTemplate(
      id: id,
      name: 'Mon grand jour',
      category: 'fetes',
      priceCoins: price,
      mine: mine,
      ownerId: 'u1',
      ownerName: 'aicha',
      recipe: recipe ??
          {
            'v': 1,
            'base': 'm:anniv',
            'texts': {'title': 'Mon grand jour', 'lines': ['Venez nombreux !']},
            'widgets': [
              {'type': 'countdown', 'config': {'title': 'Mon anniversaire', 'in_days': 14, 'hour': 18}, 'x': .5, 'y': .3},
              {'type': 'place', 'config': {'name': 'Chez moi', 'maps_url': ''}},
            ],
            'music': 'highlife',
            'slots': [{'kind': 'image', 'label': 'Ta photo'}],
            'layout': 'single',
          },
    );

/// Modèles prêts à poster créés par les utilisateurs (09/11/2026) : recette, modèle du Studio, paiement à la publication.
void main() {
  tearDown(() {
    PostTemplateLink.clear();
    CommunityTemplate.known.clear();
  });

  test('une recette devient un modèle du Studio : base du catalogue, textes, musique de la recette, widgets avec une échéance à venir', () {
    final t = _tpl();
    final tp = t.toMontage()!;
    expect(tp.id, 'u_$_id');
    expect(tp.name, 'Mon grand jour');
    expect(tp.title, 'Mon grand jour');
    expect(tp.texts, ['Venez nombreux !']);
    expect(tp.music, 'highlife');   // la musique de la recette, pas celle du catalogue
    final widgets = tp.presetWidgets!();
    final cd = widgets.firstWhere((w) => w.kind == WidgetKind.countdown);
    expect(DateTime.parse('${cd.config['at']}').isAfter(DateTime.now().add(const Duration(days: 12))), isTrue);
    expect(cd.config.containsKey('in_days'), isFalse);   // l'échéance est une vraie date, plus un nombre de jours
    expect(widgets.any((w) => w.kind == WidgetKind.place), isTrue);
    expect(CommunityTemplate.known['u:$_id'], same(t));   // retrouvé à la publication (prix, créateur)
  });

  test('sans musique dans la recette : aucune musique ; un modèle de base inconnu : indisponible', () {
    final none = _tpl(recipe: {'v': 1, 'base': 'm:anniv', 'texts': {}, 'widgets': [], 'music': null, 'slots': [], 'layout': 'single'});
    expect(none.toMontage()!.music, isNull);
    expect(_tpl(recipe: {'v': 1, 'base': 'm:modele_qui_nexiste_pas'}).toMontage(), isNull);
  });

  test('gratuit : prix à 0 ou son propre modèle ; payant sinon', () {
    expect(_tpl(price: 0).isFree, isTrue);
    expect(_tpl(price: 30, mine: true).isFree, isTrue);
    expect(_tpl(price: 30).isFree, isFalse);
  });

  test('la référence « u:{id} » est valide, retrouve le nom connu, et un résultat du Studio « montage_u_{id} » la reconstitue', () {
    final ref = TemplateRef.parse('u:$_id')!;
    expect(ref.isCommunity, isTrue);
    expect(ref.code, 'u:$_id');
    expect(ref.label, '');   // pas encore connu
    _tpl().toMontage();
    expect(TemplateRef.parse('u:$_id')!.label, 'Mon grand jour');
    expect(TemplateRef.fromStudioId('montage_u_$_id')!.code, 'u:$_id');
    expect(TemplateRef.parse('u:trop-court'), isNull);
    expect(TemplateRef.parse('u:${_id.toUpperCase()}'), isNull);
  });

  test('paiement à la publication : seulement un modèle payant d\'une autre personne reçoit un identifiant de montage', () {
    final paid = _tpl(price: 20)..toMontage();
    PostTemplateLink.set('u:$_id');
    expect(PostTemplateLink.jobIdFor('u:$_id'), isNotNull);
    expect(PostTemplateLink.jobIdFor('u:$_id')!.length, inInclusiveRange(8, 40));   // accepté par le serveur
    expect(RegExp(r'^[A-Za-z0-9_-]{8,40}$').hasMatch(PostTemplateLink.jobIdFor('u:$_id')!), isTrue);
    expect(PostTemplateLink.jobIdFor('m:noel'), isNull);   // un autre modèle : rien
    PostTemplateLink.clear();
    expect(PostTemplateLink.jobIdFor('u:$_id'), isNull);
    // gratuit : jamais d'identifiant
    CommunityTemplate.known.clear();
    _tpl(price: 0)..toMontage();
    PostTemplateLink.set('u:$_id');
    expect(PostTemplateLink.jobIdFor('u:$_id'), isNull);
    expect(paid.isFree, isFalse);
  });

  test('une recette depuis l\'éditeur : widgets sans donnée personnelle seulement, échéance en « dans N jours », 5 au plus', () {
    final at = DateTime.now().add(const Duration(days: 10, hours: 3)).toUtc().toIso8601String();
    final r = CommunityTemplate.buildRecipe(
      baseId: 'anniv',
      kick: ' Bientôt ',
      title: 'Mon titre',
      lines: const ['Une ligne'],
      musicId: 'highlife',
      widgets: [
        PostWidget(kind: WidgetKind.countdown, config: {'title': 'Fête', 'at': at}, x: .4, y: .2),
        PostWidget(kind: WidgetKind.whatsapp, config: {'phone': '+22890000000', 'label': 'Écrire'}),   // numéro personnel : jamais dans un modèle
        PostWidget(kind: WidgetKind.link, config: {'label': 'Lien', 'url': 'https://exemple.com'}),
        PostWidget(kind: WidgetKind.place, config: {'name': 'Chez moi', 'maps_url': 'https://maps.example/x'}),
        PostWidget(kind: WidgetKind.question, config: {'question': 'Ça va ?'}),
      ],
      face: const TemplateFace(avatar: 'dragon', magic: 'Feu', gesture: 'mouth'),
    );
    expect(r['v'], 1);
    expect(r['base'], 'm:anniv');
    expect((r['texts'] as Map)['kick'], 'Bientôt');
    expect(r['music'], 'highlife');
    final widgets = (r['widgets'] as List).cast<Map>();
    expect(widgets.map((w) => w['type']).toList(), ['countdown', 'place', 'question']);   // ni WhatsApp ni lien
    final cd = (widgets.first['config'] as Map);
    expect(cd['in_days'], inInclusiveRange(9, 10));
    expect(cd.containsKey('at'), isFalse);
    expect(((widgets[1]['config']) as Map)['maps_url'], '');   // adresse personnelle retirée
    expect((r['face'] as Map)['avatar'], 'dragon');
    expect(r['layout'], 'single');
    expect(((r['slots']) as List).length, 1);
  });

  test('« Dragon qui crache le feu » : modèle à filtres de visage, absent des listes sans le moteur (tout sauf Android), avec sa musique', () {
    final dragon = kMontageTemplates.firstWhere((t) => t.id == 'dragon_feu');
    expect(dragon.face!.avatar, 'dragon');
    expect(dragon.face!.magic, 'Feu');
    expect(dragon.face!.gesture, 'mouth');
    expect(dragon.music, isNotNull);
    // le test tourne hors Android : le moteur de visage est indisponible, le modèle n'est donc pas proposé
    expect(popularMontageTemplates().any((t) => t.id == 'dragon_feu'), isFalse);
  });

  test('« l\'année qui arrive » : le modèle Nouvel An annonce la bonne année (année suivante dès septembre, année en cours avant)', () {
    final now = DateTime.now();
    final expected = now.month >= 9 ? now.year + 1 : now.year;
    final nouvelAn = kMontageTemplates.firstWhere((t) => t.id == 'nouvelan');
    expect(nouvelAn.title, contains('$expected'));
  });
}
