/// Résultats échangés entre les écrans du parcours « Créer un post » (menu, choix du type, caméra, éditeur, formulaire final).
///
/// Le formulaire final se ferme toujours par un `Navigator.pop` : sans valeur quand le post est publié (ou le formulaire fermé), avec [kCreateBack]
/// quand la personne revient en arrière. Les écrans qui l'ont ouvert se ferment à leur tour dans le premier cas, et restent dans le second.
library;

/// La personne est revenue en arrière depuis le formulaire final : l'écran précédent (éditeur, choix du type) reste ouvert.
const String kCreateBack = 'back';

/// Le post est publié (ou le parcours est terminé) : les écrans du parcours se referment jusqu'à l'accueil.
const String kCreateDone = 'done';

/// Retour de l'éditeur : la personne veut refaire (rouvrir la caméra ou la galerie).
const String kCreateRedo = 'redo';

/// Les types de post du formulaire final, dans l'ordre des onglets de [UserPostForm] (qui reste le moteur de publication).
enum CreatePostKind {
  audio(0),
  text(1),
  image(2),
  video(3);

  const CreatePostKind(this.tab);

  /// Position de l'onglet dans [UserPostForm].
  final int tab;
}
