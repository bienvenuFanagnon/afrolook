// pages/chronique/my_chroniques_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/chroniqueProvider.dart';
import '../../providers/authProvider.dart';
import 'chroniquedetails.dart';
import 'chroniqueform.dart';

class MyChroniquesPage extends StatefulWidget {
  @override
  State<MyChroniquesPage> createState() => _MyChroniquesPageState();
}

class _MyChroniquesPageState extends State<MyChroniquesPage> {
  bool _isLoading = true;
  List<Chronique> _myChroniques = [];

  @override
  void initState() {
    super.initState();
    _loadMyChroniques();
  }

  void _loadMyChroniques() async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    try {
      // Récupérer le stream des chroniques
      Stream<List<Chronique>> chroniquesStream = chroniqueProvider.getUserChroniques(authProvider.loginUserData.id!);

      // Écouter le stream et mettre à jour l'état
      chroniquesStream.listen((List<Chronique> chroniques) {
        if (mounted) {
          setState(() {
            _myChroniques = chroniques;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print('Erreur stream mes chroniques: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

    } catch (e) {
      print('Erreur initialisation stream mes chroniques: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Mes Chroniques',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Color(0xFFFFD700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddChroniquePage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _myChroniques.isEmpty
          ? _buildEmptyState()
          : _buildChroniquesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddChroniquePage()),
          );
        },
        backgroundColor: Color(0xFFFFD700),
        child: Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildChroniquesList() {
    // Trier par date décroissante
    _myChroniques.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _myChroniques.length,
      itemBuilder: (context, index) {
        final chronique = _myChroniques[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChroniqueDetailPage(
                  userChroniques: [chronique],
                ),
              ),
            );
          },
          child: _buildChroniqueCard(chronique),
        );
      },
    );
  }

  Widget _buildChroniqueCard(Chronique chronique) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFD700), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            _buildChroniqueContent(chronique),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.remove_red_eye, chronique.viewCount),
                    _buildStatItem(Icons.thumb_up, chronique.likeCount),
                    _buildStatItem(Icons.favorite, chronique.loveCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChroniqueContent(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chronique.textContent!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case ChroniqueType.IMAGE:
        return CachedNetworkImage(
          imageUrl: chronique.mediaUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[800],
            child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: Icon(Icons.error, color: Color(0xFFFFD700)),
          ),
        );
      case ChroniqueType.VIDEO:
        return Stack(
          children: [
            Container(color: Colors.grey[900]),
            Center(child: Icon(Icons.play_circle_filled, color: Color(0xFFFFD700), size: 40)),
          ],
        );
    }
  }

  Widget _buildStatItem(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 12),
        SizedBox(width: 2),
        Text(
          count.toString(),
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, color: Color(0xFFFFD700), size: 80),
          SizedBox(height: 20),
          Text(
            'Aucune chronique active',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Créez votre première chronique !',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddChroniquePage()),
              );
            },
            child: Text('CRÉER UNE CHRONIQUE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFD700),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}