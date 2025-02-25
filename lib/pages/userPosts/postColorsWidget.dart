import 'dart:convert';

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
Future<Map<String, String?>> extractColorsFromImageUrl(String imageUrl) async {
  String? colorToHex(Color? color) {
    if (color == null) return null;
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }
  try {
    final ui.Image image = await loadImage(imageUrl);
    final PaletteGenerator palette = await PaletteGenerator.fromImage(image);



    final colorMap = {
      'dominantColor': colorToHex(palette.dominantColor?.color),
      'vibrantColor': colorToHex(palette.vibrantColor?.color),
      'lightVibrantColor': colorToHex(palette.lightVibrantColor?.color),
      'darkVibrantColor': colorToHex(palette.darkVibrantColor?.color),
      'mutedColor': colorToHex(palette.mutedColor?.color),
      'lightMutedColor': colorToHex(palette.lightMutedColor?.color),
      'darkMutedColor': colorToHex(palette.darkMutedColor?.color),
    };

    print("colorMap : ${jsonEncode(colorMap)}");
    return colorMap;
  } catch (e) {
    print('Erreur lors de l\'extraction des couleurs : $e');

    final colorMap = {
      'dominantColor': colorToHex(Colors.green),
      'vibrantColor': colorToHex(Colors.black38),
      // 'lightVibrantColor': colorToHex(palette.lightVibrantColor?.color),
      // 'darkVibrantColor': colorToHex(palette.darkVibrantColor?.color),
      // 'mutedColor': colorToHex(palette.mutedColor?.color),
      // 'lightMutedColor': colorToHex(palette.lightMutedColor?.color),
      // 'darkMutedColor': colorToHex(palette.darkMutedColor?.color),
    };
    return colorMap;
  }
}

Future<ui.Image> loadImage(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));
  final Uint8List bytes = response.bodyBytes;
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(bytes, (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}