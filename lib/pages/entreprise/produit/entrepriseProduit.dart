import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';


class EntrepriseProduitView extends StatefulWidget {
  @override
  State<EntrepriseProduitView> createState() => _EntreprisePublicationViewState();
}

class _EntreprisePublicationViewState extends State<EntrepriseProduitView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController textController = TextEditingController();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget homeProfileUsers() {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: [
          CircleAvatar(
            backgroundImage: AssetImage(
                'assets/images/green-business-logo-template-design-9820098082a4fc0a9e1f9179e347f35a_screen.jpg'),
          ),
          SizedBox(
            height: 2,
          ),
          SizedBox(
            width: 70,
            child: TextCustomerUserTitle(
              titre: "lucien lucien",
              fontSize: SizeText.homeProfileTextSize,
              couleur: ConstColors.textColors,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget formCommentMesage(double height, double width) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: AssetImage(
                'assets/images/handsome-man-smiling-happy-face-portrait-close-up.jpg'),
          ),
          SizedBox(
            width: 20,
          ),
          Form(
            key: _formKey,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: width * 0.6,
                  height: 80,
                  child: TextFormField(
                    maxLines: 2,
                    // Configuration du champ de texte
                    decoration: InputDecoration(
                      hintText: 'Commentaire',
                      hintStyle: TextStyle(
                        fontSize: 10,
                        //color: Colors.white,
                        fontWeight: FontWeight.normal,
                        //fontStyle: FontStyle.italic
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Veuillez entrer votre commentaire.';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                GestureDetector(
                    onTap: () {
                      if (_formKey.currentState!.validate()) {
                        // Traitez les données du formulaire ici
                        // Par exemple, envoyez les commentaires à un serveur
                      }
                    },
                    child: Container(
                        child: Image.asset(
                          "assets/images/sender.png",
                          width: 30,
                          height: 30,
                        ))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  sheetComments(double height, double width,BuildContext context) {
    return showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            child: Container(
              height: height * 0.9,
              width: width,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8),
                child: Center(
                  child: ListView(
                    //mainAxisAlignment: MainAxisAlignment.center,
                    //mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextCustomerUserTitle(
                            titre: "Commentaires",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.bold,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.cancel,
                                  size: 15,
                                  color: ConstColors.blackIconColors,
                                )),
                          ),
                        ],
                      ),
                      formCommentMesage(height, width),
                      Divider(),
                      SingleChildScrollView(
                        child: SizedBox(
                          height: height * 0.4,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                itemCount:
                                10, // Nombre d'éléments dans la liste
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 10.0),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8.0),
                                              child: CircleAvatar(
                                                radius: 15,
                                                backgroundImage: AssetImage(
                                                    'assets/images/confident-african-businesswoman-smiling-closeup-portrait-jobs-career-campaign.jpg'),
                                              ),
                                            ),
                                            //SizedBox(height: 2,),
                                            Row(
                                              children: [
                                                Column(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                      children: [
                                                        SizedBox(
                                                          //width: 100,
                                                          child:
                                                          TextCustomerUserTitle(
                                                            titre:
                                                            "lucien lucien",
                                                            fontSize: SizeText
                                                                .homeProfileTextSize,
                                                            couleur: ConstColors
                                                                .textColors,
                                                            fontWeight:
                                                            FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 20,
                                                        ),
                                                        Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child:
                                                          TextCustomerPostDescription(
                                                            titre:
                                                            "Il y a 2 minutes ",
                                                            fontSize: SizeText
                                                                .textDatePostSize,
                                                            couleur: ConstColors
                                                                .textColors,
                                                            fontWeight:
                                                            FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: width * 0.6,
                                                          child:
                                                          TextCustomerPostDescription(
                                                            titre:
                                                            "Mon premier commentaire pour cette pub Mon premier commentaire ",
                                                            fontSize: SizeText
                                                                .homeProfileTextSize,
                                                            couleur: ConstColors
                                                                .textColors,
                                                            fontWeight:
                                                            FontWeight.w400,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          //height: 30,
                                                          child: Row(
                                                            mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceAround,
                                                            children: [
                                                              IconButton(
                                                                onPressed:
                                                                    () {},
                                                                icon: IconPersonaliser(
                                                                    icone: Icons
                                                                        .favorite,
                                                                    size: 20),
                                                              ),
                                                              TextCustomerPostDescription(
                                                                titre: "21",
                                                                fontSize: SizeText
                                                                    .homeProfileTextSize,
                                                                couleur: ConstColors
                                                                    .textColors,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w400,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget homePostUsers(double height, double width,BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: CircleAvatar(
                      backgroundImage: AssetImage(
                          'assets/images/green-business-logo-template-design-9820098082a4fc0a9e1f9179e347f35a_screen.jpg'),
                    ),
                  ),
                  SizedBox(
                    height: 2,
                  ),
                  Row(
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            //width: 100,
                            child: Row(
                              children: [
                                TextCustomerUserTitle(
                                  titre: "afrolook",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.bold,
                                ),
                                Image.asset("assets/icon/iconEntrepise.png",height: 20,width: 20,)
                              ],
                            ),
                          ),
                          TextCustomerUserTitle(
                            titre: "1.5 m suivi(e)s",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w400,
                          ),
                        ],
                      ),

                    ],
                  ),
                ],
              ),
              IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz,
                    size: 30,
                    color: ConstColors.blackIconColors,
                  )),
            ],
          ),
          SizedBox(
            height: 6,
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
                  "Produits de beauté",
                  fontSize: SizeText.titlepostEntrepriseTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 6,
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
                  "Catégorie : beauté",
                  fontSize: SizeText.titlepostEntrepriseTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 6,
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
                  "Un coucher de soleil sur la plage, c'est toujours un moment de magie. Les couleurs sont si belles et les émotions sont si fortes...Afficher plus",
                  fontSize: SizeText.homeProfileTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 5,
          ),
          Align(
            alignment: Alignment.topLeft,
            child: TextCustomerPostDescription(
              titre: "IL Y A 5 MIN",
              fontSize: SizeText.homeProfileDateTextSize,
              couleur: ConstColors.textColors,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 2,
          ),
          ListItemSlider(
            sliders: [
              ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Image.asset(
                    "assets/images/produits-cosmetiques-naturels-img.jpg",
                    height: 300,
                  )),
              ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Image.asset(
                    "assets/images/confident-business-woman-portrait-smiling-face.jpg",
                    height: 300,
                  ))
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Row(
                  children: [
                    Row(
                      children: [
                        IconPersonaliser(icone: Icons.favorite, size: 20),
                        SizedBox(
                          width: 5,
                        ),
                        TextCustomerPostDescription(
                          titre: "300",
                          fontSize: SizeText.homeProfileDateTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.thumb_up,
                              size: 20,
                              color: ConstColors.likeColors,
                            )),
                        TextCustomerPostDescription(
                          titre: "300",
                          fontSize: SizeText.homeProfileDateTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              sheetComments(height, width,context);
                            },
                            icon: Icon(
                              Icons.comment,
                              size: 20,
                              color: ConstColors.blackIconColors,
                            )),
                        TextCustomerPostDescription(
                          titre: "300",
                          fontSize: SizeText.homeProfileDateTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Column(

      children: [
        Align(
         // alignment: Alignment.centerRight,
          child: Container(
            width: width,
            height: 50,
            child: AnimSearchBar(
              width: 400,
              helpText: 'rechercher un produit',
              textController: textController,
              onSuffixTap: () {
                setState(() {
                  textController.clear();
                });
              },
              onSubmitted: (String ) {  },
            ),
          ),
        ),
        SizedBox(height: 6,),
        GestureDetector(
          onTap: () {
            //Navigator.pushNamed(context, '/add_produit');
          },
          child: Align(
              alignment: Alignment.centerLeft,
              child: AddProduitButton()),
        ),
        SizedBox(height: 6,),
        Container()
        /*
        SizedBox(
          width: width,
          height: height*0.7,
          child: ListView(
            children: [
              homePostUsers(height, width,context),
              homePostUsers(height, width,context),
              homePostUsers(height, width,context),
              homePostUsers(height, width,context),
            ],
          ),
        ),

         */
      ],
    );
  }
}