import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants.dart';

class WelcomeImage extends StatelessWidget {
  const WelcomeImage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: const Text(
              "Bienvenue chez Afrolook",
              style: TextStyle(fontWeight: FontWeight.w900,fontSize: 30,color: Colors.green),
            ),
          ),
        ),
        // const SizedBox(height: defaultPadding * 2),
        // Row(
        //   children: [
        //     const Spacer(),
        //     // Expanded(
        //     //   flex: 8,
        //     //   child:Image.asset('assets/images/welcomtof.png') ,
        //     //     /*
        //     //     SvgPicture.asset(
        //     //       "assets/icons/chat.svg",
        //     //     )*/
        //     // ),
        //     // const Spacer(),
        //   ],
        // ),
        const SizedBox(height: defaultPadding * 2),
      ],
    );
  }
}