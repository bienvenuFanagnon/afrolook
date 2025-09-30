// participation_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/challenge_controller.dart';

class ParticipationModal extends StatefulWidget {
  final Challenge challenge;

  const ParticipationModal({Key? key, required this.challenge}) : super(key: key);

  @override
  _ParticipationModalState createState() => _ParticipationModalState();
}

class _ParticipationModalState extends State<ParticipationModal> {
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedMedia = [];
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final challengeController = Provider.of<ChallengeController>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participer au challenge',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Type de contenu
          _buildTypeSelector(),
          const SizedBox(height: 20),

          // Description
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Upload média
          _buildMediaUpload(),
          const SizedBox(height: 20),

          // Informations prix
          if (!widget.challenge.participationGratuite!)
            _buildPrixInfo(),

          const SizedBox(height: 20),

          // Bouton de participation
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit() ? () => _submitParticipation(challengeController) : null,
              child: Text('Confirmer la participation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    final options = _getAvailableTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type de contenu *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((type) {
            return ChoiceChip(
              label: Text(type == 'image' ? 'Image' : 'Vidéo'),
              selected: _selectedType == type,
              onSelected: (selected) {
                setState(() {
                  _selectedType = selected ? type : null;
                  _selectedMedia.clear();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMediaUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Média *', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _selectedMedia.isEmpty
            ? ElevatedButton.icon(
          onPressed: _selectMedia,
          icon: Icon(Icons.upload),
          label: Text('Ajouter un média'),
        )
            : Wrap(
          spacing: 8,
          children: _selectedMedia.map((url) {
            return Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedMedia.remove(url);
                      });
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrixInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Participation payante: ${widget.challenge.prixParticipation} FCFA',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    return _selectedType != null &&
        _selectedMedia.isNotEmpty &&
        _descriptionController.text.isNotEmpty;
  }

  void _selectMedia() async {
    // Implémentation de la sélection de média
    // Utiliser image_picker pour les images/vidéos
  }

  Future<void> _submitParticipation(ChallengeController controller) async {
    try {
      await controller.inscrireAuChallenge(
        widget.challenge.id!,
        _descriptionController.text,
        _selectedMedia,
        _selectedType!,
      );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Participation enregistrée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          if (message.contains('Solde insuffisant'))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Naviguer vers la page de recharge
              },
              child: Text('Recharger'),
            ),
        ],
      ),
    );
  }

  List<String> _getAvailableTypes() {
    switch (widget.challenge.typeContenu) {
      case 'image':
        return ['image'];
      case 'video':
        return ['video'];
      case 'les_deux':
        return ['image', 'video'];
      default:
        return ['image', 'video'];
    }
  }
}