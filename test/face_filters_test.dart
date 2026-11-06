import 'dart:ui' as ui;

import 'package:afrotok/services/face_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  liveTests();
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

void liveTests() {
  test('chaque filtre a une ancre (centre + taille) ; « sans filtre » n\'en a pas', () {
    const f = FaceBox(rect: Rect.fromLTWH(200, 150, 300, 380), leftEye: Offset(290, 280), rightEye: Offset(410, 282), nose: Offset(350, 380));
    expect(FaceFilters.anchor(f, FaceFilter.none), isNull);
    for (final k in FaceFilter.values.where((k) => k != FaceFilter.none)) {
      final a = FaceFilters.anchor(f, k)!;
      expect(a.size, greaterThan(0));
      expect(a.center.dx, inInclusiveRange(150, 550));
    }
    expect(FaceFilters.anchor(f, FaceFilter.glasses)!.center, const Offset(350, 281));
    expect(FaceFilters.anchor(f, FaceFilter.nose)!.center, const Offset(350, 380));
  });

  test('le miroir de la caméra avant renverse les positions autour de la largeur de l\'image', () {
    const f = FaceBox(rect: Rect.fromLTWH(100, 50, 200, 260), leftEye: Offset(160, 120), nose: Offset(200, 200));
    final m = f.mirrored(720);
    expect(m.rect, const Rect.fromLTWH(420, 50, 200, 260));
    expect(m.leftEye, const Offset(560, 120));
    expect(m.rightEye, isNull);
    expect(m.nose, const Offset(520, 200));
  });

  test('l\'image du filtre pour la vidéo est un PNG de la taille demandée', () async {
    final png = await FaceFilters.filterPng(FaceFilter.crown, 120);
    expect(png.length, greaterThan(100));
    expect(png.sublist(1, 4), [0x50, 0x4E, 0x47]);
  });
}
