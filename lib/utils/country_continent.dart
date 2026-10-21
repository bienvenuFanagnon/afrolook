// Fichier généré à partir de functions/src/news/geo.ts : ne pas modifier à la main (relancer le script de génération).
// Continent d'un pays (code ISO à 2 lettres) : AF Afrique · EU Europe · AS Asie · NA Amérique du Nord, centrale et Caraïbes · SA Amérique du Sud · OC Océanie.

const Map<String, String> _kCountriesByContinent = {
  'AF': 'DZ AO BJ BW BF BI CM CV CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW EH RE YT SH',
  'EU': 'AL AD AT BY BE BA BG HR CY CZ DK EE FO FI FR DE GI GR GG HU IS IE IM IT JE XK LV LI LT LU MT MD MC ME NL MK NO PL PT RO RU SM RS SK SI ES SJ SE CH UA GB VA AX',
  'AS': 'AF AM AZ BH BD BT BN KH CN GE HK IN ID IR IQ IL JP JO KZ KW KG LA LB MO MY MV MN MM NP KP OM PK PS PH QA SA SG KR LK SY TW TJ TH TL TR TM AE UZ VN YE',
  'NA': 'AG BS BB BZ CA CR CU DM DO SV GD GT HT HN JM MX NI PA KN LC VC TT US AI AW BM BQ VG KY CW GL GP MQ MS PR BL MF PM SX TC VI UM',
  'SA': 'AR BO BR CL CO EC FK GF GY PY PE SR UY VE',
  'OC': 'AU FJ KI MH FM NR NZ PW PG WS SB TO TV VU AS CK PF GU MP NC NU NF PN TK WF',
};

final Map<String, String> _kContinentOf = () {
  final out = <String, String>{};
  _kCountriesByContinent.forEach((continent, codes) {
    for (final c in codes.split(' ')) {
      out[c] = continent;
    }
  });
  return out;
}();

/// Continent d'un pays, ou null s'il est inconnu.
String? continentOfCountry(String? countryCode) {
  final code = (countryCode ?? '').trim().toUpperCase();
  return _kContinentOf[code];
}

/// Périmètres d'actualités à lire pour une personne, du plus proche au plus large : son pays, son continent, le monde.
List<String> newsScopesForCountry(String? countryCode) {
  final code = (countryCode ?? '').trim().toUpperCase();
  final out = <String>[];
  if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) out.add('country_$code');
  final continent = continentOfCountry(code);
  if (continent != null) out.add('continent_$continent');
  out.add('world');
  return out;
}
