import 'package:flutter/material.dart';

class IconPersonaliser extends StatelessWidget {
  final IconData icone;
  final double size;

  IconPersonaliser({required this.icone, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(

      child:  Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [Colors.green, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds);
          },
          child: Icon(
            icone,
            size: size,
            color: Colors.white, // Couleur de l'icône (blanc dans cet exemple)
          ),
        ),
      ),
    );

  }
}