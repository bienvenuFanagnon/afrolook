import 'package:afrotok/pages/splashChargement.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../providers/authProvider.dart';

class UpdateUserData extends StatefulWidget {
  UpdateUserData({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _UpdateUserDataState createState() => _UpdateUserDataState();
}

class _UpdateUserDataState extends State<UpdateUserData> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";
  bool isLoading = false;
  late UserAuthProvider authProvider;
  String? detectedCountryCode;
  String? detectedCountryName;
  bool hasRequestedLocation = false;

  // Couleurs de la marque
  final Color primaryBlack = Colors.black;
  final Color primaryRed = Color(0xFFE63946);
  final Color primaryYellow = Color(0xFFFFD700);

  Future<void> _getCountryCodeInBackground() async {
    // Ne pas exécuter sur le web car la géolocalisation ne fonctionne pas
    if (kIsWeb) {
      print("Plateforme Web: La géolocalisation n'est pas disponible");
      return;
    }

    // Vérifier si on a déjà fait la demande
    if (hasRequestedLocation) return;

    setState(() {
      hasRequestedLocation = true;
    });

    // Demander la permission de localisation en arrière-plan
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      try {
        // Récupérer la position actuelle
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );

        // Récupérer les informations d'adresse
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude
        );

        if (placemarks.isNotEmpty) {
          setState(() {
            detectedCountryCode = placemarks[0].isoCountryCode;
            detectedCountryName = placemarks[0].country;
          });

          print("Localisation détectée en arrière-plan (Mobile): $detectedCountryName ($detectedCountryCode)");
        }
      } catch (e) {
        print("Erreur lors de la récupération de la localisation: $e");
      }
    } else {
      print("Permission de localisation non accordée sur mobile");
    }
  }

  Future<String?> getCountryCode() async {
    if (kIsWeb) return null;

    // ✅ toujours demander la permission ici
    PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          return placemarks[0].isoCountryCode;
        }
      } catch (e) {
        print("Erreur: $e");
      }
    }

    return null;
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      // Vérifier si le pays a été sélectionné
      if (countryValue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez sélectionner un pays',
                style: TextStyle(color: Colors.white)),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      Map<String, String> userData = {
        "country": countryValue,
        "state": stateValue,
        "city": cityValue,
      };

      // Sur mobile, on récupère le vrai code pays en arrière-plan
      if (!kIsWeb) {
        String? realCountryCode = await getCountryCode();

        userData["countryCode"] = realCountryCode ?? detectedCountryCode ?? "";
        userData["realCountry"] = detectedCountryName ?? "";

        print("=== Informations utilisateur (Mobile) ===");
        print("Pays choisi par l'utilisateur: $countryValue");
        print("Région choisie: $stateValue");
        print("Ville choisie: $cityValue");
        print("=== Informations réelles (Localisation mobile) ===");
        print("Vrai pays: ${detectedCountryName ?? "Non détecté"}");
        print("Vrai code pays: ${realCountryCode ?? "Non détecté"}");
      } else {
        // Sur le web, on n'utilise que les informations choisies
        userData["countryCode"] = "";
        userData["realCountry"] = "";

        print("=== Informations utilisateur (Web) ===");
        print("Pays choisi par l'utilisateur: $countryValue");
        print("Région choisie: $stateValue");
        print("Ville choisie: $cityValue");
        print("=== Note ===");
        print("Géolocalisation non disponible sur le web");
      }

      authProvider.loginUserData.countryData = userData;
      await authProvider.updateUserCountryCode(authProvider.loginUserData).then((value) async {
        if (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Information enregistrée',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: primaryYellow,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SplahsChargement(postId: '', postType: ''),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur d'enregistrement",
                  style: TextStyle(color: Colors.white)),
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    // Récupérer la localisation en arrière-plan uniquement sur mobile
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCountryCodeInBackground();
      });
    } else {
      print("Plateforme Web: Désactivation de la géolocalisation automatique");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Personnaliser le thème pour les dialogues
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.grey[900],
          titleTextStyle: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        // Personnaliser les couleurs des textes dans les listes
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: primaryYellow),
        ),
        // Personnaliser l'AppBar des dialogues
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: primaryYellow,
          titleTextStyle: TextStyle(
            color: primaryYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: primaryBlack,
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(
              color: primaryYellow,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          backgroundColor: primaryBlack,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryYellow),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Container(
              height: 1,
              color: primaryRed.withOpacity(0.3),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec illustration
                    Container(
                      margin: EdgeInsets.only(bottom: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryRed, primaryYellow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: primaryBlack,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Où te trouves-tu ?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            kIsWeb
                                ? "Sélectionne ton pays et ta région"
                                : "Sélectionne ton pays et ta région (localisation automatique)",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sélecteur de pays
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryRed.withOpacity(0.3)),
                      ),
                      child: CSCPickerPlus(
                        showStates: true,
                        showCities: false,
                        defaultCountry: CscCountry.Togo,
                        flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                        dropdownDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[850],
                          border: Border.all(color: primaryRed.withOpacity(0.5), width: 1),
                        ),
                        disabledDropdownDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[800],
                          border: Border.all(color: Colors.grey[700]!, width: 1),
                        ),
                        countrySearchPlaceholder: "Rechercher un pays",
                        stateSearchPlaceholder: "Rechercher une région",
                        citySearchPlaceholder: "Rechercher une ville",
                        countryDropdownLabel: "Sélectionnez un pays",
                        stateDropdownLabel: "Sélectionnez une région",
                        cityDropdownLabel: "Sélectionnez une ville",

                        countryFilter: const [
                          // Pays africains
                          CscCountry.Togo,
                          CscCountry.Algeria, CscCountry.Angola, CscCountry.Benin, CscCountry.Botswana,
                          CscCountry.Burkina_Faso, CscCountry.Burundi, CscCountry.Cameroon, CscCountry.Chad,
                          CscCountry.Comoros, CscCountry.Congo, CscCountry.Djibouti, CscCountry.Egypt,
                          CscCountry.Eritrea, CscCountry.Ethiopia, CscCountry.Gabon, CscCountry.Gambia_The,
                          CscCountry.Ghana, CscCountry.Guinea, CscCountry.Kenya, CscCountry.Lesotho,
                          CscCountry.Liberia, CscCountry.Libya, CscCountry.Madagascar, CscCountry.Malawi,
                          CscCountry.Mali, CscCountry.Mauritania, CscCountry.Mauritius, CscCountry.Morocco,
                          CscCountry.Mozambique, CscCountry.Namibia, CscCountry.Niger, CscCountry.Nigeria,
                          CscCountry.Rwanda, CscCountry.Senegal, CscCountry.Seychelles, CscCountry.Sierra_Leone,
                          CscCountry.Somalia, CscCountry.South_Africa, CscCountry.Sudan, CscCountry.Tanzania,
                          CscCountry.Tunisia, CscCountry.Uganda, CscCountry.Zambia,
                          CscCountry.Zimbabwe,
                          // Pays européens
                          CscCountry.France, CscCountry.Germany, CscCountry.Italy, CscCountry.Spain,
                          CscCountry.Portugal, CscCountry.Netherlands_The, CscCountry.Belgium, CscCountry.Sweden,
                          CscCountry.Switzerland, CscCountry.Norway,
                          // Pays américains
                          CscCountry.United_States, CscCountry.Canada, CscCountry.Brazil, CscCountry.Argentina,
                          CscCountry.Mexico, CscCountry.Chile, CscCountry.Colombia, CscCountry.Peru,
                          CscCountry.Venezuela, CscCountry.Uruguay,
                          // Pays asiatiques
                          CscCountry.China, CscCountry.Japan, CscCountry.India,
                          CscCountry.Thailand, CscCountry.Vietnam, CscCountry.Malaysia, CscCountry.Singapore,
                          CscCountry.Philippines, CscCountry.Indonesia
                        ],

                        // Styles pour une meilleure visibilité
                        selectedItemStyle: TextStyle(
                          color: Colors.yellow,
                          fontSize: 14,
                        ),
                        dropdownHeadingStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownItemStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        dropdownDialogRadius: 16.0,
                        searchBarRadius: 12.0,

                        onCountryChanged: (value) {
                          setState(() {
                            countryValue = value;
                          });
                        },
                        onStateChanged: (value) {
                          setState(() {
                            stateValue = value ?? "";
                          });
                        },
                        onCityChanged: (value) {
                          setState(() {
                            cityValue = value ?? "";
                          });
                        },
                      ),
                    ),

                    SizedBox(height: 32),

                    // Bouton d'enregistrement
                    isLoading
                        ? Center(
                      child: Container(
                        height: 56,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryYellow),
                          strokeWidth: 3,
                        ),
                      ),
                    )
                        : Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveData,
                        child: Text(
                          "Enregistrer",
                          style: TextStyle(
                            color: primaryBlack,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: primaryYellow.withOpacity(0.3),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Message optionnel
                    Center(
                      child: Text(
                        kIsWeb
                            ? "Sur le web, seul ton choix est enregistré"
                            : "Tes informations réelles sont aussi enregistrées en arrière-plan",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// import 'package:afrotok/pages/splashChargement.dart';
// import 'package:csc_picker_plus/csc_picker_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
//
// import '../../../../providers/authProvider.dart';
//
// class UpdateUserData extends StatefulWidget {
//   UpdateUserData({Key? key, required this.title}) : super(key: key);
//
//   final String title;
//
//   @override
//   _UpdateUserDataState createState() => _UpdateUserDataState();
// }
//
// class _UpdateUserDataState extends State<UpdateUserData> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   String countryValue = "";
//   String stateValue = "";
//   String cityValue = "";
//   bool isLoading = false;
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//
//   Future<void> _saveData() async {
//     if (_formKey.currentState!.validate()) {
//
// setState(() {
//   isLoading=true;
// });
//       // Récupérer le code du pays
//       String? countryCode = await getCountryCode();
//
//       if (countryCode != null) {
//         print("Code pays : $countryCode");
//         // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
//       } else {
//         print("Impossible de récupérer le code pays");
//       }
//       print("Code pays : $countryCode");
//
//       Map<String, String> userData = {
//         "country": countryValue,
//         "state": stateValue,
//         "city": cityValue,
//         "countryCode": countryCode!,
//       };
//       authProvider.loginUserData.countryData=userData;
//       await authProvider.updateUserCountryCode(authProvider.loginUserData).then((value) async {
//         if(value){
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('information enregistrée', style: TextStyle(color: Colors.white)),
//               backgroundColor: Colors.green,
//             ),
//           );
//           Navigator.pop(context);
//           await Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => SplahsChargement( postId: '', postType: '',),
//             ),
//           );
//         }else{
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text("Erreur d'enregistrement", style: TextStyle(color: Colors.white)),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//       },);
// setState(() {
//   isLoading=false;
// });
//       print("Données enregistrées: $userData");
//     }
//   }
//
//   Future<String?> getCountryCode() async {
//     // Demander la permission d'accès à la localisation
//     PermissionStatus permission = await Permission.location.request();
//
//     // Vérifier si la permission est accordée
//     if (permission.isGranted) {
//       try {
//         // Récupérer la position actuelle de l'utilisateur
//         final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//
//         // Utiliser les coordonnées pour récupérer l'adresse
//         List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
//
//         // Vérifier si l'on a bien récupéré les données de localisation
//         if (placemarks.isNotEmpty) {
//           // Récupérer le code du pays
//           return placemarks[0].isoCountryCode;  // Code du pays, ex: "US", "FR"
//         }
//       } catch (e) {
//         print("Erreur lors de la récupération du pays: $e");
//         return null;
//       }
//     } else {
//       // Si la permission n'est pas accordée, vous pouvez redemander ou afficher un message
//       print("Permission de localisation non accordée.");
//       return null;
//     }
//     return null;  // Retourner null si aucune donnée valide n'est trouvée
//   }
//
//   void createAccount() async {
//     // Récupérer le code du pays
//     String? countryCode = await getCountryCode();
//
//     if (countryCode != null) {
//       print("Code pays : $countryCode");
//       // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
//     } else {
//       print("Impossible de récupérer le code pays");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title,style: TextStyle(color: Colors.white),),
//         backgroundColor: Colors.green,
//       ),
//       body: Center(
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 20),
//           height: 600,
//           child: Form(
//             key: _formKey,
//             child: Column(
//               children: [
//                 CSCPickerPlus(
//
//                   showStates: true,
//                   showCities: false,
//                   // countryStateLanguage: CountryStateLanguage.,
//                   defaultCountry:  CscCountry.Togo,
//
//                   flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
//                   dropdownDecoration: BoxDecoration(
//                     borderRadius: BorderRadius.all(Radius.circular(10)),
//                     color: Colors.white,
//                     border: Border.all(color: Colors.grey.shade300, width: 1),
//                   ),
//                   disabledDropdownDecoration: BoxDecoration(
//                     borderRadius: BorderRadius.all(Radius.circular(10)),
//                     color: Colors.grey.shade300,
//                     border: Border.all(color: Colors.grey.shade300, width: 1),
//                   ),
//                   countrySearchPlaceholder: "Pays",
//                   stateSearchPlaceholder: "Région",
//                   citySearchPlaceholder: "Ville",
//                   countryDropdownLabel: "Sélectionnez un pays",
//                   stateDropdownLabel: "Sélectionnez une région",
//                   cityDropdownLabel: "Sélectionnez une ville",
//                   countryFilter: const [
//                     // Pays africains
//                     CscCountry.Togo,
//                     CscCountry.Algeria, CscCountry.Angola, CscCountry.Benin, CscCountry.Botswana,
//                     CscCountry.Burkina_Faso, CscCountry.Burundi, CscCountry.Cameroon, CscCountry.Chad,
//                     CscCountry.Comoros, CscCountry.Congo, CscCountry.Djibouti, CscCountry.Egypt,
//                     CscCountry.Eritrea, CscCountry.Ethiopia, CscCountry.Gabon, CscCountry.Gambia_The,
//                     CscCountry.Ghana, CscCountry.Guinea, CscCountry.Kenya, CscCountry.Lesotho,
//                     CscCountry.Liberia, CscCountry.Libya, CscCountry.Madagascar, CscCountry.Malawi,
//                     CscCountry.Mali, CscCountry.Mauritania, CscCountry.Mauritius, CscCountry.Morocco,
//                     CscCountry.Mozambique, CscCountry.Namibia, CscCountry.Niger, CscCountry.Nigeria,
//                     CscCountry.Rwanda, CscCountry.Senegal, CscCountry.Seychelles, CscCountry.Sierra_Leone,
//                     CscCountry.Somalia, CscCountry.South_Africa, CscCountry.Sudan, CscCountry.Tanzania,
//                     CscCountry.Tunisia, CscCountry.Uganda, CscCountry.Zambia,
//                     CscCountry.Zimbabwe,
//
//                     // Pays européens
//                     CscCountry.France, CscCountry.Germany, CscCountry.Italy, CscCountry.Spain,
//                     CscCountry.Portugal, CscCountry.Netherlands_The, CscCountry.Belgium, CscCountry.Sweden,
//                     CscCountry.Switzerland, CscCountry.Norway,
//
//                     // Pays américains
//                     CscCountry.United_States, CscCountry.Canada, CscCountry.Brazil, CscCountry.Argentina,
//                     CscCountry.Mexico, CscCountry.Chile, CscCountry.Colombia, CscCountry.Peru,
//                     CscCountry.Venezuela, CscCountry.Uruguay,
//
//                     // Pays asiatiques
//                     CscCountry.China, CscCountry.Japan, CscCountry.India,
//                     CscCountry.Thailand, CscCountry.Vietnam, CscCountry.Malaysia, CscCountry.Singapore,
//                     CscCountry.Philippines, CscCountry.Indonesia
//                   ],                  selectedItemStyle: TextStyle(
//                     color: Colors.black,
//                     fontSize: 14,
//                   ),
//                   dropdownHeadingStyle: TextStyle(
//                     color: Colors.black,
//                     fontSize: 17,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   dropdownItemStyle: TextStyle(
//                     color: Colors.black,
//                     fontSize: 14,
//                   ),
//                   dropdownDialogRadius: 10.0,
//                   searchBarRadius: 10.0,
//                   // currentCountry: "Togo",
//
//                   onCountryChanged: (value) {
//                     setState(() {
//                       countryValue = value;
//                     });
//                   },
//                   onStateChanged: (value) {
//                     setState(() {
//                       stateValue = value ?? "";
//                     });
//                   },
//                   onCityChanged: (value) {
//                     setState(() {
//                       cityValue = value ?? "";
//                     });
//                   },
//                 ),
//                 SizedBox(height: 20),
//                 isLoading?Center(child: SizedBox(height: 30,width: 30, child: CircularProgressIndicator())): ElevatedButton(
//                   onPressed: _saveData,
//                   child: Text("Enregistrer",style: TextStyle(color: Colors.white),),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     // onPrimary: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }