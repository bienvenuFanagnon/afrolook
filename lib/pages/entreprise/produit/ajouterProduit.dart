import 'dart:io';

import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:video_player/video_player.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeButtons.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';


class AddProduit extends StatefulWidget {
  @override
  State<AddProduit> createState() => _AddProduitState();
}

class _AddProduitState extends State<AddProduit> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> content = [
    'Apple',
    'Banana',
    'Orange',
    'Pomme',
    'Carambola',
    'Cherries',
  ];

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  late  List<XFile> listimages = [];

  final ImagePicker picker = ImagePicker();

  Future<void> _getImages() async {

    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() {
        listimages = images;
      });
    });

  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(
        appBar: AppBar(
          title: TextCustomerPageTitle(
            titre: "Nouveau produit",
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
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: height*0.85,

            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titreController,
                          decoration: InputDecoration(
                            hintText: 'Titre',
                          ),
                        ),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Description',
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(
                          height: 16.0,
                        ),

                        SizedBox(
                          height: 16.0,
                        ),
                        GestureDetector(
                            onTap: () {
                              _getImages();
                            },
                            child: PostsButtons(text: 'Sélectionner des images', hauteur: SizeButtons.hauteur, largeur: SizeButtons.largeur, urlImage: '',)
                        ),


                        listimages.isNotEmpty
                            ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Wrap(
                            children: listimages
                                .map(
                                  (image) => Image.file(
                                File(image.path),
                                width: 80.0,
                                height: 50.0,
                              ),
                            )
                                .toList(),
                          ),
                        )
                            : Container(),
                        SizedBox(
                          height: 5,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Tags')),
                              SizedBox(
                                height: 50,
                                width: 100,

                                child: DropdownSearch<String>(
                                  popupProps: PopupProps.menu(
                                    showSelectedItems: true,
                                    disabledItemFn: (String s) => s.startsWith('I'),
                                  ),
                                  items: ["Brazil", "Italia (Disabled)", "Tunisia", 'Canada'],
                                  dropdownDecoratorProps: DropDownDecoratorProps(
                                    dropdownSearchDecoration: InputDecoration(

                                      hintText: "tags",
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      content.add(value!);
                                    });
                                  },
                                  selectedItem: "Brazil",
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        SimpleTags(
                          content: content,
                          wrapSpacing: 4,
                          wrapRunSpacing: 4,
                          onTagPress: (tag) {print('pressed $tag');
                          setState(() {
                            content.remove(tag);
                          });
                          },
                          onTagLongPress: (tag) {print('long pressed $tag');},
                          onTagDoubleTap: (tag) {print('double tapped $tag');

                          },
                          tagContainerPadding: EdgeInsets.all(6),
                          tagTextStyle: TextStyle(color: Colors.blueAccent),
                          tagIcon: Icon(Icons.clear, size: 12),
                          tagContainerDecoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.all(
                              Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(139, 139, 142, 0.16),
                                spreadRadius: 1,
                                blurRadius: 1,
                                offset: Offset(1.75, 3.5), // c
                              )
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 60,
                        ),
                        GestureDetector(
                            onTap: () {
                              //_getImages();
                            },
                            child: PostsButtons(text: 'Créer', hauteur: SizeButtons.creerButtonshauteur, largeur: SizeButtons.creerButtonslargeur, urlImage: 'assets/images/sender.png',)
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
    );
  }
}