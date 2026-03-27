// lib/pages/admin/admin_profile_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/dating_data.dart';
import '../../../models/model_data.dart';


class AdminProfileDetailPage extends StatefulWidget {
  final DatingProfile profile;

  const AdminProfileDetailPage({Key? key, required this.profile}) : super(key: key);

  @override
  State<AdminProfileDetailPage> createState() => _AdminProfileDetailPageState();
}

class _AdminProfileDetailPageState extends State<AdminProfileDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _likesCount = 0;
  int _coupsDeCoeurCount = 0;
  int _connectionsCount = 0;
  int _messagesCount = 0;
  UserData? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUserData();
  }

  Future<void> _loadStats() async {
    // Compter les likes reçus
    final likesSnapshot = await _firestore
        .collection('dating_likes')
        .where('toUserId', isEqualTo: widget.profile.userId)
        .count()
        .get();
    _likesCount = likesSnapshot.count ?? 0;

    // Compter les coups de cœur reçus
    final coupsSnapshot = await _firestore
        .collection('dating_coup_de_coeurs')
        .where('toUserId', isEqualTo: widget.profile.userId)
        .count()
        .get();
    _coupsDeCoeurCount = coupsSnapshot.count ?? 0;

    // Compter les connexions (matchs)
    final connSnapshot = await _firestore
        .collection('dating_connections')
        .where('userId1', isEqualTo: widget.profile.userId)
        .count()
        .get();
    final connSnapshot2 = await _firestore
        .collection('dating_connections')
        .where('userId2', isEqualTo: widget.profile.userId)
        .count()
        .get();
    _connectionsCount = (connSnapshot.count ?? 0) + (connSnapshot2.count ?? 0);

    // Compter les messages envoyés et reçus
    final messagesSnapshot = await _firestore
        .collection('dating_messages')
        .where('senderUserId', isEqualTo: widget.profile.userId)
        .count()
        .get();
    final messagesSnapshot2 = await _firestore
        .collection('dating_messages')
        .where('receiverUserId', isEqualTo: widget.profile.userId)
        .count()
        .get();
    _messagesCount = (messagesSnapshot.count ?? 0) + (messagesSnapshot2.count ?? 0);

    setState(() {});
  }

  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('Users').doc(widget.profile.userId).get();
    if (doc.exists) {
      setState(() {
        _userData = UserData.fromJson(doc.data()!);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détail profil: ${widget.profile.pseudo}'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.profile.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 80),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Infos de base
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.profile.pseudo} (${widget.profile.age} ans)',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Sexe: ${widget.profile.sexe}'),
                    Text('Localisation: ${widget.profile.ville}, ${widget.profile.pays}'),
                    if (widget.profile.profession != null) Text('Profession: ${widget.profile.profession}'),
                    Text('Bio: ${widget.profile.bio}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: widget.profile.isProfileComplete ? Colors.green : Colors.red),
                        const SizedBox(width: 4),
                        Text(widget.profile.isProfileComplete ? 'Profil complet' : 'Profil incomplet'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Statistiques
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Statistiques', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.favorite, 'Likes reçus', _likesCount.toString()),
                    _buildStatRow(Icons.star, 'Coups de cœur reçus', _coupsDeCoeurCount.toString()),
                    _buildStatRow(Icons.people, 'Matchs', _connectionsCount.toString()),
                    _buildStatRow(Icons.chat, 'Messages', _messagesCount.toString()),
                    _buildStatRow(Icons.visibility, 'Visites reçues', widget.profile.visitorsCount.toString()),
                    _buildStatRow(Icons.star, 'Score de popularité', widget.profile.popularityScore.toString()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Centres d'intérêt
            if (widget.profile.centresInteret.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Centres d\'intérêt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.profile.centresInteret
                            .map((i) => Chip(label: Text(i)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Préférences de recherche
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recherche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Recherche: ${widget.profile.rechercheSexe}'),
                    Text('Âge: ${widget.profile.rechercheAgeMin} - ${widget.profile.rechercheAgeMax} ans'),
                    Text('Pays: ${widget.profile.recherchePays}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Données utilisateur (si disponibles)
            if (_userData != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Données utilisateur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Email: ${_userData!.email ?? 'Non renseigné'}'),
                      Text('Téléphone: ${_userData!.numeroDeTelephone ?? 'Non renseigné'}'),
                      Text('Inscrit le: ${_formatTimestamp(_userData!.createdAt)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Inconnu';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }
}