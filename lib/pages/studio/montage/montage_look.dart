import 'package:flutter/material.dart';

/// « Look » : un réglage de couleur professionnel posé sur la photo ou la vidéo (comme les filtres d'Instagram), sans aucun élément animé.
///
/// Un look agit uniquement par la saturation, la luminosité et une teinte en dégradé : ce sont exactement les réglages que l'aperçu, l'image fixe et
/// l'assemblage de la vidéo par le serveur savent déjà appliquer, donc ce qu'on voit est ce qui est publié.
class MontageLook {
  const MontageLook({required this.id, required this.name, this.saturation = 1, this.brightness = 0, this.tint, this.swatch});

  final String id;
  final String name;
  final double saturation;
  final double brightness;

  /// Teinte en dégradé, du haut vers le bas de l'image (null = aucune).
  final List<Color>? tint;

  /// Couleurs de la pastille d'aperçu dans le sélecteur.
  final List<Color>? swatch;
}

/// Couleurs proposées pour le texte libre (blanc d'abord : le plus lisible sur une photo).
const List<Color> kFreeTextColors = [Color(0xFFFFFFFF), Color(0xFFFFD60A), Color(0xFF111111), Color(0xFFFF5A5F), Color(0xFF2EC4B6), Color(0xFF7BC96F)];

/// Looks proposés : sobres, dans l'esprit des filtres d'Instagram. « Modèle » (aucun look choisi) garde l'ambiance propre au modèle.
const List<MontageLook> kMontageLooks = [
  MontageLook(id: 'natural', name: 'Naturel', swatch: [Color(0xFFEFE6D8), Color(0xFF8D8A7E)]),
  MontageLook(id: 'gold', name: 'Doré', saturation: 1.08, brightness: .02, tint: [Color(0x2EFFB347), Color(0x14FF8C42)], swatch: [Color(0xFFFFD28A), Color(0xFFC77D2B)]),
  MontageLook(id: 'cinema', name: 'Cinéma', saturation: .92, brightness: -.03, tint: [Color(0x2600707A), Color(0x26C5651D)], swatch: [Color(0xFF2A7F86), Color(0xFFD08A4B)]),
  MontageLook(id: 'mono', name: 'Noir et blanc', saturation: 0, brightness: .02, swatch: [Color(0xFFE9E9E9), Color(0xFF3A3A3A)]),
  MontageLook(id: 'matte', name: 'Mat', saturation: .78, brightness: .06, tint: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)], swatch: [Color(0xFFD9D4CC), Color(0xFF9A948B)]),
  MontageLook(id: 'vivid', name: 'Éclat', saturation: 1.25, brightness: .02, swatch: [Color(0xFFFF7A59), Color(0xFF2EC4B6)]),
  MontageLook(id: 'earth', name: 'Terre', saturation: 1.05, tint: [Color(0x26A0522D), Color(0x1F6B3A1E)], swatch: [Color(0xFFC98A5E), Color(0xFF6B3A1E)]),
  MontageLook(id: 'night', name: 'Nuit', saturation: .85, brightness: -.08, tint: [Color(0x2A0B1E4A), Color(0x33050B24)], swatch: [Color(0xFF263B7A), Color(0xFF0A1230)]),
];
