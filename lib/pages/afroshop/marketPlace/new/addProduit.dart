import 'dart:io';

import 'package:afrotok/pages/entreprise/abonnement/Subscription.dart';
import 'package:afrotok/pages/user/conponent.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as Path;

import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';



class AddAnnonceStep1 extends StatefulWidget {
  final EntrepriseData entrepriseData;
  const AddAnnonceStep1({super.key, required this.entrepriseData});

  @override
  State<AddAnnonceStep1> createState() => _AddAnnonceState();
}

class _AddAnnonceState extends State<AddAnnonceStep1> {
  final _formKey = GlobalKey<FormState>();
  String _titre = '';
  String _description = '';
  String _numero = '';
  int _prix = 0;
  String _sousCategorieId = '';
  String _regionId = '';
  String _villeId = '';
  String _adresse = '';
  String _type = '';
  bool onSaveTap =false;
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";


  Categorie categorieSelected = Categorie();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final ImagePicker picker = ImagePicker();
  List<XFile>? _mediaFileList = [];

  String selectedCountryCode = ""; // Code par défaut (Togo)
  String selectedCountryName = ""; // Code par défaut (Togo)

  // Liste des codes ISO des pays africains
  final List<String> africanCountries = [
    'TG', 'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM',
    'CD', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW',
    'CI', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
    'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD',
    'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW'
  ];
  void pickImages() async {
    //List<ImageSource> selectedImages = await ImagePicker.pickMultipleImages();
    await picker.pickMultiImage(limit: 5).then((images) {
      setState(() {
        if (images != null && images.isNotEmpty) {
          if(widget.entrepriseData.abonnement!.type==TypeAbonement.GRATUIT.name){
            _mediaFileList!.add(images.first);

          }else{
            if (_mediaFileList!.length < 5) {
              int remainingSlots = 5 - _mediaFileList!.length;
              _mediaFileList!.addAll(images.take(remainingSlots));
            }

          }
        //  nbr_photos=_mediaFileList!.length;
        }
      });
    });
  }


  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(

        leading: Icon(icon, color: Colors.orange, size: 25),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
  bool checkIfFinished(int end) {
    if (end != null) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      return currentTime > end!;
    }
    return false;
  }
  void _showBottomSheetCompterNonValide(double width,bool isPremium) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: width,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  isPremium?"Votre plan premium est terminé.":  "Limite de plan gratuit atteinte",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(

                  isPremium?"Renouvelez maintenant pour continuer à profiter des nouvelles fonctionnalités":  'Vous avez atteint la limite de votre plan gratuit. Passez à l\'abonnement Premium pour débloquer plus d\'opportunités ! 🎉\n\n'
                      '- Ajoutez plusieurs images pour rendre vos annonces plus attractives.\n'
                      '- Boostez vos produits en publicité pour une visibilité maximale.\n'
                      '- Vos produits seront visibles sur toutes les pages de l\'application.\n',                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    // Action à effectuer lors du clic sur le bouton
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SubscriptionPage()),
                    );
                  },
                  icon: Icon(Icons.star, color: Colors.white),
                  label: Text(isPremium?"Renouveler": "Changer d'abonnement",style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Couleur de fond verte
                    // onPrimary: Colors.white, // Couleur du texte
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    categorieSelected = categorieProduitProvider.listCategorie.first;

  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    String produitRestant =widget.entrepriseData. abonnement!.type == TypeAbonement.GRATUIT.name
        ? "${widget.entrepriseData. abonnement!.nombre_pub ?? 0} restants"
        : "Illimité";
    return Scaffold(

      appBar: AppBar(
        title: Text('Publier un article'),

      ),

      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
         // autovalidateMode: AutovalidateMode.always, // Always show validation errors
          child: ListView(
            children: <Widget>[
              SizedBox(height: 2.0),
            ElevatedButton.icon(
              onPressed: () {
                // Action à effectuer lors du clic sur le bouton
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SubscriptionPage()),
                );
              },
              icon: Icon(Icons.star, color: Colors.white),
              label: Text("Changer d'abonnement",style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // Couleur de fond verte
                // onPrimary: Colors.white, // Couleur du texte
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
              _buildDetailTile(Icons.star, 'Type d\'abonnement',widget.entrepriseData. abonnement!.type ?? "Inconnu"),
              _buildDetailTile(Icons.production_quantity_limits, 'Produits restants', produitRestant),
              _buildDetailTile(Icons.image, 'Image/ Produit', widget.entrepriseData.abonnement!.nombre_image_pub!.toString()),

              SizedBox(height: 10.0),

              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Card(
                  elevation: 5,
                  surfaceTintColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      //height: 800,
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        //mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing:
                            8.0, // Espace horizontal entre les objets
                            runSpacing:
                            8.0, // Espace vertical entre les objets
                            children: _mediaFileList!.map((objet) {
                              return Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 100,
                                      width: 100,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(15)),
                                        child: Image.file(
                                          File(objet.path),
                                          errorBuilder: (BuildContext
                                          context,
                                              Object error,
                                              StackTrace? stackTrace) {
                                            return const Center(
                                                child: Text('not supported'));
                                          },
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        height: 30,
                                        width: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.only(
                                              topLeft:
                                              Radius.circular(10)),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _mediaFileList!
                                                  .remove(objet!);
                                            });
                                          },
                                          icon: Icon(
                                            FontAwesome.remove,
                                            size: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          TextButton(
                              onPressed: () {
                                pickImages();
                              },
                              child: Container(
                                height: 90,
                                width: width / 3,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(20)),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      child: Icon(
                                        AntDesign.pluscircle,
                                        color: CustomConstants.kSecondaryColor,
                                        size: height / 25,
                                      ),
                                    ),
                                    SizedBox(
                                      height: height / 70,
                                    ),
                                    Container(
                                      child: Text(
                                        "Ajouter photos",
                                        style: TextStyle(
                                          fontSize: height / 60,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0,bottom: 8),
                child: DropdownSearch<Categorie>(

                  onChanged: (Categorie? value) {
                    setState(() {
                      categorieSelected = value!;
                     // print('sous categorie id: ${sousCategorieSelected.id}');


                    });

                  },
                  validator: (value) {
                    if (value == null) {
                      return "Categorie requis.";
                    }
                    return null;
                  },

                  items: categorieProduitProvider.listCategorie,
                  filterFn: (item, filter) {
                    // Fonction de filtrage personnalisée
                    // Retourne true si l'élément doit être affiché, sinon false
                    // Par exemple, vous pouvez utiliser
                    return item.nom!.toLowerCase().toString().contains(filter.toLowerCase());
                    // pour filtrer les éléments en fonction de leur représentation sous forme de chaîne de caractères.
                  },

                  dropdownBuilder: (context, selectedItem) {

                    categorieSelected=selectedItem!;


                    return  Padding(
                      padding: const EdgeInsets.only(left: 5.0,bottom: 5,top: 10),
                      child: Text('${selectedItem.nom==null?"":selectedItem.nom}',overflow: TextOverflow.fade),
                    );

                  },


                  selectedItem: categorieSelected,

                  popupProps: PopupProps.menu(


                    searchFieldProps: TextFieldProps(
                      //controller: _userEditTextController,

                      decoration: InputDecoration(
                        // Supprimer la bordure
                        border: InputBorder.none,

                        prefixIcon:  IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () {
                            // _userEditTextController.clear();
                          },

                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            Navigator.pop(context);
                            // _userEditTextController.clear();
                          },
                        ),
                      ),
                    ),
                    showSearchBox: true,
                    showSelectedItems: false,

                    itemBuilder: (context, item, isSelected) {

                      return Padding(
                        padding: const EdgeInsets.only(left: 20.0,bottom: 8,top: 8),
                        child: Text(item.nom!,overflow: TextOverflow.fade),
                      );
                    },


                    // disabledItemFn: (UserData s) => s.startsWith('I'),
                  ),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: "Choisissez une Catégorie",
                        labelStyle: TextStyle(fontSize: 20)

                      /*
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(50.0),
                                ),

                                 */
                    ),

                  ),

                  //  popupItemBuilder: (context, item, isSelected) => _buildPopupItem(context, item, isSelected),
                ),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Titre'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
                onSaved: (value) {
                  _titre = value!;
                },
              ),
              PhoneFormField(
                decoration: InputDecoration(helperText: 'Numero WhatsApp',labelText: 'Numero WhatsApp'),

                initialValue: PhoneNumber.parse('+228'), // or use the controller
                validator: PhoneValidator.compose(
                    [PhoneValidator.required(context), PhoneValidator.validMobile(context)]),
                countrySelectorNavigator: const CountrySelectorNavigator.page(),
                onChanged: (phoneNumber) {

                  _numero=phoneNumber.international;
                },
                onSaved: (newValue) {

                  _numero=newValue!.international;

                },

                enabled: true,
                isCountrySelectionEnabled: true,
                isCountryButtonPersistent: true,
                countryButtonStyle: const CountryButtonStyle(
                    showDialCode: true,
                    showIsoCode: true,
                    showFlag: true,
                    flagSize: 16
                ),

                // + all parameters of TextField
                // + all parameters of FormField
                // ...
              ),

              // TextFormField(
              //   keyboardType: TextInputType.phone,
              //   decoration: InputDecoration(helperText: 'Exemple +22899999999',labelText: 'Numero WhatsApp'),
              //   validator: (value) {
              //     if (value!.isEmpty) {
              //       return 'Veuillez entrer un Numero WhatsApp';
              //     }
              //     return null;
              //   },
              //   onSaved: (value) {
              //     _numero = value!;
              //   },
              // ),

              TextFormField(
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Veuillez entrer une description';
                  }
                  return null;
                },
                onSaved: (value) {
                  _description = value!;
                },
              ),
              SizedBox(height: 10,),
              Row(
                children: [
                  Text(
                    "Choisir le Pays :",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  CountryCodePicker(
                    onChanged: (country) {
                      setState(() {
                        selectedCountryCode = country.code!;
                        selectedCountryName = country.name!;
                      });
                    },
                    initialSelection: 'TG', // Met Togo en tête
                    favorite: ['TG'], // Togo en favori
                    countryFilter: africanCountries, // Filtrer uniquement les pays africains
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                spacing: 5,
                children: [
                  Text(
                    "Pays sélectionné :",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "$selectedCountryName",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  countryFlag(selectedCountryCode, size: 20),
                ],
              ),
              // CSCPickerPlus(
              //
              //   showStates: true,
              //   showCities: false,
              //   // countryStateLanguage: CountryStateLanguage.,
              //   defaultCountry:  CscCountry.Togo,
              //
              //   flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
              //   dropdownDecoration: BoxDecoration(
              //     borderRadius: BorderRadius.all(Radius.circular(10)),
              //     color: Colors.white,
              //     border: Border.all(color: Colors.grey.shade300, width: 1),
              //   ),
              //   disabledDropdownDecoration: BoxDecoration(
              //     borderRadius: BorderRadius.all(Radius.circular(10)),
              //     color: Colors.grey.shade300,
              //     border: Border.all(color: Colors.grey.shade300, width: 1),
              //   ),
              //   countrySearchPlaceholder: "Pays",
              //   stateSearchPlaceholder: "Région",
              //   citySearchPlaceholder: "Ville",
              //   countryDropdownLabel: "Sélectionnez un pays",
              //   stateDropdownLabel: "Sélectionnez une région",
              //   cityDropdownLabel: "Sélectionnez une ville",
              //   countryFilter: const [
              //     // Pays africains
              //     CscCountry.Togo,
              //     CscCountry.Algeria, CscCountry.Angola, CscCountry.Benin, CscCountry.Botswana,
              //     CscCountry.Burkina_Faso, CscCountry.Burundi, CscCountry.Cameroon, CscCountry.Chad,
              //     CscCountry.Comoros, CscCountry.Congo, CscCountry.Djibouti, CscCountry.Egypt,
              //     CscCountry.Eritrea, CscCountry.Ethiopia, CscCountry.Gabon, CscCountry.Gambia_The,
              //     CscCountry.Ghana, CscCountry.Guinea, CscCountry.Kenya, CscCountry.Lesotho,
              //     CscCountry.Liberia, CscCountry.Libya, CscCountry.Madagascar, CscCountry.Malawi,
              //     CscCountry.Mali, CscCountry.Mauritania, CscCountry.Mauritius, CscCountry.Morocco,
              //     CscCountry.Mozambique, CscCountry.Namibia, CscCountry.Niger, CscCountry.Nigeria,
              //     CscCountry.Rwanda, CscCountry.Senegal, CscCountry.Seychelles, CscCountry.Sierra_Leone,
              //     CscCountry.Somalia, CscCountry.South_Africa, CscCountry.Sudan, CscCountry.Tanzania,
              //     CscCountry.Tunisia, CscCountry.Uganda, CscCountry.Zambia,
              //     CscCountry.Zimbabwe,
              //
              //     // Pays européens
              //     CscCountry.France, CscCountry.Germany, CscCountry.Italy, CscCountry.Spain,
              //     CscCountry.Portugal, CscCountry.Netherlands_The, CscCountry.Belgium, CscCountry.Sweden,
              //     CscCountry.Switzerland, CscCountry.Norway,
              //
              //     // Pays américains
              //     CscCountry.United_States, CscCountry.Canada, CscCountry.Brazil, CscCountry.Argentina,
              //     CscCountry.Mexico, CscCountry.Chile, CscCountry.Colombia, CscCountry.Peru,
              //     CscCountry.Venezuela, CscCountry.Uruguay,
              //
              //     // Pays asiatiques
              //     CscCountry.China, CscCountry.Japan, CscCountry.India,
              //     CscCountry.Thailand, CscCountry.Vietnam, CscCountry.Malaysia, CscCountry.Singapore,
              //     CscCountry.Philippines, CscCountry.Indonesia
              //   ],                  selectedItemStyle: TextStyle(
              //   color: Colors.black,
              //   fontSize: 14,
              // ),
              //   dropdownHeadingStyle: TextStyle(
              //     color: Colors.black,
              //     fontSize: 17,
              //     fontWeight: FontWeight.bold,
              //   ),
              //   dropdownItemStyle: TextStyle(
              //     color: Colors.black,
              //     fontSize: 14,
              //   ),
              //   dropdownDialogRadius: 10.0,
              //   searchBarRadius: 10.0,
              //   // currentCountry: "Togo",
              //
              //   onCountryChanged: (value) {
              //
              //     setState(() {
              //       countryValue = value;
              //     });
              //   },
              //   onStateChanged: (value) {
              //     setState(() {
              //       stateValue = value ?? "";
              //     });
              //   },
              //   onCityChanged: (value) {
              //     setState(() {
              //       cityValue = value ?? "";
              //     });
              //   },
              // ),

              TextFormField(
                decoration: InputDecoration(labelText: 'Prix'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Veuillez entrer un prix';
                  }
                  return null;
                },
                onSaved: (value) {
                  _prix = int.parse(value!);
                },
              ),


              SizedBox(height: height*0.12),

/*
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                hint: const Text('Choisissez une ville'),
                items: regions.map((subcategory) {
                  return DropdownMenuItem<String>(
                    value: subcategory,
                    child: Text(subcategory),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                  });
                },
              ),


 */
              // Ajoutez des champs pour les autres données de l'annonce ici


            ],
          ),
        ),
      ),
      bottomSheet:     Container(
        height: 100,
        width: width,

        child: TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              if (selectedCountryCode .isNotEmpty) {
                // Les valeurs de pays et de ville ont été sélectionnées
                print("Pays: $countryValue, Ville: $cityValue");

                ArticleData annonceRegisterData =ArticleData();
                annonceRegisterData.images=[];
                annonceRegisterData.titre=_titre;
                annonceRegisterData.dispo_annonce_afrolook=false;
                annonceRegisterData.description=_description;
                annonceRegisterData.phone=_numero;
                annonceRegisterData.vues=0;
                annonceRegisterData.popularite=1;
                annonceRegisterData.jaime=0;
                annonceRegisterData.contact=0;
                annonceRegisterData.partage=0;
                annonceRegisterData.prix=_prix;
                annonceRegisterData.user_id=authProvider.loginUserData.id!;
                annonceRegisterData.categorie_id=categorieSelected.id;
                Map<String, String> countryData = {
                  "country": selectedCountryName,
                  "state": "",
                  "city": '',
                  "countryCode": selectedCountryCode!,
                };
                annonceRegisterData.countryData=countryData;
                if(widget.entrepriseData.abonnement!=null){

                  if(widget.entrepriseData.abonnement!.type==TypeAbonement.GRATUIT.name){
                    if(widget.entrepriseData.abonnement!.nombre_pub!>0){


                      //  print('sous categorie id: $sousCategorieSelected.id');




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
                            .then((value) async {
                          if (value) {
                            widget.entrepriseData.produitsIds!.add(postId);
                            widget.entrepriseData.abonnement!.nombre_pub=widget.entrepriseData.abonnement!.nombre_pub!-1;
                            authProvider.updateEntreprise( widget.entrepriseData);
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

                            authProvider
                                .getAllUsersOneSignaUserId()
                                .then(
                                  (userIds) async {
                                if (userIds.isNotEmpty) {
                                  await authProvider.sendNotification(
                                      userIds: [annonceRegisterData.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${annonceRegisterData.user!.id!}",
                                      message:
                                      "📢 🛒 @${authProvider.loginUserData.pseudo!} a posté un nouveau produit ! Découvrez-le maintenant ! 🛒",
                                      type_notif:
                                      NotificationType.ARTICLE.name,
                                      post_id: "${annonceRegisterData!.id!}",
                                      post_type: PostDataType.IMAGE.name,
                                      chat_id: '');
                                }
                              },
                            );



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


                    }else{
                      _showBottomSheetCompterNonValide(width,false);
                    }
                  }else{
                    if(!checkIfFinished(widget.entrepriseData.abonnement!.end!) ){




                      //  print('sous categorie id: $sousCategorieSelected.id');




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
                            widget.entrepriseData.produitsIds!.add(postId);
                            widget.entrepriseData.abonnement!.nombre_pub=widget.entrepriseData.abonnement!.nombre_pub!-1;
                            authProvider.updateEntreprise( widget.entrepriseData);
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


                    }else{
                      _showBottomSheetCompterNonValide(width,true);

                    }
                  }



                }

              } else {
              // Afficher un message d'erreur
              print("Veuillez sélectionner un pays");
              final snackBar = SnackBar(
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                  content: Text(
                    "Veuillez sélectionner un pays",
                    style: TextStyle(
                        color: Colors.white),));
              // Afficher le SnackBar en bas de la page
              ScaffoldMessenger.of(context)
                  .showSnackBar(snackBar);
              setState(() {
                onSaveTap = false;
              });
            }
              print('Titre: $_titre');
              print('Description: $_description');
              print('Prix: $_prix');
              print('Phone:');
              print('Phone: $_numero');

               // Navigator.push(context, MaterialPageRoute(builder: (context) => AddAnnonceStep4(annonceRegisterData: annonceRegisterData),));


            }
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
              child: Text('Enregistrer',style: TextStyle(color: Colors.white),)),
        ),
      ),
    );
  }
}