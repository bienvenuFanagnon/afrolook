/// Noms français des pays (codes ISO à 2 lettres) pour les écrans d'actualités : tous les pays d'Afrique, plus quelques pays d'autres continents.
const Map<String, String> kCountryNamesFr = {
  'DZ': 'Algérie', 'AO': 'Angola', 'BJ': 'Bénin', 'BW': 'Botswana', 'BF': 'Burkina Faso', 'BI': 'Burundi', 'CM': 'Cameroun', 'CV': 'Cap-Vert',
  'CF': 'Centrafrique', 'TD': 'Tchad', 'KM': 'Comores', 'CG': 'Congo', 'CD': 'RD Congo', 'CI': 'Côte d\'Ivoire', 'DJ': 'Djibouti', 'EG': 'Égypte',
  'GQ': 'Guinée équatoriale', 'ER': 'Érythrée', 'SZ': 'Eswatini', 'ET': 'Éthiopie', 'GA': 'Gabon', 'GM': 'Gambie', 'GH': 'Ghana', 'GN': 'Guinée',
  'GW': 'Guinée-Bissau', 'KE': 'Kenya', 'LS': 'Lesotho', 'LR': 'Libéria', 'LY': 'Libye', 'MG': 'Madagascar', 'MW': 'Malawi', 'ML': 'Mali',
  'MR': 'Mauritanie', 'MU': 'Maurice', 'MA': 'Maroc', 'MZ': 'Mozambique', 'NA': 'Namibie', 'NE': 'Niger', 'NG': 'Nigéria', 'RW': 'Rwanda',
  'ST': 'Sao Tomé-et-Principe', 'SN': 'Sénégal', 'SC': 'Seychelles', 'SL': 'Sierra Leone', 'SO': 'Somalie', 'ZA': 'Afrique du Sud', 'SS': 'Soudan du Sud',
  'SD': 'Soudan', 'TZ': 'Tanzanie', 'TG': 'Togo', 'TN': 'Tunisie', 'UG': 'Ouganda', 'ZM': 'Zambie', 'ZW': 'Zimbabwe',
  'FR': 'France', 'BE': 'Belgique', 'CH': 'Suisse', 'CA': 'Canada', 'US': 'États-Unis', 'GB': 'Royaume-Uni',
  'DE': 'Allemagne', 'ES': 'Espagne', 'BR': 'Brésil', 'MX': 'Mexique', 'HT': 'Haïti',
};

/// Nom du pays, ou son code s'il n'est pas dans la liste.
String countryName(String? code) {
  final c = (code ?? '').toUpperCase();
  return kCountryNamesFr[c] ?? c;
}

/// Drapeau d'un pays (lettres indicatrices régionales) ; vide si le code n'est pas valide.
String countryFlag(String? code) {
  final c = (code ?? '').toUpperCase();
  if (c.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
}
