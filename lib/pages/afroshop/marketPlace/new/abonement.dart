import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:numberpicker/numberpicker.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';


class SubscriptionGridView extends StatefulWidget {
  @override
  State<SubscriptionGridView> createState() => _SubscriptionGridViewState();
}

class _SubscriptionGridViewState extends State<SubscriptionGridView> {
  int _currentValue = 30;
  double prix_total = 0;
  int prix_unitaire = 0;
  int is_selected = 1;
  String typeAbonnement="";
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
                  "Fonctionnalité non disponible",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Cette fonctionnalité n\'est pas encore disponible dans cette version de l\'application.\nPour plus d'information, contacter le responsable",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // Navigator.pop(context);

                   // Navigator.push(context, MaterialPageRoute(builder: (context) => MyPhone(),));
                    launchWhatsApp("+22870870240");

                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Fontisto.whatsapp,color: Colors.green,),
                      SizedBox(width: 5,),
                      const Text('Contacter le responsable',style: TextStyle(color: Colors.white),),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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


  bool onSaveTap = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    typeAbonnement=TypeAbonement.GRATUIT.name;
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Ajouter un abonnement'),
        ),
        bottomSheet:     Container(
          height: 100,
          width: width,

          child: TextButton(
            onPressed: () async {
              _showBottomSheetCompterNonValide(width);
              /*
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubscriptionGridView(),
                  ));


               */

              /*
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              ArticleData annonceRegisterData =ArticleData();
              annonceRegisterData.images=[];
              annonceRegisterData.titre=_titre;
              annonceRegisterData.description=_description;
              annonceRegisterData.vues=0;
              annonceRegisterData.popularite=1;
              annonceRegisterData.jaime=0;
              annonceRegisterData.contact=0;
              annonceRegisterData.prix=_prix;
              annonceRegisterData.user_id=authProvider.loginData.id!;
              annonceRegisterData.categorie_id=categorieSelected.id;


              //  print('sous categorie id: $sousCategorieSelected.id');
              print('Titre: $_titre');
              print('Description: $_description');
              print('Prix: $_prix');



              if (_mediaFileList!.isNotEmpty) {
                setState(() {
                  onSaveTap = true;
                });
                // List<ProduitImages> listImages = [];

                // print("produit final : ${produit.toJson()}");
                //print("user token : ${authProvider.loginData.token!}");
                annonceRegisterData.updatedAt =
                    DateTime.now().microsecondsSinceEpoch;
                annonceRegisterData.createdAt =
                    DateTime.now().microsecondsSinceEpoch;



                for (XFile _image in _mediaFileList!) {
                  Reference storageReference =
                  FirebaseStorage.instance.ref().child(
                      'images_article/${Path.basename(File(_image.path).path)}');

                  UploadTask uploadTask = storageReference
                      .putFile(File(_image.path)!);
                  await uploadTask.whenComplete(() async {
                    await storageReference
                        .getDownloadURL()
                        .then((fileURL) {
                      print("url media");
                      //  print(fileURL);

                      annonceRegisterData.images!.add(fileURL);
                    });
                  });
                }


                String postId = FirebaseFirestore.instance
                    .collection('Articles')
                    .doc()
                    .id;
                annonceRegisterData.id=postId;

/*
                  setState(() {
                    onTap=false;
                  });

 */
                await categorieProduitProvider.createArticle(
                    annonceRegisterData
                )
                    .then((value) {
                  if (value) {
                    final snackBar = SnackBar(
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                        content: Text("Article ajouté",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white),));

                    // Afficher le SnackBar en bas de la page
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snackBar);



                    _titre='';
                    _description='';
                    _prix=0;
                    _mediaFileList = [];
                    _formKey.currentState!.reset();

                    setState(() {
                      onSaveTap = false;
                    });
                    //categorieProduitProvider.getCategories();
/*
                      Navigator.pushReplacementNamed(
                          context, "/home");

 */
                  } else {
                    final snackBar = SnackBar(
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 1),
                        content: Text(
                          "Erreur d'ajout du produit",
                          style: TextStyle(
                              color: Colors.white),));
                    // Afficher le SnackBar en bas de la page
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snackBar);
                    setState(() {
                      onSaveTap = false;
                    });
                  }
                });


              }
              else {
                setState(() {
                  onSaveTap = false;
                });
                final snackBar = SnackBar(
                    duration: Duration(seconds: 2),
                    content: Text(
                      "Veillez ajouter les images",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),));

                // Afficher le SnackBar en bas de la page
                ScaffoldMessenger.of(context).showSnackBar(
                    snackBar);
              }
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddAnnonceStep4(annonceRegisterData: annonceRegisterData),));


            }

             */
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
                height: 50,
                width: width*0.8,
                child: Text('Valider la creation',style: TextStyle(color: Colors.white),)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Text("Le plan gratuit est votre plan par défaut."),
