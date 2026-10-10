import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/widgets.dart';

import '../../l10n/tr.dart' show trCurrentLanguage;

/// Les styles de carte. Kente, Wax, Néon, Glass et Pro sont inclus ; tous les autres sont des styles « Pro »
/// (réglage serveur `AppConfig/cards.proStyles`, voir [CardStyleIdX.defaultPro]).
enum CardStyleId {
  // Inclus et héritage
  kente, wax, neon, bogolan,
  // Moderne
  glass, pro, manga, anime, magazine, collector, sport, gamer, y2k, street,
  // Drapeaux
  flag, passport, stamp, supporter, duo, pride,
  // Idées
  film, newspaper, music, boarding, tarot, quote,
}

/// Les familles de styles, pour le sélecteur du studio.
enum CardPack { moderne, drapeaux, idees, heritage }

extension CardPackX on CardPack {
  String get label => switch (this) {
        CardPack.moderne => 'Moderne',
        CardPack.drapeaux => 'Drapeaux',
        CardPack.idees => 'Idées',
        CardPack.heritage => 'Héritage',
      };
  List<CardStyleId> get styles => CardStyleId.values.where((s) => s.pack == this).toList();
}

extension CardStyleIdX on CardStyleId {
  CardPack get pack => switch (this) {
        CardStyleId.kente || CardStyleId.wax || CardStyleId.bogolan => CardPack.heritage,
        CardStyleId.neon || CardStyleId.glass || CardStyleId.pro || CardStyleId.manga || CardStyleId.anime || CardStyleId.magazine || CardStyleId.collector ||
        CardStyleId.sport || CardStyleId.gamer || CardStyleId.y2k || CardStyleId.street =>
          CardPack.moderne,
        CardStyleId.flag || CardStyleId.passport || CardStyleId.stamp || CardStyleId.supporter || CardStyleId.duo || CardStyleId.pride => CardPack.drapeaux,
        _ => CardPack.idees,
      };

  /// Ces styles utilisent le drapeau d'un pays ; [duo] en utilise deux.
  bool get usesFlag => pack == CardPack.drapeaux;
  bool get usesSecondFlag => this == CardStyleId.duo;

  /// Styles gratuits (les autres sont « Pro » sauf réglage serveur contraire).
  static const freeStyles = {CardStyleId.kente, CardStyleId.wax, CardStyleId.neon, CardStyleId.glass, CardStyleId.pro};

  /// Liste Pro utilisée si le serveur n'en donne pas.
  static List<String> get defaultPro => [for (final s in CardStyleId.values) if (!freeStyles.contains(s)) s.name];

  String get label => switch (this) {
        CardStyleId.kente => 'Kente',
        CardStyleId.wax => 'Wax',
        CardStyleId.neon => 'Néon',
        CardStyleId.bogolan => 'Bogolan',
        CardStyleId.glass => 'Glass',
        CardStyleId.pro => 'Pro',
        CardStyleId.manga => 'Manga',
        CardStyleId.anime => 'Anime',
        CardStyleId.magazine => 'Magazine',
        CardStyleId.collector => 'Collector',
        CardStyleId.sport => 'Sport',
        CardStyleId.gamer => 'Gamer',
        CardStyleId.y2k => 'Y2K',
        CardStyleId.street => 'Street',
        CardStyleId.flag => 'Drapeau',
        CardStyleId.passport => 'Passeport',
        CardStyleId.stamp => 'Timbre',
        CardStyleId.supporter => 'Supporter',
        CardStyleId.duo => 'Duo',
        CardStyleId.pride => 'Fierté',
        CardStyleId.film => 'Film',
        CardStyleId.newspaper => 'Journal',
        CardStyleId.music => 'Musique',
        CardStyleId.boarding => 'Embarquement',
        CardStyleId.tarot => 'Tarot',
        CardStyleId.quote => 'Citation',
      };

