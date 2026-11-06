import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// Couleurs du Studio : elles suivent le thème clair ou sombre de la personne (le Studio était figé en sombre).
/// Chaque écran du Studio appelle [syncStudioColors] au début de son `build` : les couleurs `_c` du fichier lisent alors le thème courant.
AppColors studioColors = AppColors.dark;

void syncStudioColors(BuildContext context) => studioColors = AppColors.of(context);
