import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants.dart';

class WelcomeImage extends StatelessWidget {
  const WelcomeImage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final random = Random();
    final imageNumber = random.nextInt(4) + 1; // Génère un nombre entre 1 et 5
    return Column(
      children: [
        const Text(
          "Bienvenue chez Afrolook",
          style: TextStyle(fontWeight: FontWeight.w800,fontSize: 20),
        ),
        const SizedBox(height: defaultPadding * 2),
        Row(
          children: [
            const Spacer(),
            Expanded(
              flex: 8,
              child:Image.asset('assets/splash/${imageNumber}.jpg') ,
                /*
                SvgPicture.asset(
                  "assets/icons/chat.svg",
                )*/
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: defaultPadding * 2),
      ],
    );
  }
}