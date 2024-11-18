import 'package:flutter/material.dart';
import '../../components/background.dart';
import '../../constants.dart';
import '../../responsive.dart';
import 'components/sign_up_top_image.dart';
import 'components/signup_form.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  Background(
      child: SingleChildScrollView(
        child: Responsive(
          mobile: MobileSignupScreen(),
          desktop: Row(
            children: [
              Expanded(
                child: SignUpScreenTopImage(),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      // width: 450,
                      child: SignUpFormEtap1(),
                    ),
                    SizedBox(height: defaultPadding / 2),
                    // SocalSignUp()
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MobileSignupScreen extends StatelessWidget {
  const MobileSignupScreen({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    return  Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SignUpScreenTopImage(),
          SizedBox(height: 50,),
          SizedBox(
            //width: w,
            height: height*0.7,
            child: Row(
              children: [
               // Spacer(),
                Expanded(
                  flex: 8,
                  child: SignUpFormEtap1(),
                ),
               // Spacer(),
              ],
            ),
          ),
          // const SocalSignUp()
        ],
      );
  }
}
