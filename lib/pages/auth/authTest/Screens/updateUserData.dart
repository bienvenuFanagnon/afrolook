import 'package:csc_picker_plus/csc_picker_plus.dart';
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

  // Variable pour forcer le mode manuel sur mobile en cas d'échec/refus
  bool _forceManualInput = false;

  final Color primaryBlack = Colors.black;
  final Color primaryRed = Color(0xFFE63946);
  final Color primaryYellow = Color(0xFFFFD700);

  Future<void> _getCountryCodeInBackground() async {
    if (kIsWeb || _forceManualInput) return;
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
        // En cas d'erreur GPS, on bascule automatiquement sur le choix manuel
        setState(() => _forceManualInput = true);
      }
    } else {
      // Permission refusée -> basculer sur le mode manuel
      setState(() => _forceManualInput = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showingPermissionModal) {
      Permission.location.status.then((status) {
        if (status.isGranted && mounted) {
          setState(() {
            _showingPermissionModal = false;
            hasRequestedLocation = false;
            _forceManualInput = false;
          });
          _getCountryCodeInBackground();
        }
      });
    }
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      bool isManual = kIsWeb || _forceManualInput;

      if (!isManual && detectedCountryCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Localisation en cours, veuillez patienter…'), backgroundColor: primaryRed),
        );
        return;
      }

      if (isManual && countryValue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner un pays'), backgroundColor: primaryRed),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      String finalCountry = isManual ? countryValue : (detectedCountryName ?? "");
      String finalCode = isManual ? (countryValue.isNotEmpty ? "MANUAL" : "") : (detectedCountryCode ?? "");

      Map<String, String> userData = {
        "country": finalCountry,
        "state": stateValue,
        "city": cityValue,
        "countryCode": finalCode,
        "realCountry": finalCountry,
      };

      // Mise à jour de l'objet en mémoire dans le provider pour éviter la boucle du splash
      authProvider.loginUserData.countryData = userData;

      await authProvider.updateUserCountryCode(authProvider.loginUserData).then((value) async {
        if (value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Information enregistrée'), backgroundColor: primaryYellow),
          );
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SplashChargement()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur d'enregistrement"), backgroundColor: primaryRed),
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
    bool showManualPicker = kIsWeb || _forceManualInput;

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlack,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryYellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Où te trouves-tu ?",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  showManualPicker
                      ? "Sélectionne ton pays et ta région manuellement"
                      : "Ta localisation est détectée automatiquement",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                SizedBox(height: 24),

                // Affichage conditionnel : Sélecteur manuel ou Détection auto
                if (showManualPicker) ...[
                  CSCPickerPlus(
                    showStates: true,
                    showCities: true,
                    flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                    dropdownDecoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      color: Colors.grey[900],
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    disabledDropdownDecoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      color: Colors.grey[800],
                    ),
                    countrySearchPlaceholder: "Rechercher un pays",
                    stateSearchPlaceholder: "Rechercher une région",
                    citySearchPlaceholder: "Rechercher une ville",
                    countryDropdownLabel: "Sélectionnez un pays",
                    stateDropdownLabel: "Sélectionnez une région",
                    cityDropdownLabel: "Sélectionnez une ville",
                    selectedItemStyle: TextStyle(color: Colors.white, fontSize: 14),
                    dropdownHeadingStyle: TextStyle(color: primaryYellow, fontSize: 16, fontWeight: FontWeight.bold),
                    dropdownItemStyle: TextStyle(color: Colors.black, fontSize: 14),
                    onCountryChanged: (value) => setState(() => countryValue = value),
                    onStateChanged: (value) => setState(() => stateValue = value ?? ''),
                    onCityChanged: (value) => setState(() => cityValue = value ?? ''),
                  ),

                  // Option pour revenir à la tentative de détection auto si l'utilisateur le souhaite sur mobile
                  if (!kIsWeb) ...[
                    SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _forceManualInput = false;
                          hasRequestedLocation = false;
                          detectedCountryCode = null;
                        });
                        _getCountryCodeInBackground();
                      },
                      icon: Icon(Icons.refresh, color: primaryYellow, size: 16),
                      label: Text("Réessayer la détection automatique", style: TextStyle(color: primaryYellow, fontSize: 13)),
                    ),
                  ],
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryRed.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: detectedCountryCode == null
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(primaryYellow)),
                            ),
                            const SizedBox(width: 14),
                            Text("Détection de ta localisation…", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                          ],
                        ),
                        SizedBox(height: 14),
                        // Bouton pour basculer en manuel si le GPS met trop de temps ou bloque
                        GestureDetector(
                          onTap: () => setState(() => _forceManualInput = true),
                          child: Text(
                            "Entrer ma position manuellement",
                            style: TextStyle(color: primaryYellow, fontSize: 13, decoration: TextDecoration.underline),
                          ),
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
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 32),

                isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryYellow)))
                    : SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("Enregistrer", style: TextStyle(color: primaryBlack, fontSize: 18, fontWeight: FontWeight.bold)),
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