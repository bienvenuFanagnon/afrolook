import '../../services/media_shrink.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/admin_complements_api.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;

import 'dart:io';

import 'package:anim_search_bar/anim_search_bar.dart';


import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';


import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';

import 'package:simple_tags/simple_tags.dart';

import 'package:video_player/video_player.dart';

import 'package:dropdown_search/dropdown_search.dart';

import '../../constant/buttons.dart';

import '../../constant/sizeButtons.dart';

import '../../providers/authProvider.dart';

import '../../providers/postProvider.dart';

import '../../providers/userProvider.dart';

class NewAppAnnonce extends StatefulWidget {

  @override
  State<NewAppAnnonce> createState() => _NewAppInfoState();
}

class _NewAppInfoState extends State<NewAppAnnonce> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _nbrJrController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
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
          title: Text('New Annonce'),
        ),
        body: CenteredContent(child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    keyboardType: TextInputType.number,
                    controller: _nbrJrController,
                    decoration: InputDecoration(
                      hintText: 'Nombre de jour',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return ' obligatoire';
                      }

                      return null;
                    },
                  ),
                  /*
                  SizedBox(
                    height: 25.0,
                  ),
                  TextFormField(
                    
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Description',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'La Description est obligatoire';
                      }

                      return null;
                    },
                  ),
                  
                   */
                  SizedBox(
                    height: 100.0,
                  ),
                  GestureDetector(
                      onTap: () {
                        _getImages();
                      },
                      child: PostsButtons(
                        text: 'Sélectionner des images(2)',
                        hauteur: SizeButtons.hauteur,
                        largeur: SizeButtons.largeur,
                        urlImage: '',
                      )),
                  listimages.isNotEmpty
                      ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      children: listimages
                          .map(
                            (image) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(

                            borderRadius:
                            BorderRadius.all(Radius.circular(20)),
                            child: Container(
                              width: 100.0,
                              height: 100.0,
                              child: Image.file(
                                File(image.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  )
                      : Container(),

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
                            if (listimages.isNotEmpty) {
                              final shrunk = await MediaShrink.file(File(listimages.last.path));
                              final uploadId = await AdminComplementsApi.uploadImage(await shrunk.readAsBytes(), shrunk.path);
                              await AdminComplementsApi.createAnnonce(days: int.parse(_nbrJrController.text.trim()), mediaUploadId: uploadId);
                              _descriptionController.text='';
                              _titreController.text='';
                              _nbrJrController.text='';
                              listimages.clear();

                              setState(() {
                                onTap=false;
                              });

                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Le post a été validé avec succès !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }  else{
                              setState(() {
                                onTap=false;
                              });
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Veuillez sélectionner une image.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }

                          } catch (e) {
                            printVm("erreur ${e}");
                            setState(() {
                              onTap=false;
                            });
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                AdminComplementsApi.message(e, fallback: 'La validation du post a échoué. Veuillez réessayer.'),
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
                        child: LoadingAnimationWidget.flickr(
                          size: 20,
                          leftDotColor: Colors.green,
                          rightDotColor: Colors.black,
                        ),
                      ): PostsButtons(
                        text: 'Créer',
                        hauteur: SizeButtons.creerButtonshauteur,
                        largeur: SizeButtons.creerButtonslargeur,
                        urlImage: 'assets/images/sender.png',
                      )),
                ],
              ),
            ),
          ),
        ))
    );
  }
}
