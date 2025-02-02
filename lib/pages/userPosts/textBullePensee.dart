
import 'package:flutter/material.dart';


class ThoughtBubble extends StatelessWidget {
  final String text;

  ThoughtBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Grande bulle de pensée
        Positioned(
          bottom: 80,
          child: Card(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          left: 60,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
          ),
        ),
        // Petites bulles de pensée
        Positioned(
          bottom: 50,
          left: 50,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.white,
          ),
        ),

        Positioned(
          bottom: 40,
          left: 40,
          child: CircleAvatar(
            radius: 5,
            backgroundColor: Colors.white,
          ),
        ),
        // Icône de personne qui pense
        Positioned(
          bottom: 0,
          left: 2,
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
