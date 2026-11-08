import 'package:afrotok/services/collage_layouts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque mise en page a autant de cases que d\'images et remplit tout le cadre sans chevauchement', () {
    for (final n in [2, 3, 4, 5]) {
      for (final id in CollageLayouts.forCount(n)) {
        final cells = CollageLayouts.cells(id, n);
        expect(cells.length, n, reason: '$id pour $n images');
        var area = 0.0;
        for (final c in cells) {
          area += c.width * c.height;
          expect(c.left, greaterThanOrEqualTo(0));
          expect(c.right, lessThanOrEqualTo(1.0001));
          expect(c.bottom, lessThanOrEqualTo(1.0001));
        }
        expect(area, closeTo(1.0, 0.001), reason: '$id couvre tout le cadre');
        for (var i = 0; i < cells.length; i++) {
          for (var j = i + 1; j < cells.length; j++) {
            expect(cells[i].deflate(0.001).overlaps(cells[j].deflate(0.001)), isFalse, reason: '$id : cases $i et $j');
          }
        }
      }
    }
  });

  test('un identifiant qui ne convient pas au nombre d\'images donne la première mise en page possible', () {
    expect(CollageLayouts.cells('grid', 3), isEmpty);
    expect(CollageLayouts.cells0('grid', 3).length, 3);
    expect(CollageLayouts.forCount(2), ['tb', 'sbs']);
    expect(CollageLayouts.forCount(9), CollageLayouts.forCount(5));
  });

  test('l\'espace rétrécit chaque case sans en sortir ; 0 laisse les images collées', () {
    final cells = CollageLayouts.cells('sbs', 2);
    expect(CollageLayouts.withGap(cells, 0), cells);
    final g = CollageLayouts.withGap(cells, .04);
    expect(g[0].right, lessThan(.5));
    expect(g[1].left, greaterThan(.5));
    expect(g[0].width, lessThan(.5));
  });

  test('la zone d\'une image qui remplit une case est recadrée au centre, jamais déformée', () {
    final wide = CollageLayouts.coverSource(2000, 1000, 100, 100);   // image large dans une case carrée : on garde le milieu
    expect(wide.width, closeTo(1000, 0.01));
    expect(wide.left, closeTo(500, 0.01));
    final tall = CollageLayouts.coverSource(1000, 2000, 100, 100);
    expect(tall.height, closeTo(1000, 0.01));
    expect(tall.top, closeTo(500, 0.01));
    expect(CollageLayouts.coverSource(800, 400, 200, 100), const Rect.fromLTWH(0, 0, 800, 400));   // même format : tout l'image
  });
}
