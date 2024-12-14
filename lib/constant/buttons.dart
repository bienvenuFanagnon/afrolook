import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/constant/textCustom.dart';
import 'package:flutter/material.dart';

import 'constColors.dart';

class AchatJetonButton extends StatelessWidget {
  const AchatJetonButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: 100,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(

                  child: Image.asset(
                    'assets/icon/b1.png',
                    height: 15,
                    width: 15,
                  ),
                ),
                SizedBox(width: 5,),
                Container(
                  child: TextCustomerPostDescription(
                    titre: "Jetons",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
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
class SimpleButton extends StatelessWidget {
  final double width;
  final double height;
  const SimpleButton({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child:  Container(
              child: TextCustomerPostDescription(
                titre: "Commencer",
                fontSize: SizeText.textButtonSimpleSize,
                couleur: ConstColors.textColors,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class AchatPubliCachButton extends StatelessWidget {
  const AchatPubliCachButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: 110,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(

                  child: Image.asset(
                    'assets/icon/b1.png',
                    height: 15,
                    width: 15,
                  ),
                ),
                SizedBox(width: 5,),
                Container(
                  child: TextCustomerPostDescription(
                    titre: "publicach",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
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
class AddProduitButton extends StatelessWidget {
  const AddProduitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: 150,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(

                  child: Image.asset(
                    'assets/icon/b1.png',
                    height: 15,
                    width: 15,
                  ),
                ),
                SizedBox(width: 5,),
                Container(
                  child: TextCustomerPostDescription(
                    titre: "Creer un produit",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
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
class AddPubButton extends StatelessWidget {
  const AddPubButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: 130,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(

                  child: Image.asset(
                    'assets/icon/b1.png',
                    height: 15,
                    width: 15,
                  ),
                ),
                SizedBox(width: 5,),
                Container(
                  child: TextCustomerPostDescription(
                    titre: "Créer une publicité",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
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

class PostsButtons extends StatelessWidget {
  final String text;
  final String urlImage;
  final double hauteur;
  final double largeur;
  const PostsButtons({super.key, required this.text,  this.hauteur=100.0,  this.largeur=100.0, required this.urlImage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(100)),
        child: Container(
          alignment: Alignment.center,
          color: ConstColors.buttonsColors,
          width: largeur,
          height: hauteur,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [


                Container(
                  child: TextCustomerPostDescription(
                    titre: "${text}",
                    fontSize: SizeText.textButtonSimpleSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 5,),
                urlImage.length>5? Container(

                  child: Image.asset(
                    '${urlImage}',
                    height: 17,
                    width: 18,
                  ),
                ):Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