  String get subtitle => switch (this) {
        CardStyleId.kente => 'tissage royal, or et vert',
        CardStyleId.wax => 'motifs pop, couleurs vives',
        CardStyleId.neon => 'cyber, grille lumineuse',
        CardStyleId.bogolan => 'terre et motifs peints',
        CardStyleId.glass => 'verre dépoli sur fond flou',
        CardStyleId.pro => 'sobre et professionnel',
        CardStyleId.manga => 'planche noir et blanc',
        CardStyleId.anime => 'ciel d\'anime au crépuscule',
        CardStyleId.magazine => 'couverture de magazine de mode',
        CardStyleId.collector => 'carte à collectionner holo',
        CardStyleId.sport => 'affiche de match',
        CardStyleId.gamer => 'interface de jeu',
        CardStyleId.y2k => 'fenêtre rétro des années 2000',
        CardStyleId.street => 'streetwear, polaroïd au scotch',
        CardStyleId.flag => 'le drapeau en plein fond',
        CardStyleId.passport => 'passeport citoyen du monde',
        CardStyleId.stamp => 'timbre-poste dentelé',
        CardStyleId.supporter => 'écharpe et écusson',
        CardStyleId.duo => 'deux pays, une carte',
        CardStyleId.pride => 'couronne de drapeaux',
        CardStyleId.film => 'affiche de cinéma',
        CardStyleId.newspaper => 'une de journal',
        CardStyleId.music => 'lecteur de musique',
        CardStyleId.boarding => 'carte d\'embarquement',
        CardStyleId.tarot => 'carte de tarot dorée',
        CardStyleId.quote => 'grosse citation sur dégradé',
      };
}

/// Les formats de carte. Le cadre média garde une forme fixe par format : toutes les cartes se ressemblent
/// et aucune image n'est jamais coupée (voir [CardFormatX.frameRatio]).
enum CardFormat { portrait, story, square }

extension CardFormatX on CardFormat {
  String get label => switch (this) {
        CardFormat.portrait => 'Portrait 4:5',
        CardFormat.story => 'Story 9:16',
        CardFormat.square => 'Carré 1:1',
      };

  /// Taille logique de la carte ; l'export multiplie par 3 pour obtenir 1080 px de large.
  Size get size => switch (this) {
        CardFormat.portrait => const Size(360, 450),
        CardFormat.story => const Size(360, 640),
        CardFormat.square => const Size(360, 360),
      };

  /// Forme (largeur / hauteur) du cadre média.
  double get frameRatio => switch (this) {
        CardFormat.portrait => 3 / 2,
        CardFormat.story => 4 / 5,
        CardFormat.square => 2 / 1,
      };
}

/// Disposition de plusieurs images dans le cadre.
enum CardLayout { mosaic, polaroid, film, single }

extension CardLayoutX on CardLayout {
  String get label => switch (this) {
        CardLayout.mosaic => 'Mosaïque',
        CardLayout.polaroid => 'Polaroïds',
        CardLayout.film => 'Bande',
        CardLayout.single => 'Une seule',
      };
}

/// Mode de découpe d'un texte trop long.
enum CardTextMode { start, pick }

/// Police du texte de la carte (par défaut celle du style).
enum CardFont { auto, serif, round, tech, slab }

extension CardFontX on CardFont {
  String get label => switch (this) {
        CardFont.auto => 'Du style',
        CardFont.serif => 'Serif',
        CardFont.round => 'Rond',
        CardFont.tech => 'Tech',
        CardFont.slab => 'Slab',
      };
  String? get family => switch (this) {
        CardFont.auto => null,
        CardFont.serif => 'CrimsonText',
        CardFont.round => 'Righteous',
        CardFont.tech => 'Audiowide',
        CardFont.slab => 'Arvo',
      };
  FontWeight get weight => switch (this) {
        CardFont.serif => FontWeight.w600,
        CardFont.slab => FontWeight.w700,
        _ => FontWeight.w400,
      };
}

/// Lien de partage d'un post (même adresse que `AppLinkService.generateLink`).
String cardPostLink(String postId) => 'https://afrolookmedia.com/share/post/$postId';

/// Lien de partage d'un profil (ouvre la page de la personne dans l'application, ou la page web si elle n'est pas installée).
String cardProfileLink(String userId) => 'https://afrolookmedia.com/share/creator/$userId';