SizedBox(height: 20,),
              SizedBox(
                width: width,
                height: height*0.38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                         // mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(height: 15,),

                            Text(''),
                            SizedBox(height: 20,),

                            Text('Image/pub :',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Text('Nombre de pub :',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 7,),

                            Container(
                                decoration: BoxDecoration(
                                    color: Colors.greenAccent,

                                    borderRadius: BorderRadius.all(Radius.circular(20))
                                ),

                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Visible sur Afrolook:',style: TextStyle(fontWeight: FontWeight.w600),),
                                )),
                            SizedBox(height: 7,),
                            SizedBox(height: 7,),
                            Container(
                                decoration: BoxDecoration(
                                    color: Colors.greenAccent,

                                    borderRadius: BorderRadius.all(Radius.circular(20))
                                ),

                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Annonce Afrolook:',style: TextStyle(fontWeight: FontWeight.w600),),
                                )),

                            SizedBox(height: 7,),

                            Text('Prix :',style: TextStyle(fontWeight: FontWeight.w600),),
                            TextButton(
                              onPressed: () {

                              },
                              child:Container(
                                  decoration: BoxDecoration(
                                    //   color: Colors.blue,

                                      borderRadius: BorderRadius.all(Radius.circular(20))
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(

                                      '',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white),),
                                  )),
                            )


                          ],
                        ),
                      ),
                    ),


                    Card(
                      color: is_selected==1?Colors.greenAccent:Colors.grey,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(

                          children: [
                            SizedBox(height: 10,),

                            Row(
                              children: [
                                Icon(MaterialIcons.free_breakfast,color: CustomConstants.kPrimaryColor,),
                                Text('Gratuit',style: TextStyle(fontWeight: FontWeight.w900),),
                              ],
                            ),
                            SizedBox(height: 20,),
                            Text('1',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Text('5',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(FontAwesome.remove,color: Colors.red,),
                            ),
                            SizedBox(height: 5,),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(FontAwesome.remove,color: Colors.red,),
                            ),
                            SizedBox(height: 5,),

                            Text('0 fcfa',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            TextButton(
                              onPressed: () {
                                setState(() {
                                  is_selected = 1;
                                  typeAbonnement=TypeAbonement.GRATUIT.name;
                                  prix_unitaire = 0;
                                  _currentValue=30;
                                  if (is_selected==1) {


                                    if (_currentValue<=30) {
                                      prix_total = double.parse(prix_unitaire.toString());

                                    } else{
                                      prix_total = prix_unitaire+((prix_unitaire)*_currentValue)/100;

                                    }

                                  }

                                });

                              },
                              child:Container(
                                  decoration: BoxDecoration(
                                      color: Colors.blue,

                                      borderRadius: BorderRadius.all(Radius.circular(20))
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(

                                      'Sélectionner',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white),),
                                  )),
                            )



                          ],
                        ),
                      ),
                    ),
                    Card(
                      color: is_selected==2?Colors.greenAccent:Colors.grey,

                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(

                          children: [
                            SizedBox(height: 10,),

                            Row(
                              children: [
                                Icon(MaterialCommunityIcons.fuse,color: Colors.white,),
                                Text('Standard',style: TextStyle(fontWeight: FontWeight.w900),),
                              ],
                            ),
                            SizedBox(height: 20,),
                            Text('3',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Text('20',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.check_box,color: Colors.green,),
                            ),
                            SizedBox(height: 5,),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(FontAwesome.remove,color: Colors.red,),
                            ),
                            SizedBox(height: 5,),

                            Text('2000 fcfa',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            TextButton(
                              onPressed: () {
                                setState(() {
                                  is_selected = 2;
                                  typeAbonnement=TypeAbonement.STANDARD.name;
                                  prix_unitaire = 2000;
                                  if (is_selected!=1) {


                                    if (_currentValue<=30) {
                                      prix_total = double.parse(prix_unitaire.toString());

                                    } else{
                                      prix_total = prix_unitaire+((prix_unitaire+200)*_currentValue)/100;

                                    }

                                  }

                                });
                              },
                              child:Container(
                                  decoration: BoxDecoration(
                                      color: Colors.blue,

                                      borderRadius: BorderRadius.all(Radius.circular(20))
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(

                                      'Sélectionner',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white),),
                                  )),
                            )


                          ],
                        ),
                      ),
                    ),

                    Card(
                      color: is_selected==3?Colors.greenAccent:Colors.grey,

                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(

                          children: [
                            SizedBox(height: 10,),
                            Row(
                              children: [
                                Icon(Fontisto.star,color: Colors.yellowAccent,),
                                SizedBox(width: 5,),
                                Text('Premium',style: TextStyle(fontWeight: FontWeight.w900),),
                              ],
                            ),
                            SizedBox(height: 20,),
                            Text('5',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Text('50',style: TextStyle(fontWeight: FontWeight.w600),),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.check_box,color: Colors.green,),
                            ),
                            SizedBox(height: 5,),
                            SizedBox(height: 5,),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(Icons.check_box,color: Colors.green,),
                            ),
                            SizedBox(height: 5,),

                            Text('3000 fcfa',style: TextStyle(fontWeight: FontWeight.w600),),

                            SizedBox(height: 5,),

                            TextButton(
                              onPressed: () {
                                setState(() {
                                  is_selected = 3;
                                  typeAbonnement=TypeAbonement.PREMIUM.name;
                                  prix_unitaire = 3000;
                                  if (is_selected!=1) {


                                      if (_currentValue<=30) {
                                        prix_total = double.parse(prix_unitaire.toString());

                                      } else{
                                        prix_total = prix_unitaire+((prix_unitaire+200)*_currentValue)/100;

                                      }

                                  }

                                });
                              },
                              child:Container(
                                  decoration: BoxDecoration(
                                      color: Colors.blue,

                                      borderRadius: BorderRadius.all(Radius.circular(20))
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(

                                      'Sélectionner',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white),),
                                  )),
                            )

                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
              SizedBox(height: 20,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Détails ',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 20),),
                  Text('Jours ',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 20),),
                ],
              ),
              SizedBox(height: 30,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [



                        Row(
                          children: [
                            Text('Plan  : ',style: TextStyle(fontWeight: FontWeight.w600),),
                            Text('${typeAbonnement}',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.green),),
                          ],
                        ),
                        SizedBox(height: 10,),


                        Row(
                          children: [
                            Text('Durée du tarif  : ',style: TextStyle(fontWeight: FontWeight.w600),),
                    
                            Text('${_currentValue} jours',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.green,fontSize: 20),),
                          ],
                        ),
                        SizedBox(height: 10,),
                    
                    
                        Row(
                          children: [
                    
                            Text('Prix Total  : ',style: TextStyle(fontWeight: FontWeight.w600),),
                    
                            Text('${prix_total} fcfa',style: TextStyle(fontWeight: FontWeight.w600,color: Colors.green,fontSize: 20),),
                          ],
                        ),
                      ],
                    ),
                  ),

                  NumberPicker(
                    step: 10,
                    haptics: true,
                    value: _currentValue,
                    minValue: 30,
                    maxValue: 300,

                    onChanged: (value) {
                      if (is_selected!=1) {

                        setState(() {
                          _currentValue=value;
                          if (_currentValue<=30) {
                            prix_total = double.parse(prix_unitaire.toString());

                          } else{
                            prix_total = prix_unitaire+((prix_unitaire+200)*_currentValue)/100;

                          }
                        });
                      }

                    },
                  ),
                 // Text('Current value: $_currentValue'),

                ],
              ),


            ],
          ),
        ));
  }
}

class SubscriptionCard extends StatelessWidget {
  final String title;
  final int imageCount;
  final int postCount;
  final bool isAvailable;

  const SubscriptionCard({
    Key? key,
    required this.title,
    required this.imageCount,
    required this.postCount,
    required this.isAvailable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                const Icon(Icons.image),
                const SizedBox(width: 8.0),
                Text(
                  imageCount.toString(),
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(width: 16.0),
                const Icon(Icons.newspaper),
                const SizedBox(width: 8.0),
                Text(
                  postCount.toString(),
                  style: const TextStyle(fontSize: 16.0),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (isAvailable)
              const Text(
                "Disponible",
                style: TextStyle(color: Colors.green),
              ),
            if (!isAvailable)
              const Text(
                "Indisponible",
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
