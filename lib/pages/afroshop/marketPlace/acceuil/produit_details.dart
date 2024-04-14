import 'dart:io';
import 'dart:math';


import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:insta_image_viewer/insta_image_viewer.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';

class ProduitDetail extends StatefulWidget {
  final ArticleData article;
  const ProduitDetail({super.key, required this.article});

  @override
  State<ProduitDetail> createState() => _ProduitDetailState();
}

class _ProduitDetailState extends State<ProduitDetail> {

  late UserShopAuthProvider authshopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  String _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  int _length = 100; // Remplacez par la longueur souhaitée
  bool onSaveTap=false;
  bool onSupTap=false;

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  void _showBottomSheetCompterNonValide(double width) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: width,
          //height: 200,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Vous n'êtes pas connecté.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Veuillez vous connecter ou créer un compte.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                   // Navigator.pop(context);

                 //   Navigator.push(context, MaterialPageRoute(builder: (context) => MyPhone(),));

                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login,color: Colors.black,),
                      SizedBox(width: 5,),
                      const Text('Se Connecter maintenant',style: TextStyle(color: Colors.white),),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  String getRandomString() {
    final _rnd = Random();
    return String.fromCharCodes(Iterable.generate(_length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  }



  Future<void> launchWhatsApp(String phone,ArticleData articleData,String code) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"&text=Salut *${articleData.user!.nom!}*,\n*Nom du compte*: *@${authProvider.loginUserData!.nom!.toUpperCase()} Depuis Afrolook*,\n\n je vous contacte via *${"Afroshop".toUpperCase()}* à propos de l'article:\n\n*Titre*:  *${articleData.titre!.toUpperCase()}*\n *Prix*: *${articleData.prix}* fcfa\n *Code de la commande*: *${code}*";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

  int imageIndex=0;
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Details'),
          actions: [
            Container(
              // color: Colors.black12,
              height: 150,
              width: 150,
              alignment: Alignment.center,
              child: Image.asset(
                "assets/icons/afroshop_logo-removebg-preview.png",
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(

          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
            children: <Widget>[
              SizedBox(height: 20,),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Column(
                  children: [
                    SizedBox(

                      child: InstaImageViewer(
                        child: Image(
                          image: Image.network('${widget.article.images![imageIndex]}')
                              .image,
                        ),
                      ),
                    ),

                    /*
                    Container(
                      //width: width,
                      //height: height*0.55,
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,

                        imageUrl: '${widget.article.images![imageIndex]}',
                        progressIndicatorBuilder: (context, url, downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(     width: width,
                                height: height*0.5, child:  ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${widget.article.images![imageIndex]}')))),
                        errorWidget: (context, url, error) =>  Container(    width: width,
                          height: height*0.5,child: Image.network('${widget.article.images![imageIndex]}',fit: BoxFit.cover,)),
                      ),
                    ),

                     */
                  ],
                ),
              ),
              SizedBox(height: 10,),
              Container(
                alignment: Alignment.center,
                width: width,
                height: 60,
                child: ListView.builder(

                  scrollDirection: Axis.horizontal,
                itemCount: widget.article.images!.length,
                itemBuilder: (BuildContext context, int index) {
                  return    GestureDetector(
                    onTap: () {
                      setState(() {
                        imageIndex=index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: CustomConstants.kPrimaryColor)
                        ),

                        width: 110,
                        height: 60,
                        child: Image.network(
                          widget.article.images![index],

                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
                          ),
              ),
              SizedBox(height: 20,),
/*
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.call,size: 30,),
                        onPressed: () {
                          // Fonction pour lancer un appel
                        },
                      ),
                      Text("${widget.article.user!.phone}"),
                    ],
                  ),

                ],
              ),


 */
              Divider(height: 20,indent: 20,endIndent: 20,),

              Padding(
                padding: const EdgeInsets.only(bottom: 8.0,top: 8),
                child: Text("${widget.article.titre}",overflow: TextOverflow.ellipsis,style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15),),
              ),
              // Text(article.description),
              Container(

                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      color:  CustomConstants.kPrimaryColor
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Prix: ${widget.article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600),),
                  )),
               SizedBox(height: 20,),
               Text("${widget.article.description}"),

              SizedBox(height: height*0.1,),

            ]
      ),
          ),
        ),


      bottomSheet:     Container(
        height: 80,
        width: width,

        child: TextButton(
          onPressed: () async {
            await authshopProvider.getUserById(widget.article.user_id!).then((users) async {
              if (users.isNotEmpty) {
                setState(() {
                  onSaveTap=true;
                });
                await categorieProduitProvider.getCommandeById(users.first.id!,widget.article.id!).then((value) async {
                  if (value.isNotEmpty) {
                    launchWhatsApp(widget.article.user!.phone!, widget!.article!,value.first.code!);
                    setState(() {
                      onSaveTap=false;
                    });
                  }  else{
                    var codeCommande = Random().nextInt(1000000);
                    CommandeCode cmdCode =CommandeCode();
                    cmdCode.id=FirebaseFirestore.instance
                        .collection('CommandeCodes')
                        .doc()
                        .id;
                    cmdCode.code=codeCommande.toString();


                    await  categorieProduitProvider.getCodeCommande(cmdCode.code!, cmdCode).then((value) async {
                      if (value==false) {

                        Commande annonceRegisterData =Commande();
                        annonceRegisterData.id=FirebaseFirestore.instance
                            .collection('Commandes')
                            .doc()
                            .id;
                        annonceRegisterData.code=cmdCode.code!;
                        annonceRegisterData.article=widget.article;
                        annonceRegisterData.status=UserCmdStatus.ENCOURS.name;
                        annonceRegisterData.article_id=widget.article.id!;
                        annonceRegisterData.dernierprix=widget.article.prix;
                       // annonceRegisterData.user_client_id=users.first.id;
                        annonceRegisterData.user_client_status=UserCmdStatus.ENCOURS.name;
                        annonceRegisterData.user_magasin_id=widget.article.user_id;
                        annonceRegisterData.user_magasin_status=UserCmdStatus.ENCOURS.name;
                        annonceRegisterData.updatedAt =
                            DateTime.now().microsecondsSinceEpoch;
                        annonceRegisterData.createdAt =
                            DateTime.now().microsecondsSinceEpoch;

                        await categorieProduitProvider.createCommande(annonceRegisterData).then((value) async {
                          if (value) {
                            await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
                              if (value.isNotEmpty) {
                                value.first.contact=value.first.contact!+1;
                                widget.article.contact=value.first.contact!+1;
                                categorieProduitProvider.updateArticle(value.first,context).then((value) {
                                  if (value) {


                                  }
                                },);

                              }
                            },);
                            setState(() {
                              onSaveTap=false;
                            });

                            launchWhatsApp(widget.article.user!.phone!, annonceRegisterData!.article!,annonceRegisterData.code!);
                          }else{
                            setState(() {
                              onSaveTap=false;
                            });
                          }
                        },);
                        setState(() {
                          onSaveTap=false;
                        });
                      }else{
                        await categorieProduitProvider.getCommandeByCode(cmdCode.code!).then((value) {
                          if (value.isNotEmpty) {
                            launchWhatsApp(widget.article.user!.phone!, widget!.article!,value.first.code!);
                            setState(() {
                              onSaveTap=false;
                            });

                          }
                        },);

                      }
                    },);
                    setState(() {
                      onSaveTap=false;
                    });
                  }
                },);

              }  else{
                setState(() {
                  onSaveTap=false;
                });
               // _showBottomSheetCompterNonValide(width);

              }
            },);












              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddAnnonceStep4(annonceRegisterData: annonceRegisterData),));





          },
          child:onSaveTap?Container(
              height: 20,
              width: 20,

              child: CircularProgressIndicator()): Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: CustomConstants.kPrimaryColor,
                  borderRadius: BorderRadius.all(Radius.circular(5))
              ),
              height: 40,
              width: width*0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Discuter de la commande par',style: TextStyle(color: Colors.white),),
                  IconButton(
                    icon: Icon(FontAwesome.whatsapp,color: Colors.green,size: 30,),
                    onPressed: () async {

                      // Fonction pour ouvrir WhatsApp
                    },
                  ),
                ],
              )),
        ),
      ),
    );



  }

}
