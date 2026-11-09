// Une piste de musique gratuite du Studio : ses fichiers sont sur R2 (`studio_music/<id>.m4a`), son identifiant et sa fiche sont ici.
// Deux familles : les pistes faites par Afrolook (sans droits d'auteur) et les musiques libres de droits de Kevin MacLeod (CC BY 4.0, crédit obligatoire : voir [kLibreCredit]).

class StudioTrack {
  const StudioTrack(this.id, this.title, this.emoji, this.mood, this.durationMs, {this.group = '', this.libre = false, this.voice = false});
  final String id;
  final String title;
  final String emoji;
  final String mood;
  final int durationMs;

  /// Catégorie du sélecteur (« Courage », « Noël »…). Vide : déduite de l'identifiant (anciennes pistes d'Afrolook).
  final String group;

  /// Musique libre de droits de Kevin MacLeod (crédit à afficher).
  final bool libre;

  /// La piste comporte une voix ou un chœur.
  final bool voice;

  /// Catégorie affichée.
  String get section => group.isNotEmpty ? group : (_anciennes[id] ?? mood);

  /// Ligne de crédit affichée sous le titre ; null pour les pistes d'Afrolook.
  String? get credit => libre ? 'Kevin MacLeod · CC BY 4.0' : null;
}

/// Crédit complet exigé par la licence CC BY 4.0 (affiché dans l'écran « Crédits musique »).
const String kLibreCredit = 'Kevin MacLeod (incompetech.com)\nLicensed under Creative Commons: By Attribution 4.0\nhttps://creativecommons.org/licenses/by/4.0/';

/// Ordre des catégories du sélecteur.
const List<String> kStudioGroups = [
  'Courage', 'Fin de film', 'Espoir', 'Amour', 'Famille', 'Joie', 'Humour', 'Danse', 'Noël', 'Nouvel an', 'Soirée', 'Aïd', 'Halloween', 'Tristesse', 'Calme', 'Sombre', 'Spirituel', 'Américain', 'Français',
];

const Map<String, String> _anciennes = {
  'love_afro': 'Amour', 'piano_triste': 'Tristesse', 'afrobeat': 'Danse', 'amapiano': 'Danse', 'coupe_decale': 'Danse', 'highlife': 'Joie', 'afro_trap': 'Courage', 'workout': 'Courage',
  'fanfare': 'Soirée', 'noel': 'Noël', 'zen_kalimba': 'Calme', 'kora_calme': 'Calme', 'plage': 'Calme', 'nuit': 'Calme', 'berceuse': 'Famille', 'oud': 'Aïd', 'tension': 'Sombre',
};

