
import 'package:path/path.dart' as Path;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/model_data.dart';






class AddCategorie extends StatefulWidget {

  @override
  State<AddCategorie> createState() => _NewAppInfoState();
}

class _NewAppInfoState extends State<AddCategorie> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

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
    return  Scaffold(
        appBar: AppBar(
          title: Text('New Categorie'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    SizedBox(
                      height: height*0.1,
                    ),
                    SizedBox(
                      width: width*0.7,
                      child: TextFormField(

                        controller: _titreController,
                        decoration: InputDecoration(
                          hintText: "Nom de la categorie",
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Le nom est obligatoire';
                          }

                          return null;
                        },
                      ),
                    ),


                    SizedBox(
                      height: 50.0,
                    ),
                    // GestureDetector(
                    //   onTap: () {
                    //     _getImages();
                    //   },
                    //   child: Container(
                    //     height: 50,
                    //     width: width*0.5,
                    //     alignment: Alignment.center,
                    //     decoration: BoxDecoration(
                    //         color: Colors.green,
                    //         borderRadius: BorderRadius.all(Radius.circular(10))
                    //     ),
                    //     child: Text("Sélectionner des images(2)"),
                    //   ),
                    // ),
                    // listimages.isNotEmpty
                    //     ? Padding(
                    //   padding: const EdgeInsets.all(8.0),
                    //   child: Wrap(
                    //     children: listimages
                    //         .map(
                    //           (image) => Padding(
                    //         padding: const EdgeInsets.only(right: 8.0),
                    //         child: ClipRRect(
                    //
                    //           borderRadius:
                    //           BorderRadius.all(Radius.circular(20)),
                    //           child: Container(
                    //             width: 100.0,
                    //             height: 100.0,
                    //             child: Image.file(
                    //               File(image.path),
                    //               fit: BoxFit.cover,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     )
                    //         .toList(),
                    //   ),
                    // )
                    //     : Container(),

                    SizedBox(
                      height: 60,
                    ),
                    GestureDetector(
                        onTap:onTap?(){}: () async {
                          //_getImages();
                          if (_formKey.currentState!.validate()) {

                            setState(() {
                              onTap=true;
                            });

                            try {
                              String postId = FirebaseFirestore.instance
                                  .collection('Categories')
                                  .doc()
                                  .id;
                              Categorie infos = Categorie();
                              infos.id = postId;

                              // infos.description = _descriptionController.text;
                              infos.nom = _titreController.text;
                              infos.updatedAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              infos.createdAt =
                                  DateTime.now().microsecondsSinceEpoch;



                              // for (XFile _image in listimages) {
                              //   Reference storageReference =
                              //   FirebaseStorage.instance.ref().child(
                              //       'logos_categorie/${Path.basename(File(_image.path).path)}');
                              //
                              //   UploadTask uploadTask = storageReference
                              //       .putFile(File(_image.path)!);
                              //   await uploadTask.whenComplete(() async {
                              //     await storageReference
                              //         .getDownloadURL()
                              //         .then((fileURL) {
                              //       print("url media");
                              //       //  print(fileURL);
                              //
                              //       infos.logo=fileURL;
                              //     });
                              //   });
                              // }
                              await FirebaseFirestore.instance
                                  .collection('Categories')
                                  .doc(postId)
                                  .set(infos.toJson());
                              _descriptionController.text='';
                              _titreController.text='';
                              listimages.clear();
                              setState(() {
                                onTap=false;
                              });


                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  "La categorie a été validé avec succès !",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } catch (e) {
                              print("erreur ${e}");
                              setState(() {
                                onTap=false;
                              });
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'La validation du post a échoué. Veuillez réessayer.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          }

                        },
                        child:onTap? Center(
                            child: Container(child: CircularProgressIndicator(),)
                        ): Container(
                          height: 50,
                          width: width*0.7,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.all(Radius.circular(10))
                          ),
                          child: Text("Creer",style: TextStyle(color: Colors.white,fontSize: 20,fontWeight: FontWeight.w600),),
                        )),
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}
