import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../auth/authTest/Screens/Login/loginPageUser.dart';



class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  OnBoardingPageState createState() => OnBoardingPageState();
}

class OnBoardingPageState extends State<IntroductionPage> {
  final introKey = GlobalKey<IntroductionScreenState>();

  void _onIntroEnd(context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) =>  LoginPageUser()),
    );
  }

  Widget _buildFullscreenImage() {
    return Image.asset(
      'assets/images/cosmetiques-bio-avantages-inconvenients.jpg',
      fit: BoxFit.cover,
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
    );
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset('assets/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0);

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: IntroductionScreen(
        key: introKey,
        globalBackgroundColor: Colors.white,
        allowImplicitScrolling: true,
        autoScrollDuration: 3000,
        infiniteAutoScroll: true,
        globalHeader: Align(
          alignment: Alignment.topRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: _buildImage('logo/afrolook_logo.png', 50),
            ),
          ),
        ),
        globalFooter: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            child: const Text(
              'Allons-y tout de suite !',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold,color: Colors.green),
            ),
            onPressed: () => _onIntroEnd(context),
          ),
        ),
        pages: [
          PageViewModel(
            title: "Bienvenue dans Afrolook, le réseau social africain !",
            body:
            "Connectez-vous avec vos amis\n Partagez vos photos et vidéos\n Monétisez votre contenu\n Suivez les actualités et les événements qui vous intéressent \n",
            image: _buildImage('images/Mobile feed-bro.png'),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: "Gagnez des points et des prix avec Afrolook !",
            body:
            "Gagnez des points en: \n s'abonnant\n likant, \n commentant... \n",
            image: _buildImage('images/6075540.jpg'),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: "Afrolook, le réseau social qui vous met en valeur !",
            body:
            "Afrolook est conçu pour vous mettre en valeur et vous aider à atteindre vos objectifs. Développez votre popularité, boostez votre visibilité et faites-vous connaître auprès d'un large public.",
            image: _buildImage('images/Followers-amico.png'),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: "Monétisez votre audience avec Afrolook !",
            body:
            "Afrolook vous donne la possibilité de monétiser votre audience en acceptant des partenariats avec des entreprises.",
            image: _buildImage('images/45060.jpg'),
            decoration: pageDecoration,
          ),

        ],
        onDone: () => _onIntroEnd(context),
        onSkip: () => _onIntroEnd(context), // You can override onSkip callback
        showSkipButton: true,
        skipOrBackFlex: 0,
        nextFlex: 0,
        showBackButton: false,
        //rtl: true, // Display as right-to-left
        back: const Icon(Icons.arrow_back,color: Colors.green),
        skip: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600,color: Colors.green)),
        next: const Icon(Icons.arrow_forward,color: Colors.green),
        done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600,color: Colors.green)),
        curve: Curves.fastLinearToSlowEaseIn,
        controlsMargin: const EdgeInsets.all(16),
        controlsPadding: kIsWeb
            ? const EdgeInsets.all(12.0)
            : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
        dotsDecorator: const DotsDecorator(
          size: Size(10.0, 10.0),
          color: Color(0xFFBDBDBD),
          activeColor: Colors.green,
          activeSize: Size(22.0, 10.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
        ),
        dotsContainerDecorator: const ShapeDecoration(
          color: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),
      ),
    );
  }
}