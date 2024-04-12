import 'package:afrotok/constant/textCustom.dart';
import 'package:flutter/material.dart';

class Logo extends StatefulWidget {
  const Logo({super.key});

  @override
  State<Logo> createState() => _LogoState();
}

class _LogoState extends State<Logo> {
  @override
  Widget build(BuildContext context) {
    return  Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: SizedBox(
          height: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //Image.asset("assets/images/Vector.png",width: 20,height: 20,),
             // SizedBox(width: 5), // Espacement entre les images
             // Image.asset("assets/images/AfroTok.png"),
              TextCustomerMenu(
                titre: "Afrolook",
                fontSize: 20,
                couleur: Colors.green,
                fontWeight: FontWeight.w600,
              ),
              SizedBox(width: 2),
              TextCustomerMenu(
                titre: "beta",
                fontSize: 10,
                couleur: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
