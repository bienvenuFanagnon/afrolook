

import 'package:flutter/material.dart';

import 'HomeConstPost.dart';

class GamerPage extends StatefulWidget {
  const GamerPage({super.key, required this.type});
  final String type;

  @override
  State<GamerPage> createState() => _GamerPageState();
}

class _GamerPageState extends State<GamerPage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type);
  }
}

