import 'official_account_enums.dart';

/// "Afrolook Médias CI" → "afrolook_médias_ci"
String officialNameToSlug(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

/// "Afrolook Médias CI" → ["afrolook", "médias", "ci"]
List<String> officialNameToKeywords(String name) => name
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Entrée dans l'historique des actions admin.
class OfficialAccountAction {
  final String action; // libellé de l'action
  final String? note;
  final String adminId;
  final int timestamp;

  const OfficialAccountAction({
    required this.action,
    this.note,
    required this.adminId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'action': action,
        'note': note,
        'adminId': adminId,
        'timestamp': timestamp,
      };

  factory OfficialAccountAction.fromMap(Map<String, dynamic> m) =>
      OfficialAccountAction(
        action: m['action'] as String? ?? '',
        note: m['note'] as String?,
        adminId: m['adminId'] as String? ?? '',
        timestamp: m['timestamp'] as int? ?? 0,
      );
}

/// Réseau social soumis par le demandeur.
class SocialNetworkEntry {
  final SocialNetworkType type;
  final String link; // URL ou nom d'utilisateur
  final int followers;

  const SocialNetworkEntry({
    required this.type,
    required this.link,
    required this.followers,
  });

  Map<String, dynamic> toMap() => {
        'type': type.id,
        'link': link,
        'followers': followers,
      };

  factory SocialNetworkEntry.fromMap(Map<String, dynamic> m) =>
      SocialNetworkEntry(
        type: SocialNetworkType.fromId(m['type'] as String? ?? ''),
        link: m['link'] as String? ?? '',
        followers: (m['followers'] as num?)?.toInt() ?? 0,
      );
}

/// Modèle principal d'une demande de compte officiel.
/// Stocké dans la collection Firestore `OfficialAccountRequests`.
class OfficialAccountRequest {
  final String id;
  final String userId;
  final String pseudo;
  final String imageUrl;

  // ── Formulaire ──────────────────────────────────────────────
  final OfficialAccountCategory category;
  final String officialName;
  final String officialNameSlug;     // ex : "afrolook_médias_ci"
  final List<String> searchKeywords; // ex : ["afrolook", "médias", "ci"]
  final String description;
  final String country;
  final String city;
  final String phone;
  final String email;
  final String website; // optionnel
  final String profilePhotoUrl;
  final String coverPhotoUrl;
  final List<BroadcastDomain> broadcastDomains;
  final List<SocialNetworkEntry> socialNetworks;

  // ── Vérification d'identité (influenceur, artiste, entrepreneur) ────────────
  final String? birthDate;        // ISO-8601 : 'YYYY-MM-DD'
  final IdDocumentType? idDocumentType;
  final String? idNumber;
  final String? idDocumentUrl;    // URL Firebase Storage du PDF/image de la pièce

  // ── Statut et admin ─────────────────────────────────────────
  final OfficialAccountStatus status;
  final String? adminNote;
  final List<OfficialAccountAction> actionHistory;

  // ── Timestamps ──────────────────────────────────────────────
  final int createdAt;
  final int updatedAt;
  final int? processedAt;
  final String? processedBy;

  // ── CGU ─────────────────────────────────────────────────────
  final int termsAcceptedAt;

  const OfficialAccountRequest({
    required this.id,
    required this.userId,
    required this.pseudo,
    required this.imageUrl,
    required this.category,
    required this.officialName,
    required this.officialNameSlug,
    required this.searchKeywords,
    required this.description,
    required this.country,
    required this.city,
    required this.phone,
    required this.email,
    this.website = '',
    required this.profilePhotoUrl,
    required this.coverPhotoUrl,
    required this.broadcastDomains,
    required this.socialNetworks,
    this.birthDate,
    this.idDocumentType,
    this.idNumber,
    this.idDocumentUrl,
    required this.status,
    this.adminNote,
    required this.actionHistory,
    required this.createdAt,
    required this.updatedAt,
    this.processedAt,
    this.processedBy,
    required this.termsAcceptedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'pseudo': pseudo,
        'imageUrl': imageUrl,
        'category': category.id,
        'officialName': officialName,
        'officialNameSlug': officialNameSlug,
        'searchKeywords': searchKeywords,
        'description': description,
        'country': country,
        'city': city,
        'phone': phone,
        'email': email,
        'website': website,
        'profilePhotoUrl': profilePhotoUrl,
        'coverPhotoUrl': coverPhotoUrl,
        'broadcastDomains': broadcastDomains.map((d) => d.id).toList(),
        'socialNetworks': socialNetworks.map((s) => s.toMap()).toList(),
        'birthDate': birthDate,
        'idDocumentType': idDocumentType?.id,
        'idNumber': idNumber,
        'idDocumentUrl': idDocumentUrl,
        'status': status.id,
        'adminNote': adminNote,
        'actionHistory': actionHistory.map((a) => a.toMap()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'processedAt': processedAt,
        'processedBy': processedBy,
        'termsAcceptedAt': termsAcceptedAt,
      };

  factory OfficialAccountRequest.fromMap(Map<String, dynamic> m, String docId) =>
      OfficialAccountRequest(
        id: docId,
        userId: m['userId'] as String? ?? '',
        pseudo: m['pseudo'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        category: OfficialAccountCategory.fromId(m['category'] as String? ?? ''),
        officialName: m['officialName'] as String? ?? '',
        officialNameSlug: m['officialNameSlug'] as String? ?? '',
        searchKeywords: (m['searchKeywords'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        description: m['description'] as String? ?? '',
        country: m['country'] as String? ?? '',
        city: m['city'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        email: m['email'] as String? ?? '',
        website: m['website'] as String? ?? '',
        profilePhotoUrl: m['profilePhotoUrl'] as String? ?? '',
        coverPhotoUrl: m['coverPhotoUrl'] as String? ?? '',
        broadcastDomains: (m['broadcastDomains'] as List<dynamic>? ?? [])
            .map((d) => BroadcastDomain.fromId(d as String))
            .toList(),
        socialNetworks: (m['socialNetworks'] as List<dynamic>? ?? [])
            .map((s) => SocialNetworkEntry.fromMap(s as Map<String, dynamic>))
            .toList(),
        birthDate: m['birthDate'] as String?,
        idDocumentType: m['idDocumentType'] != null
            ? IdDocumentType.fromId(m['idDocumentType'] as String)
            : null,
        idNumber: m['idNumber'] as String?,
        idDocumentUrl: m['idDocumentUrl'] as String?,
        status: OfficialAccountStatus.fromId(m['status'] as String? ?? 'pending'),
        adminNote: m['adminNote'] as String?,
        actionHistory: (m['actionHistory'] as List<dynamic>? ?? [])
            .map((a) => OfficialAccountAction.fromMap(a as Map<String, dynamic>))
            .toList(),
        createdAt: m['createdAt'] as int? ?? 0,
        updatedAt: m['updatedAt'] as int? ?? 0,
        processedAt: m['processedAt'] as int?,
        processedBy: m['processedBy'] as String?,
        termsAcceptedAt: m['termsAcceptedAt'] as int? ?? 0,
      );

  OfficialAccountRequest copyWith({
    OfficialAccountStatus? status,
    String? adminNote,
    List<OfficialAccountAction>? actionHistory,
    int? updatedAt,
    int? processedAt,
    String? processedBy,
  }) =>
      OfficialAccountRequest(
        id: id,
        userId: userId,
        pseudo: pseudo,
        imageUrl: imageUrl,
        category: category,
        officialName: officialName,
        officialNameSlug: officialNameSlug,
        searchKeywords: searchKeywords,
        description: description,
        country: country,
        city: city,
        phone: phone,
        email: email,
        website: website,
        profilePhotoUrl: profilePhotoUrl,
        coverPhotoUrl: coverPhotoUrl,
        broadcastDomains: broadcastDomains,
        socialNetworks: socialNetworks,
        birthDate: birthDate,
        idDocumentType: idDocumentType,
        idNumber: idNumber,
        idDocumentUrl: idDocumentUrl,
        status: status ?? this.status,
        adminNote: adminNote ?? this.adminNote,
        actionHistory: actionHistory ?? this.actionHistory,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        processedAt: processedAt ?? this.processedAt,
        processedBy: processedBy ?? this.processedBy,
        termsAcceptedAt: termsAcceptedAt,
      );
}
