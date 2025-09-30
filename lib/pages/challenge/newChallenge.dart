// challenge_post_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as Path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class ChallengePostPage extends StatefulWidget {
  final Challenge? challenge; // Si null = création, si non null = participation
  final bool isParticipation; // true = participation, false = création

  const ChallengePostPage({
    Key? key,
    this.challenge,
    this.isParticipation = false,
  }) : super(key: key);

  @override
  _ChallengePostPageState createState() => _ChallengePostPageState();
}

class _ChallengePostPageState extends State<ChallengePostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _prixController = TextEditingController();
  final TextEditingController _prixParticipationController = TextEditingController();
  final TextEditingController _prixVoteController = TextEditingController();
  final TextEditingController _lienController = TextEditingController();

  // Contrôleurs pour le challenge
  final TextEditingController _descriptionCadeauController = TextEditingController();
  final TextEditingController _montantCadeauController = TextEditingController();

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;

  File? _selectedFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  double _uploadProgress = 0;

  // Variables pour le challenge
  String _selectedTypeContenu = 'les_deux';
  String _selectedGiftType = 'virtuel';
  bool _participationGratuite = true;
  bool _voteGratuit = true;
  DateTime _dateDebutInscription = DateTime.now();
  DateTime _dateFinInscription = DateTime.now().add(Duration(days: 7));
  DateTime _dateFinChallenge = DateTime.now().add(Duration(days: 14));

  // Types de contenu
  final Map<String, String> _typesContenu = {
    'image': 'Image uniquement',
    'video': 'Vidéo uniquement',
    'les_deux': 'Image et Vidéo',
  };

  // Types de cadeaux
  final Map<String, String> _typesCadeaux = {
    'physique': 'Cadeau physique',
    'virtuel': 'Cadeau virtuel',
  };

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    // Pré-remplir les dates pour la création
    if (widget.isParticipation) {
      _dateFinInscription = _dateFinInscription.add(Duration(days: 7));
      _dateFinChallenge = _dateFinChallenge.add(Duration(days: 14));
    }
  }

  // Méthode pour sélectionner une image
  Future<void> _selectImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _imageBytes = null; // Reset les bytes si on sélectionne un nouveau fichier
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de l\'image: $e');
    }
  }

  // Méthode pour sélectionner une vidéo
  Future<void> _selectVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        // Vérifier la taille et la durée de la vidéo
        final file = File(video.path);
        final size = await file.length();
        if (size > 20 * 1024 * 1024) { // 20MB
          _showError('La vidéo est trop lourde (max 20MB)');
          return;
        }

        setState(() {
          _selectedFile = file;
          _imageBytes = null;
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection de la vidéo: $e');
    }
  }

  // Méthode pour uploader le média
  Future<String> _uploadMedia(File file, String fileName) async {
    try {
      Reference storageRef = FirebaseStorage.instance.ref().child('challenge_media/$fileName');
      UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Erreur upload: $e');
    }
  }

  // Vérifier le type de contenu
  bool _isMediaTypeValid(String mediaType) {
    if (widget.isParticipation && widget.challenge != null) {
      final challengeType = widget.challenge!.typeContenu;
      switch (challengeType) {
        case 'image':
          return mediaType == 'image';
        case 'video':
          return mediaType == 'video';
        case 'les_deux':
          return mediaType == 'image' || mediaType == 'video';
        default:
          return true;
      }
    }
    return true;
  }

  // Méthode principale de soumission
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifications média
    if (_selectedFile == null && _imageBytes == null) {
      _showError('Veuillez sélectionner un média');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Utilisateur non connecté');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      if (widget.isParticipation) {
        await _participerAuChallenge(user.uid);
      } else {
        await _creerChallenge(user.uid);
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Créer un nouveau challenge
  Future<void> _creerChallenge(String userId) async {
    final now = DateTime.now().microsecondsSinceEpoch;

    // Créer le post du challenge
    String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
    String challengeId = FirebaseFirestore.instance.collection('Challenges').doc().id;

    // Upload du média
    String mediaUrl = '';
    String mediaType = 'image';

    if (_selectedFile != null) {
      final fileName = '${Uuid().v4()}_${Path.basename(_selectedFile!.path)}';
      mediaUrl = await _uploadMedia(_selectedFile!, fileName);
      mediaType = _selectedFile!.path.toLowerCase().contains('.mp4') ? 'video' : 'image';
    } else if (_imageBytes != null) {
      // Gérer l'upload des bytes d'image
      final fileName = '${Uuid().v4()}.jpg';
      final tempFile = await _convertUint8ListToFile(_imageBytes!, fileName);
      mediaUrl = await _uploadMedia(tempFile, fileName);
      mediaType = 'image';
    }

    // Créer le post
    Post post = Post()
      ..id = postId
      ..user_id = userId
      ..description = _descriptionController.text
      ..type = PostType.CHALLENGE.name
      ..dataType = mediaType.toUpperCase()
      ..status = PostStatus.VALIDE.name
      ..createdAt = now
      ..updatedAt = now
      ..images = mediaType == 'image' ? [mediaUrl] : []
      ..url_media = mediaType == 'video' ? mediaUrl : null
      ..likes = 0
      ..loves = 0
      ..comments = 0
      ..vues = 0;

    // Créer le challenge
    Challenge challenge = Challenge()
      ..id = challengeId
      ..user_id = userId
      ..postChallengeId = postId
      ..titre = _titreController.text
      ..description = _descriptionController.text
      ..statut = 'en_attente'
      ..typeCadeaux = _selectedGiftType
      ..descriptionCadeaux = _descriptionCadeauController.text
      ..prix = int.tryParse(_montantCadeauController.text) ?? 0
      ..participationGratuite = _participationGratuite
      ..prixParticipation = _participationGratuite ? 0 : int.tryParse(_prixParticipationController.text) ?? 0
      ..voteGratuit = _voteGratuit
      ..prixVote = _voteGratuit ? 0 : int.tryParse(_prixVoteController.text) ?? 0
      ..typeContenu = _selectedTypeContenu
      ..startInscriptionAt = _dateDebutInscription.microsecondsSinceEpoch
      ..endInscriptionAt = _dateFinInscription.microsecondsSinceEpoch
      ..finishedAt = _dateFinChallenge.microsecondsSinceEpoch
      ..createdAt = now
      ..updatedAt = now
      ..disponible = true
      ..isAprouved = true
      ..totalParticipants = 0
      ..totalVotes = 0
      ..postsIds = []
      ..usersInscritsIds = []
      ..usersVotantsIds = [];

    // Enregistrement dans Firestore
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance.collection('Posts').doc(postId),
      post.toJson(),
    );

    batch.set(
      FirebaseFirestore.instance.collection('Challenges').doc(challengeId),
      challenge.toJson(),
    );

    await batch.commit();

    // Envoyer les notifications
    // await _envoyerNotificationsChallenge(challenge, post);

    _showSuccess('Challenge créé avec succès!');
    Navigator.of(context).pop();
  }

  // Participer à un challenge existant
  Future<void> _participerAuChallenge(String userId) async {
    if (widget.challenge == null) return;

    final challenge = widget.challenge!;
    final now = DateTime.now().microsecondsSinceEpoch;

    // VÉRIFICATIONS POUR LA PARTICIPATION (PUBLICATION)

    // 1. Vérifier que le challenge est en cours
    if (!challenge.isEnCours) {
      _showError('Le challenge n\'est pas encore commencé ou est terminé');
      return;
    }

    // 2. Vérifier que l'utilisateur est inscrit
    if (!challenge.isInscrit(userId)) {
      _showError('Vous devez être inscrit pour participer à ce challenge');
      return;
    }

    // 3. Vérifier que l'utilisateur n'a pas déjà publié un post pour ce challenge
    final existingPost = await _checkIfUserAlreadyPosted(userId);
    if (existingPost) {
      _showError('Vous avez déjà publié votre participation à ce challenge');
      return;
    }

    // 4. Vérifier le type de média
    if (_selectedFile == null) {
      _showError('Veuillez sélectionner un média');
      return;
    }

    String mediaType = _selectedFile!.path.toLowerCase().contains('.mp4') ? 'video' : 'image';
    if (!_isMediaTypeValid(mediaType)) {
      _showError('Type de média non autorisé pour ce challenge');
      return;
    }

    // 5. Vérifier le solde si participation payante (optionnel - pour publication spéciale)
    if (widget.isParticipation && !challenge.participationGratuite!) {
      final solde = await _getSoldeUtilisateur(userId);
      if (solde < challenge.prixParticipation!) {
        _showSoldeInsuffisant(challenge.prixParticipation! - solde.toInt());
        return;
      }
    }

    // UPLOAD DU MÉDIA
    final fileName = '${Uuid().v4()}_${Path.basename(_selectedFile!.path)}';
    final mediaUrl = await _uploadMedia(_selectedFile!, fileName);

    // CRÉER LE POST DE PARTICIPATION
    String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

    Post post = Post()
      ..id = postId
      ..user_id = userId
      ..challenge_id = challenge.id
      ..description = _descriptionController.text
      ..type = PostType.CHALLENGEPARTICIPATION.name
      ..dataType = mediaType.toUpperCase()
      ..status = PostStatus.VALIDE.name
      ..createdAt = now
      ..updatedAt = now
      ..images = mediaType == 'image' ? [mediaUrl] : []
      ..url_media = mediaType == 'video' ? mediaUrl : null
      ..likes = 0
      ..loves = 0
      ..comments = 0
      ..vues = 0
      ..votesChallenge = 0
      ..usersVotesIds = [];

    // TRANSACTION POUR LA PARTICIPATION (PUBLICATION)
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Vérifications finales
      final challengeRef = FirebaseFirestore.instance.collection('Challenges').doc(challenge.id!);
      final challengeDoc = await transaction.get(challengeRef);

      if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

      final currentChallenge = Challenge.fromJson(challengeDoc.data()!);

      // Vérifications finales
      if (!currentChallenge.isEnCours) {
        throw Exception('Le challenge n\'est plus en cours');
      }

      if (!currentChallenge.isInscrit(userId)) {
        throw Exception('Vous n\'êtes pas inscrit à ce challenge');
      }

      // Vérifier si l'utilisateur a déjà un post pour ce challenge
      final postsQuery = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: userId)
          .where('challenge_id', isEqualTo: challenge.id)
          .get();

      if (postsQuery.docs.isNotEmpty) {
        throw Exception('Vous avez déjà publié votre participation');
      }

      // Déduire le prix si participation payante
      if (widget.isParticipation && !challenge.participationGratuite!) {
        await _debiterUtilisateur(
            userId,
            challenge.prixParticipation!,
            'Participation au challenge: ${challenge.titre}'
        );
      }

      // CRÉER LE POST
      transaction.set(
        FirebaseFirestore.instance.collection('Posts').doc(postId),
        post.toJson(),
      );

      // METTRE À JOUR LE CHALLENGE
      transaction.update(challengeRef, {
        'posts_ids': FieldValue.arrayUnion([postId]),
        'updated_at': now
      });

      // METTRE À JOUR LES STATISTIQUES (optionnel)
      transaction.update(challengeRef, {
        'total_participants': FieldValue.increment(1), // Si vous voulez compter les posts comme participants
      });
    });
    postProvider.addPostIdToAppDefaultData(postId);

    _showSuccess('Votre participation a été publiée avec succès!');
    Navigator.of(context).pop();
  }

