import 'package:afrotok/l10n/tr_montage.dart';
import 'package:afrotok/services/music_clip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Son sur un film (08/11/2026) : durée, répétition avec raccord, coupure, fondus, « caler la fin du son sur la fin de la vidéo ». Mêmes règles que le serveur.
void main() {
  test('son plus court que le film : répété ; plus long : coupé ; presque pareil : ni l\'un ni l\'autre', () {
    const short = MusicClipPlan(clipMs: 7000, startMs: 0, trackMs: 2000);
    expect(short.loops, isTrue);
    expect(short.cuts, isFalse);
    expect(short.repeats, 5);   // (7 − 0,4) ÷ (2 − 0,4) = 4,1 : il faut 5 reprises (5 x 2 − 4 x 0,4 = 8,4 s) ; même calcul que le serveur
    const long = MusicClipPlan(clipMs: 4000, startMs: 3000, trackMs: 10000);
    expect(long.cuts, isTrue);
    expect(long.loops, isFalse);
    expect(long.repeats, 1);
    const same = MusicClipPlan(clipMs: 15000, startMs: 0, trackMs: 15400);
    expect(same.loops, isFalse);
    expect(same.cuts, isFalse);
    // le point de départ compte : 10 s de son joués depuis la seconde 8 n'ont que 2 s devant eux
    const late = MusicClipPlan(clipMs: 7000, startMs: 8000, trackMs: 10000);
    expect(late.availableMs, 2000);
    expect(late.loops, isTrue);
    // durée du son inconnue : on ne dit rien
    const unknown = MusicClipPlan(clipMs: 7000, startMs: 0);
    expect(unknown.loops, isFalse);
    expect(unknown.cuts, isFalse);
    expect(unknown.alignedStartMs, isNull);
  });

  test('caler la fin du son sur la fin de la vidéo : le début est choisi pour que le son se termine avec le film', () {
    const p = MusicClipPlan(clipMs: 15000, startMs: 0, trackMs: 60000);
    expect(p.alignedStartMs, 45000);
    expect(p.isAligned, isFalse);
    const done = MusicClipPlan(clipMs: 15000, startMs: 45000, trackMs: 60000);
    expect(done.isAligned, isTrue);
    expect(done.availableMs, 15000);
    expect(done.cuts, isFalse);
    // un son plus court que le film ne peut pas être calé
    expect(const MusicClipPlan(clipMs: 15000, startMs: 0, trackMs: 9000).alignedStartMs, isNull);
  });

  test('fondu d\'entrée de 0,3 s, fondu de sortie calé sur la fin (1,5 s au plus, un quart du film), rien hors du film', () {
    const p = MusicClipPlan(clipMs: 15000, startMs: 0, trackMs: 60000);
    expect(p.fadeOutMs, 1500);
    expect(p.volumeAt(0), 0);
    expect(p.volumeAt(150), closeTo(.5, .01));
    expect(p.volumeAt(300), 1);
    expect(p.volumeAt(7000), 1);
    expect(p.volumeAt(15000 - 750), closeTo(.5, .01));
    expect(p.volumeAt(14999), lessThan(.01));
    expect(p.volumeAt(-5), 0);
    expect(p.volumeAt(15000), 0);
    // un film court : le fondu de sortie vaut au plus le quart du film
    expect(const MusicClipPlan(clipMs: 4000, startMs: 0, trackMs: 9000).fadeOutMs, 1000);
  });

  test('aux raccords de répétition, le volume baisse un peu, puis revient', () {
    const p = MusicClipPlan(clipMs: 7000, startMs: 0, trackMs: 2000);   // raccord au bout de 2000 − 400 = 1600 ms
    final seam = p.volumeAt(1600);
    expect(seam, lessThan(.7));
    expect(p.volumeAt(1000), 1);
    expect(p.volumeAt(2400), 1);
  });

  test('« 1:05 » : minutes et secondes', () {
    expect(MusicClipPlan.mmss(65000), '1:05');
    expect(MusicClipPlan.mmss(0), '0:00');
  });

  test('toutes les phrases du montage sont traduites dans les 7 langues, avec les mêmes champs {…}', () {
    final holes = RegExp(r'\{[a-z]+\}');
    for (final e in kTrMontage.entries) {
      final fields = holes.allMatches(e.key).map((m) => m.group(0)).toSet();
      for (final lang in ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw']) {
        final t = e.value[lang];
        expect(t, isNotNull, reason: '${e.key} : $lang manquant');
        expect(t!.trim(), isNotEmpty, reason: '${e.key} : $lang vide');
        expect(holes.allMatches(t).map((m) => m.group(0)).toSet(), fields, reason: '${e.key} : champs différents en $lang');
      }
    }
  });
}
