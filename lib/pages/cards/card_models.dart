import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

/// Les styles de carte. Kente, Wax et Néon sont inclus ; les autres sont des styles « Pro » (réglage serveur
/// `AppConfig/cards.proStyles`, `bogolan` par défaut).
enum CardStyleId { kente, wax, neon, bogolan }

extension CardStyleIdX on CardStyleId {
  String get label => switch (this) {
        CardStyleId.kente => 'Kente',
        CardStyleId.wax => 'Wax',
        CardStyleId.neon => 'Néon Lagos',
        CardStyleId.bogolan => 'Bogolan',
      };
  String get subtitle => switch (this) {
        CardStyleId.kente => 'tissage royal, or et vert',
        CardStyleId.wax => 'motifs pop, couleurs vives',
        CardStyleId.neon => 'nuit électrique, vert Afrolook',
        CardStyleId.bogolan => 'terre et motifs peints',
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
    this.credit,
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

  /// Crédit affiché quand la carte reprend le post d'un autre auteur (« Post de @pseudo »).
  final String? credit;

  bool get hasMedia => images.isNotEmpty;
  String? get link => postId == null ? null : cardPostLink(postId!);

  CardSource copyWith({String? text, List<ImageProvider>? images}) => CardSource(
        pseudo: pseudo,
        avatar: avatar,
        verified: verified,
        text: text ?? this.text,
        images: images ?? this.images,
        isVideo: isVideo,
        postId: postId,
        date: date,
        likes: likes,
        comments: comments,
        credit: credit,
      );

  /// Brouillon : texte et images que l'utilisateur vient de saisir dans la page de création de post.
  static CardSource draft({
    required String pseudo,
    ImageProvider? avatar,
    bool verified = false,
    String text = '',
    List<Uint8List> imageBytes = const [],
  }) =>
      CardSource(
        pseudo: pseudo,
        avatar: avatar,
        verified: verified,
        text: text,
        images: [for (final b in imageBytes) MemoryImage(b)],
        date: DateTime.now(),
      );
}

/// Les réglages choisis dans le studio.
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
    this.showDate = true,
    this.showQr = true,
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
  bool showDate;
  bool showQr;

  static const maxImages = 4;
}
