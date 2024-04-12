import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPage.dart';
import 'package:flutter/material.dart';

import '../../../../../../constant/sizeButtons.dart';
import '../../../constants.dart';
import '../../Login/loginPageUser.dart';
import '../../Login/login_screen.dart';
import '../../Signup/signup_screen.dart';
import '../../login.dart';

class LoginAndSignupBtn extends StatelessWidget {
  const LoginAndSignupBtn({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: SizeButtons.loginAndSignupBtnlargeur,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return  LoginPageUser();
                  },
                ),
              );
            },
            child: Text(
              "Se connecter",
              style: TextStyle(color: kPrimaryColor),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: SizeButtons.loginAndSignupBtnlargeur,

          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const SignUpScreen();
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryLightColor,
              elevation: 0,
            ),
            child: Text(
              "S'inscrire",
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}
