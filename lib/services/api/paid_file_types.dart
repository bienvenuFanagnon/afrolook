/// Types de fichiers acceptés par l'API pour les contenus PAYANTS (fiche 38, §2.6). Ils ne passent que par un envoi PRIVÉ (`private: true` de
/// `POST /uploads`), jamais en public. Les types publics restent jpeg/png/webp, mp4, mp3, m4a, pdf, zip.
/// Les fichiers `.xmp`, `.cube`, `.lut` n'ont pas de type fiable : il faut les mettre dans un `.zip`.
class PaidFileTypes {
  PaidFileTypes._();

  /// Extension -> type MIME pour un envoi privé (ce que le serveur accepte, ni plus ni moins).
  static const Map<String, String> mimeByExtension = {
    // déjà acceptés en public
    'mp4': 'video/mp4',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    // ajoutés pour les fichiers payants
    'wav': 'audio/wav',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'epub': 'application/epub+zip',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'psd': 'image/vnd.adobe.photoshop',
    '7z': 'application/x-7z-compressed',
    'rar': 'application/vnd.rar',
  };

  static const List<String> audio = ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'];
  static const List<String> video = ['mp4', 'mov', 'webm'];
  static const List<String> documents = ['pdf', 'epub', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'];
  static const List<String> archives = ['zip', '7z', 'rar', 'psd'];

  /// Taille maximale (Mo) d'un fichier payant selon son genre : audio 50 Mo (30 Mo en public), le reste suit les plafonds du serveur.
  static const int audioMaxMb = 50;

  /// Type MIME d'un fichier d'après son nom ou son chemin (null si l'extension n'est pas acceptée par le serveur).
  static String? mimeFor(String pathOrName) {
    final i = pathOrName.lastIndexOf('.');
    if (i < 0 || i == pathOrName.length - 1) return null;
    return mimeByExtension[pathOrName.substring(i + 1).toLowerCase()];
  }

  /// Vrai si l'extension est acceptée pour un fichier payant.
  static bool isAccepted(String pathOrName) => mimeFor(pathOrName) != null;
}
