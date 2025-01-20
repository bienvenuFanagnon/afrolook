import 'dart:convert';

import 'package:afrotok/providers/authProvider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart';

enum MediaType { image, video, text }

// class WhatsappStory {
//   final MediaType? mediaType;
//   final String? media;
//   final double? duration;
//   final String? caption;
//   final String? when;
//   final String? color;
//
//   WhatsappStory({
//     this.mediaType,
//     this.media,
//     this.duration,
//     this.caption,
//     this.when,
//     this.color,
//   });
// }

class WhatsappStory {
  MediaType? mediaType;
  final String? media;
  final double? duration;
  final String? caption;
  String? when;
  String? color;
  int nbrVues;
  List<String> vues;
  int nbrJaimes;
  List<String> jaimes;
  int createdAt;
  int updatedAt;

  WhatsappStory({
    this.mediaType,
    this.media,
    this.duration,
    this.caption,
    this.when,
    this.color,
    this.nbrVues = 0,
    this.vues = const [],
    this.nbrJaimes = 0,
    this.jaimes = const [],
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // Fonction pour incrémenter le nombre de vues
  // void incrementViews(String userId,AuthProvider authProvider) {
  //   if (!vues.contains(userId)) {
  //     vues.add(userId);
  //     nbrVues = vues.length;
  //     updatedAt = DateTime.now().millisecondsSinceEpoch;
  //
  //   }
  // }

  // Fonction pour ajouter ou retirer un "j'aime"
  // void toggleLike(String userId,UserAuthProvider authProvider,UserData user) {
  //   if (jaimes.contains(userId)) {
  //     jaimes.remove(userId);
  //   } else {
  //     jaimes.add(userId);
  //   }
  //   nbrJaimes = jaimes.length;
  //   updatedAt = DateTime.now().millisecondsSinceEpoch;
  //   user
  //   authProvider.updateUser(this);
  //
  // }

  // Fonction pour retourner un JSON
  Map<String, dynamic> toJson() {
    return {
      'mediaType':media!.isEmpty?"text":"image",
      'media': media,
      'duration': duration,
      'caption': caption,
      'when': when,
      'color': color,
      'nbrVues': nbrVues,
      'vues': vues,
      'nbrJaimes': nbrJaimes,
      'jaimes': jaimes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Fonction pour créer une instance de WhatsappStory à partir d'un JSON
  factory WhatsappStory.fromJson(Map<String, dynamic> json) {
    return WhatsappStory(
      mediaType: MediaType.values.firstWhere((e) => e.name.toString() == json['mediaType']),
      media: json['media'],
      duration: double.parse(json['duration'].toString()),
      caption: json['caption'],
      when: json['when'],
      color: json['color'],
      nbrVues: json['nbrVues'],
      vues: List<String>.from(json['vues']),
      nbrJaimes: json['nbrJaimes'],
      jaimes: List<String>.from(json['jaimes']),
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

class Highlight {
  final String? image;
  final String? headline;

  Highlight({this.image, this.headline});
}

class Gnews {
  final String? title;
  final List<Highlight>? highlights;

  Gnews({this.title, this.highlights});
}

/// The repository fetches the data from the same directory from git.
/// This is just to demonstrate fetching from a remote (workflow).
class Repository {
  static MediaType _translateType(String? type) {
    if (type == "image") {
      return MediaType.image;
    }

    if (type == "video") {
      return MediaType.video;
    }

    return MediaType.text;
  }

  static Future<List<WhatsappStory>> getWhatsappStories(List<WhatsappStory>? data) async {
    final uri =
        "https://raw.githubusercontent.com/blackmann/storyexample/master/lib/data/whatsapp.json";
    // final response = await get(Uri.parse(uri));

    // final data = jsonDecode(utf8.decode(response.bodyBytes))['data'];

    final res = data!.map<WhatsappStory>((it) {
      return WhatsappStory(
          caption: it.caption,
          media: it.media,
          duration: double.parse(it.duration.toString()),
          when: it.when,
          mediaType: _translateType(it.mediaType!.name!),
          color: it.color);
    }).toList();

    return res;
  }

  static Future<Gnews> getNews() async {
    final uri =
        "https://raw.githubusercontent.com/blackmann/storyexample/master/lib/data/gnews.json";
    final response = await get(Uri.parse(uri));

    // use utf8.decode to make emojis work
    final data = jsonDecode(utf8.decode(response.bodyBytes))['data'];

    final title = data['title'];
    final highlights = data['highlights'].map<Highlight>((it) {
      return Highlight(headline: it['headline'], image: it['image']);
    }).toList();

    return Gnews(title: title, highlights: highlights);
  }
}
