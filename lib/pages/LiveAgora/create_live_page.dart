// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/model_data.dart';
import '../paiement/newDepot.dart';
import 'create_live_page.dart';
import 'livePage.dart';
import 'livesAgora.dart';
// pages/live/create_live_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'livePage.dart';

class CreateLivePage extends StatefulWidget {
  @override
  _CreateLivePageState createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<CreateLivePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // NOUVEAUX CONTROLLERS POUR LIVE PAYANT
  final TextEditingController _participationFeeController = TextEditingController(text: '100');
  final TextEditingController _freeTrialController = TextEditingController(text: '1');

  // VARIABLES POUR LES PARAMÈTRES
  bool _isPaidLive = false;
  String _audioBehavior = 'reduce';
  int _audioReductionPercent = 50;
  bool _blurVideoAfterTrial = true;
  bool _showPaymentModalAfterTrial = true;

  // ⭐⭐ NOUVELLE VARIABLE POUR SÉCURISATION ⭐⭐
  bool _isCreating = false;
  Timer? _creationTimer;

  @override
  void dispose() {
    // Nettoyer le timer si la page est fermée
    _creationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un live', style: TextStyle(color: Color(0xFFF9A825))),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: 20),
              _buildTitleField(),
              SizedBox(height: 20),
              _buildLiveTypeSection(),
              if (_isPaidLive) ..._buildPaidLiveOptions(),
              SizedBox(height: 30),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Titre du live',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un titre';
        }
        if (value.length > 100) {
          return 'Titre trop long (max 100 caractères)';
        }
        return null;
      },
    );
  }

  Widget _buildLiveTypeSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type de live',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLiveTypeOption(
                    title: 'Gratuit',
                    subtitle: 'Tout le monde peut regarder',
                    isSelected: !_isPaidLive,
                    onTap: () => setState(() => _isPaidLive = false),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildLiveTypeOption(
                    title: 'Payant',
                    subtitle: 'Spectateurs payent pour regarder',
                    isSelected: _isPaidLive,
                    onTap: () => setState(() => _isPaidLive = true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTypeOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFF9A825).withOpacity(0.2) : Colors.grey[800],
          border: Border.all(
            color: isSelected ? Color(0xFFF9A825) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPaidLiveOptions() {
    return [
      SizedBox(height: 20),
      _buildParticipationFeeField(),
      SizedBox(height: 20),
      _buildFreeTrialField(),
      SizedBox(height: 20),
      _buildAudioBehaviorSection(),
      SizedBox(height: 20),
      _buildVisualRestrictionsSection(),
    ];
  }

  Widget _buildParticipationFeeField() {
    return TextFormField(
      controller: _participationFeeController,
      style: TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Prix de participation (FCFA)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
        ),
        prefixText: 'FCFA ',
        prefixStyle: TextStyle(color: Colors.white70),
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return 'Veuillez entrer un prix';
        }
        if (_isPaidLive) {
          final price = double.tryParse(value!);
          if (price == null) {
            return 'Prix invalide';
          }
          if (price < 10) {
            return 'Minimum 10 FCFA';
          }
          if (price > 100000) {
            return 'Maximum 100 000 FCFA';
          }
        }
        return null;
      },
    );
  }

  Widget _buildFreeTrialField() {
    return TextFormField(
      controller: _freeTrialController,
      style: TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Temps d\'essai gratuit (minutes)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
        ),
        suffixText: 'min',
        suffixStyle: TextStyle(color: Colors.white70),
      ),
      validator: (value) {
        if (_isPaidLive && (value == null || value.isEmpty)) {
          return 'Veuillez entrer une durée';
        }
        if (_isPaidLive) {
          final minutes = int.tryParse(value!);
          if (minutes == null) {
            return 'Durée invalide';
          }
          if (minutes < 1) {
            return 'Minimum 1 minute';
          }
          if (minutes > 60) {
            return 'Maximum 60 minutes';
          }
        }
        return null;
      },
    );
  }

  Widget _buildAudioBehaviorSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comportement du son après l\'essai',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildAudioOption(
              value: 'mute',
              title: '🔇 Son coupé',
              subtitle: 'Le spectateur ne peut plus entendre',
            ),
            _buildAudioOption(
              value: 'reduce',
              title: '🎵 Son réduit',
              subtitle: 'Le son est baissé mais audible',
            ),
            _buildAudioOption(
              value: 'keep',
              title: '🔊 Son normal',
              subtitle: 'Le son reste inchangé',
            ),
            if (_audioBehavior == 'reduce') ...[
              SizedBox(height: 16),
              Text(
                'Réduction du son: $_audioReductionPercent%',
                style: TextStyle(color: Colors.white70),
              ),
              Slider(
                value: _audioReductionPercent.toDouble(),
                min: 10,
                max: 90,
                divisions: 8,
                label: '$_audioReductionPercent%',
                onChanged: (value) {
                  setState(() {
                    _audioReductionPercent = value.round();
                  });
                },
                activeColor: Color(0xFFF9A825),
                inactiveColor: Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<String>(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white)),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      value: value,
      groupValue: _audioBehavior,
      onChanged: (newValue) {
        setState(() {
          _audioBehavior = newValue!;
        });
      },
      activeColor: Color(0xFFF9A825),
    );
  }

  Widget _buildVisualRestrictionsSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restrictions visuelles après l\'essai',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text(
                'Flouter la vidéo',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Rendre le flux vidéo flou',
                style: TextStyle(color: Colors.white70),
              ),
              value: _blurVideoAfterTrial,
              onChanged: (value) {
                setState(() {
                  _blurVideoAfterTrial = value;
                });
              },
              activeColor: Color(0xFFF9A825),
            ),
            SwitchListTile(
              title: Text(
                'Afficher le modal de paiement',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Montrer automatiquement la demande de paiement',
                style: TextStyle(color: Colors.white70),
              ),
              value: _showPaymentModalAfterTrial,
              onChanged: (value) {
                setState(() {
                  _showPaymentModalAfterTrial = value;
                });
              },
              activeColor: Color(0xFFF9A825),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐⭐ BOUTON CRÉATION AVEC SÉCURISATION ⭐⭐
  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isCreating ? null : _createLive,
      child: _isCreating
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Création en cours...',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ],
      )
          : Text(
        'Démarrer le live',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCreating ? Colors.grey[700] : Color(0xFFF9A825),
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ⭐⭐ MÉTHODE DE CRÉATION SÉCURISÉE ⭐⭐
  Future<void> _createLive() async {
    // 1. VÉRIFICATION PRÉLIMINAIRE
    if (_isCreating) {
      print('⚠️ Tentative bloquée : création déjà en cours');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      print('❌ Validation du formulaire échouée');
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      print('❌ Utilisateur non authentifié');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous devez être connecté pour créer un live'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. ACTIVER LE VERROUILLAGE
    setState(() => _isCreating = true);

    // Timer de sécurité : déverrouille automatiquement après 10 secondes
    _creationTimer = Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _isCreating = false);
        print('🔓 Verrouillage automatique libéré après 10 secondes');
      }
    });

    try {
      // 3. VÉRIFIER SI L'UTILISATEUR A DÉJÀ UN LIVE ACTIF
      final activeLiveQuery = await _firestore
          .collection('lives')
          .where('hostId', isEqualTo: user.uid)
          .where('isLive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeLiveQuery.docs.isNotEmpty) {
        // L'utilisateur a déjà un live actif
        print('❌ Utilisateur a déjà un live actif: ${activeLiveQuery.docs.first.id}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous avez déjà un live en cours. Terminez-le avant d\'en créer un nouveau.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigation vers le live existant
        final existingLiveId = activeLiveQuery.docs.first.id;
        final liveData = activeLiveQuery.docs.first.data();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: existingLiveId,
              isHost: true,
              hostName: liveData['hostName'] ?? 'Hôte',
              hostImage: liveData['hostImage'] ?? '',
              isInvited: false,
              postLive: PostLive.fromMap(liveData),
            ),
          ),
        );
        return;
      }

      // 4. CRÉER LE NOUVEAU LIVE
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final String liveId = _firestore.collection('lives').doc().id;

      // Création du live avec tous les paramètres
      final PostLive newLive = PostLive(
        liveId: liveId,
        hostId: user.uid,
        hostName: authProvider.loginUserData.pseudo! ?? 'Utilisateur',
        hostImage: authProvider.loginUserData.imageUrl! ?? 'https://via.placeholder.com/150',
        title: _titleController.text.trim(),
        startTime: DateTime.now(),

        // Paramètres live payant
        isPaidLive: _isPaidLive,
        participationFee: _isPaidLive ? double.parse(_participationFeeController.text) : 0.0,
        freeTrialMinutes: _isPaidLive ? int.parse(_freeTrialController.text) : 0,

        // Comportement après essai
        audioBehaviorAfterTrial: _audioBehavior,
        audioReductionPercent: _audioReductionPercent,
        blurVideoAfterTrial: _blurVideoAfterTrial,
        showPaymentModalAfterTrial: _showPaymentModalAfterTrial,
      );

      // 5. SAUVEGARDE DANS FIRESTORE
      await _firestore.collection('lives').doc(liveId).set(newLive.toMap());
      print("✅ Live créé avec succès: $liveId");

      // 6. ENVOYER LES NOTIFICATIONS (en arrière-plan)
      _sendNotifications(authProvider, newLive);

      // 7. NAVIGATION VERS LE LIVE
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LivePage(
            liveId: liveId,
            isHost: true,
            hostName: newLive.hostName!,
            hostImage: newLive.hostImage!,
            isInvited: false,
            postLive: newLive,
          ),
        ),
      );

    } catch (e) {
      print("❌ Erreur création live: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du live: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      // 8. DÉSACTIVER LE VERROUILLAGE QUOI QU'IL ARRIVE
      _creationTimer?.cancel();
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  // ⭐⭐ MÉTHODE POUR ENVOYER LES NOTIFICATIONS (ASYNCHRONE)
  Future<void> _sendNotifications(UserAuthProvider authProvider, PostLive newLive) async {
    try {
      // Cette partie s'exécute en arrière-plan, ne bloque pas l'interface
      authProvider.getAllUsersOneSignaUserId().then((userIds) async {
        if (userIds.isNotEmpty) {
          await authProvider.sendNotification(
            userIds: userIds,
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: "",
            message: "🚀 @${authProvider.loginUserData.pseudo!} vient tout juste de lancer un live 🎬✨ ! : ${newLive.title}",
            type_notif: NotificationType.CHRONIQUE.name,
            post_id: newLive.liveId ?? "id",
            post_type: PostDataType.TEXT.name,
            chat_id: '',
          );
          print("📨 Notifications envoyées à ${userIds.length} utilisateurs");
        }
      });
    } catch (e) {
      print("⚠️ Erreur envoi notifications: $e");
      // Ne pas bloquer la création du live si les notifications échouent
    }
  }
}


//
//
// // models/live_models.dart
// import 'dart:async';
// import 'dart:math';
// import 'package:afrotok/pages/component/consoleWidget.dart';
// import 'package:afrotok/pages/component/showUserDetails.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
//
//
// import '../../models/model_data.dart';
// import '../paiement/newDepot.dart';
// import 'create_live_page.dart';
// import 'livePage.dart';
// import 'livesAgora.dart';
// // pages/live/create_live_page.dart
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import '../../models/model_data.dart';
// import '../../providers/authProvider.dart';
// import 'livePage.dart';
//
// class CreateLivePage extends StatefulWidget {
//   @override
//   _CreateLivePageState createState() => _CreateLivePageState();
// }
//
// class _CreateLivePageState extends State<CreateLivePage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final TextEditingController _titleController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//
//   // NOUVEAUX CONTROLLERS POUR LIVE PAYANT
//   final TextEditingController _participationFeeController = TextEditingController(text: '100');
//   final TextEditingController _freeTrialController = TextEditingController(text: '1');
//
//   // VARIABLES POUR LES PARAMÈTRES
//   bool _isPaidLive = false;
//   String _audioBehavior = 'reduce';
//   int _audioReductionPercent = 50;
//   bool _blurVideoAfterTrial = true;
//   bool _showPaymentModalAfterTrial = true;
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = context.watch<UserAuthProvider>();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Créer un live', style: TextStyle(color: Color(0xFFF9A825))),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               SizedBox(height: 20),
//               _buildTitleField(),
//               SizedBox(height: 20),
//               _buildLiveTypeSection(),
//               if (_isPaidLive) ..._buildPaidLiveOptions(),
//               SizedBox(height: 30),
//               _buildCreateButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTitleField() {
//     return TextFormField(
//       controller: _titleController,
//       style: TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: 'Titre du live',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//       ),
//       validator: (value) {
//         if (value == null || value.isEmpty) {
//           return 'Veuillez entrer un titre';
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildLiveTypeSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Type de live',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildLiveTypeOption(
//                     title: 'Gratuit',
//                     subtitle: 'Tout le monde peut regarder',
//                     isSelected: !_isPaidLive,
//                     onTap: () => setState(() => _isPaidLive = false),
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: _buildLiveTypeOption(
//                     title: 'Payant',
//                     subtitle: 'Spectateurs payent pour regarder',
//                     isSelected: _isPaidLive,
//                     onTap: () => setState(() => _isPaidLive = true),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLiveTypeOption({
//     required String title,
//     required String subtitle,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFFF9A825).withOpacity(0.2) : Colors.grey[800],
//           border: Border.all(
//             color: isSelected ? Color(0xFFF9A825) : Colors.transparent,
//             width: 2,
//           ),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               subtitle,
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   List<Widget> _buildPaidLiveOptions() {
//     return [
//       SizedBox(height: 20),
//       _buildParticipationFeeField(),
//       SizedBox(height: 20),
//       _buildFreeTrialField(),
//       SizedBox(height: 20),
//       _buildAudioBehaviorSection(),
//       SizedBox(height: 20),
//       _buildVisualRestrictionsSection(),
//     ];
//   }
//
//   Widget _buildParticipationFeeField() {
//     return TextFormField(
//       controller: _participationFeeController,
//       style: TextStyle(color: Colors.white),
//       keyboardType: TextInputType.number,
//       decoration: InputDecoration(
//         labelText: 'Prix de participation (FCFA)',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//         prefixText: 'FCFA ',
//         prefixStyle: TextStyle(color: Colors.white70),
//       ),
//       validator: (value) {
//         if (_isPaidLive && (value == null || value.isEmpty)) {
//           return 'Veuillez entrer un prix';
//         }
//         if (_isPaidLive && double.tryParse(value!) == null) {
//           return 'Prix invalide';
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildFreeTrialField() {
//     return TextFormField(
//       controller: _freeTrialController,
//       style: TextStyle(color: Colors.white),
//       keyboardType: TextInputType.number,
//       decoration: InputDecoration(
//         labelText: 'Temps d\'essai gratuit (minutes)',
//         labelStyle: TextStyle(color: Color(0xFF2E7D32)),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFF2E7D32)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Color(0xFFF9A825)),
//         ),
//         suffixText: 'min',
//         suffixStyle: TextStyle(color: Colors.white70),
//       ),
//       validator: (value) {
//         if (_isPaidLive && (value == null || value.isEmpty)) {
//           return 'Veuillez entrer une durée';
//         }
//         if (_isPaidLive && int.tryParse(value!) == null) {
//           return 'Durée invalide';
//         }
//         return null;
//       },
//     );
//   }
//
//   Widget _buildAudioBehaviorSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Comportement du son après l\'essai',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             _buildAudioOption(
//               value: 'mute',
//               title: '🔇 Son coupé',
//               subtitle: 'Le spectateur ne peut plus entendre',
//             ),
//             _buildAudioOption(
//               value: 'reduce',
//               title: '🎵 Son réduit',
//               subtitle: 'Le son est baissé mais audible',
//             ),
//             _buildAudioOption(
//               value: 'keep',
//               title: '🔊 Son normal',
//               subtitle: 'Le son reste inchangé',
//             ),
//             if (_audioBehavior == 'reduce') ...[
//               SizedBox(height: 16),
//               Text(
//                 'Réduction du son: $_audioReductionPercent%',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               Slider(
//                 value: _audioReductionPercent.toDouble(),
//                 min: 10,
//                 max: 90,
//                 divisions: 8,
//                 label: '$_audioReductionPercent%',
//                 onChanged: (value) {
//                   setState(() {
//                     _audioReductionPercent = value.round();
//                   });
//                 },
//                 activeColor: Color(0xFFF9A825),
//                 inactiveColor: Colors.grey,
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAudioOption({
//     required String value,
//     required String title,
//     required String subtitle,
//   }) {
//     return RadioListTile<String>(
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: TextStyle(color: Colors.white)),
//           SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: TextStyle(color: Colors.white70, fontSize: 12),
//           ),
//         ],
//       ),
//       value: value,
//       groupValue: _audioBehavior,
//       onChanged: (newValue) {
//         setState(() {
//           _audioBehavior = newValue!;
//         });
//       },
//       activeColor: Color(0xFFF9A825),
//     );
//   }
//
//   Widget _buildVisualRestrictionsSection() {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Restrictions visuelles après l\'essai',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 12),
//             SwitchListTile(
//               title: Text(
//                 'Flouter la vidéo',
//                 style: TextStyle(color: Colors.white),
//               ),
//               subtitle: Text(
//                 'Rendre le flux vidéo flou',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               value: _blurVideoAfterTrial,
//               onChanged: (value) {
//                 setState(() {
//                   _blurVideoAfterTrial = value;
//                 });
//               },
//               activeColor: Color(0xFFF9A825),
//             ),
//             SwitchListTile(
//               title: Text(
//                 'Afficher le modal de paiement',
//                 style: TextStyle(color: Colors.white),
//               ),
//               subtitle: Text(
//                 'Montrer automatiquement la demande de paiement',
//                 style: TextStyle(color: Colors.white70),
//               ),
//               value: _showPaymentModalAfterTrial,
//               onChanged: (value) {
//                 setState(() {
//                   _showPaymentModalAfterTrial = value;
//                 });
//               },
//               activeColor: Color(0xFFF9A825),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCreateButton() {
//     return ElevatedButton(
//       onPressed: _createLive,
//       child: Text(
//         'Démarrer le live',
//         style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//       ),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Color(0xFFF9A825),
//         padding: EdgeInsets.symmetric(vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _createLive() async {
//     if (_formKey.currentState!.validate()) {
//       User? user = _auth.currentUser;
//       late UserAuthProvider authProvider =
//       Provider.of<UserAuthProvider>(context, listen: false);
//
//       if (user != null) {
//         String liveId = _firestore.collection('lives').doc().id;
//
//         // Création du live avec tous les nouveaux paramètres
//         PostLive newLive = PostLive(
//           liveId: liveId,
//           hostId: user.uid,
//           hostName: authProvider.loginUserData.pseudo! ?? 'Utilisateur',
//           hostImage: authProvider.loginUserData.imageUrl! ?? 'https://via.placeholder.com/150',
//           title: _titleController.text,
//           startTime: DateTime.now(),
//
//           // Paramètres live payant
//           isPaidLive: _isPaidLive,
//           participationFee: _isPaidLive ? double.parse(_participationFeeController.text) : 0.0,
//           freeTrialMinutes: _isPaidLive ? int.parse(_freeTrialController.text) : 0,
//
//           // Comportement après essai
//           audioBehaviorAfterTrial: _audioBehavior,
//           audioReductionPercent: _audioReductionPercent,
//           blurVideoAfterTrial: _blurVideoAfterTrial,
//           showPaymentModalAfterTrial: _showPaymentModalAfterTrial,
//         );
//
//         try {
//           await _firestore.collection('lives').doc(liveId).set(newLive.toMap());
//         authProvider
//             .getAllUsersOneSignaUserId()
//             .then(
//               (userIds) async {
//             if (userIds.isNotEmpty) {
//
//               await authProvider.sendNotification(
//                   userIds: userIds,
//                   smallImage: "${authProvider.loginUserData.imageUrl!}",
//                   send_user_id: "${authProvider.loginUserData.id!}",
//                   recever_user_id: "",
//                   message: "🚀 @${authProvider.loginUserData.pseudo!} vient tout juste de lancer un live 🎬✨ ! :${newLive.title}",
//                   type_notif: NotificationType.CHRONIQUE.name,
//                   post_id: "id",
//                   post_type: PostDataType.TEXT.name, chat_id: ''
//               );
//
//             }
//           },
//         );
//           print("✅ Live créé avec succès:");
//           print("   - Type: ${_isPaidLive ? 'Payant' : 'Gratuit'}");
//           if (_isPaidLive) {
//             print("   - Prix: ${_participationFeeController.text} FCFA");
//             print("   - Essai gratuit: ${_freeTrialController.text} min");
//             print("   - Comportement audio: $_audioBehavior");
//           }
//
//           // Navigation vers le live
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => LivePage(
//                 liveId: liveId,
//                 isHost: true,
//                 hostName: newLive.hostName!,
//                 hostImage: newLive.hostImage!,
//                 isInvited: false,
//                 postLive: newLive,
//               ),
//             ),
//           );
//
//         } catch (e) {
//           print("❌ Erreur création live: $e");
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Erreur lors de la création du live'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }
// }
//