/// Ce que la carte raconte : l'auteur, le texte d'origine et les médias du post (ou d'un brouillon).
class CardSource {
  const CardSource({
    required this.pseudo,
    this.avatar,
    this.verified = false,
    this.text = '',
    this.images = const [],
    this.isVideo = false,
    this.postId,
    this.date,
    this.likes = 0,
    this.comments = 0,
    this.followers = 0,
    this.profileId,
    this.country,
    this.credit,
    this.externalLink,
  });

  final String pseudo;
  final ImageProvider? avatar;
  final bool verified;

  /// Texte d'origine complet (la découpe pour la carte se fait dans le studio).
  final String text;

  /// Médias du post (images, ou image de couverture d'une vidéo). Jusqu'à 4 sont retenus dans la carte.
  final List<ImageProvider> images;
  final bool isVideo;
  final String? postId;
  final DateTime? date;
  final int likes;
  final int comments;

  /// Abonnés de l'auteur (statistique facultative de la carte).
  final int followers;

  /// Auteur du post, ou créateur de la carte pour un brouillon : le QR mène à son profil quand il n'y a pas de post.
  final String? profileId;

  /// Pays de l'auteur (code ISO à 2 lettres), pour les styles « drapeau ».
  final String? country;

  /// Crédit affiché quand la carte reprend le post d'un autre auteur (« Post de @pseudo »).
  final String? credit;

  /// Carte « lien » : adresse de la vidéo ou de la page d'origine (YouTube, TikTok, Instagram…). Le QR et le partage mènent là.
  final String? externalLink;

  bool get hasMedia => images.isNotEmpty;
  /// Lien du QR (obligatoire sur toute carte) : le post d'origine, sinon le profil de la personne, sinon l'accueil.
  String get link => (externalLink ?? '').isNotEmpty
      ? externalLink!
      : postId != null
      ? cardPostLink(postId!)
      : (profileId ?? '').isNotEmpty
          ? cardProfileLink(profileId!)
          : 'https://afrolookmedia.com';

  CardSource copyWith({String? text, List<ImageProvider>? images, bool? isVideo, String? externalLink, String? credit}) => CardSource(
        pseudo: pseudo,
        avatar: avatar,
        verified: verified,
        text: text ?? this.text,
        images: images ?? this.images,
        isVideo: isVideo ?? this.isVideo,
        postId: postId,
        date: date,
        likes: likes,
        comments: comments,
        followers: followers,
        profileId: profileId,
        country: country,
        credit: credit ?? this.credit,
        externalLink: externalLink ?? this.externalLink,
      );

  /// Brouillon : texte et images que l'utilisateur vient de saisir dans la page de création de post.
  static CardSource draft({
    required String pseudo,
    ImageProvider? avatar,
    bool verified = false,
    String text = '',
    List<Uint8List> imageBytes = const [],
    int followers = 0,
    String? profileId,
    String? country,
  }) =>
      CardSource(
        pseudo: pseudo,
        avatar: avatar,
        verified: verified,
        text: text,
        images: [for (final b in imageBytes) MemoryImage(b)],
        date: DateTime.now(),
        followers: followers,
        profileId: profileId,
        country: country,
      );
}

/// Chiffre court des statistiques : 950 → « 950 », 1400 → « 1,4k », 12 500 → « 12,5k », 2 300 000 → « 2,3M ».
/// La virgule décimale suit la langue (français, espagnol, allemand, portugais) ; le point sinon.
String compactCount(int n, {String? lang}) {
  final comma = const {'fr', 'es', 'de', 'pt'}.contains(lang ?? trCurrentLanguage);
  String fmt(double v) {
    final t = v.toStringAsFixed(1);
    final s = t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
    return comma ? s.replaceAll('.', ',') : s;
  }

  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = (n / 100).floor() / 10; // une décimale, arrondie vers le bas : 1999 → 1,9k
    if (k < 1000) return '${fmt(k)}k';
  }
  final m = (n / 100000).floor() / 10;
  return '${fmt(m)}M';
}

