
import 'package:flutter/material.dart';

import 'HomeConstPost.dart';

class ActualitePage extends StatefulWidget {
  const ActualitePage({super.key, required this.type});
  final String type;

  @override
  State<ActualitePage> createState() => _ActualitePageState();
}

class _ActualitePageState extends State<ActualitePage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type);
  }
}
