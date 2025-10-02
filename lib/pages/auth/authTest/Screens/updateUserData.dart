import 'package:afrotok/pages/splashChargement.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter/material.dart';
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
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {

setState(() {
  isLoading=true;
});
      // Récupérer le code du pays
      String? countryCode = await getCountryCode();

      if (countryCode != null) {
        print("Code pays : $countryCode");
        // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
      } else {
        print("Impossible de récupérer le code pays");
      }
      print("Code pays : $countryCode");

      Map<String, String> userData = {
        "country": countryValue,
        "state": stateValue,
        "city": cityValue,
        "countryCode": countryCode!,
      };
      authProvider.loginUserData.countryData=userData;
      await authProvider.updateUserCountryCode(authProvider.loginUserData).then((value) async {
        if(value){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('information enregistrée', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SplahsChargement( postId: '', postType: '',),
            ),
          );
        }else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur d'enregistrement", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
        }
      },);
setState(() {
  isLoading=false;
});
      print("Données enregistrées: $userData");
    }
  }

  Future<String?> getCountryCode() async {
    // Demander la permission d'accès à la localisation
    PermissionStatus permission = await Permission.location.request();

    // Vérifier si la permission est accordée
    if (permission.isGranted) {
      try {
        // Récupérer la position actuelle de l'utilisateur
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        // Utiliser les coordonnées pour récupérer l'adresse
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

        // Vérifier si l'on a bien récupéré les données de localisation
        if (placemarks.isNotEmpty) {
          // Récupérer le code du pays
          return placemarks[0].isoCountryCode;  // Code du pays, ex: "US", "FR"
        }
      } catch (e) {
        print("Erreur lors de la récupération du pays: $e");
        return null;
      }
    } else {
      // Si la permission n'est pas accordée, vous pouvez redemander ou afficher un message
      print("Permission de localisation non accordée.");
      return null;
    }
    return null;  // Retourner null si aucune donnée valide n'est trouvée
  }

  void createAccount() async {
    // Récupérer le code du pays
    String? countryCode = await getCountryCode();

    if (countryCode != null) {
      print("Code pays : $countryCode");
      // Continuez à utiliser ce code pour enregistrer l'utilisateur dans votre base de données
    } else {
      print("Impossible de récupérer le code pays");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          height: 600,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CSCPickerPlus(

                  showStates: true,
                  showCities: false,
                  // countryStateLanguage: CountryStateLanguage.,
                  defaultCountry:  CscCountry.Togo,

                  flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                  dropdownDecoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  disabledDropdownDecoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.grey.shade300,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  countrySearchPlaceholder: "Pays",
                  stateSearchPlaceholder: "Région",
                  citySearchPlaceholder: "Ville",
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
                  ],                  selectedItemStyle: TextStyle(
                    color: Colors.black,
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
                  dropdownDialogRadius: 10.0,
                  searchBarRadius: 10.0,
                  // currentCountry: "Togo",

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
                SizedBox(height: 20),
                isLoading?Center(child: SizedBox(height: 30,width: 30, child: CircularProgressIndicator())): ElevatedButton(
                  onPressed: _saveData,
                  child: Text("Enregistrer",style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    // onPrimary: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}