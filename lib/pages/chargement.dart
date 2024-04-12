

import 'package:afrotok/constant/constColors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ripple_wave/ripple_wave.dart';

import '../providers/authProvider.dart';
import '../providers/userProvider.dart';

class Chargement extends StatefulWidget {
  const Chargement({super.key});

  @override
  State<Chargement> createState() => _ChargementState();
}

class _ChargementState extends State<Chargement> {
  late AnimationController animationController;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  void start() {
    animationController.repeat();
  }

  void stop() {
    animationController.stop();
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    userProvider.getProfileUsers(authProvider.loginUserData!.id!,context,20).then((value) {
      if (value.isNotEmpty) {
        Navigator.pop(context);
      }

    },);



  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent.withOpacity(0.8),
      body: Center(
        child: Container(
          height: 200,
          width: 200,
          child:  RippleWave(

            childTween: Tween(begin: 0.9, end: 1.0,),
            color: ConstColors.chargementColors,
            repeat: true,
          //  animationController: animationController,
            child: Image.asset('assets/logo/afrolook_logo.png',height: 70,width: 70,),
          ),
        ),
      ),
    );
  }
}
