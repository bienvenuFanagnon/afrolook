// pages/mes_gains_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../services/remuneration_service.dart';
import '../postDetails.dart';
import '../postDetailsVideoListe.dart';

// ============================================
// PAGE PRINCIPALE DES GAINS
// ============================================
class MesGainsPage extends StatefulWidget {
  final String userId;

  const MesGainsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _MesGainsPageState createState() => _MesGainsPageState();
}

class _MesGainsPageState extends State<MesGainsPage> with SingleTickerProviderStateMixin {
  final RemunerationService _service = RemunerationService();

  bool _isLoading = false;
  bool _hasCalculated = false;
  bool _isProcessing = false;

  Map<String, dynamic>? _gainsActuels;
  RemunerationConfig? _config;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Variables pour la progression
  int _currentProgress = 0;
  int _totalProgress = 0;
  String _currentPostDescription = '';
  bool _showProgress = false;

  final List<Map<String, String>> _motivationMessages = [
    {
      'title': '🔥 PUBLIE ET GAGNE',
      'message': 'Plus tu publies, plus tu gagnes ! Chaque vue compte.',
      'icon': '🚀',
    },
    {
      'title': '👥 INVITE TES AMIS',
      'message': 'Parraine un ami et gagne 10% de ses gains à vie !',
      'icon': '🤝',
    },
    {
      'title': '📱 PARTAGE SUR LES RÉSEAUX',
      'message': 'WhatsApp, Facebook, TikTok - Partage tes looks partout !',
      'icon': '📲',
    },
    {
      'title': '🎯 ABONNE-TOI',
      'message': 'Suis d\'autres créateurs et booste ta visibilité !',
      'icon': '⭐',
    },
    {
      'title': '💎 CONTENU DE QUALITÉ',
      'message': 'Plus ton contenu est beau, plus tu as de vues !',
      'icon': '✨',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _chargerConfiguration();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _chargerConfiguration() async {
    _config = await _service.getActiveConfig();
    setState(() {});
  }

  Future<void> _calculerGains() async {
    setState(() {
      _showProgress = true;
      _currentProgress = 0;
      _totalProgress = 0;
      _isLoading = true;
    });

    try {
      _gainsActuels = await _service.calculerTousGains(
        widget.userId,
        _config!,
            (current, total, post) {
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
            _currentPostDescription = post.description ?? 'Publication sans description';
          });
        },
      );

      setState(() {
        _hasCalculated = true;
        _isLoading = false;
        _showProgress = false;
      });

      _animationController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showProgress = false;
      });

