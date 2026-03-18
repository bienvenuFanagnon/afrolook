// pages/pronostics/create_pronostic_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/postService/massNotificationService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/model_data.dart';
import '../userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';

class CreatePronosticPage extends StatefulWidget {
  final Canal? canal;

  const CreatePronosticPage({
    Key? key,
    this.canal,
  }) : super(key: key);

  @override
  State<CreatePronosticPage> createState() => _CreatePronosticPageState();
}

class _CreatePronosticPageState extends State<CreatePronosticPage> {
  // Providers
  late PostProvider _postProvider;
  late UserAuthProvider _authProvider;
  late UserProvider _userProvider;
  late PronosticProvider _pronosticProvider;
  late MassNotificationService _notificationService;

  // Contrôleurs
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Contrôleurs pour les équipes
  final _equipeANomController = TextEditingController();
  final _equipeAUrlController = TextEditingController();
  final _equipeBNomController = TextEditingController();
  final _equipeBUrlController = TextEditingController();

  // Contrôleur pour la cagnotte
  final TextEditingController _cagnotteController = TextEditingController();

  // États
  bool _isLoading = false;
  Uint8List? _selectedImage;
  String? _imageName;

  // Options du pronostic
  String _typeAcces = 'GRATUIT'; // GRATUIT ou PAYANT
  double _prixParticipation = 500.0; // Prix par défaut
  double _cagnotte = 10000.0; // Cagnotte par défaut
  int _quotaMaxParScore = 10; // Quota par défaut

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221); // Rouge
  final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = const Color(0xFF121212); // Noir
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
    _notificationService = MassNotificationService();

    // Initialiser le contrôleur de cagnotte
    _cagnotteController.text = _cagnotte.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _equipeANomController.dispose();
    _equipeAUrlController.dispose();
    _equipeBNomController.dispose();
    _equipeBUrlController.dispose();
    _cagnotteController.dispose();
    super.dispose();
  }

  // Sélectionner une image pour le post
  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        final compressedBytes = await _compressImage(bytes);

        setState(() {
          _selectedImage = compressedBytes;
          _imageName = image.name;
        });
      } catch (e) {
        _showSnackBar('Erreur lors du traitement de l\'image', isError: true);
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1080,
        minWidth: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      return bytes;
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageName = null;
    });
  }

  // Widget de sélection d'image
  Widget _buildImageSelector() {
    if (_selectedImage == null) {
      return GestureDetector(
        onTap: _selectImage,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[700]!, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.image, size: 60, color: _hintColor),
              const SizedBox(height: 16),
              Text(
                'Ajouter une image',
                style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Image du match (obligatoire)',
                textAlign: TextAlign.center,
                style: TextStyle(color: _hintColor, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_selectedImage!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _removeImage,
            ),
          ),
        ),
      ],
    );
  }

  // Widget pour les équipes
  Widget _buildEquipesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.people, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'Équipes',
                style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Équipe A
          Text('Équipe A', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _equipeANomController,
                  style: TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Nom de l\'équipe',
                    hintStyle: TextStyle(color: _hintColor),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.sports_football, color: _primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nom de l\'équipe A requis';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _equipeAUrlController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'URL du logo (optionnel)',
              hintStyle: TextStyle(color: _hintColor),
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Iconsax.link, color: _primaryColor),
            ),
          ),

          const SizedBox(height: 20),

          // Équipe B
          Text('Équipe B', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _equipeBNomController,
                  style: TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Nom de l\'équipe',
                    hintStyle: TextStyle(color: _hintColor),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(MaterialIcons.sports_soccer, color: _primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nom de l\'équipe B requis';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _equipeBUrlController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'URL du logo (optionnel)',
              hintStyle: TextStyle(color: _hintColor),
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Iconsax.link, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour les options du pronostic
  Widget _buildOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.setting, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'Options du pronostic',
                style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type d'accès
          Text('Type d\'accès', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAccessTypeButton('GRATUIT', Iconsax.lock_1),
                ),
                Expanded(
                  child: _buildAccessTypeButton('PAYANT', Iconsax.money),
                ),
              ],
            ),
          ),

          if (_typeAcces == 'PAYANT') ...[
            const SizedBox(height: 16),

            // Prix de participation
            Text('Prix de participation (FCFA)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _prixParticipation,
                      min: 100,
                      max: 10000,
                      divisions: 100,
                      activeColor: _primaryColor,
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) {
                        setState(() {
                          _prixParticipation = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_prixParticipation.toStringAsFixed(0)} FCFA',
                      style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Cagnotte (saisie manuelle)
          Text('Cagnotte totale (FCFA)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cagnotteController,
                  style: TextStyle(color: _textColor, fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0 - 50 000',
                    hintStyle: TextStyle(color: _hintColor),
                    filled: true,
                    fillColor: _backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Iconsax.money, color: _secondaryColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _cagnotte = double.tryParse(value) ?? 0;
                      if (_cagnotte > 50000) {
                        _cagnotte = 50000;
                        _cagnotteController.text = '50000';
                      } else if (_cagnotte < 0) {
                        _cagnotte = 0;
                        _cagnotteController.text = '0';
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez saisir la cagnotte';
                    }
                    final cagnotte = double.tryParse(value);
                    if (cagnotte == null) {
                      return 'Veuillez saisir un nombre valide';
                    }
                    if (cagnotte < 0) {
                      return 'La cagnotte ne peut pas être négative';
                    }
                    if (cagnotte > 50000) {
                      return 'Maximum 50 000 FCFA';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _secondaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _secondaryColor),
                ),
                child: Text(
                  'FCFA',
                  style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Montant à partager entre les gagnants (max 50 000 FCFA)',
            style: TextStyle(color: _hintColor, fontSize: 12, fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 16),

          // Quota par score
          Text('Quota maximum par score', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _quotaMaxParScore.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey[700],
                    onChanged: (value) {
                      setState(() {
                        _quotaMaxParScore = value.toInt();
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_quotaMaxParScore',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Maximum $_quotaMaxParScore personnes par score',
            style: TextStyle(color: _hintColor, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessTypeButton(String type, IconData icon) {
    bool isSelected = _typeAcces == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _typeAcces = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _hintColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : _hintColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour la description
  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.note, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            style: TextStyle(color: _textColor),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Décrivez le match, les enjeux...',
              hintStyle: TextStyle(color: _hintColor),
              filled: true,
              fillColor: _backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'La description est requise';
              }
              if (value.length < 10) {
                return 'Minimum 10 caractères';
              }
              return null;
            },
          ),

          const SizedBox(height: 8),
          Text(
            '${_descriptionController.text.length}/500',
            style: TextStyle(color: _hintColor, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  // Widget récapitulatif
  Widget _buildRecapSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _secondaryColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle, color: _secondaryColor),
              const SizedBox(width: 8),
              Text(
                'Récapitulatif',
                style: TextStyle(color: _secondaryColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildRecapRow('Équipe A', _equipeANomController.text.isEmpty ? 'Non définie' : _equipeANomController.text),
          _buildRecapRow('Équipe B', _equipeBNomController.text.isEmpty ? 'Non définie' : _equipeBNomController.text),
          _buildRecapRow('Type', _typeAcces),
          if (_typeAcces == 'PAYANT')
            _buildRecapRow('Prix', '${_prixParticipation.toStringAsFixed(0)} FCFA'),
          _buildRecapRow('Cagnotte', '${_cagnotte.toStringAsFixed(0)} FCFA'),
          _buildRecapRow('Quota/score', '$_quotaMaxParScore personnes'),
        ],
      ),
    );
  }

  Widget _buildRecapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _hintColor)),
          Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Publication du pronostic
  Future<void> _publishPronostic() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      _showSnackBar('Veuillez sélectionner une image', isError: true);
      return;
    }

    // Validation supplémentaire de la cagnotte
    final cagnotteValue = double.tryParse(_cagnotteController.text) ?? 0;
    if (cagnotteValue < 0 || cagnotteValue > 50000) {
      _showSnackBar('La cagnotte doit être entre 0 et 50 000 FCFA', isError: true);
      return;
    }
    _cagnotte = cagnotteValue;

    setState(() => _isLoading = true);

    try {
      // 1. Créer l'image dans Storage
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingWidget(),
      );

      // Upload de l'image
      String postId = const Uuid().v4();
      String uniqueFileName = const Uuid().v4();
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('post_media/pronostics/$uniqueFileName.jpg');

      await storageReference.putData(_selectedImage!);
      String imageUrl = await storageReference.getDownloadURL();

      // 2. Créer le Post principal
      Post post = Post()
        ..id = postId
        ..user_id = _authProvider.loginUserData.id
        ..description = _descriptionController.text
        ..type = 'PRONOSTIC'
        ..typeTabbar = 'PRONOSTIC'
        ..dataType = PostDataType.IMAGE.name
        ..images = [imageUrl]
        ..createdAt = DateTime.now().microsecondsSinceEpoch
        ..updatedAt = DateTime.now().microsecondsSinceEpoch
        ..status = PostStatus.VALIDE.name
        ..comments = 0
        ..likes = 0
        ..vues = 0
        ..partage = 0
        ..feedScore = 0.5;

      if (widget.canal != null) {
        post.canal_id = widget.canal!.id;
        post.categorie = "CANAL";
      }

      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .set(post.toJson());

      // 3. Créer les équipes
      Equipe equipeA = Equipe(
        id: const Uuid().v4(),
        nom: _equipeANomController.text,
        urlLogo: _equipeAUrlController.text.isEmpty
            ? 'https://via.placeholder.com/150'
            : _equipeAUrlController.text,
      );

      Equipe equipeB = Equipe(
        id: const Uuid().v4(),
        nom: _equipeBNomController.text,
        urlLogo: _equipeBUrlController.text.isEmpty
            ? 'https://via.placeholder.com/150'
            : _equipeBUrlController.text,
      );

      // 4. Créer le Pronostic
      await _pronosticProvider.createPronostic(
        postId: postId,
        createurId: _authProvider.loginUserData.id!,
        equipeA: equipeA,
        equipeB: equipeB,
        typeAcces: _typeAcces,
        prixParticipation: _typeAcces == 'PAYANT' ? _prixParticipation : 0,
        cagnotte: _cagnotte,
        quotaMaxParScore: _quotaMaxParScore,
      );

      // 5. Notifications
      String message = "🔮 Nouveau pronostic en ligne sur AfroLook ! ⚽\n"
          "${_equipeANomController.text} vs ${_equipeBNomController.text}\n"
          "💰 Donnez vite votre pronostic pour remporter ${_cagnotte.toStringAsFixed(0)} FCFA !";

      if (widget.canal != null) {
        await _authProvider.sendPushNotificationToUsers(
          sender: _authProvider.loginUserData,
          message: message,
          typeNotif: NotificationType.POST.name,
          postId: postId,
          postType: 'PRONOSTIC',
          chatId: '',
          smallImage: widget.canal!.urlImage,
          isChannel: true,
          channelTitle: widget.canal!.titre,
          canal: widget.canal,
        );
      } else {
        await _authProvider.sendPushNotificationToUsers(
          sender: _authProvider.loginUserData,
          message: message,
          typeNotif: NotificationType.POST.name,
          postId: postId,
          postType: 'PRONOSTIC',
          chatId: '',
          smallImage: _authProvider.loginUserData.imageUrl,
          isChannel: false,
        );
      }

      if (context.mounted) {
        Navigator.pop(context); // Fermer le dialog de chargement
        Navigator.pop(context, true); // Retourner à la page précédente avec succès

        _showSnackBar(
          '✅ Pronostic publié avec succès!\n'
              '${_equipeANomController.text} vs ${_equipeBNomController.text}',
        );
      }

    } catch (e) {
      print('Erreur publication pronostic: $e');

      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Fermer le dialog de chargement
        }

        _showSnackBar('Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Iconsax.chart, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nouveau pronostic',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.canal != null ? 'Poster dans ${widget.canal!.titre}' : 'Post public',
                  style: TextStyle(color: _hintColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _publishPronostic,
            child: Text(
              'PUBLIER',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image
              _buildImageSelector(),
              const SizedBox(height: 16),

              // Équipes
              _buildEquipesSection(),
              const SizedBox(height: 16),

              // Options
              _buildOptionsSection(),
              const SizedBox(height: 16),

              // Description
              _buildDescriptionSection(),
              const SizedBox(height: 16),

              // Récapitulatif
              _buildRecapSection(),
              const SizedBox(height: 30),

              // Bouton de publication
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _publishPronostic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'PUBLIER LE PRONOSTIC',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// // pages/pronostics/create_pronostic_page.dart
//
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:afrotok/providers/pronostic_provider.dart';
// import 'package:afrotok/providers/userProvider.dart';
// import 'package:afrotok/services/postService/massNotificationService.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart';
//
// import '../../models/model_data.dart';
// import '../userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';
//
// class CreatePronosticPage extends StatefulWidget {
//   final Canal? canal;
//
//   const CreatePronosticPage({
//     Key? key,
//     this.canal,
//   }) : super(key: key);
//
//   @override
//   State<CreatePronosticPage> createState() => _CreatePronosticPageState();
// }
//
// class _CreatePronosticPageState extends State<CreatePronosticPage> {
//   // Providers
//   late PostProvider _postProvider;
//   late UserAuthProvider _authProvider;
//   late UserProvider _userProvider;
//   late PronosticProvider _pronosticProvider;
//   late MassNotificationService _notificationService;
//
//   // Contrôleurs
//   final _formKey = GlobalKey<FormState>();
//   final _descriptionController = TextEditingController();
//
//   // Contrôleurs pour les équipes
//   final _equipeANomController = TextEditingController();
//   final _equipeAUrlController = TextEditingController();
//   final _equipeBNomController = TextEditingController();
//   final _equipeBUrlController = TextEditingController();
//
//   // États
//   bool _isLoading = false;
//   Uint8List? _selectedImage;
//   String? _imageName;
//
//   // Options du pronostic
//   String _typeAcces = 'GRATUIT'; // GRATUIT ou PAYANT
//   double _prixParticipation = 500.0; // Prix par défaut
//   double _cagnotte = 10000.0; // Cagnotte par défaut
//   int _quotaMaxParScore = 10; // Quota par défaut
//
//   // Couleurs
//   final Color _primaryColor = const Color(0xFFE21221); // Rouge
//   final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
//   final Color _backgroundColor = const Color(0xFF121212); // Noir
//   final Color _cardColor = const Color(0xFF1E1E1E);
//   final Color _textColor = Colors.white;
//   final Color _hintColor = Colors.grey[400]!;
//
//   @override
//   void initState() {
//     super.initState();
//     _postProvider = Provider.of<PostProvider>(context, listen: false);
//     _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _userProvider = Provider.of<UserProvider>(context, listen: false);
//     _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
//     _notificationService = MassNotificationService();
//   }
//
//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     _equipeANomController.dispose();
//     _equipeAUrlController.dispose();
//     _equipeBNomController.dispose();
//     _equipeBUrlController.dispose();
//     super.dispose();
//   }
//
//   // Sélectionner une image pour le post
//   Future<void> _selectImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? image = await picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 85,
//       maxWidth: 1920,
//       maxHeight: 1080,
//     );
//
//     if (image != null) {
//       try {
//         final bytes = await image.readAsBytes();
//         final compressedBytes = await _compressImage(bytes);
//
//         setState(() {
//           _selectedImage = compressedBytes;
//           _imageName = image.name;
//         });
//       } catch (e) {
//         _showSnackBar('Erreur lors du traitement de l\'image', isError: true);
//       }
//     }
//   }
//
//   Future<Uint8List> _compressImage(Uint8List bytes) async {
//     try {
//       final result = await FlutterImageCompress.compressWithList(
//         bytes,
//         minHeight: 1080,
//         minWidth: 1080,
//         quality: 75,
//         format: CompressFormat.jpeg,
//       );
//       return result;
//     } catch (e) {
//       return bytes;
//     }
//   }
//
//   void _removeImage() {
//     setState(() {
//       _selectedImage = null;
//       _imageName = null;
//     });
//   }
//
//   // Widget de sélection d'image
//   Widget _buildImageSelector() {
//     if (_selectedImage == null) {
//       return GestureDetector(
//         onTap: _selectImage,
//         child: Container(
//           width: double.infinity,
//           height: 200,
//           decoration: BoxDecoration(
//             color: _backgroundColor,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: Colors.grey[700]!, width: 2),
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Iconsax.image, size: 60, color: _hintColor),
//               const SizedBox(height: 16),
//               Text(
//                 'Ajouter une image',
//                 style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Image du match (obligatoire)',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: _hintColor, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Stack(
//       children: [
//         Container(
//           width: double.infinity,
//           height: 200,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             color: Colors.black,
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(16),
//             child: Image.memory(_selectedImage!, fit: BoxFit.cover),
//           ),
//         ),
//         Positioned(
//           top: 8,
//           right: 8,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.7),
//               shape: BoxShape.circle,
//             ),
//             child: IconButton(
//               icon: const Icon(Icons.close, color: Colors.white),
//               onPressed: _removeImage,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Widget pour les équipes
//   Widget _buildEquipesSection() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Iconsax.people, color: _primaryColor),
//               const SizedBox(width: 8),
//               Text(
//                 'Équipes',
//                 style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           // Équipe A
//           Text('Équipe A', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _equipeANomController,
//                   style: TextStyle(color: _textColor),
//                   decoration: InputDecoration(
//                     hintText: 'Nom de l\'équipe',
//                     hintStyle: TextStyle(color: _hintColor),
//                     filled: true,
//                     fillColor: _backgroundColor,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                     prefixIcon: Icon(Icons.sports_football, color: _primaryColor),
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Nom de l\'équipe A requis';
//                     }
//                     return null;
//                   },
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextFormField(
//             controller: _equipeAUrlController,
//             style: TextStyle(color: _textColor),
//             decoration: InputDecoration(
//               hintText: 'URL du logo (optionnel)',
//               hintStyle: TextStyle(color: _hintColor),
//               filled: true,
//               fillColor: _backgroundColor,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none,
//               ),
//               prefixIcon: Icon(Iconsax.link, color: _primaryColor),
//             ),
//           ),
//
//           const SizedBox(height: 20),
//
//           // Équipe B
//           Text('Équipe B', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _equipeBNomController,
//                   style: TextStyle(color: _textColor),
//                   decoration: InputDecoration(
//                     hintText: 'Nom de l\'équipe',
//                     hintStyle: TextStyle(color: _hintColor),
//                     filled: true,
//                     fillColor: _backgroundColor,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                     prefixIcon: Icon(MaterialIcons.sports_soccer, color: _primaryColor),
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Nom de l\'équipe B requis';
//                     }
//                     return null;
//                   },
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           TextFormField(
//             controller: _equipeBUrlController,
//             style: TextStyle(color: _textColor),
//             decoration: InputDecoration(
//               hintText: 'URL du logo (optionnel)',
//               hintStyle: TextStyle(color: _hintColor),
//               filled: true,
//               fillColor: _backgroundColor,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none,
//               ),
//               prefixIcon: Icon(Iconsax.link, color: _primaryColor),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Widget pour les options du pronostic
//   Widget _buildOptionsSection() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Iconsax.setting, color: _primaryColor),
//               const SizedBox(width: 8),
//               Text(
//                 'Options du pronostic',
//                 style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           // Type d'accès
//           Text('Type d\'accès', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Container(
//             decoration: BoxDecoration(
//               color: _backgroundColor,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _buildAccessTypeButton('GRATUIT', Iconsax.lock_1),
//                 ),
//                 Expanded(
//                   child: _buildAccessTypeButton('PAYANT', Iconsax.money),
//                 ),
//               ],
//             ),
//           ),
//
//           if (_typeAcces == 'PAYANT') ...[
//             const SizedBox(height: 16),
//
//             // Prix de participation
//             Text('Prix de participation (FCFA)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Container(
//               decoration: BoxDecoration(
//                 color: _backgroundColor,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Slider(
//                       value: _prixParticipation,
//                       min: 100,
//                       max: 10000,
//                       divisions: 100,
//                       activeColor: _primaryColor,
//                       inactiveColor: Colors.grey[700],
//                       onChanged: (value) {
//                         setState(() {
//                           _prixParticipation = value;
//                         });
//                       },
//                     ),
//                   ),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: _primaryColor.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       '${_prixParticipation.toStringAsFixed(0)} FCFA',
//                       style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//
//           const SizedBox(height: 16),
//
//           // Cagnotte
//           Text('Cagnotte totale (FCFA)', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Container(
//             decoration: BoxDecoration(
//               color: _backgroundColor,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Slider(
//                     value: _cagnotte,
//                     min: 1000,
//                     max: 1000000,
//                     divisions: 100,
//                     activeColor: _secondaryColor,
//                     inactiveColor: Colors.grey[700],
//                     onChanged: (value) {
//                       setState(() {
//                         _cagnotte = value;
//                       });
//                     },
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: _secondaryColor.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     '${_cagnotte.toStringAsFixed(0)} FCFA',
//                     style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 16),
//
//           // Quota par score
//           Text('Quota maximum par score', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           Container(
//             decoration: BoxDecoration(
//               color: _backgroundColor,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Slider(
//                     value: _quotaMaxParScore.toDouble(),
//                     min: 1,
//                     max: 20,
//                     divisions: 19,
//                     activeColor: Colors.blue,
//                     inactiveColor: Colors.grey[700],
//                     onChanged: (value) {
//                       setState(() {
//                         _quotaMaxParScore = value.toInt();
//                       });
//                     },
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     '$_quotaMaxParScore',
//                     style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 8),
//           Text(
//             'Maximum $_quotaMaxParScore personnes par score',
//             style: TextStyle(color: _hintColor, fontSize: 12, fontStyle: FontStyle.italic),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAccessTypeButton(String type, IconData icon) {
//     bool isSelected = _typeAcces == type;
//
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _typeAcces = type;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         decoration: BoxDecoration(
//           color: isSelected ? _primaryColor : Colors.transparent,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               color: isSelected ? Colors.white : _hintColor,
//               size: 18,
//             ),
//             const SizedBox(width: 8),
//             Text(
//               type,
//               style: TextStyle(
//                 color: isSelected ? Colors.white : _hintColor,
//                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Widget pour la description
//   Widget _buildDescriptionSection() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Iconsax.note, color: _primaryColor),
//               const SizedBox(width: 8),
//               Text(
//                 'Description',
//                 style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           TextFormField(
//             controller: _descriptionController,
//             style: TextStyle(color: _textColor),
//             maxLines: 5,
//             decoration: InputDecoration(
//               hintText: 'Décrivez le match, les enjeux...',
//               hintStyle: TextStyle(color: _hintColor),
//               filled: true,
//               fillColor: _backgroundColor,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none,
//               ),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'La description est requise';
//               }
//               if (value.length < 10) {
//                 return 'Minimum 10 caractères';
//               }
//               return null;
//             },
//           ),
//
//           const SizedBox(height: 8),
//           Text(
//             '${_descriptionController.text.length}/500',
//             style: TextStyle(color: _hintColor, fontSize: 12),
//             textAlign: TextAlign.right,
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Widget récapitulatif
//   Widget _buildRecapSection() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _cardColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _secondaryColor, width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Iconsax.info_circle, color: _secondaryColor),
//               const SizedBox(width: 8),
//               Text(
//                 'Récapitulatif',
//                 style: TextStyle(color: _secondaryColor, fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//
//           _buildRecapRow('Équipe A', _equipeANomController.text.isEmpty ? 'Non définie' : _equipeANomController.text),
//           _buildRecapRow('Équipe B', _equipeBNomController.text.isEmpty ? 'Non définie' : _equipeBNomController.text),
//           _buildRecapRow('Type', _typeAcces),
//           if (_typeAcces == 'PAYANT')
//             _buildRecapRow('Prix', '${_prixParticipation.toStringAsFixed(0)} FCFA'),
//           _buildRecapRow('Cagnotte', '${_cagnotte.toStringAsFixed(0)} FCFA'),
//           _buildRecapRow('Quota/score', '$_quotaMaxParScore personnes'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRecapRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(color: _hintColor)),
//           Text(value, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.red : Colors.green,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   // Publication du pronostic
//   Future<void> _publishPronostic() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     if (_selectedImage == null) {
//       _showSnackBar('Veuillez sélectionner une image', isError: true);
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       // 1. Créer l'image dans Storage
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         // builder: (context) => const LoadingWidget(message: 'Publication en cours...'),
//         builder: (context) => const LoadingWidget(),
//       );
//
//       // Upload de l'image
//       String postId = const Uuid().v4();
//       String uniqueFileName = const Uuid().v4();
//       Reference storageReference = FirebaseStorage.instance
//           .ref()
//           .child('post_media/pronostics/$uniqueFileName.jpg');
//
//       await storageReference.putData(_selectedImage!);
//       String imageUrl = await storageReference.getDownloadURL();
//
//       // 2. Créer le Post principal
//       Post post = Post()
//         ..id = postId
//         ..user_id = _authProvider.loginUserData.id
//         ..description = _descriptionController.text
//         ..type = 'PRONOSTIC' // Type spécifique pour identifier
//         ..typeTabbar = 'PRONOSTIC'
//         ..dataType = PostDataType.IMAGE.name
//         ..images = [imageUrl]
//         ..createdAt = DateTime.now().microsecondsSinceEpoch
//         ..updatedAt = DateTime.now().microsecondsSinceEpoch
//         ..status = PostStatus.VALIDE.name
//         ..comments = 0
//         ..likes = 0
//         ..vues = 0
//         ..partage = 0
//         ..feedScore = 0.5;
//
//       if (widget.canal != null) {
//         post.canal_id = widget.canal!.id;
//         post.categorie = "CANAL";
//       }
//
//       await FirebaseFirestore.instance
//           .collection('Posts')
//           .doc(postId)
//           .set(post.toJson());
//
//       // 3. Créer les équipes
//       Equipe equipeA = Equipe(
//         id: const Uuid().v4(),
//         nom: _equipeANomController.text,
//         urlLogo: _equipeAUrlController.text.isEmpty
//             ? 'https://via.placeholder.com/150'
//             : _equipeAUrlController.text,
//       );
//
//       Equipe equipeB = Equipe(
//         id: const Uuid().v4(),
//         nom: _equipeBNomController.text,
//         urlLogo: _equipeBUrlController.text.isEmpty
//             ? 'https://via.placeholder.com/150'
//             : _equipeBUrlController.text,
//       );
//
//       // 4. Créer le Pronostic
//       await _pronosticProvider.createPronostic(
//         postId: postId,
//         createurId: _authProvider.loginUserData.id!,
//         equipeA: equipeA,
//         equipeB: equipeB,
//         typeAcces: _typeAcces,
//         prixParticipation: _typeAcces == 'PAYANT' ? _prixParticipation : 0,
//         cagnotte: _cagnotte,
//         quotaMaxParScore: _quotaMaxParScore,
//       );
//
//       // 5. Notifications
//       if (widget.canal != null) {
//         await _authProvider.sendPushNotificationToUsers(
//           sender: _authProvider.loginUserData,
//           message: "🔮 Nouveau pronostic en ligne sur AfroLook ! ⚽\n${_equipeANomController.text} vs ${_equipeBNomController.text}\n💰 Donnez vite votre pronostic pour remporter plus de 50 000 FCFA !",          typeNotif: NotificationType.POST.name,
//           postId: postId,
//           postType: 'PRONOSTIC',
//           chatId: '',
//           smallImage: widget.canal!.urlImage,
//           isChannel: true,
//           channelTitle: widget.canal!.titre,
//           canal: widget.canal,
//         );
//       } else {
//         await _authProvider.sendPushNotificationToUsers(
//           sender: _authProvider.loginUserData,
//           message: "🔮 Nouveau pronostic en ligne sur AfroLook ! ⚽\n${_equipeANomController.text} vs ${_equipeBNomController.text}\n💰 Donnez vite votre pronostic pour remporter plus de 50 000 FCFA !",          typeNotif: NotificationType.POST.name,
//           postId: postId,
//           postType: 'PRONOSTIC',
//           chatId: '',
//           smallImage: _authProvider.loginUserData.imageUrl,
//           isChannel: false,
//         );
//       }
//
//       if (context.mounted) {
//         Navigator.pop(context); // Fermer le dialog de chargement
//         Navigator.pop(context, true); // Retourner à la page précédente avec succès
//
//         _showSnackBar(
//           '✅ Pronostic publié avec succès!\n'
//               '${_equipeANomController.text} vs ${_equipeBNomController.text}',
//         );
//       }
//
//     } catch (e) {
//       print('Erreur publication pronostic: $e');
//
//       if (context.mounted) {
//         if (Navigator.canPop(context)) {
//           Navigator.pop(context); // Fermer le dialog de chargement
//         }
//
//         _showSnackBar('Erreur: $e', isError: true);
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _backgroundColor,
//       appBar: AppBar(
//         backgroundColor: _cardColor,
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: _primaryColor,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Icon(Iconsax.chart, color: Colors.white),
//             ),
//             const SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Nouveau pronostic',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   widget.canal != null ? 'Poster dans ${widget.canal!.titre}' : 'Post public',
//                   style: TextStyle(color: _hintColor, fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: _isLoading ? null : _publishPronostic,
//             child: Text(
//               'PUBLIER',
//               style: TextStyle(
//                 color: _primaryColor,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               // Image
//               _buildImageSelector(),
//               const SizedBox(height: 16),
//
//               // Équipes
//               _buildEquipesSection(),
//               const SizedBox(height: 16),
//
//               // Options
//               _buildOptionsSection(),
//               const SizedBox(height: 16),
//
//               // Description
//               _buildDescriptionSection(),
//               const SizedBox(height: 16),
//
//               // Récapitulatif
//               _buildRecapSection(),
//               const SizedBox(height: 30),
//
//               // Bouton de publication (optionnel, déjà dans l'app bar)
//               SizedBox(
//                 width: double.infinity,
//                 height: 55,
//                 child: ElevatedButton(
//                   onPressed: _publishPronostic,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _primaryColor,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(25),
//                     ),
//                   ),
//                   child: const Text(
//                     'PUBLIER LE PRONOSTIC',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }