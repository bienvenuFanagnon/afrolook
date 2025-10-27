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
import '../../../../providers/userProvider.dart';
import '../../../entreprise/profile/ProfileEntreprise.dart';


class AddNewProduit extends StatefulWidget {
  final EntrepriseData entrepriseData;
  const AddNewProduit({super.key, required this.entrepriseData});

  @override
  State<AddNewProduit> createState() => _AddAnnonceState();
}

class _AddAnnonceState extends State<AddNewProduit> {
  final _formKey = GlobalKey<FormState>();
  String _titre2 = '';
  final _titre = TextEditingController();
  final _description = TextEditingController();
  final _prix = TextEditingController();
  String _description2 = '';
  String _numero = '';
  // int _prix = 0;
  String _sousCategorieId = '';
  String _regionId = '';
  String _villeId = '';
  String _adresse = '';
  String _type = '';
  bool onSaveTap = false;
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";

  Categorie? categorieSelected;
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final ImagePicker picker = ImagePicker();
  List<XFile>? _mediaFileList = [];

  String selectedCountryCode = "TG"; // Code par défaut (Togo)
  String selectedCountryName = "Togo"; // Nom par défaut (Togo)

  // Liste des codes ISO des pays africains
  final List<String> africanCountries = [
    'TG', 'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM',
    'CD', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW',
    'CI', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
    'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD',
    'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW'
  ];

  @override
  void initState() {
    super.initState();
    // categorieSelected = null;
  }

  // Vérifier si l'utilisateur peut publier
  bool _canPublishProduct() {
    // Si l'utilisateur est admin, il peut toujours publier
    if (authProvider.loginUserData.role == UserRole.ADM.name) {
      return true;
    }

    final abonnement = widget.entrepriseData.abonnement;
    if (abonnement == null) return false;

    // Vérifier si l'abonnement est expiré
    if (_isSubscriptionExpired(abonnement)) {
      return false;
    }

    // Vérifier le nombre de produits restants
    if (abonnement.type == TypeAbonement.GRATUIT.name) {
      final produitsRestants = abonnement.nombre_pub ?? 0;
      return produitsRestants > 0;
    } else if (abonnement.type == TypeAbonement.PREMIUM.name) {
      final produitsRestants = abonnement.nombre_pub ?? 0;
      return produitsRestants > 0;
    }

    return false;
  }

  // Vérifier si l'abonnement est expiré
  bool _isSubscriptionExpired(EntrepriseAbonnement abonnement) {
    if (abonnement.end == null) return true;
    return DateTime.now().millisecondsSinceEpoch > abonnement.end!;
  }

  // Obtenir le nombre de produits restants
  int _getRemainingProducts() {
    if (authProvider.loginUserData.role == UserRole.ADM.name) {
      return 999; // Nombre illimité pour les admins
    }

    final abonnement = widget.entrepriseData.abonnement;
    if (abonnement == null) return 0;

    if (_isSubscriptionExpired(abonnement)) {
      return 0;
    }

    return abonnement.nombre_pub ?? 0;
  }

  // Obtenir le nombre maximum d'images autorisées
  int _getMaxImagesAllowed() {
    if (authProvider.loginUserData.role == UserRole.ADM.name) {
      return 10; // Maximum pour les admins
    }

    final abonnement = widget.entrepriseData.abonnement;
    if (abonnement == null) return 1;

    if (_isSubscriptionExpired(abonnement)) {
      return 1;
    }

    return abonnement.nombre_image_pub ?? 1;
  }

  void pickImages() async {
    final maxImages = _getMaxImagesAllowed();

    await picker.pickMultiImage().then((images) {
      setState(() {
        if (images != null && images.isNotEmpty) {
          if (_mediaFileList!.length >= maxImages) {
            _showImageLimitDialog(maxImages);
            return;
          }

          int remainingSlots = maxImages - _mediaFileList!.length;
          _mediaFileList!.addAll(images.take(remainingSlots));
        }
      });
    });
  }

