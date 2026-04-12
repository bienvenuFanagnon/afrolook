import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../providers/authProvider.dart';
import '../component/showUserDetails.dart';
import '../pub/native_ad_widget.dart';

class UserClassement extends StatefulWidget {
  const UserClassement({super.key});

  @override
  State<UserClassement> createState() => _UserClassementState();
}

class _UserClassementState extends State<UserClassement> {
  late UserAuthProvider authProvider;
  List<UserData> _topUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _fetchTopUsers();
  }

  /// Récupère les 10 utilisateurs les plus populaires depuis Firebase
  Future<void> _fetchTopUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Requête Firestore: trier par popularité décroissant et limiter à 10
      QuerySnapshot userSnapshot = await _firestore
          .collection('Users')
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .get();

      final List<UserData> fetchedUsers = [];

      for (var doc in userSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;

        // Construction de l'objet UserData
        final user = UserData.fromJson(userData);

        fetchedUsers.add(user);
      }

      setState(() {
        _topUsers = fetchedUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur lors de la récupération du classement: $e');
      setState(() {
        _errorMessage = 'Impossible de charger le classement';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "TOP 10 Afrolook Stars",
          style: TextStyle(
            fontSize: SizeText.homeProfileTextSize,
            color: Colors.yellow[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
        iconTheme: IconThemeData(color: Colors.yellow[700]),
      ),
      body: _buildBody(height, width),
    );
  }

  Widget _buildBody(double height, double width) {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_topUsers.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _fetchTopUsers,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // En-tête avec informations
            _buildHeader(),

            SizedBox(height: 16),

            // Liste des top 10 avec pub en premier élément
            ListView.builder(
              itemCount: _topUsers.length + 1, // +1 pour la pub
              shrinkWrap: true,
              padding: EdgeInsets.only(top: 8, bottom: 20),
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                // Premier élément (index 0) = la pub
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _buildAdBanner(key: 'top10_first_ad'),
                  );
                }

                // Ajuster l'index pour les utilisateurs
                final userIndex = index - 1;

                return GestureDetector(
                  onTap: () {
                    showUserDetailsModalDialog(
                      _topUsers[userIndex],
                      width,
                      height,
                      context,
                    );
                  },
                  child: TopFiveUserItem(
                    user: _topUsers[userIndex],
                    rank: userIndex + 1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[800]?.withOpacity(0.3),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Classement par popularité",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Mis à jour en temps réel",
            style: TextStyle(
              fontSize: 18,
              color: Colors.yellow[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Les stars sont classées selon leur activité: publications, likes et commentaires",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchTopUsers,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 11, // +1 pour la pub
      padding: EdgeInsets.only(top: 16),
      itemBuilder: (context, index) {
        // Premier élément (index 0) = placeholder de pub
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[700]!,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }

        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: MrecAdWidget(
        // templateType: TemplateType.small,
        onAdLoaded: () {
          print('✅ Native Ad chargée dans top10: $key');
        },
      ),
    );
  }
}

// Widget pour afficher un utilisateur du top 10
class TopFiveUserItem extends StatefulWidget {
  final UserData user;
  final int rank;

  const TopFiveUserItem({
    super.key,
    required this.user,
    required this.rank,
  });

  @override
  State<TopFiveUserItem> createState() => _TopFiveUserItemState();
}

class _TopFiveUserItemState extends State<TopFiveUserItem> {
  late UserAuthProvider authProvider;
  @override
  void initState() {
    // TODO: implement initState
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Définir les couleurs en fonction du rang
    Color rankColor;
    if (widget.rank == 1) {
      rankColor = Colors.yellow[700]!;
    } else if (widget.rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (widget.rank == 3) {
      rankColor = Colors.orange[800]!;
    } else {
      rankColor = Colors.green[600]!;
    }

    // Trophée pour le top 3
    IconData? rankIcon;
    if (widget.rank == 1) {
      rankIcon = Icons.emoji_events;
    } else if (widget.rank == 2) {
      rankIcon = Icons.emoji_events;
    } else if (widget.rank == 3) {
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Numéro de classement
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: widget.rank <= 3
                  ? LinearGradient(
                colors: [rankColor, rankColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: widget.rank > 3 ? rankColor : null,
              shape: BoxShape.circle,
            ),
            child: rankIcon != null && widget.rank <= 3
                ? Icon(rankIcon, color: Colors.white, size: 24)
                : Text(
              "${widget.rank}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.rank <= 3 ? Colors.white : Colors.black,
              ),
            ),
          ),

          SizedBox(width: 12),

          // Avatar utilisateur
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: widget.user.imageUrl != null && widget.user.imageUrl!.isNotEmpty
                    ? NetworkImage(widget.user.imageUrl!)
                    : null,
                radius: 24,
                backgroundColor: Colors.grey[800],
                child: widget.user.imageUrl == null || widget.user.imageUrl!.isEmpty
                    ? Icon(Icons.person, size: 28, color: Colors.grey[600])
                    : null,
              ),
              if (widget.user.isVerify ?? false)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 12),

          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "@${widget.user.pseudo}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 12, color: Colors.green[600]),
                    SizedBox(width: 4),
                    Text(
                      "${widget.user.userAbonnesIds?.length ?? 0} abonnés",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.star, size: 12, color: Colors.yellow[700]),
                    SizedBox(width: 4),
                    Text(
                      "${((widget.user.totalPoints/authProvider.appDefaultData.appTotalPoints ?? 0) * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.yellow[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badge de contribution pour le top 3
          if (widget.rank <= 3)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${widget.user.totalPoints ?? 0} pts",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}