import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/splashChargement.dart';
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

class _UpdateUserDataState extends State<UpdateUserData>
    with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";
  bool isLoading = false;
  late UserAuthProvider authProvider;
  String? detectedCountryCode;
  String? detectedCountryName;
  bool hasRequestedLocation = false;
  bool _showingPermissionModal = false;

  // Couleurs de la marque
  final Color primaryBlack = Colors.black;
  final Color primaryRed = Color(0xFFE63946);
  final Color primaryYellow = Color(0xFFFFD700);

  Future<void> _getCountryCodeInBackground() async {
    if (kIsWeb) return;
    if (hasRequestedLocation) return;

    setState(() => hasRequestedLocation = true);

    final PermissionStatus permission = await Permission.location.request();

    if (permission.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty && mounted) {
          setState(() {
            detectedCountryCode = placemarks[0].isoCountryCode;
            detectedCountryName = placemarks[0].country;
            stateValue = placemarks[0].administrativeArea ?? "";
            cityValue = placemarks[0].locality ?? "";
          });
        }
      } catch (e) {
        printVm("Erreur géolocalisation: $e");
      }
    } else {
      // Permission refusée → modal bloquant
      _showLocationPermissionModal();
    }
  }

  void _showLocationPermissionModal() {
    if (_showingPermissionModal || !mounted) return;
    setState(() => _showingPermissionModal = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryRed, primaryYellow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.black, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  "Localisation requise",
                  style: TextStyle(
                    color: primaryYellow,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  "Afrolook utilise ta localisation pour te connecter avec des personnes et des contenus près de toi, et pour t'offrir la meilleure expérience possible.\n\nCette autorisation est indispensable pour continuer.",
                  style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.settings, color: Colors.black),
                    label: const Text(
                      "Ouvrir les paramètres",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => openAppSettings(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showingPermissionModal) {
      // L'utilisateur revient des paramètres — vérifier si la permission est accordée
      Permission.location.status.then((status) {
        if (status.isGranted && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            _showingPermissionModal = false;
            hasRequestedLocation = false; // permet de relancer
          });
          _getCountryCodeInBackground();
        }
      });
    }
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      // Géolocalisation requise — pas de sélection manuelle
      if (!kIsWeb && detectedCountryCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Localisation en cours, veuillez patienter…',
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
        "country": detectedCountryName ?? "",
        "state": stateValue,
        "city": cityValue,
        "countryCode": detectedCountryCode ?? "",
        "realCountry": detectedCountryName ?? "",
      };

      printVm("=== Informations localisation ===");
      printVm("Pays: ${detectedCountryName ?? "Non détecté"}");
      printVm("Code pays: ${detectedCountryCode ?? "Non détecté"}");
      printVm("Région: $stateValue");
      printVm("Ville: $cityValue");

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
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SplashChargement(),
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
    WidgetsBinding.instance.addObserver(this);
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCountryCodeInBackground();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
                                ? "Ta localisation est détectée automatiquement"
                                : "Ta localisation est détectée automatiquement",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Localisation détectée automatiquement (lecture seule)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryRed.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: detectedCountryCode == null
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(primaryYellow),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  "Détection de ta localisation…",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on, color: primaryYellow, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        detectedCountryName ?? detectedCountryCode!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryYellow.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: primaryYellow.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        detectedCountryCode!,
                                        style: TextStyle(
                                          color: primaryYellow,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (stateValue.isNotEmpty || cityValue.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    [if (stateValue.isNotEmpty) stateValue, if (cityValue.isNotEmpty) cityValue].join(", "),
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  "Localisation détectée automatiquement — non modifiable.",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
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
//         printVm("Code pays : $countryCode");
//         // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
//       } else {
//         printVm("Impossible de récupérer le code pays");
//       }
//       printVm("Code pays : $countryCode");
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
//       printVm("Données enregistrées: $userData");
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
//         printVm("Erreur lors de la récupération du pays: $e");
//         return null;
//       }
//     } else {
//       // Si la permission n'est pas accordée, vous pouvez redemander ou afficher un message
//       printVm("Permission de localisation non accordée.");
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
//       printVm("Code pays : $countryCode");
//       // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
//     } else {
//       printVm("Impossible de récupérer le code pays");
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
