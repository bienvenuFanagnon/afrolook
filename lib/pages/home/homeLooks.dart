

import 'package:afrotok/pages/home/HomeConstPost.dart';
import 'package:flutter/material.dart';


class LooksPage extends StatefulWidget {
  const LooksPage({super.key, required this.type,this.sortType});
  final String type;
  final String? sortType; // 'recent', 'popular', ou null pour l'algorithme par défaut


  @override
  State<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends State<LooksPage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type,sortType: widget.sortType,);
  }
}

