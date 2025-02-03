import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as Path;
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';

class EditCanal extends StatefulWidget {
  final Canal canal;

  EditCanal({required this.canal});

  @override
  _EditCanalState createState() => _EditCanalState();
}

class _EditCanalState extends State<EditCanal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  XFile? imageProfile;
  XFile? imageCouverture;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titreController.text = widget.canal.titre!;
    _descriptionController.text = widget.canal.description!;
  }

  Future<void> _getImageProfile() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageProfile = image;
    });
  }

  Future<void> _getImageCouverture() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageCouverture = image;
    });
  }

  Future<void> _updateCanal() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (imageProfile != null) {
          Reference storageReferenceProfile = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
          UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
          await uploadTaskProfile.whenComplete(() async {
            await storageReferenceProfile.getDownloadURL().then((fileURL) {
              widget.canal.urlImage = fileURL;
            });
          });
        }

        if (imageCouverture != null) {
          Reference storageReferenceCouverture = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
          UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
          await uploadTaskCouverture.whenComplete(() async {
            await storageReferenceCouverture.getDownloadURL().then((fileURL) {
              widget.canal.urlCouverture = fileURL;
            });
          });
        }

        widget.canal.titre = _titreController.text;
        widget.canal.description = _descriptionController.text;

        await FirebaseFirestore.instance.collection('Canaux').doc(widget.canal.id).update(widget.canal.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Le Canal a été mis à jour avec succès !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur de mise à jour.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails du Canal'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: imageProfile != null
                          ? FileImage(File(imageProfile!.path)) as ImageProvider<Object>
                          : widget.canal.urlImage != null
                          ? NetworkImage(widget.canal.urlImage!) as ImageProvider<Object>
                          : null,
                      child: imageProfile == null && widget.canal.urlImage == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _getImageProfile,
                      child: const Text('Modifier l\'image de profil'),
                    ),
                    const SizedBox(height: 20),
                    imageCouverture != null
                        ? Image.file(File(imageCouverture!.path))
                        : widget.canal.urlCouverture != null
                        ? Image.network(widget.canal.urlCouverture!)
                        : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _getImageCouverture,
                      child: const Text('Modifier l\'image de couverture'),
                    ),
                  ],
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Titre'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                      controller: _titreController,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer une description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 50),
                    ElevatedButton(
                      onPressed: _updateCanal,
                      child: Text('Mettre à jour le canal'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}