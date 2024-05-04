import 'package:flutter/material.dart';

import 'auth/authTest/Screens/Login/loginPageUser.dart';

class BonASavoir extends StatefulWidget {
  const BonASavoir({super.key});

  @override
  State<BonASavoir> createState() => _BonASavoirState();
}

class _BonASavoirState extends State<BonASavoir> {
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Bon A Savoir'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(

            children: <Widget>[
              SizedBox(height: 10,),
              Image.asset('assets/images/welcom.jpg',height:height*0.3 ,),
              SizedBox(height: 10,),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Afrolook",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w900),),
                  SizedBox(height: 30.0),
                  Text(
                    'Description de l\'application',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'AfroLook est un réseau social permettant à ses utilisateurs de bénéficier des avantages des réseaux sociaux avec des systèmes de monétisation adaptables, de créer leur popularité (avoir des abonnés, des likes et des j\'aime) et de mettre au service marketing des entreprises partenaires.',
                    textAlign: TextAlign.justify,style: TextStyle(fontWeight: FontWeight.bold)
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    'Gagner des points en likant des posts et des profils et les échanger pour gagner divers prix lors d\'événements promotionnels.',
                    textAlign: TextAlign.justify,style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),

                  Text(
                    "Afrolook vous offre un montant entre 1000 et 2000 FCFA que vous pourrez retirer après avoir atteint 50 abonnés. Vérifiez la page Monétisation pour plus d'informations.",
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            SizedBox(height: 50,),

              Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LoginPageUser()));
              }, child: Text("Se Connecter")),
            )

                  ]
                  ),
          ),
        ),
    );
  }
}