/// Modèles de carte : un formulaire à remplir (événement, promo, annonce, citation) au lieu d'un texte libre.
/// La carte garde le style choisi (couleurs, fond, police) ; la mise en page est celle d'une affiche.
enum CardTemplateId { event, promo, ad, quote }

/// Un champ d'un modèle : [key] est la clé stockée dans [CardSpec.fields] ; [example] pré-remplit le champ.
class TemplateField {
  const TemplateField(this.key, this.label, this.example, this.icon, {this.max = 60, this.lines = 1, this.main = false});
  final String key;
  final String label;
  final String example;
  final IconData icon;
  final int max;
  final int lines;

  /// Champ principal (titre, citation) : mis en grand sur la carte.
  final bool main;
}

extension CardTemplateX on CardTemplateId {
  String get label => switch (this) {
        CardTemplateId.event => 'Événement',
        CardTemplateId.promo => 'Promo',
        CardTemplateId.ad => 'Annonce',
        CardTemplateId.quote => 'Citation',
      };

  IconData get icon => switch (this) {
        CardTemplateId.event => Icons.celebration_rounded,
        CardTemplateId.promo => Icons.local_offer_rounded,
        CardTemplateId.ad => Icons.campaign_rounded,
        CardTemplateId.quote => Icons.format_quote_rounded,
      };

  /// Champs du modèle, dans l'ordre d'affichage. Le premier est le champ principal.
  List<TemplateField> get fields => switch (this) {
        CardTemplateId.event => const [
            TemplateField('title', 'Titre', 'Soirée Afrobeats', Icons.title_rounded, main: true),
            TemplateField('date', 'Date et heure', 'Samedi 25 oct. · 20h', Icons.event_rounded),
            TemplateField('place', 'Lieu', 'Abidjan, Cocody', Icons.place_rounded),
            TemplateField('price', 'Prix ou entrée', 'Entrée 5 000 FCFA', Icons.payments_rounded),
            TemplateField('contact', 'Contact', '+225 07 00 00 00 00', Icons.phone_rounded),
          ],
        CardTemplateId.promo => const [
            TemplateField('title', 'Titre', 'Grande vente de la rentrée', Icons.title_rounded, main: true),
            TemplateField('offer', 'Offre', '-30 %', Icons.local_offer_rounded, max: 24),
            TemplateField('date', 'Valable jusqu\'au', 'Jusqu\'au 31 oct.', Icons.event_rounded),
            TemplateField('place', 'Lieu', 'Boutique Afro Style, Dakar', Icons.place_rounded),
            TemplateField('contact', 'Contact', '+221 77 000 00 00', Icons.phone_rounded),
          ],
        CardTemplateId.ad => const [
            TemplateField('title', 'Titre', 'Appartement à louer', Icons.title_rounded, main: true),
            TemplateField('price', 'Prix', '150 000 FCFA / mois', Icons.payments_rounded),
            TemplateField('place', 'Lieu', 'Douala, Bonamoussadi', Icons.place_rounded),
            TemplateField('details', 'Détails', '2 chambres, salon, cuisine, eau et courant.', Icons.notes_rounded, max: 140, lines: 3),
            TemplateField('contact', 'Contact', '+237 6 00 00 00 00', Icons.phone_rounded),
          ],
        CardTemplateId.quote => const [
            TemplateField('quote', 'Citation', 'Seul, on va vite. Ensemble, on va loin.', Icons.format_quote_rounded, max: 180, lines: 3, main: true),
            TemplateField('author', 'Auteur', 'Proverbe africain', Icons.person_rounded, max: 50),
          ],
      };

  /// Le champ « lien » facultatif (le QR code l'ouvre) est commun à tous les modèles sauf la citation.
  bool get hasLink => this != CardTemplateId.quote;
}

/// Les réglages choisis dans le studio.
/// Cadrage d'une image sur la carte : zoom (1 = l'image entière) et décalage en fraction de la taille du cadre.
class ImageAdjust {
  const ImageAdjust({this.zoom = 1, this.dx = 0, this.dy = 0});
  final double zoom;
  final double dx;
  final double dy;

  static const minZoom = 0.5;
  static const maxZoom = 6.0;