// Méthode pour vérifier si l'utilisateur a déjà publié un post pour ce challenge
  Future<bool> _checkIfUserAlreadyPosted(String userId) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('Posts')
          .where('user_id', isEqualTo: userId)
          .where('challenge_id', isEqualTo: widget.challenge!.id)
          .limit(1)
          .get();

      return postsSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Erreur vérification post existant: $e');
      return false;
    }
  }

// Méthode pour vérifier le type de média
  // Méthodes utilitaires
  Future<File> _convertUint8ListToFile(Uint8List uint8List, String fileName) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String filePath = '${tempDir.path}/$fileName';
    return File(filePath).writeAsBytes(uint8List);
  }

  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
    await FirebaseFirestore.instance.collection('Users').doc(userId).update({
      'votre_solde_principal': FieldValue.increment(-montant)
    });

    // Crediter l'application
    await FirebaseFirestore.instance.collection('app_default_data').doc('solde').set({
      'solde_gain': FieldValue.increment(montant)
    }, SetOptions(merge: true));

    // Log de transaction
    await FirebaseFirestore.instance.collection('transactions').add({
      'user_id': userId,
      'type': 'debit',
      'montant': montant,
      'raison': raison,
      'created_at': DateTime.now().microsecondsSinceEpoch
    });
  }

  Future<void> _envoyerNotificationsChallenge(Challenge challenge, Post post) async {
    try {
      final userIds = await authProvider.getAllUsersOneSignaUserId();
      if (userIds.isNotEmpty) {
        await authProvider.sendNotification(
            userIds: userIds,
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: "",
            message: "🎉 Nouveau challenge: ${challenge.titre}! 🎁 Prix: ${challenge.prix} FCFA",
            type_notif: 'CHALLENGE',
            post_id: post.id!,
            post_type: post.dataType ?? 'IMAGE',
            chat_id: ''
        );
      }
    } catch (e) {
      print('Erreur envoi notification: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSoldeInsuffisant(int montantManquant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solde insuffisant'),
        content: Text('Il vous manque $montantManquant FCFA pour participer à ce challenge.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Naviguer vers la page de recharge
              // Navigator.push(context, MaterialPageRoute(builder: (_) => RechargePage()));
            },
            child: Text('Recharger'),
          ),
        ],
      ),
    );
  }

  // Sélecteurs de date
  Future<void> _selectDate2(BuildContext context, bool isStart, bool isInscription) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _dateDebutInscription : (isInscription ? _dateFinInscription : _dateFinChallenge),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateDebutInscription = picked;
        } else if (isInscription) {
          _dateFinInscription = picked;
        } else {
          _dateFinChallenge = picked;
        }
      });
    }
  }
  Future<void> _selectDate(BuildContext context, bool isStart, bool isInscription) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _dateDebutInscription
          : (isInscription ? _dateFinInscription : _dateFinChallenge),
      firstDate: DateTime(2000), // ✅ Autorise les dates passées
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateDebutInscription = picked;
        } else if (isInscription) {
          _dateFinInscription = picked;
        } else {
          _dateFinChallenge = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCreation = !widget.isParticipation;
    final bool isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    // Vérifier les permissions
    if (isCreation && !isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Créer un Challenge')),
        body: Center(
          child: Text('Seuls les administrateurs peuvent créer des challenges'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreation ? 'Créer un Challenge' : 'Participer au Challenge'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading ? _buildLoading() : _buildForm(isCreation),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Traitement en cours...'),
          if (_uploadProgress > 0) ...[
            SizedBox(height: 10),
            LinearProgressIndicator(value: _uploadProgress),
            Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(bool isCreation) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Média
            _buildMediaSection(isCreation),
            SizedBox(height: 20),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: isCreation ? 'Description du challenge' : 'Description de votre participation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ce champ est obligatoire';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            // Section spécifique à la création
            if (isCreation) ..._buildCreationFields(),

            // Section spécifique à la participation
            if (!isCreation && widget.challenge != null) ..._buildParticipationInfo(),

            SizedBox(height: 30),

            // Bouton de soumission
            _buildSubmitButton(isCreation),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(bool isCreation) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Média ${isCreation ? 'du challenge' : 'de participation'}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            // Restrictions pour la participation
            if (!isCreation && widget.challenge != null)
              Text(
                'Type autorisé: ${_typesContenu[widget.challenge!.typeContenu] ?? 'Tous'}',
                style: TextStyle(color: Colors.grey[600]),
              ),

            SizedBox(height: 10),

            // Aperçu du média
            if (_selectedFile != null || _imageBytes != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedFile != null && _selectedFile!.path.toLowerCase().contains('.mp4')
                    ? _buildVideoPreview()
                    : _buildImagePreview(),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library, size: 40, color: Colors.grey),
                    Text('Aucun média sélectionné'),
                  ],
                ),
              ),

            SizedBox(height: 10),

            // Boutons de sélection
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectImage,
                    icon: Icon(Icons.photo),
                    label: Text('Image'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectVideo,
                    icon: Icon(Icons.videocam),
                    label: Text('Vidéo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return _imageBytes != null
        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
        : _selectedFile != null
        ? Image.file(_selectedFile!, fit: BoxFit.cover)
        : Container();
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: Center(child: Icon(Icons.play_arrow, size: 50, color: Colors.white)),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: EdgeInsets.all(4),
            color: Colors.black54,
            child: Text('VIDEO', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCreationFields() {
    return [
      // Titre du challenge
      TextFormField(
        controller: _titreController,
        decoration: InputDecoration(
          labelText: 'Titre du challenge',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Le titre est obligatoire';
          }
          return null;
        },
      ),
      SizedBox(height: 20),

      // Type de contenu
      DropdownButtonFormField<String>(
        value: _selectedTypeContenu,
        decoration: InputDecoration(
          labelText: 'Type de contenu autorisé',
          border: OutlineInputBorder(),
        ),
        items: _typesContenu.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedTypeContenu = value!;
          });
        },
      ),
      SizedBox(height: 20),

      // Informations du cadeau
      Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎁 Informations du prix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedGiftType,
                decoration: InputDecoration(labelText: 'Type de cadeau'),
                items: _typesCadeaux.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGiftType = value!;
                  });
                },
              ),
              SizedBox(height: 10),

              TextFormField(
                controller: _descriptionCadeauController,
                decoration: InputDecoration(labelText: 'Description du cadeau'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La description est obligatoire';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),

              TextFormField(
                controller: _montantCadeauController,
                decoration: InputDecoration(labelText: 'Montant du prix (FCFA)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le montant est obligatoire';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: 20),

      // Configuration des frais
      Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💰 Configuration des frais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              // Participation gratuite/payante
              Row(
                children: [
                  Text('Participation gratuite'),
                  Switch(
                    value: _participationGratuite,
                    onChanged: (value) {
                      setState(() {
                        _participationGratuite = value;
                      });
                    },
                  ),
                ],
              ),

              if (!_participationGratuite) ...[
                TextFormField(
                  controller: _prixParticipationController,
                  decoration: InputDecoration(labelText: 'Prix de participation (FCFA)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_participationGratuite && (value == null || value.isEmpty)) {
                      return 'Le prix de participation est obligatoire';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
              ],

              // Vote gratuit/payant
              Row(
                children: [
                  Text('Vote gratuit'),
                  Switch(
                    value: _voteGratuit,
                    onChanged: (value) {
                      setState(() {
                        _voteGratuit = value;
                      });
                    },
                  ),
                ],
              ),

              if (!_voteGratuit) ...[
                TextFormField(
                  controller: _prixVoteController,
                  decoration: InputDecoration(labelText: 'Prix du vote (FCFA)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_voteGratuit && (value == null || value.isEmpty)) {
                      return 'Le prix du vote est obligatoire';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      SizedBox(height: 20),

      // Dates du challenge
      Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📅 Dates du challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              _buildDateField('Début des inscriptions', _dateDebutInscription, true, true),
              SizedBox(height: 10),

              _buildDateField('Fin des inscriptions', _dateFinInscription, false, true),
              SizedBox(height: 10),

              _buildDateField('Fin du challenge', _dateFinChallenge, false, false),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildParticipationInfo() {
    final challenge = widget.challenge!;
    return [
      Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📋 Informations du challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Text('Titre: ${challenge.titre ?? 'N/A'}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),

              Text('Description: ${challenge.description ?? 'N/A'}'),
              SizedBox(height: 5),

              Text('Prix à gagner: ${challenge.prix ?? 0} FCFA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),

              Text('Type de contenu: ${_typesContenu[challenge.typeContenu] ?? 'Tous'}'),
              SizedBox(height: 5),

              if (!challenge.participationGratuite!)
                Text('Coût de participation: ${challenge.prixParticipation} FCFA', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
      ),
      SizedBox(height: 20),
    ];
  }

  Widget _buildDateField(String label, DateTime date, bool isStart, bool isInscription) {
    return Row(
      children: [
        Expanded(
          child: Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
        ),
        TextButton(
          onPressed: () => _selectDate(context, isStart, isInscription),
          child: Text('Modifier'),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isCreation) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: isCreation ? Colors.blue : Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
          isCreation ? 'Créer le Challenge' : 'Participer au Challenge',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}