import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/userPosts/challenge/lookChallenge/listLookChallenge.dart';
import 'package:afrotok/pages/userPosts/challenge/userPostToChallenge.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu/popup_menu.dart';

import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/textCustom.dart';
import '../../../models/chatmodels/message.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../component/consoleWidget.dart';
import '../../component/showUserDetails.dart';
import '../dataWidgte.dart';


class ChallengeDetails extends StatefulWidget {
  late  Challenge challenge;
   ChallengeDetails({super.key, required this.challenge});

  @override
  State<ChallengeDetails> createState() => _ChallengeDetailsState();
}

class _ChallengeDetailsState extends State<ChallengeDetails> {
  final ScrollController _scrollController = ScrollController();

  String token='';
  bool dejaVuPub=true;

  GlobalKey btnKey = GlobalKey();
  GlobalKey btnKey2 = GlobalKey();
  GlobalKey btnKey3 = GlobalKey();
  GlobalKey btnKey4 = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  int imageIndex=0;
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);


  late PostProvider challengeProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool _buttonEnabled=false;
  bool contact_whatsapp=false;
  bool contact_afrolook=false;
  bool isLoading=false;

  void showConfirmationDialog(Challenge challenge,BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirmation"),
          content: Text("Vous voulez participer au challenge ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Non", style: TextStyle(color: Colors.red)),
            ),
            isLoading?Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator())): ElevatedButton(
              onPressed: () async {
                if(!isLoading){
                  if(!isIn(challenge.usersInscritsIds!, authProvider.loginUserData.id!)){
                    setState(() {
                      isLoading=true;
                    });
                    challenge.usersInscritsIds!.add(authProvider.loginUserData.id!);
                    await postProvider.updateChallenge(challenge).then((value) {
                      if(value){

                        Navigator.pop(context);
                        showSuccessDialog(context);

                      }
                      setState(() {
                        isLoading=false;
                      });
                    },);
                  }

                }

              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Oui",style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }
  void showChallengeUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Défi terminé ❌"),
          content: Text(
              "Malheureusement, ce défi n'est plus disponible.\n\nRestez à l'affût des prochains challenges !"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  void showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Félicitations 🎉"),
          content: Text(
              "Vous faites partie des participants du challenge.\n\nSuivez exactement les règles du challenge pour gagner le prix. Bonne chance !"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }


  TextEditingController commentController =TextEditingController();
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }


  late AnimationController _starController;
  late AnimationController _unlikeController;
  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }


  RandomColor _randomColor = RandomColor();


  Color _getBackgroundColor(String status) {
    switch (status) {
      case "ATTENTE":
        return Colors.orange.shade100;
      case "ENCOURS":
        return Colors.green.shade100;
      case "TERMINER":
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getTextColor(String status) {
    switch (status) {
      case "ATTENTE":
        return Colors.orange;
      case "ENCOURS":
        return Colors.green;
      case "TERMINER":
        return Colors.black87;
      default:
        return Colors.black54;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "ATTENTE":
        return "En attente...";
      case "ENCOURS":
        return "En live";
      case "TERMINER":
        return "Terminé";
      default:
        return "Inconnu";
    }
  }
  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }
  PopupMenu? postmenu;

  Future<void> checkChallengeStatus(BuildContext context, Challenge? challenge) async {
    switch (challenge!.statut) {
      case 'TERMINER':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Challenge 🔥🎁 Terminé'),
            content: Text('Ce challenge est terminé. Merci d’avoir participé !'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'ATTENTE':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Challenge 🔥🎁 en Attente'),
            content: Text('Le challenge n’a pas encore commencé. Revenez plus tard pour le suivre en direct.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'ENCOURS':
      // Aucun message modal, ou autre logique pour un challenge en cours
        print('Le challenge est en cours.');
        await postProvider.getChallengeById(widget.challenge!.id!).then((value) {
          if(value.isNotEmpty){
            widget.challenge=value.first;
            Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeUserChosePost(otherUser: authProvider.loginUserData, challenge: widget.challenge,),));

          }
        },);
        break;

      default:
        print('Statut inconnu.');
        break;
    }
  }

  String formatAbonnes(int nbAbonnes) {
    if (nbAbonnes >= 1000) {
      double nombre = nbAbonnes / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return nbAbonnes.toString();
    }
  }
  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }


  void onShow() {
    printVm('Menu is show');
  }

  Widget homeChallenge(Challenge challenge,Color color, double height, double width) {

    Post post=challenge!.postChallenge!;


    Random random = Random();
    bool abonneTap = false;
    int like = post!.likes!;
    int imageIndex = 0;
    int love = post!.loves!;
    int vue = post!.vues!;
    int comments = post!.comments!;
    bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
    bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
    List<int> likes = [];
    List<int> loves = [];
    int idUser = 7;
    // Calculer la taille du texte en fonction de la longueur de la description
    double baseFontSize = 20.0;
    double scale = post.description!.length / 1000;  // Ajustez ce facteur selon vos besoins
    double fontSize = baseFontSize - scale;
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    // Limiter la taille de la police à une valeur minimale
    fontSize = fontSize < 15 ? 15 : fontSize;
    int limitePosts = 30;


    return SliverToBoxAdapter(
      child: SizedBox(
        // height: height * 0.35,

          child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateImages) {
                return Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child:  GestureDetector(
                                  onTap: () async {
                                    await  authProvider.getUserById(post.user!.id!).then((users) async {
                                      if(users.isNotEmpty){
                                        showUserDetailsModalDialog(users.first, w, h,context);

                                      }
                                    },);

                                  },
                                  child:
                                  CircleAvatar(

                                    backgroundImage:
                                    NetworkImage('${post.user!.imageUrl!}'),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 2,
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        //width: 100,
                                        child: TextCustomerUserTitle(
                                          titre: "@${post.user!.pseudo!}",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Column(
                                            children: [
                                              TextCustomerUserTitle(
                                                titre:
                                                "${formatNumber(post.user!.userlikes!)} like(s)",
                                                fontSize: SizeText.homeProfileTextSize,
                                                couleur: Colors.green,
                                                fontWeight: FontWeight.w700,
                                              ),

                                              TextCustomerUserTitle(
                                                titre:
                                                "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                                fontSize: SizeText.homeProfileTextSize,
                                                couleur: ConstColors.textColors,
                                                fontWeight: FontWeight.w400,
                                              ),

                                            ],
                                          ),
                                          // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),

                                        ],
                                      ),
                                    ],
                                  ),
                                  Visibility(
                                    visible:authProvider.loginUserData.id!=post.user!.id ,

                                    child: StatefulBuilder(builder: (BuildContext context,
                                        void Function(void Function()) setState) {
                                      return Container(
                                        child: isUserAbonne(
                                            post.user!.userAbonnesIds!,
                                            authProvider.loginUserData.id!)
                                            ? Container()
                                            : TextButton(
                                            onPressed: abonneTap
                                                ? () {}
                                                : () async {
                                              setState(() {
                                                abonneTap=true;
                                              });
                                              await authProvider.abonner(post.user!,context).then((value) {

                                              },);
                                              setState(() {
                                                abonneTap=false;
                                              });
                                            },
                                            child: abonneTap
                                                ? Center(
                                              child:
                                              LoadingAnimationWidget
                                                  .flickr(
                                                size: 20,
                                                leftDotColor:
                                                Colors.green,
                                                rightDotColor:
                                                Colors.black,
                                              ),
                                            )
                                                : Text(
                                              "S'abonner",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.normal,
                                                  color: Colors.blue),
                                            )),
                                      );
                                    }),
                                  ),
                                  /*
                              IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.add_circle_outlined,
                                    size: 20,
                                    color: ConstColors.regIconColors,
                                  )),

                               */
                                ],
                              ),
                              SizedBox(width: 10,),



                            ],
                          ),
                          IconButton(
                              onPressed: () {
                                // _showPostMenuModalDialog(post,context);
                              },
                              icon: Icon(
                                Icons.more_horiz,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              )),
                        ],
                      ),
                      Visibility(
                          visible: post.type==PostType.PUB.name,
                          child: Row(
                            children: [
                              Icon(Icons.public,color: Colors.green,),
                              Text(" Publicité",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                            ],
                          )
                      ),

                      SizedBox(
                        height: 5,
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: HashTagText(
                      //     text: "${post.description}",
                      //     decoratedStyle: TextStyle(
                      //       fontSize: 13,
                      //       fontWeight: FontWeight.w600,
                      //
                      //       color: Colors.green,
                      //       fontFamily: 'Nunito', // Définir la police Nunito
                      //     ),
                      //     basicStyle: TextStyle(
                      //       fontSize: 12,
                      //       color: Colors.black87,
                      //       fontWeight: FontWeight.normal,
                      //       fontFamily: 'Nunito', // Définir la police Nunito
                      //     ),
                      //     textAlign: TextAlign.left, // Centrage du texte
                      //     maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                      //     softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                      //     // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                      //     onTap: (text) {
                      //       print(text);
                      //     },
                      //   ),
                      // ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: HashTagText(
                          text: "${challenge.postChallenge!.description!}",
                          decoratedStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,

                            color: Colors.green,
                            fontFamily: 'Nunito', // Définir la police Nunito
                          ),
                          basicStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.normal,
                            fontFamily: 'Nunito', // Définir la police Nunito
                          ),
                          textAlign: TextAlign.left, // Centrage du texte
                          maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                          softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                          // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                          onTap: (text) {
                            print(text);
                          },
                        ),
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: HashTagText(
                      //     text: "${challenge.descriptionCadeaux}",
                      //     decoratedStyle: TextStyle(
                      //       fontSize: 13,
                      //       fontWeight: FontWeight.w600,
                      //
                      //       color: Colors.green,
                      //       fontFamily: 'Nunito', // Définir la police Nunito
                      //     ),
                      //     basicStyle: TextStyle(
                      //       fontSize: 12,
                      //       color: Colors.black87,
                      //       fontWeight: FontWeight.normal,
                      //       fontFamily: 'Nunito', // Définir la police Nunito
                      //     ),
                      //     textAlign: TextAlign.left, // Centrage du texte
                      //     maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                      //     softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                      //     // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                      //     onTap: (text) {
                      //       print(text);
                      //     },
                      //   ),
                      // ),


                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextCustomerPostDescription(
                            titre:
                            "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                            fontSize: SizeText.homeProfileDateTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Visibility(
                        visible: post.dataType == PostDataType.TEXT.name
                            ? true
                            : false,
                        child: Container(
                          color: color,
                          child: Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              // width: width * 0.8,
                              // height: height * 0.5,
                              child: Container(
                                // height: 200,
                                // constraints: BoxConstraints(
                                //   // minHeight: 100.0, // Set your minimum height
                                //   maxHeight:
                                //   height * 0.6, // Set your maximum height
                                // ),
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Center(
                                      child: HashTagText(
                                        text: "${post.description}",
                                        decoratedStyle: TextStyle(
                                          fontSize: fontSize,

                                          fontWeight: FontWeight.w600,

                                          color: Colors.green,
                                          fontFamily: 'Nunito', // Définir la police Nunito
                                        ),
                                        basicStyle: TextStyle(
                                          fontSize: fontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                          fontFamily: 'Nunito', // Définir la police Nunito
                                        ),
                                        textAlign: TextAlign.center, // Centrage du texte
                                        maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                                        softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                                        // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                                        onTap: (text) {
                                          print(text);
                                        },
                                      ),
                                    )),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),



                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 10,
                        children: [
                          Visibility(
                            visible: post.dataType != PostDataType.TEXT.name
                                ? true
                                : false,
                            child: Container(
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                child: Container(
                                    child: InstaImageViewer(
                                      child:CachedNetworkImage(

                                        fit: BoxFit.contain,

                                        imageUrl: '${post.images!.first}',
                                        progressIndicatorBuilder: (context, url, downloadProgress) =>
                                        //  LinearProgressIndicator(),

                                        Skeletonizer(
                                            child: SizedBox(

                                                width: w * 0.9,
                                                height: h * 0.4,
                                                child:  ClipRRect(
                                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                        errorWidget: (context, url, error) =>  Skeletonizer(child: Container(
                                            width: w * 0.9,
                                            height: h * 0.4,
                                            child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                      ),
                                    )
                                ),
                              ),
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: Colors.brown,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Prix à gagner: ${challenge.prix} FCFA', // Texte du bouton
                                    style: TextStyle(
                                      fontSize: 15, //
                                      color: Colors.white,// Taille du texte
                                      fontWeight: FontWeight.w900, // Texte en gras
                                    ),
                                  ),
                                ),
                              ),

                              DateTextWidget(
                                startDateMillis: widget.challenge.startAt!, // Remplace avec ta valeur en millisecondes
                                endDateMillis: widget.challenge.finishedAt!,
                              ),
                              Row(
                                children: [
                                  Text(
                                    "Etat: ",
                                    style: TextStyle(
                                      // color: _getTextColor(widget.challenge.statut!),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getBackgroundColor(widget.challenge.statut!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.challenge.statut == StatutData.ENCOURS.name) ...[
                                            const Icon(Icons.circle, color: Colors.green, size: 10),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            _getStatusText(widget.challenge.statut!),
                                            style: TextStyle(
                                              color: _getTextColor(widget.challenge.statut!),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),  ),
                                  ),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {


                                      await postProvider.getChallengeById(widget.challenge!.id!).then((value) {
                                        if(value.isNotEmpty){
                                          widget.challenge=value.first;
                                          if(widget.challenge.statut!=StatutData.TERMINER.name&&widget.challenge.statut!=StatutData.ANNULER.name){
                                            // Logique à exécuter lorsque l'utilisateur appuie sur le bouton
                                            print("L'utilisateur a décidé de participer !");
                                            if(!isIn(widget.challenge.usersInscritsIds!, authProvider.loginUserData.id!)){
                                              showConfirmationDialog(widget.challenge,context);

                                            }
                                          }else{
                                            showChallengeUnavailableDialog(context);
                                          }
                                        }
                                      },);


                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:isIn(widget.challenge.usersInscritsIds!, authProvider.loginUserData.id!)?Colors.red: Colors.green, // Couleur de fond verte
                                      // onPrimary: Colors.white, // Couleur du texte (blanc)
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding pour le bouton
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // Coins arrondis
                                      ),
                                    ),
                                    child:isIn(widget.challenge.usersInscritsIds!, authProvider.loginUserData.id!)?Text(
                                      'Vous participé déja au challenge', // Texte du bouton
                                      style: TextStyle(
                                        fontSize: 12, //
                                        color: Colors.white,// Taille du texte
                                        fontWeight: FontWeight.bold, // Texte en gras
                                      ),
                                    ): Text(
                                      'Participer au challenge', // Texte du bouton
                                      style: TextStyle(
                                        fontSize: 12, //
                                        color: Colors.white,// Taille du texte
                                        fontWeight: FontWeight.bold, // Texte en gras
                                      ),
                                    ),
                                  ),
                                  Row(
                                    spacing: 5,
                                    children: [
                                      const Icon(Icons.group_add),
                                      Text(
                                        '${challenge.usersInscritsIds!.length}', // Texte du bouton
                                        style: TextStyle(
                                          fontSize: 15, //
                                          color: Colors.green,// Taille du texte
                                          fontWeight: FontWeight.w900, // Texte en gras
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 5,),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {


                                      await postProvider.getChallengeById(widget.challenge!.id!).then((value) {
                                        if(value.isNotEmpty){
                                          widget.challenge=value.first;
                                          // Logique à exécuter lorsque l'utilisateur appuie sur le bouton

                                            if(isIn(widget.challenge.usersInscritsIds!, authProvider.loginUserData.id!)){
                                              checkChallengeStatus(context,widget.challenge,);

                                            }else{
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('Challenge 🔥🎁'),
                                                  content: Text('Vous ne faites pas partie des participants de ce challenge.Participer ou Veuillez attendre le prochain événement.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(),
                                                      child: Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                              );                                            }



                                        }
                                      },);


                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, // Couleur de fond verte
                                      // onPrimary: Colors.white, // Couleur du texte (blanc)
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding pour le bouton
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // Coins arrondis
                                      ),
                                    ),
                                    child:Text(
                                      'Poster votre look challenge', // Texte du bouton
                                      style: TextStyle(
                                        fontSize: 12, //
                                        color: Colors.white,// Taille du texte
                                        fontWeight: FontWeight.bold, // Texte en gras
                                      ),
                                    )
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {

                                      Navigator.push(context, MaterialPageRoute(builder: (context) => LookChallengeListPage(challenge: challenge),));

                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade500, // Couleur de fond verte
                                      // onPrimary: Colors.white, // Couleur du texte (blanc)
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding pour le bouton
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10), // Coins arrondis
                                      ),
                                    ),
                                    child:Text(
                                      'Voir les looks challenges', // Texte du bouton
                                      style: TextStyle(
                                        fontSize: 12, //
                                        color: Colors.white,// Taille du texte
                                        fontWeight: FontWeight.bold, // Texte en gras
                                      ),
                                    )
                                  ),
                                ],
                              ),
                              Container(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                          if (!isIn(post.users_love_id!,
                                              authProvider.loginUserData.id!)) {
                                            setState(() {
                                              post.loves = post.loves! + 1;

                                              post.users_love_id!
                                                  .add(authProvider!.loginUserData.id!);
                                              love = post.loves!;
                                              //loves.add(idUser);
                                            });
                                            CollectionReference userCollect =
                                            FirebaseFirestore.instance
                                                .collection('Users');
                                            // Get docs from collection reference
                                            QuerySnapshot querySnapshotUser =
                                            await userCollect
                                                .where("id",
                                                isEqualTo: post.user!.id!)
                                                .get();
                                            // Afficher la liste
                                            List<UserData> listUsers = querySnapshotUser
                                                .docs
                                                .map((doc) => UserData.fromJson(
                                                doc.data() as Map<String, dynamic>))
                                                .toList();
                                            if (listUsers.isNotEmpty) {
                                              listUsers.first!.jaimes =
                                                  listUsers.first!.jaimes! + 1;
                                              printVm("user trouver");
                                              if (post.user!.oneIgnalUserid != null &&
                                                  post.user!.oneIgnalUserid!.length > 5) {


                                                NotificationData notif =
                                                NotificationData();
                                                notif.id = firestore
                                                    .collection('Notifications')
                                                    .doc()
                                                    .id;
                                                notif.titre = "Nouveau j'aime ❤️";
                                                notif.media_url =
                                                    authProvider.loginUserData.imageUrl;
                                                notif.type = NotificationType.POST.name;
                                                notif.description =
                                                "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                                                notif.users_id_view = [];
                                                notif.user_id =
                                                    authProvider.loginUserData.id;
                                                notif.receiver_id = post.user!.id!;
                                                notif.post_id = post.id!;
                                                notif.post_data_type =
                                                PostDataType.IMAGE.name!;

                                                notif.updatedAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.createdAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.status = PostStatus.VALIDE.name;

                                                // users.add(pseudo.toJson());

                                                await firestore
                                                    .collection('Notifications')
                                                    .doc(notif.id)
                                                    .set(notif.toJson());
                                                await authProvider.sendNotification(
                                                    userIds: [post.user!.oneIgnalUserid!],
                                                    smallImage:
                                                    "${authProvider.loginUserData.imageUrl!}",
                                                    send_user_id:
                                                    "${authProvider.loginUserData.id!}",
                                                    recever_user_id: "${post.user!.id!}",
                                                    message:
                                                    "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                                    type_notif:
                                                    NotificationType.POST.name,
                                                    post_id: "${post!.id!}",
                                                    post_type: PostDataType.IMAGE.name,
                                                    chat_id: '');
                                              }
                                              // postProvider.updateVuePost(post, context);

                                              //userProvider.updateUser(listUsers.first);
                                              SnackBar snackBar = SnackBar(
                                                content: Text(
                                                  '+2 points.  Voir le classement',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.green),
                                                ),
                                              );
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(snackBar);
                                              postProvider.updatePost(
                                                  post, listUsers.first, context);
                                              await authProvider.getAppData();
                                              authProvider.appDefaultData.nbr_loves =
                                                  authProvider.appDefaultData.nbr_loves! +
                                                      2;
                                              authProvider.updateAppData(
                                                  authProvider.appDefaultData);
                                            } else {
                                              post.user!.jaimes = post.user!.jaimes! + 1;
                                              SnackBar snackBar = SnackBar(
                                                content: Text(
                                                  '+2 points.  Voir le classement',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.green),
                                                ),
                                              );
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(snackBar);
                                              postProvider.updatePost(
                                                  post, post.user!, context);
                                              await authProvider.getAppData();
                                              authProvider.appDefaultData.nbr_loves =
                                                  authProvider.appDefaultData.nbr_loves! +
                                                      2;
                                              authProvider.updateAppData(
                                                  authProvider.appDefaultData);
                                            }

                                            tapLove = true;
                                          }
                                          printVm("jaime");
                                          // setState(() {
                                          // });
                                        },
                                        child: Container(
                                          //height: 20,
                                          width: 70,
                                          height: 30,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  // AnimateIcon(
                                                  //   key: UniqueKey(),
                                                  //   onTap: () {},
                                                  //   iconType: IconType.continueAnimation,
                                                  //   height: 20,
                                                  //   width: 20,
                                                  //   color: Colors.red,
                                                  //   animateIcon: AnimateIcons.heart,
                                                  // ),

                                                  Icon(
                                                    isIn(
                                                        post.users_love_id!,
                                                        authProvider
                                                            .loginUserData.id!)
                                                        ? Ionicons.heart
                                                        : Ionicons.md_heart_outline,
                                                    color: Colors.red,
                                                    size: 20,
                                                    // color: ConstColors.likeColors,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                        left: 1.0, right: 1),
                                                    child: TextCustomerPostDescription(
                                                      titre: "${formatAbonnes(love)}",
                                                      fontSize: SizeText
                                                          .homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                        },
                                        child: Container(
                                          width: 70,
                                          height: 30,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    isIn(
                                                        post.users_like_id!,
                                                        authProvider
                                                            .loginUserData.id!)
                                                        ? MaterialCommunityIcons.eye
                                                        : MaterialCommunityIcons
                                                        .eye,
                                                    size: 20,
                                                    color: isIn(
                                                        post.users_like_id!,
                                                        authProvider
                                                            .loginUserData.id!)
                                                        ? Colors.blue
                                                        : Colors.black,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                        left: 1.0, right: 1),
                                                    child: TextCustomerPostDescription(
                                                      titre: "${formatAbonnes(vue)}",
                                                      fontSize: SizeText
                                                          .homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              /*
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 1.0,right: 1),
                                    child: SizedBox(
                                      height: 2,
                                      // width: width*0.75,
                                      child: LinearProgressIndicator(
                                        color: Colors.blue,
                                        value: like/post.user!.abonnes!+1,
                                        semanticsLabel: 'Linear progress indicator',
                                      ),
                                    ),
                                  ),
                                ),
                                TextCustomerPostDescription(
                                  titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                  fontSize: SizeText.homeProfileDateTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.bold,
                                ),

                                 */
                                            ],
                                          ),
                                        ),
                                      );
                                    }),

                                    StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PostComments(post: post),
                                              ));

                                          //sheetComments(height*0.7,width,post);
                                        },
                                        child: Container(
                                          width: 70,
                                          height: 30,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    FontAwesome.comments,
                                                    size: 20,
                                                    color: Colors.green,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                        left: 1.0, right: 1),
                                                    child: TextCustomerPostDescription(
                                                      titre: "${formatAbonnes(comments)}",
                                                      fontSize: SizeText
                                                          .homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          //width: width*0.75,
                                          child: LinearProgressIndicator(
                                            color: Colors.blueGrey,
                                            value: comments/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${(comments/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                            ],
                                          ),
                                        ),
                                      );
                                    }),

                                    StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                          // await authProvider.createLink(post).then((value) {
                                          final box = context.findRenderObject() as RenderBox?;

                                          await authProvider.createLink(true,post).then((url) async {
                                            await Share.shareUri(
                                              Uri.parse(
                                                  '${url}'),
                                              sharePositionOrigin:
                                              box!.localToGlobal(Offset.zero) & box.size,
                                            );


                                            setState(() {
                                              post.partage = post.partage! + 1;

                                              // post.users_love_id!
                                              //     .add(authProvider!.loginUserData.id!);
                                              // love = post.loves!;
                                              // //loves.add(idUser);
                                            });
                                            CollectionReference userCollect =
                                            FirebaseFirestore.instance
                                                .collection('Users');
                                            // Get docs from collection reference
                                            QuerySnapshot querySnapshotUser =
                                            await userCollect
                                                .where("id",
                                                isEqualTo: post.user!.id!)
                                                .get();
                                            // Afficher la liste
                                            List<UserData> listUsers = querySnapshotUser
                                                .docs
                                                .map((doc) => UserData.fromJson(
                                                doc.data() as Map<String, dynamic>))
                                                .toList();
                                            if (listUsers.isNotEmpty) {
                                              listUsers.first!.partage =
                                                  listUsers.first!.partage! + 1;
                                              printVm("user trouver");
                                              if (post.user!.oneIgnalUserid != null &&
                                                  post.user!.oneIgnalUserid!.length > 5) {


                                                NotificationData notif =
                                                NotificationData();
                                                notif.id = firestore
                                                    .collection('Notifications')
                                                    .doc()
                                                    .id;
                                                notif.titre = "Nouveau partage 📲";
                                                notif.media_url =
                                                    authProvider.loginUserData.imageUrl;
                                                notif.type = NotificationType.POST.name;
                                                notif.description =
                                                "@${authProvider.loginUserData.pseudo!} a partagé votre look";
                                                notif.users_id_view = [];
                                                notif.user_id =
                                                    authProvider.loginUserData.id;
                                                notif.receiver_id = post.user!.id!;
                                                notif.post_id = post.id!;
                                                notif.post_data_type =
                                                PostDataType.IMAGE.name!;

                                                notif.updatedAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.createdAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.status = PostStatus.VALIDE.name;

                                                // users.add(pseudo.toJson());

                                                await firestore
                                                    .collection('Notifications')
                                                    .doc(notif.id)
                                                    .set(notif.toJson());
                                                await authProvider.sendNotification(
                                                    userIds: [post.user!.oneIgnalUserid!],
                                                    smallImage:
                                                    "${authProvider.loginUserData.imageUrl!}",
                                                    send_user_id:
                                                    "${authProvider.loginUserData.id!}",
                                                    recever_user_id: "${post.user!.id!}",
                                                    message:
                                                    "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                                    type_notif:
                                                    NotificationType.POST.name,
                                                    post_id: "${post!.id!}",
                                                    post_type: PostDataType.IMAGE.name,
                                                    chat_id: '');
                                              }
                                              // postProvider.updateVuePost(post, context);

                                              //userProvider.updateUser(listUsers.first);
                                              // SnackBar snackBar = SnackBar(
                                              //   content: Text(
                                              //     '+2 points.  Voir le classement',
                                              //     textAlign: TextAlign.center,
                                              //     style: TextStyle(color: Colors.green),
                                              //   ),
                                              // );
                                              // ScaffoldMessenger.of(context)
                                              //     .showSnackBar(snackBar);
                                              postProvider.updatePost(
                                                  post, listUsers.first, context);
                                              // await authProvider.getAppData();
                                              // authProvider.appDefaultData.nbr_loves =
                                              //     authProvider.appDefaultData.nbr_loves! +
                                              //         2;
                                              // authProvider.updateAppData(
                                              //     authProvider.appDefaultData);


                                              tapLove = true;
                                            }

                                          },);
                                        },
                                        child: Container(
                                          //height: 20,
                                          width: 70,
                                          height: 30,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  // AnimateIcon(
                                                  //
                                                  //   key: UniqueKey(),
                                                  //   onTap: () {},
                                                  //   iconType: IconType.continueAnimation,
                                                  //   height: 20,
                                                  //   width: 20,
                                                  //   color: Colors.red,
                                                  //   animateIcon: AnimateIcons.share,
                                                  //
                                                  // ),

                                                  Icon(
                                                    isIn(
                                                        post.users_love_id!,
                                                        authProvider
                                                            .loginUserData.id!)
                                                        ? Icons.share
                                                        : Icons.share,
                                                    color: Colors.red,
                                                    size: 20,
                                                    // color: ConstColors.likeColors,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                        left: 1.0, right: 1),
                                                    child: TextCustomerPostDescription(
                                                      titre: "${formatAbonnes(post.partage!)}",
                                                      fontSize: SizeText
                                                          .homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height: 10,
                          ),
                        ],
                      ),

                      // Divider(
                      //   height: 3,
                      // )
                    ],
                  ),
                );
              })),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('Challenges 🔥🎁🏆',style: TextStyle(color: Colors.green,fontSize: 18),),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          ),

        ],
      ),
      body: CustomScrollView(

        controller: _scrollController,
        slivers: <Widget>[



          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            sliver: homeChallenge(widget.challenge,Colors.brown, height, width),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            sliver:    SliverToBoxAdapter(
              child: Text(
                "🔥 Les participants du challenge 💪🏾🏆",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            sliver: FutureBuilder<List<UserData>>(
              future: userProvider.getChallengeUsers(
                  widget.challenge.usersInscritsIds!
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      // height: height * 0.35,

                        child: Center(child: CircularProgressIndicator())),
                  );
                } else if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: SizedBox(

                        child: Center(child: CircularProgressIndicator())),
                  );
                } else {
                  List<UserData> list = snapshot.data!;


                  return SliverToBoxAdapter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final user = list[index];
                        return ListTile(
                          onTap: () {
                            showUserDetailsModalDialog(user, width, height,context);

                          },
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(user.imageUrl!),
                          ),
                          title: Text("@${user.pseudo!}", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${user.userAbonnesIds!.length!} abonné(s)", style: TextStyle(fontWeight: FontWeight.bold)),
                          // trailing: ElevatedButton(
                          //   onPressed: () {
                          //     // Action pour s'abonner
                          //   },
                          //   child: Text("S'abonner"),
                          // ),
                        );
                      },
                    ),
                  );

                }
              },
            ),
          ),

        ],
      ),
    );
  }
}