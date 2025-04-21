

import 'package:flutter/material.dart';

import 'HomeConstPost.dart';

class SportPage extends StatefulWidget {
  const SportPage({super.key, required this.type});
  final String type;

  @override
  State<SportPage> createState() => _SportPageState();
}

class _SportPageState extends State<SportPage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type);
  }
}