  void _showImageLimitDialog(int maxImages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limite d\'images atteinte'),
        content: Text('Vous ne pouvez ajouter que $maxImages image(s) maximum avec votre abonnement actuel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  void _showSubscriptionExpiredModal(bool isPremium) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 30, color: Colors.red),
                ),
                SizedBox(height: 15),
                Text(
                  "Abonnement expiré",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),
                Text(
                  isPremium
                      ? "Votre abonnement premium est expiré. Renouvelez-le pour continuer à publier des produits."
                      : "Votre abonnement gratuit est expiré. Passez à l'abonnement premium pour continuer à publier.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToPremiumSubscription();
                  },
                  icon: Icon(Icons.star, color: Colors.white),
                  label: Text("Voir les abonnements", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomConstants.kPrimaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoProductsLeftModal(bool isPremium) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.production_quantity_limits, size: 30, color: Colors.orange),
                ),
                SizedBox(height: 15),
                Text(
                  "Limite de produits atteinte",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),
                Text(
                  isPremium
                      ? "Vous avez atteint la limite de produits de votre abonnement premium. Renouvelez ou améliorez votre abonnement pour publier plus de produits."
                      : "Vous avez atteint la limite de produits gratuits. Passez à l'abonnement premium pour publier plus de produits.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToPremiumSubscription();
                  },
                  icon: Icon(Icons.star, color: Colors.white),
                  label: Text("Améliorer l'abonnement", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomConstants.kPrimaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToPremiumSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiumSubscriptionPage(
          entreprise: widget.entrepriseData,
          user: authProvider.loginUserData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    final remainingProducts = _getRemainingProducts();
    final maxImages = _getMaxImagesAllowed();
    final canPublish = _canPublishProduct();
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    String produitRestant = isAdmin
        ? "Illimité (Admin)"
        : remainingProducts > 0
        ? "$remainingProducts restants"
        : "0 restant";

    String imagesInfo = isAdmin
        ? "$maxImages maximum"
        : "${widget.entrepriseData.abonnement?.nombre_image_pub ?? 1} maximum";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Publier un article',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.02),
              CustomConstants.kPrimaryColor.withOpacity(0.05),
              Colors.amber.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                // Bannière d'alerte si impossible de publier
                if (!canPublish && !isAdmin)
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getRemainingProducts() == 0
                                  ? "Vous avez atteint votre limite de produits."
                                  : "Votre abonnement est expiré.",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Titre de l'entreprise
                GestureDetector(
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.white,
                          body: Center(
                            child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                          ),
                        ),
                      ),
                    );

                    try {
                      final value = await userProvider.getUserEntreprise(authProvider.loginUserData.id!);
                      Navigator.pop(context);

                      if (value) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EntrepriseProfil(userId: authProvider.loginUserData.id!),
                          ),
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Color(0xFF2ECC71).withOpacity(0.1),
                                    child: Icon(Icons.store_mall_directory, color: Color(0xFF2ECC71), size: 32),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Créez votre entreprise",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Pour vendre vos produits et services, créez gratuitement une entreprise avec un nom unique.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2ECC71),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(context, '/new_entreprise');
                                    },
                                    child: Text("Créer maintenant", style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur lors du chargement")),
                      );
                    }
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black,
                            CustomConstants.kPrimaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Entreprise',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  widget.entrepriseData.titre ?? 'Nom entreprise',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Bouton d'abonnement
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: _navigateToPremiumSubscription,
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star, color: Colors.amber),
                    ),
                    title: Text(
                      "Améliorer l'abonnement",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      "Débloquer plus de fonctionnalités",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ),
                ),

                SizedBox(height: 16),

                // Détails de l'abonnement
                _buildDetailTile(Icons.star, 'Type d\'abonnement',
                    widget.entrepriseData.abonnement!.type ?? "Inconnu", Colors.amber),
                SizedBox(height: 8),
                _buildDetailTile(Icons.production_quantity_limits, 'Produits restants',
                    produitRestant, CustomConstants.kPrimaryColor),
                SizedBox(height: 8),
                _buildDetailTile(Icons.image, 'Images par produit',
                    imagesInfo, Colors.blue),

                SizedBox(height: 20),

                // Section images
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo_library, color: CustomConstants.kPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Images du produit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '(${_mediaFileList!.length}/$maxImages)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _mediaFileList!.map((objet) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(objet.path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (BuildContext context, Object error,
                                          StackTrace? stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: Icon(Icons.error, color: Colors.grey),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _mediaFileList!.remove(objet);
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _mediaFileList!.length >= maxImages ? null : pickImages,
                          icon: Icon(Icons.add_photo_alternate,
                              color: _mediaFileList!.length >= maxImages ? Colors.grey : CustomConstants.kPrimaryColor),
                          label: Text(
                            'Ajouter des photos',
                            style: TextStyle(color: _mediaFileList!.length >= maxImages ? Colors.grey : CustomConstants.kPrimaryColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                                color: _mediaFileList!.length >= maxImages ? Colors.grey : CustomConstants.kPrimaryColor
                            ),
                          ),
                        ),
                        if (_mediaFileList!.length >= maxImages)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Limite de $maxImages image(s) atteinte',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Catégorie
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _buildFormField(
                          label: 'Prix (FCFA) *',
                          icon: Icons.attach_money,
                          child: TextFormField(
                            controller: _prix,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Ex: 25000',
                            ),
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Veuillez entrer un prix';
                              }
                              return null;
                            },

                          ),
                        ),
                        SizedBox(height: 16),

                        Row(
                          children: [
                            Icon(Icons.category, color: CustomConstants.kPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Catégorie',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        DropdownSearch<Categorie>(
                          onChanged: (Categorie? value) {
                            setState(() {
                              categorieSelected = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return "Veuillez choisir une catégorie";
                            }
                            return null;
                          },
                          items: categorieProduitProvider.listCategorie,
                          filterFn: (item, filter) {
                            return item.nom!
                                .toLowerCase()
                                .contains(filter.toLowerCase());
                          },
                          dropdownBuilder: (context, selectedItem) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                selectedItem?.nom ?? "Choisissez une catégorie",
                                style: TextStyle(
                                  color: selectedItem == null
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                          selectedItem: null,
                          popupProps: PopupProps.menu(
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                hintText: "Rechercher une catégorie...",
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            showSearchBox: true,
                            showSelectedItems: false,
                            itemBuilder: (context, item, isSelected) {
                              return ListTile(
                                leading: Icon(Icons.category,
                                    color: CustomConstants.kPrimaryColor),
                                title: Text(item.nom!),
                                trailing: isSelected
                                    ? Icon(Icons.check, color: CustomConstants.kPrimaryColor)
                                    : null,
                              );
                            },
                          ),
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: "Catégorie *",
                              labelStyle: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: CustomConstants.kPrimaryColor),
                              ),
                              hintText: "Sélectionnez une catégorie",
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Champs de formulaire
                _buildFormField(
                  label: 'Titre du produit *',
                  icon: Icons.title,
                  child: TextFormField(
                    controller: _titre,
                    decoration: InputDecoration(
                      hintText: 'Ex: Téléphone Samsung Galaxy S21',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Veuillez entrer un titre';
                      }
                      return null;
                    },
                  ),
                ),

                SizedBox(height: 16),

                _buildFormField(
                  label: 'Numéro WhatsApp *',
                  icon: FontAwesome.whatsapp,
                  child: PhoneFormField(
                    decoration: InputDecoration(
                      hintText: 'Votre numéro WhatsApp',
                    ),
                    initialValue: PhoneNumber.parse('+228'),
                    validator: PhoneValidator.compose([
                      PhoneValidator.required(context),
                      PhoneValidator.validMobile(context)
                    ]),
                    countrySelectorNavigator: const CountrySelectorNavigator.page(),
                    onChanged: (phoneNumber) {
                      _numero = phoneNumber.international;
                    },
                    onSaved: (newValue) {
                      _numero = newValue!.international;
                    },
                    enabled: true,
                    isCountrySelectionEnabled: true,
                    countryButtonStyle: const CountryButtonStyle(
                      showDialCode: true,
                      showIsoCode: true,
                      showFlag: true,
                      flagSize: 16,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                _buildFormField(
                  label: 'Description *',
                  icon: Icons.description,
                  child: TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Décrivez votre produit en détail...',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Veuillez entrer une description';
                      }
                      return null;
                    },

                  ),
                ),

                SizedBox(height: 16),

                // Sélection du pays
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: CustomConstants.kPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Localisation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Pays : $selectedCountryName",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            countryFlag(selectedCountryCode, size: 20),
                          ],
                        ),
                        SizedBox(height: 12),
                        CountryCodePicker(
                          onChanged: (country) {
                            setState(() {
                              selectedCountryCode = country.code!;
                              selectedCountryName = country.name!;
                            });
                          },
                          initialSelection: 'TG',
                          favorite: ['TG'],
                          countryFilter: africanCountries,
                          showCountryOnly: false,
                          showOnlyCountryWhenClosed: false,
                          alignLeft: false,
                          textStyle: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),



                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: Container(
        height: 80,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onSaveTap || !canPublish
              ? null
              : () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              if (selectedCountryCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Veuillez sélectionner un pays"),
                  ),
                );
                return;
              }

              if (_mediaFileList!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Veuillez ajouter au moins une image"),
                  ),
                );
                return;
              }

              // Vérifications finales avant publication
              if (!_canPublishProduct()) {
                final abonnement = widget.entrepriseData.abonnement;
                if (abonnement != null && _isSubscriptionExpired(abonnement)) {
                  _showSubscriptionExpiredModal(abonnement.type == TypeAbonement.PREMIUM.name);
                } else {
                  _showNoProductsLeftModal(abonnement?.type == TypeAbonement.PREMIUM.name ?? false);
                }
                return;
              }

              await _publishProduct();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: canPublish ? CustomConstants.kPrimaryColor : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(double.infinity, 50),
          ),
          child: onSaveTap
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Publication en cours...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text(
                canPublish ? 'Publier l\'article' : 'Publication bloquée',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publishProduct() async {
    setState(() {
      onSaveTap = true;
    });

    try {
      ArticleData annonceRegisterData = ArticleData();
      annonceRegisterData.images = [];
      annonceRegisterData.titre = _titre.text;
      annonceRegisterData.dispo_annonce_afrolook = false;
      annonceRegisterData.description = _description.text;
      annonceRegisterData.phone = _numero;
      annonceRegisterData.vues = 0;
      annonceRegisterData.popularite = 1;
      annonceRegisterData.jaime = 0;
      annonceRegisterData.contact = 0;
      annonceRegisterData.partage = 0;
      annonceRegisterData.prix = int.parse(_prix.text!) ;
      annonceRegisterData.user_id = authProvider.loginUserData.id!;
      annonceRegisterData.categorie_id = categorieSelected!.id!;

      Map<String, String> countryData = {
        "country": selectedCountryName,
        "state": "",
        "city": '',
        "countryCode": selectedCountryCode,
      };
      annonceRegisterData.countryData = countryData;

      annonceRegisterData.updatedAt = DateTime.now().microsecondsSinceEpoch;
      annonceRegisterData.createdAt = DateTime.now().microsecondsSinceEpoch;

      // Upload des images
      for (XFile _image in _mediaFileList!) {
        Reference storageReference = FirebaseStorage.instance.ref().child(
            'images_article/${Path.basename(File(_image.path).path)}');

        UploadTask uploadTask = storageReference.putFile(File(_image.path)!);
        await uploadTask.whenComplete(() async {
          await storageReference.getDownloadURL().then((fileURL) {
            annonceRegisterData.images!.add(fileURL);
          });
        });
      }

      String postId = FirebaseFirestore.instance.collection('Articles').doc().id;
      annonceRegisterData.id = postId;

      bool success = await categorieProduitProvider.createArticle(annonceRegisterData);

      if (success) {
        // Mettre à jour le compteur de produits seulement si l'utilisateur n'est pas admin
        if (authProvider.loginUserData.role != UserRole.ADM.name) {
          widget.entrepriseData.produitsIds!.add(postId);
          widget.entrepriseData.abonnement!.nombre_pub = _getRemainingProducts() - 1;
          authProvider.updateEntreprise(widget.entrepriseData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text("Article ajouté avec succès"),
          ),
        );

        // Réinitialiser le formulaire
        // _titre.text = '';
        // _description = '';
        // _prix = 0;
        _mediaFileList = [];
        // _formKey.currentState!.reset();
        // // setState(() {
        // //   categorieSelected = null;
        // // });

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Erreur lors de l'ajout du produit"),
          ),
        );
      }

    } catch (e) {
      print("Erreur lors de la publication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Erreur lors de la publication: ${e.toString()}"),
        ),
      );
    } finally {
      setState(() {
        onSaveTap = false;
      });
    }
  }

  Widget _buildFormField(
      {required String label, required IconData icon, required Widget child}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: CustomConstants.kPrimaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

