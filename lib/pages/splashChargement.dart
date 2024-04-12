

import 'package:afrotok/constant/constColors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ripple_wave/ripple_wave.dart';

import '../providers/authProvider.dart';
import '../providers/userProvider.dart';

class SplahsChargement extends StatefulWidget {
  const SplahsChargement({super.key});

  @override
  State<SplahsChargement> createState() => _ChargementState();
}

class _ChargementState extends State<SplahsChargement> {
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
    authProvider.getIsFirst().then((value) {
      print("isfirst: ${value}");
      if (value==null||value==false) {
        print("is_first");

        authProvider.storeIsFirst(true);
        Navigator.pushNamed(context, '/introduction');



      }else{
       // authProvider.storeIsFirst(false);
        print("is_not_first");

        authProvider.getToken().then((token) async {
          print("token: ${token}");

          if (token==null||token=='') {
            print("token: existe pas");
            Navigator.pushNamed(context, '/welcome');




          }else{
            print("token: existe");
            await    authProvider.getLoginUser(token!).then((value) async {
              if (value) {
                await      userProvider.getProfileUsers(authProvider.loginUserData!.id!,context,20).then((value) async {
                  if (value.isNotEmpty) {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                        context,
                        '/home');
                    Navigator.pushNamed(context, '/chargement');
                    /*

                    await       await userProvider.getAllAnnonces().then((value) {

                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context,
                          '/home');
                      Navigator.pushNamed(context, '/chargement');
                    },);

                     */

                  }else{
                    Navigator.pushNamed(context, '/welcome');

                  }

                },);
              }else{
                Navigator.pushNamed(context, '/welcome');

              }

            },);
          }
        },);

      }
    },);






  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
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
              Text("Connexion...")
            ],
          ),
        ),
      ),
    );
  }
}
