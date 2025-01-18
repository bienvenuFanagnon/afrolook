

import 'dart:convert';
import 'dart:math';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/pages/auth/authTest/Screens/updateUserData.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:ripple_wave/ripple_wave.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';
import 'UserServices/detailsUserService.dart';
import 'UserServices/listUserService.dart';
import 'afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'afroshop/marketPlace/acceuil/produit_details.dart';
import 'component/consoleWidget.dart';

class SplahsChargement extends StatefulWidget {
  final String postId;
  final String postType;
  const SplahsChargement({super.key, required this.postId, required this.postType});

  @override
  State<SplahsChargement> createState() => _ChargementState();
}

class _ChargementState extends State<SplahsChargement> {
  late AnimationController animationController;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  late int app_version_code=36;
  int limitePosts=30;

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void start() {
    animationController.repeat();
  }

  late Random random = Random();
  late int imageNumber = 1; // Génère un nombre entre 1 et 6
  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  late VideoPlayerController _controller;
  late bool isFinished=false;

  void stop() {
    animationController.stop();
  }
  @override
  void initState() {
    setState(() {
      isFinished=false;
    });
    authProvider.getAppData().then(
          (appdata) async {
        printVm("code app data *** : ${authProvider.appDefaultData.app_version_code}");
        if (app_version_code== authProvider.appDefaultData.app_version_code_officiel) {
          authProvider.getIsFirst().then((value) {
            printVm("isfirst: ${value}");
            if (value==null||value==false) {
              printVm("is_first");

              authProvider.storeIsFirst(true);
              if (mounted) {
                Navigator.pushNamed(context, '/introduction');
              }
              // Navigator.pushNamed(context, '/introduction');



            }else{
              // authProvider.storeIsFirst(false);
              printVm("is_not_first");

              authProvider.getToken().then((token) async {
                printVm("token: ${token}");

                if (token==null||token=='') {
                  printVm("token: existe pas");
                  Navigator.pushNamed(context, '/welcome');




                }else{
                  printVm("token: existe");
                  await    authProvider.getLoginUser(token!).then((value) async {
                    if (value) {
                      if(authProvider.loginUserData.countryData!["countryCode"]!=null){
                        printVm("*****************countryData************ : ${jsonEncode(authProvider.loginUserData.countryData!)}");
                        // await userProvider.getAllAnnonces();
                        userProvider.changeState(user: authProvider.loginUserData,
                            state: UserState.ONLINE.name);

                        // Navigator.pop(context);


                        if(widget.postId!=null&&widget.postId.isNotEmpty){

                          switch (widget.postType) {
                            case "POST":
                              await postProvider.getPostsImagesById(widget.postId!).then((posts) {
                                if(posts.isNotEmpty){
                                  Navigator.pushNamed(
                                      context,
                                      '/home');
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));
                                }else{
                                  Navigator.pushNamed(
                                      context,
                                      '/home');
                                }

                              },);
                              break;
                            case "ARTICLE":

                              await    postProvider.getArticleById(widget.postId!).then((value) async {
                                if (value.isNotEmpty) {
                                  value.first.vues=value.first.vues!+1;
                                  // article.vues=value.first.vues!+1;
                                  categorieProduitProvider.updateArticle(value.first,context).then((value) {
                                    if (value) {


                                    }
                                  },);
                                  await    authProvider.getUserById(value.first.user_id!).then((users) async {
                                    if(users.isNotEmpty){
                                      value.first.user=users.first;
                                      await    postProvider.getEntreprise(value.first.user_id!).then((entreprises) {
                                        if(entreprises.isNotEmpty){
                                          entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
                                          // setState(() {
                                          //   _isLoading=false;
                                          // });
                                          Navigator.pushNamed(
                                              context,
                                              '/home');
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    HomeAfroshopPage(title: ""),
                                              ));
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ProduitDetail(article: value.first, entrepriseData: entreprises.first,),
                                              ));
                                        }
                                      },);
                                    }
                                  },);
                                }
                              },);

                              break;

                            case "SERVICE":

                              await    postProvider.getUserServiceById(widget.postId!).then((value) async {
                                if (value.isNotEmpty) {
                                  UserServiceData  data=value.first;
                                  data.vues=value.first.vues!+1;
                                  Navigator.pushNamed(
                                      context,
                                      '/home');
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UserServiceListPage(),
                                      ));
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => DetailUserServicePage(data: data),));

                                  if(!isIn(data.usersViewId!, authProvider.loginUserData!.id!)){
                                    data.usersViewId!.add(authProvider.loginUserData!.id!) ;

                                  }
                                  postProvider.updateUserService(data,context).then((value) {
                                    if (value) {


                                    }
                                  },);
                                }
                              },);

                              break;
                            default:
                              Navigator.pushNamed(
                                  context,
                                  '/home');                          }
                        }else{
                          Navigator.pushNamed(
                              context,
                              '/home');
                        }

                        //  Navigator.pushNamed(context, '/chargement');
                      }else{
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UpdateUserData(title: "Mise à jour d'adresse"),));
                      }


                    }else{
                      Navigator.pushNamed(context, '/welcome');

                    }

                  },);
                }
              },);

            }
          },);


        }        else{
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 300,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.info,color: Colors.red,),
                        Text(
                          'Nouvelle mise à jour disponible!',
                          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10.0),
                        Text(
                          'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
                          style: TextStyle(fontSize: 16.0),
                        ),
                        SizedBox(height: 20.0),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            _launchUrl(Uri.parse('${authProvider.appDefaultData.app_link}'));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.ios_logo_google_playstore,color: Colors.white,),
                              SizedBox(width: 5,),
                              Text('Télécharger sur le play store',
                                style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
                            ],
                          ),

                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

        }

        // Navigator.push(context, MaterialPageRoute(builder: (context) => IntroIaCompagnon(instruction:authProvider.appDefaultData.ia_instruction! ,),));


      },
    );
    _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.setVolume(0.0); // Couper le son
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.position == _controller.value.duration) {
        setState(() {
          isFinished=true;
        });
        // Navigator.of(context).pushReplacement(
        // Navigator.of(context).pushReplacement(
        //   PageTransition(
        //     type: PageTransitionType.fade,
        //     duration: Duration(milliseconds: 2000), // Ajuste la durée selon tes besoins
        //     child: SplahsChargement(postId: "", postType: '',),
        //   ),
        // );
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (context) => SplahsChargement(postId: "")),
        // );
      }
    });
    // imageNumber = random.nextInt(6) + 1; // Génère un nombre entre 1 et 6
    // if(!mounted){
    //   authProvider.getAppData().then((value) {
    //     if (app_version_code== authProvider.appDefaultData.app_version_code) {
    //
    //       // postProvider.getPostsImages(limitePosts).then((value) {
    //       //
    //       // },);
    //       try{
    //         authProvider.getIsFirst().then((value) {
    //           printVm("isfirst: ${value}");
    //           if (value==null||value==false) {
    //             printVm("is_first");
    //
    //             authProvider.storeIsFirst(true);
    //             Navigator.pushNamed(context, '/introduction');
    //
    //
    //
    //           }else{
    //             // authProvider.storeIsFirst(false);
    //             printVm("is_not_first");
    //
    //             authProvider.getToken().then((token) async {
    //               printVm("token: ${token}");
    //
    //               if (token==null||token=='') {
    //                 printVm("token: existe pas");
    //                 Navigator.pushNamed(context, '/welcome');
    //
    //
    //
    //
    //               }else{
    //                 printVm("token: existe");
    //                 await    authProvider.getLoginUser(token!).then((value) async {
    //                   if (value) {
    //                     // await userProvider.getAllAnnonces();
    //                     userProvider.changeState(user: authProvider.loginUserData,
    //                         state: UserState.ONLINE.name);
    //
    //                     // Navigator.pop(context);
    //                     if(widget.postId!=null&&widget.postId.isNotEmpty){
    //                       await postProvider.getPostsImagesById(widget.postId!).then((posts) {
    //                         if(posts.isNotEmpty){
    //                           Navigator.pushNamed(
    //                               context,
    //                               '/home');
    //                           Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));
    //                         }else{
    //                           Navigator.pushNamed(
    //                               context,
    //                               '/home');
    //                         }
    //
    //                       },);
    //                     }else{
    //                       Navigator.pushNamed(
    //                           context,
    //                           '/home');
    //                     }
    //
    //                     //  Navigator.pushNamed(context, '/chargement');
    //
    //                   }else{
    //                     Navigator.pushNamed(context, '/welcome');
    //
    //                   }
    //
    //                 },);
    //               }
    //             },);
    //
    //           }
    //         },);
    //
    //       }catch(e){
    //         printVm("erreur chargement: $e");
    //       }
    //
    //
    //
    //
    //     }
    //     else{
    //       showModalBottomSheet(
    //         context: context,
    //         builder: (BuildContext context) {
    //           return Container(
    //             height: 300,
    //             child: Center(
    //               child: Padding(
    //                 padding: const EdgeInsets.all(20.0),
    //                 child: Column(
    //                   mainAxisAlignment: MainAxisAlignment.center,
    //                   crossAxisAlignment: CrossAxisAlignment.center,
    //                   children: [
    //                     Icon(Icons.info,color: Colors.red,),
    //                     Text(
    //                       'Nouvelle mise à jour disponible!',
    //                       style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
    //                     ),
    //                     SizedBox(height: 10.0),
    //                     Text(
    //                       'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
    //                       style: TextStyle(fontSize: 16.0),
    //                     ),
    //                     SizedBox(height: 20.0),
    //                     ElevatedButton(
    //                       style: ElevatedButton.styleFrom(
    //                         backgroundColor: Colors.green,
    //                       ),
    //                       onPressed: () {
    //                         _launchUrl(Uri.parse('${authProvider.appDefaultData.app_link}'));
    //                       },
    //                       child: Row(
    //                         mainAxisAlignment: MainAxisAlignment.center,
    //                         children: [
    //                           Icon(Ionicons.ios_logo_google_playstore,color: Colors.white,),
    //                           SizedBox(width: 5,),
    //                           Text('Télécharger sur le play store',
    //                             style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
    //                         ],
    //                       ),
    //
    //                     ),
    //                   ],
    //                 ),
    //               ),
    //             ),
    //           );
    //         },
    //       );
    //
    //     }
    //
    //   },);
    //
    // }
    //
    //
    //   authProvider.getAppData().then((value) {
    //     if (app_version_code== authProvider.appDefaultData.app_version_code) {
    //
    //       // postProvider.getPostsImages(limitePosts).then((value) {
    //       //
    //       // },);
    //       try{
    //
    //
    //       }catch(e){
    //         printVm("erreur chargement: $e");
    //       }
    //
    //
    //
    //
    //     }else{
    //       showModalBottomSheet(
    //         context: context,
    //         builder: (BuildContext context) {
    //           return Container(
    //             height: 300,
    //             child: Center(
    //               child: Padding(
    //                 padding: const EdgeInsets.all(20.0),
    //                 child: Column(
    //                   mainAxisAlignment: MainAxisAlignment.center,
    //                   crossAxisAlignment: CrossAxisAlignment.center,
    //                   children: [
    //                     Icon(Icons.info,color: Colors.red,),
    //                     Text(
    //                       'Nouvelle mise à jour disponible!',
    //                       style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
    //                     ),
    //                     SizedBox(height: 10.0),
    //                     Text(
    //                       'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
    //                       style: TextStyle(fontSize: 16.0),
    //                     ),
    //                     SizedBox(height: 20.0),
    //                     ElevatedButton(
    //                       style: ElevatedButton.styleFrom(
    //                         backgroundColor: Colors.green,
    //                       ),
    //                       onPressed: () {
    //                         _launchUrl(Uri.parse('${authProvider.appDefaultData.app_link}'));
    //                       },
    //                       child: Row(
    //                         mainAxisAlignment: MainAxisAlignment.center,
    //                         children: [
    //                           Icon(Ionicons.ios_logo_google_playstore,color: Colors.white,),
    //                           SizedBox(width: 5,),
    //                           Text('Télécharger sur le play store',
    //                             style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
    //                         ],
    //                       ),
    //
    //                     ),
    //                   ],
    //                 ),
    //               ),
    //             ),
    //           );
    //         },
    //       );
    //
    //     }
    //
    //   },);



    super.initState();

  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    // final random = Random();
    // final imageNumber = random.nextInt(6) + 1; // Génère un nombre entre 1 et 5
    return
     Scaffold(
        backgroundColor: Colors.black,

        body: Center(
          child:!isFinished?_controller.value.isInitialized
              ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
              : Center(child: CircularProgressIndicator()): Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              image: DecorationImage(
                // image: AssetImage('assets/splash/${imageNumber}.jpg'), // Chemin de votre image
                image: AssetImage('assets/splash/spc2.jpg'), // Chemin de votre image
                fit: BoxFit.cover, // Pour couvrir tout l'écran
              ),
            ),

            child: Padding(
              padding: const EdgeInsets.only(top: 40.0,bottom: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    child:  RippleWave(

                      childTween: Tween(begin: 0.9, end: 1.0,),
                      color: ConstColors.chargementColors,
                      repeat: true,
                      //  animationController: animationController,
                      child: Image.asset('assets/logo/afrolook_logo.png',height: 50,width: 50,),
                    ),
                  ),
                  // SizedBox(height: height*0.4,),
                  Text("Connexion...",style: TextStyle(color: Colors.white,fontWeight: FontWeight.w900,fontSize: 20),)
                ],
              ),
            ),
          ),
        ),
      );
  }
}
