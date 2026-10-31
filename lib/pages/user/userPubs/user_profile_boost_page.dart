import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';

import 'user_create_advertisement_page.dart';

/// Boost d'un profil, d'un canal ou d'un groupe de chat.
/// En attente de la route serveur « boost payé en pièces » : voir connaissances/lacunes_api_compte_boosts.md.
class UserProfileBoostPage extends StatelessWidget {
  /// Si null → boost du profil utilisateur.
  final Canal? canal;

  /// Si non-null → boost du groupe de chat spécifié.
  final Map<String, dynamic>? group;

  const UserProfileBoostPage({Key? key, this.canal, this.group}) : super(key: key);

  @override
  Widget build(BuildContext context) => const BoostSoonView(titre: 'Booster');
}
