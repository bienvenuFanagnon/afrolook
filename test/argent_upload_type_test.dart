import 'package:afrotok/services/api/argent_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le type d\'une image est lu dans son contenu, pas dans son extension', () {
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
    final jpg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];
    final webp = [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50];
    final gif = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];
    expect(ArgentUpload.sniffImageType(png, path: '/tmp/capture.jpg'), 'image/png');   // une capture PNG sous un nom en .jpg
    expect(ArgentUpload.sniffImageType(jpg, path: '/tmp/photo.png'), 'image/jpeg');
    expect(ArgentUpload.sniffImageType(webp, path: 'x.jpg'), 'image/webp');
    expect(ArgentUpload.sniffImageType(gif, path: 'x.jpg'), 'image/gif');
    expect(ArgentUpload.sniffImageType([1, 2, 3], path: 'x.webp'), 'image/webp');   // inconnu : l'extension décide
  });
}