      _showMessage('Erreur lors du calcul: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Color(0xFFFFD700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getPeriodeText() {
    DateTime now = DateTime.now();
    DateTime cinqMois = DateTime(now.year, now.month - 5, 1);
    final format = DateFormat('MMM yyyy');
    return '${format.format(cinqMois)} - ${format.format(now)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'MES GAINS - ${widget.userId.substring(0,10)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFFFFD700),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        actions: [
          // Bouton pour l'historique des transactions
          IconButton(
            icon: Icon(Icons.history, color: Color(0xFFFFD700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoriqueEncaissementsPage(userId: widget.userId),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFFFFD700), Colors.black],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading && _showProgress
          ? _buildProgressIndicator()
          : RefreshIndicator(
        onRefresh: _calculerGains,
        color: Color(0xFFFFD700),
        backgroundColor: Colors.black,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderInfo(),
                SizedBox(height: 20),
                _buildCalculButton(),
                SizedBox(height: 25),
                if (_hasCalculated) ...[
                  _buildCarteResume(),
                  SizedBox(height: 20),
                  _buildConfigurationInfo(),
                  SizedBox(height: 25),
                  _buildStatsResume(),
                  SizedBox(height: 25),
                  _buildMotivationSection(),
                  SizedBox(height: 25),
                  _buildGainsActuels(),
                ] else ...[
                  _buildWelcomeMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.date_range, color: Color(0xFFFFD700), size: 30),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Période de calcul',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  _getPeriodeText(),
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '(5 derniers mois)',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculButton() {
    return Container(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _calculerGains,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFFD700),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 10,
          shadowColor: Color(0xFFFFD700).withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isLoading ? Icons.hourglass_empty : Icons.calculate, size: 28),
            SizedBox(width: 10),
            Text(
              _isLoading ? 'CALCUL EN COURS...' : 'CALCULER MES GAINS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    double progress = _totalProgress > 0 ? _currentProgress / _totalProgress : 0;

    return Center(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CALCUL EN COURS',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    strokeWidth: 8,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              '$_currentProgress / $_totalProgress publications',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
              child: Text(
                _currentPostDescription.length > 30
                    ? '${_currentPostDescription.substring(0, 30)}...'
                    : _currentPostDescription,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(FontAwesomeIcons.dollarSign, color: Color(0xFFFFD700), size: 60),
          SizedBox(height: 20),
          Text(
            'Calculez vos gains !',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 15),
          Text(
            'Découvrez combien vous avez gagné avec vos publications des 5 derniers mois.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
          SizedBox(height: 10),
          Text(
            'Chaque ${_config?.nombreVuesParPalier ?? 100} vues = ${_config?.montantParPalier ?? 200} ${_config?.devise ?? 'FCFA'}',
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsResume() {
    var gains = _gainsActuels;
    if (gains == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${gains['postsTraites']}',
            'Publications',
            Icons.post_add,
          ),
          Container(height: 40, width: 1, color: Color(0xFFFFD700).withOpacity(0.3)),
          _buildStatItem(
            '${gains['postsAvecGains']}',
            'Posts gagnants',
            Icons.emoji_events,
          ),
          Container(height: 40, width: 1, color: Color(0xFFFFD700).withOpacity(0.3)),
          _buildStatItem(
            '${gains['totalGains']?.toStringAsFixed(0)}',
            'Gains totaux',
            Icons.monetization_on,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String valeur, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 24),
        SizedBox(height: 4),
        Text(valeur, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _buildCarteResume() {
    if (_gainsActuels == null) return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A1A), Colors.black]),
        boxShadow: [BoxShadow(color: Color(0xFFFFD700).withOpacity(0.2), blurRadius: 20, offset: Offset(0, 5))],
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SOLDE DISPONIBLE', style: TextStyle(color: Colors.grey.shade400, fontSize: 14, letterSpacing: 1)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, color: Color(0xFFFFD700), size: 16),
                      SizedBox(width: 4),
                      Text('5 derniers mois', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${_gainsActuels?['totalGains']?.toStringAsFixed(0) ?? '0'}',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Color(0xFFFFD700).withOpacity(0.3), blurRadius: 15)],
                  ),
                ),
                SizedBox(width: 5),
                Text(_config?.devise ?? 'FCFA', style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _gainsActuels?['totalGains'] > 0 && !_isProcessing ? () => _showEncaissementDialog() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFD700),
                foregroundColor: Colors.black,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
                shadowColor: Color(0xFFFFD700).withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'ENCAISSER MES GAINS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(Icons.remove_red_eye, '${_config?.nombreVuesParPalier}', 'vues ='),
          Container(height: 40, width: 1, color: Color(0xFFFFD700).withOpacity(0.3)),
          _buildInfoItem(Icons.monetization_on, '${_config?.montantParPalier}', _config?.devise ?? 'FCFA'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String valeur, String label) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 20),
        SizedBox(height: 4),
        Text(valeur, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildMotivationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Icon(FontAwesomeIcons.fire, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text(
                'BOOSTE TES GAINS',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ),
        Container(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _motivationMessages.length,
            itemBuilder: (context, index) => _buildMotivationCard(_motivationMessages[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationCard(Map<String, String> message) {
    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 10,
            child: Text(message['icon'] ?? '🔥', style: TextStyle(fontSize: 60, color: Colors.white.withOpacity(0.1))),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(message['title'] ?? '', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(message['message'] ?? '', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGainsActuels() {
    var gainsParPost = _gainsActuels?['gainsParPost'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Icon(FontAwesomeIcons.chartLine, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text(
                'GAINS PAR PUBLICATION',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ),
        if (gainsParPost.isEmpty)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Color(0xFFFFD700).withOpacity(0.1)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 50, color: Colors.grey.shade700),
                  SizedBox(height: 10),
                  Text('Aucun gain disponible', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  SizedBox(height: 5),
                  Text('Publie du contenu pour commencer à gagner !', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ...gainsParPost.map((gain) => _buildGainPostCard(gain)).toList(),
      ],
    );
  }

  Widget _buildGainPostCard(Map<String, dynamic> gain) {
    Post post = gain['post'];

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () {
          if(post.dataType==PostDataType.VIDEO.name){
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoTikTokPageDetails(initialPost: post),
              ),
            );

          }else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsPost(post: post),
              ),
            );

          }
        },
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFFFFD700).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(Icons.post_add, color: Color(0xFFFFD700), size: 25)),
        ),
        title: Text(
          post.description ?? 'Sans description',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.remove_red_eye, size: 14, color: Colors.grey.shade500),
                SizedBox(width: 4),
                Text('${gain['vuesActuelles']} vues', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
            Text(
              'Paliers: ${gain['paliersNonPayes']} disponibles',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('+${gain['montantGagnable']}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(_config?.devise ?? 'FCFA', style: TextStyle(color: Colors.green.shade300, fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // ENCAISSEMENT
  // ============================================

  Future<void> _effectuerEncaissement() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // Afficher le loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700))),
              SizedBox(height: 15),
              Text('Transfert sécurisé en cours...', style: TextStyle(color: Colors.white)),
              SizedBox(height: 5),
              Text('Veuillez patienter', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    // Appel au service avec la nouvelle méthode
    var resultat = await _service.encaisserGains(
      widget.userId,
      _gainsActuels!['gainsParPost'], // Liste des posts avec leurs gains
      _gainsActuels!['totalGains'],   // Montant total
    );

    Navigator.pop(context); // Fermer le loader
    setState(() => _isProcessing = false);

    // Afficher le résultat
    _showResultatDialog(resultat);
  }

  void _showResultatDialog(Map<String, dynamic> resultat) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: resultat['success'] ? Colors.green :
            resultat['code'] == 'ENCAISSEMENT_EN_COURS' ? Color(0xFFFFD700) : Colors.red,
            width: 2,
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resultat['success'] ? Icons.check_circle :
                resultat['code'] == 'ENCAISSEMENT_EN_COURS' ? Icons.hourglass_empty : Icons.error,
                color: resultat['success'] ? Colors.green :
                resultat['code'] == 'ENCAISSEMENT_EN_COURS' ? Color(0xFFFFD700) : Colors.red,
                size: 50,
              ),
              SizedBox(height: 15),
              Text(
                resultat['success'] ? 'TRANSFERT RÉUSSI !' :
                resultat['code'] == 'ENCAISSEMENT_EN_COURS' ? 'TRANSFERT EN COURS' : 'ERREUR',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                resultat['success']
                    ? '${resultat['montant']} ${_config?.devise} ont été crédités sur votre compte principal'
                    : resultat['code'] == 'ENCAISSEMENT_EN_COURS'
                    ? 'Un transfert est déjà en cours. Veuillez patienter quelques instants.'
                    : resultat['error'] ?? 'Une erreur est survenue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400),
              ),
              if (resultat['success']) ...[
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, color: Colors.green, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Transaction sécurisée #${resultat['transactionId'].toString().substring(0, 8)}...',
                        style: TextStyle(color: Colors.green.shade300, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (resultat['success']) {
                    _calculerGains(); // Recalculer après encaissement
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: resultat['success'] ? Colors.green : Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEncaissementDialog() {
    if (_isProcessing) {
      _showMessage('Un encaissement est déjà en cours...');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFFFFD700), size: 60),
              SizedBox(height: 15),
              Text(
                'TRANSFERT VERS COMPTE PRINCIPAL',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text('Montant à transférer', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    SizedBox(height: 8),
                    Text(
                      '${_gainsActuels?['totalGains']?.toStringAsFixed(0) ?? '0'} ${_config?.devise ?? 'FCFA'}',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text('→ Compte principal', style: TextStyle(color: Colors.green, fontSize: 14)),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Transaction sécurisée - Anti-fraude actif',
                        style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.symmetric(vertical: 15)),
                      child: Text('ANNULER'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Fermer le dialogue
                        await _effectuerEncaissement();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('TRANSFÉRER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // PARRAINAGE
  // ============================================

  void _showParrainageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FontAwesomeIcons.gift, color: Color(0xFFFFD700), size: 50),
              SizedBox(height: 15),
              Text('MON CODE DE PARRAINAGE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFFFFD700))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('AFRO2024', style: TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    SizedBox(width: 10),
                    Icon(Icons.copy, color: Color(0xFFFFD700), size: 20),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Partage ton code et gagne 10% des gains de tes filleuls à vie !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareButton(FontAwesomeIcons.whatsapp, Color(0xFF25D366)),
                  _buildShareButton(FontAwesomeIcons.facebook, Color(0xFF1877F2)),
                  _buildShareButton(FontAwesomeIcons.tiktok, Colors.white),
                  _buildShareButton(FontAwesomeIcons.telegram, Color(0xFF0088CC)),
                ],
              ),
              SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton(IconData icon, Color color) {
    return InkWell(
      onTap: () async {
        final url = 'https://afrolook.com/parrainage/AFRO2024';
        if (await canLaunch(url)) await launch(url);
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 25),
      ),
    );
  }
}

// ============================================
// PAGE HISTORIQUE DES ENCAISSEMENTS
// ============================================
class HistoriqueEncaissementsPage extends StatefulWidget {
  final String userId;

  const HistoriqueEncaissementsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _HistoriqueEncaissementsPageState createState() => _HistoriqueEncaissementsPageState();
}

class _HistoriqueEncaissementsPageState extends State<HistoriqueEncaissementsPage> {
  final RemunerationService _service = RemunerationService();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  RemunerationConfig? _config;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    _config = await _service.getActiveConfig();
    _transactions = await _service.getHistoriqueEncaissements(widget.userId);

    setState(() => _isLoading = false);
  }

  String _formatDate(int microseconds) {
    if (microseconds <= 0) return 'Date inconnue';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(
          DateTime.fromMicrosecondsSinceEpoch(microseconds)
      );
    } catch (e) {
      return 'Date invalide';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'HISTORIQUE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFFFFD700),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFFFFD700), Colors.black],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700))))
          : _transactions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FontAwesomeIcons.clock, color: Colors.grey.shade700, size: 60),
            SizedBox(height: 20),
            Text(
              'Aucun encaissement',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              'Vous n\'avez pas encore effectué d\'encaissement',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: Color(0xFFFFD700),
        backgroundColor: Colors.black,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            var tx = _transactions[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.payments, color: Colors.green, size: 24),
                  ),
                ),
                title: Text(
                  '${tx['montant']} ${_config?.devise ?? 'FCFA'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      tx['description'] ?? 'Encaissement',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _formatDate(tx['createdAt'] ?? 0),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    'SUCCÈS',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}