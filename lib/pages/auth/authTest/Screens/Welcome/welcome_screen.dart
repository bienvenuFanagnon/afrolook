import 'dart:math';

import 'package:flutter/material.dart';

import '../../components/background.dart';
import '../../responsive.dart';
import 'components/login_signup_btn.dart';
import 'components/welcome_image.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  Background(
      child: SingleChildScrollView(
        child: SafeArea(
          child: Responsive(

            mobile: MobileWelcomeScreen(),
            desktop: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: WelcomeImage(),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 450,
                        child: LoginAndSignupBtn(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileWelcomeScreen extends StatefulWidget {
  const MobileWelcomeScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<MobileWelcomeScreen> createState() => _MobileWelcomeScreenState();
}

class _MobileWelcomeScreenState extends State<MobileWelcomeScreen> {
  late Random random = Random();
  late int imageNumber = 1; // Génère un nombre entre 1 et 6
  @override
  void initState() {
    // TODO: implement initState
    imageNumber = random.nextInt(6) + 1; // Génère un nombre entre 1 et 6

    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return  Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/splash/${imageNumber}.jpg'), // Chemin de votre image
          fit: BoxFit.cover, // Pour couvrir tout l'écran
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          WelcomeImage(),
          SizedBox(height: height*0.1,),
          Row(
            children: [
              Spacer(),
              Expanded(
                flex: 8,
                child: LoginAndSignupBtn(),
              ),
              Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}
