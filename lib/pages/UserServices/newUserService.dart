import 'dart:io';

import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Pour sélectionner une image depuis la galerie
import 'package:path/path.dart' as Path;
import 'package:phone_form_field/phone_form_field.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:provider/provider.dart';

class UserServiceForm extends StatefulWidget {
  final UserServiceData? existingService;
  final bool isEditing;

  const UserServiceForm({
    Key? key,
    this.existingService,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _UserServiceFormState createState() => _UserServiceFormState();
}

class _UserServiceFormState extends State<UserServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  late UserServiceData _userService;
  XFile? _coverImage;
  bool _isLoading = false;
  String? _selectedCategory;
  String? _selectedCountry;
  String? _selectedCity;

  // Contrôleurs pour la recherche
  final TextEditingController _categorySearchController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  late UserAuthProvider authProvider;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    _userService = widget.existingService ?? UserServiceData();
    _selectedCategory = _userService.category;
    _selectedCountry = _userService.country;
    _selectedCity = _userService.city;
  }

  @override
  void dispose() {
    _categorySearchController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  // Fonction pour afficher le bottom sheet de recherche
  Future<void> _showSearchableBottomSheet({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String? currentValue,
    required Function(String) onSelected,
  }) async {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredItems = List.from(items);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterItems(String query) {
              setModalState(() {
                filteredItems = items.where((item) {
                  return item.toLowerCase().contains(query.toLowerCase());
                }).toList();
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // En-tête
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.yellow),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Barre de recherche
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.green),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: filterItems,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Liste des résultats
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = item == currentValue;

                        return ListTile(
                          leading: isSelected
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : Icon(Icons.circle_outlined, color: Colors.grey),
                          title: Text(
                            item,
                            style: TextStyle(
                              color: isSelected ? Colors.yellow : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Widget pour les champs de sélection avec recherche
  Widget _buildSearchableField({
    required String label,
    required String? value,
    required String hintText,
    required Function() onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value != null ? Colors.green : Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? hintText,
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.grey,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.yellow,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    setState(() {
      _coverImage = image;
    });
  }

  Future<String?> _uploadImage(File imageFile, String serviceId) async {
    try {
      final String fileName = '${serviceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('services/$serviceId/$fileName');

      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload image: $e');
      return null;
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isEditing && _coverImage == null && _userService.imageCourverture == null) {
      _showErrorSnackBar('Veuillez sélectionner une image de couverture');
      return;
    }

    // Validation des champs de sélection
    if (_selectedCategory == null) {
      _showErrorSnackBar('Veuillez sélectionner une catégorie');
      return;
    }
    if (_selectedCountry == null) {
      _showErrorSnackBar('Veuillez sélectionner un pays');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      _formKey.currentState!.save();

      // Gérer l'upload de l'image
      if (_coverImage != null) {
        final String serviceId = _userService.id ?? _firestore.collection('UserServices').doc().id;
        final String? imageUrl = await _uploadImage(File(_coverImage!.path), serviceId);
        if (imageUrl != null) {
          _userService.imageCourverture = imageUrl;
        }
      }

      // Mettre à jour les timestamps
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_userService.id == null) {
        _userService.id = _firestore.collection('UserServices').doc().id;
        _userService.createdAt = now;
        _userService.userId = authProvider.loginUserData.id;
        _userService.disponible = true;
      }
      _userService.updatedAt = now;

      // Mettre à jour les nouvelles propriétés
      _userService.category = _selectedCategory;
      _userService.country = _selectedCountry;
      _userService.city = _selectedCity;

      // Sauvegarder
      await _firestore.collection('UserServices').doc(_userService.id).set(_userService.toJson());

      _showSuccessSnackBar(
          widget.isEditing ? 'Service modifié avec succès!' : 'Service créé avec succès!'
      );

      Future.delayed(Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });

    } catch (e) {
      print('Erreur sauvegarde service: $e');
      _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message, textAlign: TextAlign.center),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message, textAlign: TextAlign.center),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.isEditing ? 'Modifier le Service' : 'Nouveau Service',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageSection(),
              SizedBox(height: 20),
              _buildSearchableField(
                label: 'Catégorie',
                value: _selectedCategory,
                hintText: 'Sélectionner une catégorie',
                onTap: () => _showSearchableBottomSheet(
                  context: context,
                  title: 'Choisir une catégorie',
                  items: ServiceConstants.categories,
                  currentValue: _selectedCategory,
                  onSelected: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildSearchableField(
                label: 'Pays',
                value: _selectedCountry,
                hintText: 'Sélectionner un pays',
                onTap: () => _showSearchableBottomSheet(
                  context: context,
                  title: 'Choisir un pays',
                  items: ServiceConstants.africanCountries,
                  currentValue: _selectedCountry,
                  onSelected: (value) {
                    setState(() {
                      _selectedCountry = value;
                    });
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildCityField(),
              SizedBox(height: 16),
              _buildContactField(),
              SizedBox(height: 16),
              _buildTitreField(),
              SizedBox(height: 16),
              _buildDescriptionField(),
              SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 16),
          Text(
            widget.isEditing ? 'Modification en cours...' : 'Création en cours...',
            style: TextStyle(color: Colors.yellow),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image de couverture *',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_coverImage != null || _userService.imageCourverture != null)
                    ? Colors.green
                    : Colors.grey,
                width: 2,
              ),
            ),
            child: _coverImage != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(_coverImage!.path), fit: BoxFit.cover),
            )
                : _userService.imageCourverture != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_userService.imageCourverture!, fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, color: Colors.green, size: 40),
                SizedBox(height: 8),
                Text(
                  'Ajouter une image',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isEditing && _coverImage == null && _userService.imageCourverture == null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Une image attire plus de clients',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildCityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ville (optionnel)',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: _selectedCity,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide.none),
              hintText: 'Ex: Lomé, Dakar, Abidjan...',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            onChanged: (value) {
              _selectedCity = value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact WhatsApp *',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: _userService.contact,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.phone, color: Colors.green),
              border: OutlineInputBorder(borderSide: BorderSide.none),
              hintText: '+228 XX XXX XXX',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un numéro de contact';
              }
              if (!RegExp(r'^\+?[\d\s\-\(\)]{8,}$').hasMatch(value)) {
                return 'Numéro invalide';
              }
              return null;
            },
            onSaved: (value) {
              _userService.contact = value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTitreField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Titre du service *',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: _userService.titre,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide.none),
              hintText: 'Ex: Plombier professionnel expérimenté',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            maxLength: 100,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un titre';
              }
              if (value.length < 5) {
                return 'Le titre doit faire au moins 5 caractères';
              }
              return null;
            },
            onSaved: (value) {
              _userService.titre = value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description *',
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: _userService.description,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide.none),
              hintText: 'Décrivez votre service, vos compétences, votre expérience...',
              hintStyle: TextStyle(color: Colors.grey),
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            maxLines: 4,
            maxLength: 500,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              if (value.length < 10) {
                return 'La description doit faire au moins 10 caractères';
              }
              return null;
            },
            onSaved: (value) {
              _userService.description = value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveService,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        )
            : Text(
          widget.isEditing ? 'MODIFIER LE SERVICE' : 'CRÉER LE SERVICE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}




class ServiceConstants {
  static const List<String> categories = [
    // 🔧 Services techniques
    'Menuiserie',
    'Plomberie',
    'Électricité',
    'Maçonnerie',
    'Peinture',
    'Décoration intérieure',
    'Carrelage',
    'Climatisation & Froid',
    'Réparation & Maintenance',
    'Mécanique auto & moto',
    'Électronique & Téléphone',
    'Informatique & Réseaux',

    // 💅 Services personnels
    'Couture & Stylisme',
    'Coiffure homme & femme',
    'Esthétique & Onglerie',
    'Maquillage & Soins du corps',

    // 🍽️ Services de vie quotidienne
    'Cuisine & Traiteur',
    'Boulangerie & Pâtisserie',
    'Nettoyage & Entretien',
    'Jardinage & Espaces verts',
    'Sécurité & Gardiennage',
    'Transport & Livraison',

    // 🎨 Services créatifs & médias
    'Photographie & Vidéographie',
    'Événementiel & Décoration de fête',
    'Musique & Sonorisation',
    'Artisanat & Sculpture',

    // 📱 Services professionnels
    'Marketing & Communication',
    'Community Management',
    'Formation & Coaching',
    'Traduction & Rédaction',
    'Consulting & Comptabilité',

    // 🩺 Santé & Bien-être
    'Médecine traditionnelle',
    'Santé & Bien-être',

    // Autres
    'Autre'
  ];

  static const List<String> africanCountries = [
    // 🌍 Afrique de l’Ouest d’abord
    'Togo',
    'Bénin',
    'Ghana',
    'Côte d\'Ivoire',
    'Burkina Faso',
    'Mali',
    'Sénégal',
    'Niger',
    'Nigéria',
    'Guinée',
    'Guinée-Bissau',
    'Sierra Leone',
    'Libéria',
    'Cap-Vert',
    'Gambie',

    // 🌍 Autres régions d’Afrique
    'Cameroun',
    'Congo',
    'Gabon',
    'Tchad',
    'Rwanda',
    'Burundi',
    'Kenya',
    'Ouganda',
    'Tanzanie',
    'Afrique du Sud',
    'Maroc',
    'Algérie',
    'Tunisie',
    'Égypte',
    'Angola',
    'Namibie',
    'Zambie',
    'Zimbabwe',
    'Mozambique',
    'Madagascar',
    'Mauritanie',
    'Éthiopie',
    'Soudan',
    'Soudan du Sud'
  ];
}
