import 'package:afrotok/pages/userPosts/userPubTabs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../depot/depotPublicash.dart';
import 'addTabs.dart';

class AddPubForm extends StatefulWidget {
  const AddPubForm({super.key});

  @override
  State<AddPubForm> createState() => _UserProfilState();
}

class _UserProfilState extends State<AddPubForm> {

  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap = false;

  late List<XFile> listimages = [];

  final ImagePicker picker = ImagePicker();

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Nouvelle publicité",
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 15.0),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                                '${userProvider.entrepriseData.urlImage}'),
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
                                  child: TextCustomerUserTitle(
                                    titre: "#${userProvider.entrepriseData.titre}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextCustomerUserTitle(
                                  titre: "${userProvider.entrepriseData.suivi} suivi(e)s",
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
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Column(
                        children: [
                          SizedBox(
                            //width: 100,
                            child: TextCustomerUserTitle(
                              titre: "PubliCash",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextCustomerUserTitle(
                            titre: "${userProvider.entrepriseData.publicash!.toStringAsFixed(2)}",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w400,
                          ),
                          SizedBox(height: 5,),
                          GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DepotPage(),));
                              },
                              child: AchatPubliCachButton()),

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
                        titre: "Pub Image",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      child: TextCustomerMenu(
                        titre: "Pub Vidéos",
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
                      child: SingleChildScrollView(child: UserPostPubImage()),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: UserPostPubVideo()),
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
