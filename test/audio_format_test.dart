import 'package:afrotok/utils/audio_format.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _b(String s, {int at = 0, int len = 16}) {
  final out = List<int>.filled(len, 0);
  for (var i = 0; i < s.length; i++) {
    out[at + i] = s.codeUnitAt(i);
  }
  return out;
}

void main() {
  test('reconnaît les formats courants', () {
    expect(AudioKind.sniff(_b('ID3')), AudioKind.mp3);
    expect(AudioKind.sniff([0xFF, 0xFB, 0x90, 0x00, 0, 0]), AudioKind.mp3);
    expect(AudioKind.sniff([0xFF, 0xF1, 0x50, 0x80, 0, 0]), AudioKind.aac);
    expect(AudioKind.sniff(_b('ftyp', at: 4)), AudioKind.m4a);
    expect(AudioKind.sniff([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]), AudioKind.wav);
    expect(AudioKind.sniff(_b('OggS')), AudioKind.ogg);
    expect(AudioKind.sniff(_b('fLaC')), AudioKind.flac);
    expect(AudioKind.sniff([0x1A, 0x45, 0xDF, 0xA3, 0, 0]), AudioKind.webm);
  });

  test('iPhone / iPad : ogg, webm, amr à convertir ; le reste se lit tel quel', () {
    expect(AudioKind.mp3.appleCompatible, isTrue);
    expect(AudioKind.m4a.appleCompatible, isTrue);
    expect(AudioKind.ogg.appleCompatible, isFalse);
    expect(AudioKind.webm.appleCompatible, isFalse);
    expect(AudioKind.mp3.mime, 'audio/mpeg');
    expect(AudioKind.wav.ext, 'wav');
  });

  test('fichier trop court ou inconnu : m4a par défaut', () {
    expect(AudioKind.sniff([1, 2]), AudioKind.unknown);
    expect(AudioKind.sniff(List.filled(16, 7)), AudioKind.unknown);
    expect(AudioKind.unknown.mime, 'audio/mp4');
  });
}
