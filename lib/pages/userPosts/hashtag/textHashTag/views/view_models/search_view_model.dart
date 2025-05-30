import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../../models/model_data.dart';
import '../../../../../../providers/authProvider.dart';
import '../../models/user.dart';

///Search view model
final searchViewModel = SearchViewModel();

enum SearchResultView { users, hashtag, none }

class SearchViewModel {
  late final ValueNotifier<List<User>> _users = ValueNotifier([]);
  ValueNotifier<List<User>> get users => _users;

  late final ValueNotifier<List<String>> _hashtags = ValueNotifier([]);
  ValueNotifier<List<String>> get hashtags => _hashtags;

  late final ValueNotifier<bool> _loading = ValueNotifier(false);
  ValueNotifier<bool> get loading => _loading;

  late final ValueNotifier<SearchResultView> _activeView =
      ValueNotifier(SearchResultView.none);
  ValueNotifier<SearchResultView> get activeView => _activeView;

  void _setLoading(bool val) {
    if (val != _loading.value) {
      _loading.value = val;
    }
  }

  Future<void> searchUser(String query,List<UserData>? users) async {
    if (query.isEmpty) return;
    _activeView.value = SearchResultView.users;

    query = query.toLowerCase().trim();

    _users.value = [];

    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 250));

    // final result =User.allUsers
    final result =users!
        .where((userData) => userData.pseudo != null && userData.pseudo!.isNotEmpty)
        .map((userData) => User(
      id: userData.id ?? '',
      userName: userData.pseudo ?? '',
      fullName: '${userData.prenom ?? ''} ${userData.nom ?? ''}',
      avatar: userData.imageUrl ?? '',
    ))
        .toList()
        .where(
          (user) =>
              user.userName.toLowerCase().contains(query) ||
              user.fullName.toLowerCase().contains(query),
        )
        .toList();

    _users.value = [...result];
    _setLoading(false);
  }

  Future<void> searchHashtag(String query) async {
    if (query.isEmpty) return;

    _activeView.value = SearchResultView.hashtag;

    query = query.toLowerCase().trim();

    _hashtags.value = [];

    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 250));

    final result = _dummyHashtags
        .where((tag) => tag.toLowerCase().contains(query))
        .toList();

    _hashtags.value = [...result];
    _setLoading(false);
  }
}

 List<String> _dummyHashtags = <String>[
  // Général
  "AfroLook",
  "Afrique",
  "Togo",
  "JeunesseAfricaine",
  "CulturAfro",
  "AfroStyle",
  "AfroVibes",

  // Éducation
  "EducationAfricaine",
  "LearnToGrow",
  "SuccessStories",
  "JeunesEcoliers",
  "EtudiantsAfricains",
  "FormationPro",
  "AfroEducation",
  "InnovationEducative",

  // Mode (Fashion)
  "AfroFashion",
  "AfroChic",
  "ModeAfricaine",
  "StylAfricain",
  "FashionTogo",
  "WaxStyle",
  "AnkaraFashion",
  "AfroCouture",
  "MannequinatAfricain",
  "AfroTrend",
  "BlackExcellence",

  // Musique
  "AfroBeats",
  "MusiqueAfricaine",
  "ArtistesAfricains",
  "AfroGroove",
  "ChansonTogolaise",
  "VibesAfricaines",
  "AfroPop",
  "RapAfricain",
  "AfroDance",
  "SoulAfricaine",
  "RythmesAfricains",

  // Médias
  "MédiaAfricaine",
  "ContentCreators",
  "InfluenceursAfricains",
  "DigitalAfrica",
  "AfroMedia",
  "AfriqueConnectée",
  "RéseauxSociauxAfrique",
  "TendancesAfricaines",

  // Entrepreneuriat
  "StartupsAfricaines",
  "EntrepreneursAfricains",
  "TogoStartup",
  "InnovationAfrique",
  "SuccessAfricain",
  "AfroBusiness",
  "LeadersAfricains",
  "InvestirAfrique",
  "EntrepreneuriatTogo",
  "RêvesAfricains",

  // Mannequinat
  "MannequinsAfricains",
  "CatwalkAfrica",
  "AfroModels",
  "FashionShowAfrica",
  "ModelingAfrique",
  "BeautéNoire",
  "DiversitéMode",
  "AfroGlow",
  "TalentAfricain",

  // Lifestyle et Inspiration
  "InspirationAfricaine",
  "AfroLifestyle",
  "BlackCreativity",
  "JeunesseInspirée",
  "MotivationAfrique",
  "FiertéAfricaine",
  "VivreEnAfrique",
  "SavoirFaireAfricain",
  "TalentsNoirs",
  "ArtisanatAfricain",

  // Environnement et développement
  "AfriqueVerte",
  "DéveloppementDurableAfrique",
  "GreenAfrica",
  "EnergieRenouvelable",
  "InnovationDurable",
  "ChangementClimatiqueAfrique",

  // Divertissement
  "AfroMovies",
  "FilmsAfricains",
  "TendancesMusicales",
  "DanseAfricaine",
  "ArtistesTogolais",
  "FestivalsAfricains",
  "CélébrationAfrique",
  "AfroEntertainment",

  // Social et communautaire
  "SolidaritéAfricaine",
  "AfroCommunauté",
  "AmitiéNoire",
  "ForceAfricain",
  "UnitéAfricaine",
  "AfroPride",

  // Technologie et numérique
  "TechAfrique",
  "NumériqueTogo",
  "DéveloppeursAfricains",
  "AfricaInTech",
  "TechnoTogo",
  "ProgrammersAfrica",

  // Autres tendances
  "FiertéNoire",
  "AfroArt",
  "DiasporaAfricaine",
  "HistoireAfricaine",
  "BeautéNaturelle",
  "CultureTogolaise",
  "ModeEthnique",
  "ArtAfro",
];

