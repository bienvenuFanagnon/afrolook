/// Interrupteur par module : chaque module bascule de Firebase vers la nouvelle API indépendamment (valeurs lues dans Remote Config,
/// clé `api_modules` = JSON { "lives": true, "music": false, ... }). Par défaut tout reste sur l'ancien système : rien ne change tant qu'on n'active pas.
/// `{"all": true}` active tout, avec des exceptions possibles (`"music": false`).
class ApiModules {
  ApiModules([Map<String, dynamic> values = const {}]) : _values = Map.of(values);

  Map<String, dynamic> _values;

  static const all = [
    'lives', 'groups', 'shop', 'music', 'studio', 'quiz', 'etude', 'contes', 'journal', 'ads', 'share', 'rewards', 'comments', 'channels', 'feed', 'wallet',
  ];

  void update(Map<String, dynamic> values) => _values = Map.of(values);

  bool useApi(String module) => _values['all'] == true ? _values[module] != false : _values[module] == true;
}
