import 'package:afrotok/pages/admin/new_category.dart';
import 'package:afrotok/pages/entreprise/abonnement/MySubscription.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/entreprise/produit/component.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../produit/entrepriseProduit.dart';
import '../pubs/pub.dart';

class EntrepriseProfil extends StatefulWidget {
  const EntrepriseProfil({super.key});

  @override
  State<EntrepriseProfil> createState() => _EntrepriseProfilState();
}

class _EntrepriseProfilState extends State<EntrepriseProfil> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Mon Entreprise",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),


        //backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(

            children: [
              // Padding(
              //   padding: const EdgeInsets.only(bottom: 8.0),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       Row(
              //         children: [
              //           Padding(
              //             padding: const EdgeInsets.only(right: 15.0),
              //             child: CircleAvatar(
              //               radius: 30,
              //               backgroundImage: NetworkImage(
              //                   '${userProvider.entrepriseData.urlImage}'),
              //             ),
              //           ),
              //           SizedBox(
              //             height: 2,
              //           ),
              //           Row(
              //             children: [
              //               Column(
              //                 children: [
              //                   SizedBox(
              //                     //width: 100,
              //                     child: TextCustomerUserTitle(
              //                       titre: "#${userProvider.entrepriseData.titre}",
              //                       fontSize: SizeText.homeProfileTextSize,
              //                       couleur: ConstColors.textColors,
              //                       fontWeight: FontWeight.bold,
              //                     ),
              //                   ),
              //                   TextCustomerUserTitle(
              //                     titre: "${userProvider.entrepriseData.suivi} suivi(e)s",
              //                     fontSize: SizeText.homeProfileTextSize,
              //                     couleur: ConstColors.textColors,
              //                     fontWeight: FontWeight.w400,
              //                   ),
              //                 ],
              //               ),
              //
              //             ],
              //           ),
              //         ],
              //       ),
              //       Padding(
              //         padding: const EdgeInsets.only(right: 12.0),
              //         child: Column(
              //           children: [
              //             SizedBox(
              //               //width: 100,
              //               child: TextCustomerUserTitle(
              //                 titre: "PubliCash",
              //                 fontSize: SizeText.homeProfileTextSize,
              //                 couleur: ConstColors.textColors,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //             TextCustomerUserTitle(
              //               titre: "${userProvider.entrepriseData.publicash!.toStringAsFixed(2)}",
              //               fontSize: SizeText.homeProfileTextSize,
              //               couleur: ConstColors.textColors,
              //               fontWeight: FontWeight.w400,
              //             ),
              //             SizedBox(height: 5,),
              //             GestureDetector(
              //               onTap: () {
              //                 Navigator.push(context, MaterialPageRoute(builder: (context) => DepotPage(),));
              //               },
              //                 child: AchatPubliCachButton()),
              //
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              entrepriseHeader(userProvider.entrepriseData),
              SizedBox(
                height: 10,

              ),

              Row(
                //mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Column(
                      children: [
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "${userProvider.entrepriseData.publication}",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "Publications ",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
              SizedBox(
                height: 15,
              ),
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  //height: 50,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: TextCustomerPostDescription(
                      titre:
                      "Description",
                      fontSize: SizeText.titlepostEntrepriseTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 15,
              ),
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  //height: 50,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: TextCustomerPostDescription(
                        titre:
                        "${userProvider.entrepriseData.description}",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 15,

              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  // mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          SizedBox(height: 10,),
                          ClipRRect(
                            borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => CurrentSubscriptionPage(abonnement: userProvider.entrepriseData.abonnement!,),));
                              },
                              child: Container(
                                color: ConstColors.buttonsColors,
                                // alignment: Alignment.centerLeft,
                                width: 180,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 5.0),
                                        child: Container(
                                          child: Image.asset(
                                            'assets/icon/entreprise.png',
                                            height: 20,
                                            width: 20,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        child: TextCustomerMenu(
                                          titre: "Mon Abonnement",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    ],

                                  ),
                                ),
                              ),
                            ),
                          ),
                          authProvider.loginUserData.role!=UserRole.ADM.name?Container():       SizedBox(height: 10,),
                          authProvider.loginUserData.role!=UserRole.ADM.name?Container():
                          GestureDetector(
                            onTap: () async {
                              await userProvider.getGratuitInfos().then((value) {


                                Navigator.pushNamed(context, '/new_annonce');

                              },);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                              child: Container(
                                color: ConstColors.buttonsColors,
                                // alignment: Alignment.centerLeft,
                                width: 180,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 5.0),
                                        child: Container(
                                          child: Icon(Icons.add),
                                        ),
                                      ),
                                      Container(
                                        child: TextCustomerMenu(
                                          titre: "Annonce",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    ],

                                  ),
                                ),
                              ),
                            ),
                          ),
                          authProvider.loginUserData.role!=UserRole.ADM.name?Container():       SizedBox(height: 10,),

                          authProvider.loginUserData.role!=UserRole.ADM.name?Container():
                          GestureDetector(
                            onTap: () async {
                              await userProvider.getGratuitInfos().then((value) {


                                Navigator.push(context, MaterialPageRoute(builder: (context) => AddCategorie(),));

                              },);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                              child: Container(
                                color: ConstColors.buttonsColors,
                                // alignment: Alignment.centerLeft,
                                width: 180,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 5.0),
                                        child: Container(
                                          child: Icon(Icons.category,color: Colors.green,),
                                        ),
                                      ),
                                      Container(
                                        child: TextCustomerMenu(
                                          titre: "Catégorie",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    ],

                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 10,),
                          ClipRRect(
                            borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                            child: Container(
                              color: ConstColors.buttonsColors,
                              // alignment: Alignment.centerLeft,
                              width: 180,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5.0),
                                      child: Container(
                                        child: Image.asset(
                                          'assets/icon/entrepriseContact.png',
                                          height: 20,
                                          width: 20,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
    userProvider.getUserEntreprise(authProvider.loginUserData.id!).then((value) {
    if (value) {
      Navigator.pushNamed(context, '/list_conversation_entreprise_user');
    }else{
    Navigator.pushNamed(context, '/new_entreprise');
    }

    },);




                                      },
                                      child: Container(
                                        child: TextCustomerMenu(
                                          titre: "Clients Contactés",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  ],

                                ),
                              ),
                            ),
                          ),



                        ],
                      ),
                    ),

                  ],
                ),
              ),
              SizedBox(
                height: 10,

              ),
              SizedBox(
                width: width,
                height:height*0.86 ,
                child: ContainedTabBarView(
                  tabs: [
                    Container(
                      child: TextCustomerMenu(
                        titre: "Nos Produits",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Container(
                      child: TextCustomerMenu(
                        titre: "Nos Pubs",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  tabBarProperties: TabBarProperties(
                    height: 32.0,
                    indicatorColor: ConstColors.menuItemsColors,
                    indicatorWeight: 6.0,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey[400],
                  ),
                  views: [

                    Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: EntrepriseProduitView()
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: EntreprisePubView(),
                    ),
                  ],
                  onChange: (index) => print(index),
                ),
              ),

            ],
          ),

        ),
      ),
    );
  }
}
