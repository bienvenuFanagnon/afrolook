import 'package:flutter/material.dart';
import '../widgets/pseudo_tag.dart';
import '../widgets/canal_tag.dart';

class TextCustomerUserTitle extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextCustomerUserTitle({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    // Les pseudos (« @prenom.nom ») s'affichent en capsule Afrolook partout dans l'app.
    if (CanalTag.isCanalLabel(titre)) {
      return CanalTag(
        label: titre,
        style: TextStyle(fontSize: fontSize, color: couleur, fontWeight: fontWeight),
      );
    }
    if (PseudoTag.isPseudoLabel(titre)) {
      return PseudoTag(
        label: titre,
        style: TextStyle(fontSize: fontSize, color: couleur, fontWeight: fontWeight),
      );
    }
    return Text(
      titre,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        color: couleur,
        fontWeight: fontWeight,
        fontStyle: FontStyle.italic
      ),
    );
  }
}
class TextCustomerPostDescription extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextCustomerPostDescription({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (CanalTag.isCanalLabel(titre)) {
      return CanalTag(
        label: titre,
        style: TextStyle(fontSize: fontSize, color: couleur, fontWeight: fontWeight),
      );
    }
    if (PseudoTag.isPseudoLabel(titre)) {
      return PseudoTag(
        label: titre,
        style: TextStyle(fontSize: fontSize, color: couleur, fontWeight: fontWeight),
      );
    }
    return Text(
      titre,
      //overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: fontSize,
          color: couleur,
          fontWeight: fontWeight,
          //fontStyle: FontStyle.italic
      ),
    );
  }
}
class TextDatePost extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextDatePost({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titre,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontSize: fontSize,
        color: couleur,
        fontWeight: fontWeight,
        //fontStyle: FontStyle.italic
      ),
    );
  }
}
class TextCustomerMenu extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextCustomerMenu({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titre,
      //overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        color: couleur,
        fontWeight: fontWeight,
        //fontStyle: FontStyle.italic
      ),
    );
  }
}

class TextCustomerIntroIa extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextCustomerIntroIa({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titre,
      //overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        letterSpacing: 1,
        fontSize: fontSize,
        color: couleur,
        fontWeight: fontWeight,
        //fontStyle: FontStyle.italic
      ),
    );
  }
}

class TextCustomerPageTitle extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextCustomerPageTitle({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titre,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: fontSize,
          color: couleur,
          fontWeight: fontWeight,
          fontStyle: FontStyle.italic
      ),
    );
  }
}
class TextStatutDescription extends StatelessWidget {
  final String titre;
  final double fontSize;
  final Color couleur;
  final FontWeight fontWeight;

  TextStatutDescription({
    required this.titre,
    required this.fontSize,
    required this.couleur,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titre,
      //overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: fontSize,
          color: couleur,
          fontWeight: fontWeight,
          fontStyle: FontStyle.normal

      ),
    );
  }
}