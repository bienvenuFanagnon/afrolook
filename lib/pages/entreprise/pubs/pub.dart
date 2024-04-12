import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../user/profile/profileTabsBar/entreprise/postImage.dart';
import '../../user/profile/profileTabsBar/entreprise/postVideo.dart';
import '../profile/entreprisePostImage.dart';
import '../profile/entreprisePostVideo.dart';

class EntreprisePubView extends StatefulWidget {
  @override
  State<EntreprisePubView> createState() => _EntreprisePublicationViewState();
}

class _EntreprisePublicationViewState extends State<EntreprisePubView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController textController = TextEditingController();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;








  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  SingleChildScrollView(
      child: Container(
        child:   SizedBox(
          width: width,
          height:height*0.8 ,
          child: ContainedTabBarView(
            tabs: [
              Container(
                child: TextCustomerMenu(
                  titre: "Simple",
                  fontSize: SizeText.homeProfileTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                child: TextCustomerMenu(
                  titre: "Videos",
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
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: width,
                          height: 50,
                          child: AnimSearchBar(
                            width: 400,
                            helpText: 'rechercher une pub',
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
                        onTap: () async {

                         await userProvider.getUsers(authProvider.loginUserData.id!,context).then((value) async {
                           if (value) {
                             if (userProvider.listUsers.isNotEmpty) {
                               await authProvider.getAppData();

                             //  print("app data2 : ${authProvider.appDefaultData.toJson()!}");
                
                               Navigator.pushNamed(context, '/add_pub');
                             }
                
                           }
                         },);
                
                        },
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: AddPubButton()),
                      ),
                      ProfileEntreprisePostImageTab(),
                
                    ],
                  ),
                ),
              ),
              ProfileEntreprisePostVideoTab(),
            ],
            onChange: (index) => print(index),
          ),
        ),

      ),
    );
  }
}