  bool get isDefault => zoom == 1 && dx == 0 && dy == 0;

  /// Garde l'image dans des limites raisonnables : le zoom reste entre 0,5 et 6, et l'image ne sort pas du cadre.
  ImageAdjust clamped() {
    final z = zoom.clamp(minZoom, maxZoom).toDouble();
    final lim = (z <= 1 ? 0.0 : (z - 1) / 2) + 0.35;
    return ImageAdjust(zoom: z, dx: dx.clamp(-lim, lim).toDouble(), dy: dy.clamp(-lim, lim).toDouble());
  }

  ImageAdjust copyWith({double? zoom, double? dx, double? dy}) => ImageAdjust(zoom: zoom ?? this.zoom, dx: dx ?? this.dx, dy: dy ?? this.dy);
}

class CardSpec {
  CardSpec({
    this.style = CardStyleId.neon,
    this.format = CardFormat.portrait,
    this.layout = CardLayout.mosaic,
    List<int>? imageOrder,
    this.textMode = CardTextMode.start,
    Set<int>? pickedSentences,
    this.font = CardFont.auto,
    this.showAuthor = true,
    this.showStats = true,
    this.showFollowers = false,
    this.showDate = true,
    this.country,
    this.country2,
    this.likesText,
    this.commentsText,
    this.followersText,
    this.template,
  })  : imageOrder = imageOrder ?? <int>[],
        pickedSentences = pickedSentences ?? <int>{};

  CardStyleId style;
  CardFormat format;
  CardLayout layout;

  /// Indices (dans [CardSource.images]) des images retenues, dans l'ordre choisi. 4 au plus.
  List<int> imageOrder;
  CardTextMode textMode;

  /// Phrases choisies en mode [CardTextMode.pick] (indices dans la liste des phrases du texte).
  Set<int> pickedSentences;
  CardFont font;
  bool showAuthor;
  bool showStats;

  /// Nombre d'abonnés de l'auteur (facultatif, désactivé par défaut).
  bool showFollowers;
  bool showDate;

  /// Pays des styles « drapeau » (code ISO à 2 lettres) ; null : pays de l'auteur. [country2] sert au style Duo.
  String? country;
  String? country2;

  /// Chiffres écrits à la main (« 1,2 M ») qui remplacent les vrais ; null ou vide : le chiffre réel du post.
  String? likesText;
  String? commentsText;
  String? followersText;

  /// Cadrage de chaque image (clé : indice dans [CardSource.images]) ; absent = image entière, centrée.
  final Map<int, ImageAdjust> adjusts = {};

  /// Modèle de carte choisi (null : texte libre) et valeurs de ses champs.
  CardTemplateId? template;
  final Map<String, String> fields = {};

  String field(String key) => (fields[key] ?? '').trim();

  /// Lien du QR code : le lien du modèle s'il est valide, sinon celui de la source (post, profil, vidéo d'origine…).
  String linkFor(CardSource source) {
    if (template != null && template!.hasLink) {
      var l = field('link');
      if (l.isNotEmpty) {
        if (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(l)) l = 'https://$l';
        final u = Uri.tryParse(l);
        if (u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.contains('.')) return l;
      }
    }
    return source.link;
  }

  /// Résumé en une ligne par champ (légende de la publication quand la carte vient d'un modèle).
  String templateSummary() {
    if (template == null) return '';
    final parts = <String>[for (final f in template!.fields) if (field(f.key).isNotEmpty) field(f.key)];
    return parts.join(' · ');
  }

  static String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
  /// Chiffre écrit à la main : un nombre entier (« 1400 », « 1 400 ») devient « 1,4k » ; un texte (« 12k », « 1,2 M ») reste tel quel.
  static String? _count(String? v) {
    final c = _clean(v);
    if (c == null) return null;
    final digits = c.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
    if (RegExp(r'^\d{1,12}$').hasMatch(digits)) return compactCount(int.parse(digits));
    return c;
  }

  String? get likesOverride => _count(likesText);
  String? get commentsOverride => _count(commentsText);
  String? get followersOverride => _count(followersText);

  static const maxImages = 4;
}
