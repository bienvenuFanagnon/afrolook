/// Catégories de compte officiel.
/// Ajouter une entrée ici suffit pour supporter une nouvelle catégorie.
enum OfficialAccountCategory {
  influencer('Influenceur / Créateur de contenu', '🎬', true),
  media('Média d\'information', '📰', false),
  journalist('Journaliste', '🖊️', false),
  stateInstitution('Institution de l\'État', '🏛️', false),
  company('Entreprise / Marque', '🏢', false),
  ngo('ONG', '🌍', false),
  association('Association', '🤝', false),
  artist('Artiste', '🎨', true),
  publicFigure('Personnalité publique', '⭐', false),
  entrepreneur('Entrepreneur', '💼', true),
  other('Autre', '📋', false);

  const OfficialAccountCategory(this.label, this.emoji, this.requiresIdVerification);

  /// Libellé affiché à l'utilisateur.
  final String label;

  /// Emoji représentant la catégorie.
  final String emoji;

  /// Si true → le formulaire demande date de naissance + pièce d'identité
  /// et vérifie que le demandeur a ≥ 18 ans.
  final bool requiresIdVerification;

  /// true si cette catégorie peut bénéficier de la monétisation,
  /// des commissions cadeaux et du programme parrainage.
  bool get canMonetize => const {
    OfficialAccountCategory.influencer,
    OfficialAccountCategory.artist,
    OfficialAccountCategory.entrepreneur,
  }.contains(this);

  /// Badge couleur : orange = personnel, bleu = institutionnel
  bool get isPersonal => const {
    OfficialAccountCategory.influencer,
    OfficialAccountCategory.artist,
    OfficialAccountCategory.entrepreneur,
    OfficialAccountCategory.publicFigure,
    OfficialAccountCategory.journalist,
  }.contains(this);

  String get id => name; // clé stockée en Firestore

  static OfficialAccountCategory fromId(String id) =>
      OfficialAccountCategory.values.firstWhere(
        (c) => c.id == id,
        orElse: () => OfficialAccountCategory.other,
      );
}

/// Statuts du cycle de vie d'une demande.
enum OfficialAccountStatus {
  pending('En attente', 0xFFFF9800),
  underReview('En cours d\'analyse', 0xFF2196F3),
  moreInfoNeeded('Informations complémentaires demandées', 0xFF9C27B0),
  approved('Acceptée', 0xFF4CAF50),
  rejected('Refusée', 0xFFF44336),
  suspended('Suspendue', 0xFF607D8B);

  const OfficialAccountStatus(this.label, this.color);

  final String label;
  final int color; // ARGB stocké comme int pour éviter l'import Flutter

  String get id => name;

  static OfficialAccountStatus fromId(String id) =>
      OfficialAccountStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => OfficialAccountStatus.pending,
      );
}

/// Réseaux sociaux supportés.
enum SocialNetworkType {
  facebook('Facebook', 'assets/icons/facebook.png'),
  instagram('Instagram', 'assets/icons/instagram.png'),
  tiktok('TikTok', 'assets/icons/tiktok.png'),
  youtube('YouTube', 'assets/icons/youtube.png'),
  linkedin('LinkedIn', 'assets/icons/linkedin.png'),
  twitter('X (Twitter)', 'assets/icons/twitter.png'),
  snapchat('Snapchat', 'assets/icons/snapchat.png'),
  threads('Threads', 'assets/icons/threads.png'),
  telegram('Telegram', 'assets/icons/telegram.png'),
  whatsappChannel('WhatsApp Channel', 'assets/icons/whatsapp.png'),
  other('Autre', '');

  const SocialNetworkType(this.label, this.iconAsset);

  final String label;
  final String iconAsset;

  String get id => name;

  static SocialNetworkType fromId(String id) =>
      SocialNetworkType.values.firstWhere(
        (s) => s.id == id,
        orElse: () => SocialNetworkType.other,
      );
}

/// Domaines de diffusion — personnalise les recommandations et le profil public.
/// Ajouter un domaine ici suffit pour le rendre disponible dans le formulaire.
enum BroadcastDomain {
  news('Actualités'),
  politics('Politique'),
  economy('Économie'),
  business('Business'),
  entrepreneurship('Entrepreneuriat'),
  sport('Sport'),
  culture('Culture'),
  music('Musique'),
  cinema('Cinéma'),
  humor('Humour'),
  education('Éducation'),
  health('Santé'),
  agriculture('Agriculture'),
  technology('Technologie'),
  ai('Intelligence artificielle'),
  environment('Environnement'),
  religion('Religion'),
  fashion('Mode'),
  lifestyle('Lifestyle'),
  gaming('Jeux vidéo'),
  cooking('Cuisine'),
  science('Science'),
  other('Autres');

  const BroadcastDomain(this.label);

  final String label;
  String get id => name;

  static BroadcastDomain fromId(String id) =>
      BroadcastDomain.values.firstWhere(
        (d) => d.id == id,
        orElse: () => BroadcastDomain.other,
      );
}

/// Type de pièce d'identité (influenceurs).
enum IdDocumentType {
  nationalId('Carte nationale d\'identité'),
  passport('Passeport'),
  driverLicense('Permis de conduire'),
  residencePermit('Titre de séjour');

  const IdDocumentType(this.label);
  final String label;
  String get id => name;

  static IdDocumentType fromId(String id) =>
      IdDocumentType.values.firstWhere(
        (d) => d.id == id,
        orElse: () => IdDocumentType.nationalId,
      );
}
