import '../models/model_data.dart' show Canal;
import 'watermark.dart';

/// Signature du montage (08/11/2026) : le @pseudo de la personne, ou « #titre » quand le post est publié DANS UN CANAL (jamais le pseudo à la place du canal).
/// Remplie par la page d'édition du parcours « Créer un post » (qui connaît le canal) et effacée à sa fermeture ; l'éditeur de montage la lit.
class MontageSignature {
  MontageSignature._();

  static String? canalTitle;
  static String? canalImage;
  static int canalMembers = 0;

  static void setCanal(Canal? c) {
    canalTitle = c?.titre;
    canalImage = c?.urlImage;
    canalMembers = c?.membersCount ?? 0;
  }

  static void clear() => setCanal(null);

  /// Le post est publié dans un canal qui a un nom.
  static bool get isCanal => Watermark.channelLabel(canalTitle).isNotEmpty;

  /// Libellé de la signature : « #titre » pour un canal, sinon le pseudo tel quel (l'écran ajoute le « @»).
  static String label(String? pseudo) => isCanal ? Watermark.channelLabel(canalTitle) : (pseudo ?? '');

  /// Photo à côté de la signature : celle du canal (ou aucune), sinon celle de la personne.
  static String? avatar(String? own) => isCanal ? ((canalImage ?? '').isEmpty ? null : canalImage) : own;

  /// Abonnés affichés : ceux du canal, sinon ceux de la personne.
  static int followers(int own) => isCanal ? canalMembers : own;

  /// Libellé de la fin animée Afrolook : « #titre » ou « @pseudo ».
  static String outroLabel(String? pseudo) => isCanal ? Watermark.channelLabel(canalTitle) : Watermark.userLabel(pseudo);
}
