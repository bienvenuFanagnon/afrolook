import 'dart:ui' as ui;

import 'package:afrotok/services/face_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque filtre se dessine sur un visage sans erreur, même sans repères des yeux ni du nez', () {
    const full = FaceBox(rect: Rect.fromLTWH(200, 150, 300, 380), leftEye: Offset(290, 280), rightEye: Offset(410, 282), nose: Offset(350, 380));
    const bare = FaceBox(rect: Rect.fromLTWH(200, 150, 300, 380));
    for (final f in FaceFilter.values) {
      for (final face in [full, bare]) {
        final rec = ui.PictureRecorder();
        FaceFilters.drawOn(Canvas(rec), face, f);
        rec.endRecording().dispose();
      }
    }
  });

  test('un visage se lit depuis la réponse du canal Android', () {
    final f = FaceBox.fromMap({'left': 10, 'top': 20, 'width': 100, 'height': 140, 'leftEye': {'x': 40.0, 'y': 60.0}, 'nose': {'x': 60.0, 'y': 90.0}});
    expect(f.rect, const Rect.fromLTWH(10, 20, 100, 140));
    expect(f.leftEye, const Offset(40, 60));
    expect(f.rightEye, isNull);
    expect(f.nose, const Offset(60, 90));
  });

  test('chaque filtre a un emoji, « sans filtre » n\'en a pas ; hors Android la liste est cachée', () {
    expect(FaceFilters.emoji(FaceFilter.none), '');
    for (final f in FaceFilter.values.where((f) => f != FaceFilter.none)) {
      expect(FaceFilters.emoji(f), isNotEmpty);
    }
  });
}
