

import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';

import 'mesInvitationTable.dart';


class Amis extends StatefulWidget {
  const Amis({super.key});

  @override
  State<Amis> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<Amis> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Amis",
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          Navigator.pushNamed(context, '/add_list_amis');
          // Action à effectuer lors du clic sur le bouton
        },
        child: Icon(FontAwesome.users,color: Colors.white,),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat, // Vous pouvez changer cette valeur selon vos besoins

      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[

            SizedBox(height: 20,),
            Container(
              width: width,
              height: height*0.9,
             // color: Colors.red,


              child: ContainedTabBarView(


                tabs: [
                  Center(
                    child: Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: TextCustomerMenu(
                              titre: "Mes Amis",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(200)),
                            child: Container(

                              color: Colors.red,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: TextCustomerMenu(
                                  titre: "${userProvider.countFriends}",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: TextCustomerMenu(
                              titre: "Mes Invitations",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(200)),
                            child: Container(

                              color: Colors.red,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: TextCustomerMenu(
                                  titre: "${userProvider.countInvitations}",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                tabBarProperties: TabBarProperties(
                  alignment: TabBarAlignment.center,
                  height: 32.0,
                  indicatorColor: ConstColors.menuItemsColors,
                  indicatorWeight: 6.0,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[400],
                ),
                views: [

                  MesAmis(context: context,),

                  MesInvitations(context: context,),
                  
                ],
                onChange: (index) => print(index),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class ConversationList extends StatefulWidget{
  String name;
  String messageText;
  String imageUrl;
  String time;
  bool isMessageRead;
  ConversationList({required this.name,required this.messageText,required this.imageUrl,required this.time,required this.isMessageRead});
  @override
  _ConversationListState createState() => _ConversationListState();
}


class _ConversationListState extends State<ConversationList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  maxRadius: 30,
                ),
                SizedBox(width: 16,),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.name, style: TextStyle(fontSize: 16),),
                        SizedBox(height: 6,),
                        Text('320 abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: widget.isMessageRead?FontWeight.bold:FontWeight.normal),),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),


        ],
      ),
    );
  }
}

class Invitations extends StatefulWidget{
  String name;
  String messageText;
  String imageUrl;
  String time;
  int invitation_id;
  int user_accepted_id;
  Invitation userInvitation=Invitation();
  bool isMessageRead;
  GlobalKey<FormState> formKey;
  BuildContext context;
  Invitations({required this.formKey,required this.context,required this.name,required this.messageText,required this.time,required this.imageUrl,required this.isMessageRead,required this.invitation_id,required this.user_accepted_id,required this.userInvitation});
  @override
  _InvitationsState createState() => _InvitationsState();
}

class _InvitationsState extends State<Invitations> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  bool inviteTap=false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  maxRadius: 30,
                ),
                SizedBox(width: 16,),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.name, style: TextStyle(fontSize: 16),),
                        SizedBox(height: 6,),
                        Text('${widget.userInvitation.inviteUser!.abonnes!} abonné(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: widget.isMessageRead?FontWeight.bold:FontWeight.normal),),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: inviteTap?() {}: () async {
                setState(() {
                  inviteTap =true;
                });
                await  userProvider.acceptInvitation(widget.userInvitation).then((value) async {
                  if (value) {

                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                      key: widget.formKey,
                      content: Center(child: Text("invitation acceptée!",style: TextStyle(color: Colors.green),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));


                    await authProvider.getToken().then((value) {

                    },);
                    await  authProvider.getUserByToken(token: authProvider.token!);
                    await userProvider.getUsersProfile(authProvider.loginUserData!.id!,context);
                    setState(() {

                      inviteTap =false;
                    });

                  }  else{
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                      content: Center(child: Text("Erreur lors de l'acceptation.",style: TextStyle(color: Colors.red),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));

                    setState(() {

                      inviteTap =false;

                    });
                  }




                },);

              },
                  child:inviteTap?Center(
                    child: LoadingAnimationWidget.flickr(
                      size: 15,
                      leftDotColor: Colors.green,
                      rightDotColor: Colors.black,
                    ),
                  ): Text('Accepter',style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
              ),
              TextButton(onPressed: () {  },
                  child: Text('Refuser',style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.red),)
              ),
            ],
          ),
        ],
      ),
    );
  }
}