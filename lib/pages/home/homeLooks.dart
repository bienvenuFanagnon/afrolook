

import 'package:afrotok/pages/home/HomeConstPost.dart';
import 'package:flutter/material.dart';


class LooksPage extends StatefulWidget {
  const LooksPage({super.key, required this.type,this.sortType, this.feedKey});
  final String type;
  final String? sortType; // 'recent', 'popular', ou null pour l'algorithme par défaut
  // Clé exposée pour permettre à homeScreen de déclencher le filtre pays
  // et le rafraîchissement depuis sa barre supérieure combinée.
  final GlobalKey<State<HomeConstPostPage>>? feedKey;


  @override
  State<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends State<LooksPage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(key: widget.feedKey, type: widget.type,sortType: widget.sortType,);
  }
}

