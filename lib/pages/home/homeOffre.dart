

import 'package:flutter/material.dart';

import 'HomeConstPost.dart';

class OffrePage extends StatefulWidget {
  const OffrePage({super.key, required this.type});
  final String type;

  @override
  State<OffrePage> createState() => _OffrePageState();
}

class _OffrePageState extends State<OffrePage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type);
  }
}