// Généré depuis les fichiers compressés (id = nom du fichier studio_music/<id>.m4a, durée réelle) : 70 musiques libres de droits de Kevin MacLeod.
const List<StudioTrack> kLibreTracks = <StudioTrack>[
  StudioTrack('heroic_age', 'Heroic Age', '💪', 'Courage', 97500, group: 'Courage', libre: true),
  StudioTrack('undaunted', 'Undaunted', '💪', 'Courage', 212600, group: 'Courage', libre: true),
  StudioTrack('motivator', 'Motivator', '💪', 'Courage', 237900, group: 'Courage', libre: true),
  StudioTrack('despair_and_triumph', 'Despair and Triumph', '💪', 'Courage', 240000, group: 'Courage', libre: true),
  StudioTrack('long_road_ahead', 'Long Road Ahead', '💪', 'Courage', 146100, group: 'Courage', libre: true, voice: true),
  StudioTrack('our_story_begins', 'Our Story Begins', '💪', 'Courage', 84600, group: 'Courage', libre: true, voice: true),
  StudioTrack('eternal_hope', 'Eternal Hope', '🎬', 'Fin de film', 240000, group: 'Fin de film', libre: true, voice: true),
  StudioTrack('angel_share', 'Angel Share', '🌅', 'Espoir', 200600, group: 'Espoir', libre: true, voice: true),
  StudioTrack('morning', 'Morning', '🌅', 'Espoir', 153400, group: 'Espoir', libre: true),
  StudioTrack('aretes', 'Aretes', '🌅', 'Espoir', 240000, group: 'Espoir', libre: true, voice: true),
  StudioTrack('reawakening', 'Reawakening', '❤️', 'Amour', 214100, group: 'Amour', libre: true),
  StudioTrack('what_is_love', 'What Is Love', '❤️', 'Amour', 208000, group: 'Amour', libre: true),
  StudioTrack('canon_in_d_for_two_harps', 'Canon in D for Two Harps', '❤️', 'Amour', 240000, group: 'Amour', libre: true),
  StudioTrack('habanera', 'Habanera', '❤️', 'Amour', 240000, group: 'Amour', libre: true, voice: true),
  StudioTrack('dreamer', 'Dreamer', '👨‍👩‍👧', 'Famille', 204100, group: 'Famille', libre: true),
  StudioTrack('avec_soin', 'Avec Soin', '👨‍👩‍👧', 'Famille', 145100, group: 'Famille', libre: true),
  StudioTrack('fireflies_and_stardust', 'Fireflies and Stardust', '👨‍👩‍👧', 'Famille', 240000, group: 'Famille', libre: true),
  StudioTrack('carefree', 'Carefree', '😄', 'Joie', 205200, group: 'Joie', libre: true),
  StudioTrack('montauk_point', 'Montauk Point', '😄', 'Joie', 219800, group: 'Joie', libre: true),
  StudioTrack('paradise_found', 'Paradise Found', '😄', 'Joie', 187500, group: 'Joie', libre: true),
  StudioTrack('super_friendly', 'Super Friendly', '😄', 'Joie', 134400, group: 'Joie', libre: true, voice: true),
  StudioTrack('monkeys_spinning_monkeys', 'Monkeys Spinning Monkeys', '😂', 'Humour', 125100, group: 'Humour', libre: true),
  StudioTrack('sergios_magic_dustbin', 'Sergio\'s Magic Dustbin', '😂', 'Humour', 151500, group: 'Humour', libre: true),
  StudioTrack('mischief_maker', 'Mischief Maker', '😂', 'Humour', 201700, group: 'Humour', libre: true),
  StudioTrack('darxieland', 'DarxieLand', '😂', 'Humour', 145600, group: 'Humour', libre: true),
  StudioTrack('happy_happy_game_show', 'Happy Happy Game Show', '😂', 'Humour', 158700, group: 'Humour', libre: true),
  StudioTrack('allada', 'Allada', '💃', 'Danse', 223500, group: 'Danse', libre: true),
  StudioTrack('arroz_con_pollo', 'Arroz Con Pollo', '💃', 'Danse', 162100, group: 'Danse', libre: true),
  StudioTrack('samba_isobel', 'Samba Isobel', '💃', 'Danse', 240000, group: 'Danse', libre: true),
  StudioTrack('zanzibar', 'Zanzibar', '💃', 'Danse', 218700, group: 'Danse', libre: true, voice: true),
  StudioTrack('tafi_maradi', 'Tafi Maradi', '💃', 'Danse', 158900, group: 'Danse', libre: true, voice: true),
  StudioTrack('silent_night', 'Silent Night', '🎄', 'Noël', 131300, group: 'Noël', libre: true),
  StudioTrack('jingle_bells', 'Jingle Bells', '🎄', 'Noël', 142100, group: 'Noël', libre: true),
  StudioTrack('we_wish_you_a_merry_christmas', 'We Wish you a Merry Christmas', '🎄', 'Noël', 138100, group: 'Noël', libre: true),
  StudioTrack('deck_the_halls_b', 'Deck the Halls B', '🎄', 'Noël', 240000, group: 'Noël', libre: true),
  StudioTrack('angels_we_have_heard_on_high', 'Angels We Have Heard on High', '🎄', 'Noël', 240000, group: 'Noël', libre: true),
  StudioTrack('nouvelle_noel', 'Nouvelle Noel', '🎄', 'Noël', 191200, group: 'Noël', libre: true),
  StudioTrack('it_came_upon_a_midnight_clear', 'It Came Upon a Midnight Clear', '🎄', 'Noël', 240000, group: 'Noël', libre: true),
  StudioTrack('christmas_rap', 'Christmas Rap', '🎄', 'Noël', 186800, group: 'Noël', libre: true),
  StudioTrack('celebration', 'Celebration', '🎆', 'Nouvel an', 240000, group: 'Nouvel an', libre: true),
  StudioTrack('beachfront_celebration', 'Beachfront Celebration', '🎆', 'Nouvel an', 187300, group: 'Nouvel an', libre: true),
  StudioTrack('frost_waltz_alternate', 'Frost Waltz (Alternate)', '🎆', 'Nouvel an', 136100, group: 'Nouvel an', libre: true),
  StudioTrack('disco_con_tutti', 'Disco con Tutti', '🎉', 'Soirée', 236400, group: 'Soirée', libre: true),
  StudioTrack('future_cha_cha', 'Future Cha Cha', '🎉', 'Soirée', 240000, group: 'Soirée', libre: true, voice: true),
  StudioTrack('desert_city', 'Desert City', '🌙', 'Aïd', 89400, group: 'Aïd', libre: true),
  StudioTrack('tabuk', 'Tabuk', '🌙', 'Aïd', 158600, group: 'Aïd', libre: true),
  StudioTrack('danse_macabre', 'Danse Macabre', '🎃', 'Halloween', 240000, group: 'Halloween', libre: true),
  StudioTrack('graveyard_shift', 'Graveyard Shift', '🎃', 'Halloween', 197500, group: 'Halloween', libre: true, voice: true),
  StudioTrack('spider_eyes', 'Spider Eyes', '🎃', 'Halloween', 215400, group: 'Halloween', libre: true),
  StudioTrack('heavy_heart', 'Heavy Heart', '😢', 'Tristesse', 240000, group: 'Tristesse', libre: true),
  StudioTrack('colorless_aura', 'Colorless Aura', '😢', 'Tristesse', 158100, group: 'Tristesse', libre: true),
  StudioTrack('lost_time', 'Lost Time', '😢', 'Tristesse', 227400, group: 'Tristesse', libre: true),
  StudioTrack('danse_morialta', 'Danse Morialta', '😢', 'Tristesse', 236400, group: 'Tristesse', libre: true),
  StudioTrack('shores_of_avalon', 'Shores of Avalon', '😢', 'Tristesse', 236100, group: 'Tristesse', libre: true, voice: true),
  StudioTrack('airship_serenity', 'Airship Serenity', '🌿', 'Calme', 240000, group: 'Calme', libre: true),
  StudioTrack('immersed', 'Immersed', '🌿', 'Calme', 240000, group: 'Calme', libre: true),
  StudioTrack('late_night_radio', 'Late Night Radio', '🌿', 'Calme', 240000, group: 'Calme', libre: true),
  StudioTrack('jazz_brunch', 'Jazz Brunch', '🌿', 'Calme', 240000, group: 'Calme', libre: true),
  StudioTrack('man_down', 'Man Down', '🌑', 'Sombre', 198600, group: 'Sombre', libre: true),
  StudioTrack('dark_fog', 'Dark Fog', '🌑', 'Sombre', 239100, group: 'Sombre', libre: true),
  StudioTrack('mystery_bazaar', 'Mystery Bazaar', '🌑', 'Sombre', 158500, group: 'Sombre', libre: true),
  StudioTrack('amazing_grace_2011', 'Amazing Grace 2011', '🙏', 'Spirituel', 189300, group: 'Spirituel', libre: true),
  StudioTrack('gregorian_chant', 'Gregorian Chant', '🙏', 'Spirituel', 194100, group: 'Spirituel', libre: true, voice: true),
  StudioTrack('virtutes_vocis', 'Virtutes Vocis', '🙏', 'Spirituel', 240000, group: 'Spirituel', libre: true, voice: true),
  StudioTrack('americana', 'Americana', '🇺🇸', 'Américain', 202300, group: 'Américain', libre: true),
  StudioTrack('the_entertainer', 'The Entertainer', '🇺🇸', 'Américain', 193400, group: 'Américain', libre: true),
  StudioTrack('bama_country', 'Bama Country', '🇺🇸', 'Américain', 211900, group: 'Américain', libre: true),
  StudioTrack('porch_swing_days_slower', 'Porch Swing Days - slower', '🇺🇸', 'Américain', 216300, group: 'Américain', libre: true, voice: true),
  StudioTrack('valse_gymnopedie', 'Valse Gymnopedie', '🇫🇷', 'Français', 191800, group: 'Français', libre: true),
  StudioTrack('aquarium', 'Aquarium', '🇫🇷', 'Français', 144100, group: 'Français', libre: true),
  StudioTrack('reign', 'Reign', '🎬', 'Fin de film', 162600, group: 'Fin de film', libre: true, voice: true),
  StudioTrack('magistar', 'Magistar', '🎬', 'Fin de film', 192100, group: 'Fin de film', libre: true, voice: true),
  StudioTrack('noble_race', 'Noble Race', '🎬', 'Fin de film', 240000, group: 'Fin de film', libre: true),
  StudioTrack('egmont_overture_finale', 'Egmont Overture Finale', '🎬', 'Fin de film', 103900, group: 'Fin de film', libre: true),
  StudioTrack('inspired', 'Inspired', '🎬', 'Fin de film', 240000, group: 'Fin de film', libre: true),
  StudioTrack('continue_life', 'Continue Life', '🎬', 'Fin de film', 114100, group: 'Fin de film', libre: true),
  StudioTrack('evening', 'Evening', '🎬', 'Fin de film', 186300, group: 'Fin de film', libre: true),
  StudioTrack('truth_of_the_legend', 'Truth of the Legend', '🎬', 'Fin de film', 93100, group: 'Fin de film', libre: true, voice: true),
];

/// Minuscules et sans accents : « noel » trouve « Noël », « ete » trouve « été ».
String foldSearch(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Les pistes qui correspondent à la recherche [query] (titre, catégorie, ambiance : « courage », « noel », « triste », « eternal ») et à la catégorie [group] (null = toutes).
List<StudioTrack> filterStudioTracks(Iterable<StudioTrack> tracks, {String query = '', String? group}) {
  final q = foldSearch(query.trim());
  return [
    for (final t in tracks)
      if ((group == null || t.section == group) && (q.isEmpty || foldSearch('${t.title} ${t.section} ${t.mood}').contains(q))) t,
];
}
