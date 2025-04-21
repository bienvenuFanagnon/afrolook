

import 'package:flutter/material.dart';

import 'HomeConstPost.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key, required this.type});
  final String type;

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  @override
  Widget build(BuildContext context) {
    return HomeConstPostPage(type: widget.type);
  }
}

