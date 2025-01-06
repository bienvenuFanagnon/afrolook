import 'package:flutter/material.dart';

import '../constants.dart';

class AlreadyHaveAnAccountCheck extends StatelessWidget {
  final bool login;
  final Function? press;
  const AlreadyHaveAnAccountCheck({
    Key? key,
    this.login = true,
    required this.press,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          login ? "Vous n'avez pas de compte ? " : "Vous avez déjà un compte ? ",
          style: TextStyle(color:login ?Colors.white: Colors.black),
        ),
        GestureDetector(
          onTap: press as void Function()?,
          child: Text(
            login ? "S'inscrire" : "Se connecter",
            style: TextStyle(
              color:login ? Colors.yellow:Colors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
        )
      ],
    );
  }
}
