import 'package:afrotok/pages/story/storyTabs.dart';
import 'package:afrotok/pages/userPosts/userPubTabs.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';

class StoriesForm extends StatefulWidget {
  const StoriesForm({super.key});

  @override
  State<StoriesForm> createState() => _StoriesFormState();
}

class _StoriesFormState extends State<StoriesForm> {

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Nouveau Statut",
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
                            backgroundImage: AssetImage(
                                'assets/images/confident-african-businesswoman-smiling-closeup-portrait-jobs-career-campaign.jpg'),
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
                                    titre: "Loranzo josh",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextCustomerUserTitle(
                                  titre: "850 abonne",
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
                              titre: "PubliCach",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextCustomerUserTitle(
                            titre: "500",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w400,
                          ),
                          SizedBox(height: 2,),
                          AchatPubliCachButton(),

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
                        titre: "Text Simple",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      child: TextCustomerMenu(
                        titre: "Text avec Image",
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
                      child: StatutText(),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: StatutTextImage()),
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
