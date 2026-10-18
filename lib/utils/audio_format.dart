import 'dart:typed_data';

/// Format réel d'un fichier audio, reconnu à ses premiers octets.
///
/// Pourquoi : Android lit un fichier même si son étiquette est fausse, iPhone et iPad non. Un mp3 étiqueté « audio/mp4 » ou
/// rangé dans un fichier « .m4a » est refusé par iOS (erreur « impossible d'ouvrir »). On donne donc au lecteur le vrai type.
enum AudioKind {
  mp3('audio/mpeg', 'mp3', true),
  m4a('audio/mp4', 'm4a', true),
  aac('audio/aac', 'aac', true),
  wav('audio/wav', 'wav', true),
  flac('audio/flac', 'flac', true),
  ogg('audio/ogg', 'ogg', false),
  webm('audio/webm', 'webm', false),
  amr('audio/amr', 'amr', false),
  unknown('audio/mp4', 'm4a', true);

  const AudioKind(this.mime, this.ext, this.appleCompatible);
  final String mime;
  final String ext;

  /// Lisible par iPhone et iPad sans conversion.
  final bool appleCompatible;

  /// Reconnaît le format d'après le début du fichier (12 octets suffisent).
  static AudioKind sniff(List<int> b) {
    if (b.length < 4) return AudioKind.unknown;
    bool at(int i, String s) {
      if (b.length < i + s.length) return false;
      for (var k = 0; k < s.length; k++) {
        if (b[i + k] != s.codeUnitAt(k)) return false;
      }
      return true;
    }

    if (at(0, 'ID3')) return AudioKind.mp3;
    if (at(0, 'RIFF') && at(8, 'WAVE')) return AudioKind.wav;
    if (at(0, 'OggS')) return AudioKind.ogg;
    if (at(0, 'fLaC')) return AudioKind.flac;
    if (at(4, 'ftyp')) return AudioKind.m4a;
    if (at(0, '#!AMR')) return AudioKind.amr;
    if (b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) return AudioKind.webm;
    if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
      // Trame MPEG : couche III = mp3 ; ADTS (couche 00) = AAC brut
      final layer = (b[1] >> 1) & 0x03;
      return layer == 0 ? AudioKind.aac : AudioKind.mp3;
    }
    return AudioKind.unknown;
  }

  static AudioKind sniffBytes(Uint8List b) => sniff(b.length > 16 ? b.sublist(0, 16) : b);
}
