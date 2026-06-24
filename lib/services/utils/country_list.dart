/// Liste des pays avec code ISO 3166-1 alpha-2 et nom français
const List<Map<String, String>> kCountries = [
  {'code': 'ALL', 'name': 'Tous les pays', 'flag': '🌍'},
  // ── Afrique ────────────────────────────────────────────────────────────────
  {'code': 'DZ', 'name': 'Algérie', 'flag': '🇩🇿'},
  {'code': 'AO', 'name': 'Angola', 'flag': '🇦🇴'},
  {'code': 'BJ', 'name': 'Bénin', 'flag': '🇧🇯'},
  {'code': 'BW', 'name': 'Botswana', 'flag': '🇧🇼'},
  {'code': 'BF', 'name': 'Burkina Faso', 'flag': '🇧🇫'},
  {'code': 'BI', 'name': 'Burundi', 'flag': '🇧🇮'},
  {'code': 'CM', 'name': 'Cameroun', 'flag': '🇨🇲'},
  {'code': 'CV', 'name': 'Cap-Vert', 'flag': '🇨🇻'},
  {'code': 'CF', 'name': 'Centrafrique', 'flag': '🇨🇫'},
  {'code': 'KM', 'name': 'Comores', 'flag': '🇰🇲'},
  {'code': 'CG', 'name': 'Congo-Brazzaville', 'flag': '🇨🇬'},
  {'code': 'CD', 'name': 'Congo-Kinshasa (RDC)', 'flag': '🇨🇩'},
  {'code': 'CI', 'name': 'Côte d\'Ivoire', 'flag': '🇨🇮'},
  {'code': 'DJ', 'name': 'Djibouti', 'flag': '🇩🇯'},
  {'code': 'EG', 'name': 'Égypte', 'flag': '🇪🇬'},
  {'code': 'ER', 'name': 'Érythrée', 'flag': '🇪🇷'},
  {'code': 'ET', 'name': 'Éthiopie', 'flag': '🇪🇹'},
  {'code': 'GA', 'name': 'Gabon', 'flag': '🇬🇦'},
  {'code': 'GM', 'name': 'Gambie', 'flag': '🇬🇲'},
  {'code': 'GH', 'name': 'Ghana', 'flag': '🇬🇭'},
  {'code': 'GN', 'name': 'Guinée', 'flag': '🇬🇳'},
  {'code': 'GW', 'name': 'Guinée-Bissau', 'flag': '🇬🇼'},
  {'code': 'GQ', 'name': 'Guinée équatoriale', 'flag': '🇬🇶'},
  {'code': 'KE', 'name': 'Kenya', 'flag': '🇰🇪'},
  {'code': 'LS', 'name': 'Lesotho', 'flag': '🇱🇸'},
  {'code': 'LR', 'name': 'Liberia', 'flag': '🇱🇷'},
  {'code': 'LY', 'name': 'Libye', 'flag': '🇱🇾'},
  {'code': 'MG', 'name': 'Madagascar', 'flag': '🇲🇬'},
  {'code': 'MW', 'name': 'Malawi', 'flag': '🇲🇼'},
  {'code': 'ML', 'name': 'Mali', 'flag': '🇲🇱'},
  {'code': 'MA', 'name': 'Maroc', 'flag': '🇲🇦'},
  {'code': 'MR', 'name': 'Mauritanie', 'flag': '🇲🇷'},
  {'code': 'MU', 'name': 'Maurice', 'flag': '🇲🇺'},
  {'code': 'MZ', 'name': 'Mozambique', 'flag': '🇲🇿'},
  {'code': 'NA', 'name': 'Namibie', 'flag': '🇳🇦'},
  {'code': 'NE', 'name': 'Niger', 'flag': '🇳🇪'},
  {'code': 'NG', 'name': 'Nigeria', 'flag': '🇳🇬'},
  {'code': 'UG', 'name': 'Ouganda', 'flag': '🇺🇬'},
  {'code': 'RW', 'name': 'Rwanda', 'flag': '🇷🇼'},
  {'code': 'ST', 'name': 'São Tomé-et-Príncipe', 'flag': '🇸🇹'},
  {'code': 'SN', 'name': 'Sénégal', 'flag': '🇸🇳'},
  {'code': 'SC', 'name': 'Seychelles', 'flag': '🇸🇨'},
  {'code': 'SL', 'name': 'Sierra Leone', 'flag': '🇸🇱'},
  {'code': 'SO', 'name': 'Somalie', 'flag': '🇸🇴'},
  {'code': 'SD', 'name': 'Soudan', 'flag': '🇸🇩'},
  {'code': 'SS', 'name': 'Soudan du Sud', 'flag': '🇸🇸'},
  {'code': 'SZ', 'name': 'Eswatini (Swaziland)', 'flag': '🇸🇿'},
  {'code': 'TZ', 'name': 'Tanzanie', 'flag': '🇹🇿'},
  {'code': 'TD', 'name': 'Tchad', 'flag': '🇹🇩'},
  {'code': 'TG', 'name': 'Togo', 'flag': '🇹🇬'},
  {'code': 'TN', 'name': 'Tunisie', 'flag': '🇹🇳'},
  {'code': 'ZM', 'name': 'Zambie', 'flag': '🇿🇲'},
  {'code': 'ZW', 'name': 'Zimbabwe', 'flag': '🇿🇼'},
  // ── Europe ─────────────────────────────────────────────────────────────────
  {'code': 'DE', 'name': 'Allemagne', 'flag': '🇩🇪'},
  {'code': 'BE', 'name': 'Belgique', 'flag': '🇧🇪'},
  {'code': 'ES', 'name': 'Espagne', 'flag': '🇪🇸'},
  {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
  {'code': 'GB', 'name': 'Royaume-Uni', 'flag': '🇬🇧'},
  {'code': 'IT', 'name': 'Italie', 'flag': '🇮🇹'},
  {'code': 'NL', 'name': 'Pays-Bas', 'flag': '🇳🇱'},
  {'code': 'PT', 'name': 'Portugal', 'flag': '🇵🇹'},
  {'code': 'CH', 'name': 'Suisse', 'flag': '🇨🇭'},
  // ── Amériques ──────────────────────────────────────────────────────────────
  {'code': 'BR', 'name': 'Brésil', 'flag': '🇧🇷'},
  {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
  {'code': 'US', 'name': 'États-Unis', 'flag': '🇺🇸'},
  {'code': 'HT', 'name': 'Haïti', 'flag': '🇭🇹'},
  // ── Autres ─────────────────────────────────────────────────────────────────
  {'code': 'CN', 'name': 'Chine', 'flag': '🇨🇳'},
  {'code': 'IN', 'name': 'Inde', 'flag': '🇮🇳'},
  {'code': 'AE', 'name': 'Émirats arabes unis', 'flag': '🇦🇪'},
];

String countryFlag(String code) {
  if (code == 'ALL') return '🌍';
  final entry = kCountries.firstWhere(
    (c) => c['code'] == code,
    orElse: () => {'flag': '🏳️'},
  );
  return entry['flag'] ?? '🏳️';
}

String countryName(String code) {
  if (code == 'ALL') return 'Tous les pays';
  final entry = kCountries.firstWhere(
    (c) => c['code'] == code,
    orElse: () => {'name': code},
  );
  return entry['name'] ?? code;
}
