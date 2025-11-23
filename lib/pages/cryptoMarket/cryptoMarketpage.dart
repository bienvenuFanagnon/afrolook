import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/cryptoMarket/portefolioPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/crypto_model.dart';
import '../../providers/authProvider.dart';
import '../../providers/crypto_market_provider.dart';
import 'cryptowidgets/bottom_navigation.dart';
import 'cryptowidgets/crypto_list.dart';
import 'cryptowidgets/featured_cryptos.dart';
import 'cryptowidgets/market_activity.dart';
import 'cryptowidgets/market_overview.dart';
import 'cryptowidgets/trending_cryptos.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_crypto_page.dart';
import 'crypto_form_page.dart';
import 'crypto_detail_page.dart';

class CryptoMarketPage extends StatefulWidget {
  @override
  State<CryptoMarketPage> createState() => _CryptoMarketPageState();
}

class _CryptoMarketPageState extends State<CryptoMarketPage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final List<Map<String, dynamic>> _excitationMessages = [
    {
      'title': '🚀 AFROCOIN EN FORTE HAUSSE !',
      'message': 'L\'AFC a pris +18% cette semaine ! Ne ratez pas l\'opportunité.',
      'icon': Iconsax.trade1,
      'color': Color(0xFF00B894)
    },
    {
      'title': '💎 KORACON VOLATILE !',
      'message': 'La KRC montre une volatilité exceptionnelle. Parfait pour le trading actif !',
      'icon': Iconsax.trade2,
      'color': Color(0xFFFF6B9D)
    },
    {
      'title': '📈 NILOGOLD STABLE ET SÛR',
      'message': 'Le NIG continue sa croissance régulière. Investissement sécurisé !',
      'icon': Iconsax.chart_2,
      'color': Color(0xFFFFD700)
    },
    {
      'title': '🔥 SAVANNAH TOKEN COMMUNATAIRE',
      'message': 'Le SVT explose grâce à l\'activité de la communauté AfroLook !',
      'icon': Iconsax.people,
      'color': Color(0xFF43E97B)
    },
    {
      'title': '💰 TIMBUKTU DOLLAR PREMIUM',
      'message': 'Le TBD reste la valeur refuge du marché. Stabilité garantie !',
      'icon': Iconsax.shield_tick,
      'color': Color(0xFF667EEA)
    },
    {
      'title': '🌟 DIVERSIFIEZ VOTRE PORTEFEUILLE',
      'message': '5 cryptos africaines uniques pour maximiser vos gains !',
      'icon': Iconsax.wallet_3,
      'color': Color(0xFFFA709A)
    }
  ];

  final List<Map<String, dynamic>> _activityMessages = [
    {
      'user': 'Fatou D.',
      'action': 'a acheté',
      'amount': '150 AFC',
      'profit': '25,000',
      'product': 'AfroCoin',
      'type': 'buy'
    },
    {
      'user': 'Mohamed K.',
      'action': 'a vendu',
      'amount': '75 KRC',
      'profit': '18,500',
      'product': 'KoraCoin',
      'type': 'sell'
    },
    {
      'user': 'Amina S.',
      'action': 'a investi sur',
      'amount': '50 NIG',
      'profit': '32,000',
      'product': 'NiloGold',
      'type': 'buy'
    },
    {
      'user': 'Jean-Paul M.',
      'action': 'a réalisé un profit de',
      'amount': '200 SVT',
      'profit': '45,000',
      'product': 'Savannah Token',
      'type': 'sell'
    },
    {
      'user': 'Binta T.',
      'action': 'vient d\'acquérir',
      'amount': '100 TBD',
      'profit': '28,000',
      'product': 'Timbuktu Dollar',
      'type': 'buy'
    },
    {
      'user': 'Koffi A.',
      'action': 'a doublé son investissement sur',
      'amount': '80 AFC',
      'profit': '15,000',
      'product': 'AfroCoin',
      'type': 'buy'
    },
    {
      'user': 'Sophie L.',
      'action': 'a vendu avec succès',
      'amount': '120 KRC',
      'profit': '22,000',
      'product': 'KoraCoin',
      'type': 'sell'
    },
    {
      'user': 'Omar D.',
      'action': 'a acheté rapidement',
      'amount': '90 NIG',
      'profit': '12,500',
      'product': 'NiloGold',
      'type': 'buy'
    },
    {
      'user': 'Grace M.',
      'action': 'a réalisé un gain sur',
      'amount': '180 SVT',
      'profit': '38,000',
      'product': 'Savannah Token',
      'type': 'sell'
    },
    {
      'user': 'David K.',
      'action': 'vient d\'investir dans',
      'amount': '60 TBD',
      'profit': '9,500',
      'product': 'Timbuktu Dollar',
      'type': 'buy'
    },
    {
      'user': 'Isabelle R.',
      'action': 'a gagné sur',
      'amount': '110 AFC',
      'profit': '19,000',
      'product': 'AfroCoin',
      'type': 'sell'
    },
    {
      'user': 'Moussa C.',
      'action': 'a acheté en gros',
      'amount': '95 KRC',
      'profit': '14,200',
      'product': 'KoraCoin',
      'type': 'buy'
    }
  ];

  bool _showWelcomeModal = true;
  bool _acceptedTerms = false;
  int _currentActivityIndex = 0;
  int _currentExcitationIndex = 0;
  List<Map<String, dynamic>> _displayedFeaturedCryptos = [];

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    _startActivityRotation();
    _startExcitationRotation();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final marketProvider = Provider.of<CryptoMarketProvider>(context, listen: false);
      marketProvider.fetchCryptos();
      marketProvider.fetchPortfolio();
    });
  }

  void _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenModal = prefs.getBool('hasSeenCryptoModal') ?? false;
    bool hasAcceptedTerms = prefs.getBool('acceptedCryptoTerms') ?? false;

    setState(() {
      _showWelcomeModal = !hasSeenModal;
      _acceptedTerms = hasAcceptedTerms;
    });
  }

  void _startActivityRotation() {
    Future.delayed(Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _currentActivityIndex = (_currentActivityIndex + 1) % _activityMessages.length;
        });
        _startActivityRotation();
      }
    });
  }

  void _startExcitationRotation() {
    Future.delayed(Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _currentExcitationIndex = (_currentExcitationIndex + 1) % _excitationMessages.length;
        });
        _startExcitationRotation();
      }
    });
  }

  void _updateFeaturedCryptos(List<CryptoCurrency> cryptos) {
    final availableCryptos = List.from(cryptos);
    _displayedFeaturedCryptos = availableCryptos.take(3).map((crypto) {
      return {
        'crypto': crypto,
        'reason': _getRandomFeatureReason(crypto.name),
        'trend': crypto.dailyPriceChange >= 0 ? 'up' : 'down'
      };
    }).toList();
  }

  String _getRandomFeatureReason(String cryptoName) {
    final reasons = [
      'Demande internationale croissante',
      'Technologie blockchain innovante',
      'Adoption massive en Afrique',
      'Partenariats stratégiques signés',
      'Roadmap de développement ambitieuse',
      'Communauté très active',
      'Utility token à fort potentiel',
      'Écosystème en expansion'
    ];
    return reasons[DateTime.now().millisecondsSinceEpoch % reasons.length];
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Conditions d\'Utilisation - Marché Crypto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Avant de commencer à trader sur Afrocoin Market, veuillez lire et accepter nos conditions :',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              SizedBox(height: 16),
              _buildTermPoint('✓ Trading de cryptomonnaies virtuelles internes'),
              _buildTermPoint('✓ Volatilité des prix basée sur l\'algorithme de marché'),
              _buildTermPoint('✓ Possibilité de gains et de pertes virtuelles'),
              _buildTermPoint('✓ Investissement dans l\'écosystème AfroLook'),
              _buildTermPoint('✓ Transactions sécurisées et transparentes'),
              _buildTermPoint('✓ Respect des règles de la communauté'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF00B894).withOpacity(0.3)),
                ),
                child: Text(
                  'En acceptant, vous reconnaissez comprendre les risques et opportunités du trading crypto virtuel.',
                  style: TextStyle(
                    color: Color(0xFF00B894),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'REFUSER',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('acceptedCryptoTerms', true);
              setState(() {
                _acceptedTerms = true;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B894),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'ACCEPTER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.tick_circle, color: Color(0xFF00B894), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPortfolioBeforeAction(
      Function action, {
        bool forceRefresh = false,
        bool showLoading = true,
      }) async {
    final marketProvider = Provider.of<CryptoMarketProvider>(context, listen: false);

    // Afficher un indicateur de chargement si demandé
    if (showLoading) {
      _showLoadingDialog();
    }

    try {
      // Vérification et rafraîchissement si nécessaire
      if (forceRefresh || marketProvider.portfolio == null) {
        await marketProvider.fetchPortfolio();
      }

      // Fermer le loading
      if (showLoading && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Vérification finale
      if (marketProvider.portfolio == null) {
        _showCreatePortfolioDialog();
        return;
      }

      // Exécuter l'action
      action();

    } catch (e) {
      // Fermer le loading en cas d'erreur
      if (showLoading && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showErrorDialog('Erreur de vérification: ${e.toString()}');
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF00B894)),
            SizedBox(width: 16),
            Text(
              'Vérification du portefeuille...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        title: Text(
          'Erreur',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFF00B894))),
          ),
        ],
      ),
    );
  }

  void _showCreatePortfolioDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Iconsax.wallet_add, color: Color(0xFF00B894)),
            SizedBox(width: 8),
            Text(
              'Portefeuille Requis',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Vous devez créer un portefeuille pour commencer à trader. Voulez-vous créer un portefeuille?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'PLUS TARD',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CryptoPortfolioPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B894),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'CRÉER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F111C),
      body: Stack(
        children: [
          _buildMainContent(),
          if (_showWelcomeModal) _buildWelcomeModal(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<CryptoMarketProvider>(
      builder: (context, marketProvider, child) {
        if (marketProvider.isLoading && marketProvider.cryptos.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF00B894)),
          );
        }

        if (marketProvider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.warning_2, color: Colors.red, size: 50),
                SizedBox(height: 16),
                Text(
                  marketProvider.errorMessage,
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    marketProvider.fetchCryptos();
                    marketProvider.fetchPortfolio();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B894),
                  ),
                  child: Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        // Mettre à jour les cryptos en vedette
        _updateFeaturedCryptos(marketProvider.cryptos);

        return RefreshIndicator(
          onRefresh: () async {
            await marketProvider.fetchCryptos();
            await marketProvider.fetchPortfolio();
          },
          backgroundColor: Color(0xFF0F111C),
          color: Color(0xFF00B894),
          child: CustomScrollView(
            slivers: [
              // AppBar personnalisée
              SliverAppBar(
                backgroundColor: Color(0xFF0F111C),
                elevation: 0,
                pinned: true,
                title: Text(
                  'Afrocoin Market',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                actions: [
                  // Bouton d'aide
                  IconButton(
                    icon: Icon(Iconsax.info_circle, color: Colors.white),
                    onPressed: _showWelcomeModalDialog,
                  ),
                  // Bouton portefeuille
                  IconButton(
                    icon: Icon(Iconsax.wallet_3, color: Colors.white),
                    onPressed: () {
                      if (!_acceptedTerms) {
                        _showTermsAndConditions();
                        return;
                      }
                      _checkPortfolioBeforeAction(() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CryptoPortfolioPage()),
                        );
                      });
                    },
                  ),
                  // Bouton admin (seulement pour les ADM)
                  Consumer<CryptoMarketProvider>(
                    builder: (context, marketProvider, child) {
                      // Vérifier si l'utilisateur est admin
                      // final isAdmin = marketProvider.isAdmin; // À implémenter dans le provider
                      final isAdmin = authProvider.loginUserData.role==UserRole.ADM.name; // À implémenter dans le provider
                      if (isAdmin) {
                        return IconButton(
                          icon: Icon(Iconsax.shield_tick, color: Color(0xFF00B894)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminCryptoPage()),
                            );
                          },
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ],
              ),

              // Bannière d'excitation
              SliverToBoxAdapter(
                child: _buildExcitationBanner(),
              ),

              // Activités récentes
              SliverToBoxAdapter(
                child: _buildActivityFeed(),
              ),

              // Cryptos en vedette
              if (_displayedFeaturedCryptos.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildFeaturedCryptosSection(),
                ),

              // Cryptos tendances
              if (marketProvider.trendingCryptos.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildTrendingSection(marketProvider.trendingCryptos),
                ),

              // Toutes les cryptos
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final crypto = marketProvider.cryptos[index];
                      return _buildCryptoListItem(crypto);
                    },
                    childCount: marketProvider.cryptos.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExcitationBanner() {
    final message = _excitationMessages[_currentExcitationIndex];

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            message['color'],
            message['color'].withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: message['color'].withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(message['icon'], color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message['title'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            message['message'],
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),

                onTap: () {
                  if (!_acceptedTerms) {
                    _showTermsAndConditions();
                    return;
                  }
                  _checkPortfolioBeforeAction(() {
                    _showCryptoSelection();
                  });
                },
                child: Center(
                  child: Text(
                    'INVESTIR MAINTENANT',
                    style: TextStyle(
                      color: message['color'],
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    final activity = _activityMessages[_currentActivityIndex];
    final isBuy = activity['type'] == 'buy';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A3649)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isBuy ? Color(0xFF00B894).withOpacity(0.2) : Color(0xFFFF6B9D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                isBuy ? Iconsax.arrow_down : Iconsax.arrow_up_3,
                color: isBuy ? Color(0xFF00B894) : Color(0xFFFF6B9D),
                size: 16,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${activity['user']} ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: '${activity['action']} ',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: '${activity['amount']} ',
                    style: TextStyle(
                      color: isBuy ? Color(0xFF00B894) : Color(0xFFFF6B9D),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: 'de ${activity['product']}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${activity['profit']} FCFA',
                style: TextStyle(
                  color: Color(0xFF00B894),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                'Profit',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCryptosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Iconsax.star_1, color: Color(0xFFFFD700)),
              SizedBox(width: 8),
              Text(
                'CRYPTO EN VEDETTE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _displayedFeaturedCryptos.length,
            itemBuilder: (context, index) {
              final feature = _displayedFeaturedCryptos[index];
              return _buildFeaturedCryptoCard(feature);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCryptoCard(Map<String, dynamic> feature) {
    final crypto = feature['crypto'] as CryptoCurrency;
    final reason = feature['reason'] as String;
    final trend = feature['trend'] as String;

    return GestureDetector(
      onTap: () {
        if (!_acceptedTerms) {
          _showTermsAndConditions();
          return;
        }
        _checkPortfolioBeforeAction(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CryptoDetailPage(cryptoId: crypto.id)),
          );
        });
      },
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A202C),
              Color(0xFF131A26),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF00B894).withOpacity(0.3)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFF00B894).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Iconsax.star_1, color: Color(0xFF00B894), size: 16),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      crypto.symbol,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                crypto.name,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                reason,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trend == 'up' ? Color(0xFF00B894).withOpacity(0.2) : Color(0xFFFF4D4D).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trend == 'up' ? '📈 HAUSSE' : '📉 BAISSE',
                      style: TextStyle(
                        color: trend == 'up' ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildTrendingSection(List<CryptoCurrency> trendingCryptos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Iconsax.trend_up, color: Color(0xFFFF6B9D)),
              SizedBox(width: 8),
              Text(
                'CRYPTO TENDANCES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: trendingCryptos.length,
            itemBuilder: (context, index) {
              final crypto = trendingCryptos[index];
              return _buildTrendingCryptoCard(crypto);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCryptoCard(CryptoCurrency crypto) {
    final isPositive = crypto.dailyPriceChange >= 0;

    return GestureDetector(
      onTap: () {
        if (!_acceptedTerms) {
          _showTermsAndConditions();
          return;
        }
        _checkPortfolioBeforeAction(() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CryptoDetailPage(cryptoId: crypto.id)),
          );
        });
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A202C),
              Color(0xFF131A26),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFFF6B9D).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              crypto.symbol,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              crypto.name,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(
                  isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                  color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  '${(crypto.dailyPriceChange * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoListItem(CryptoCurrency crypto) {
    final isPositive = crypto.dailyPriceChange >= 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A202C).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!_acceptedTerms) {
              _showTermsAndConditions();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CryptoDetailPage(cryptoId: crypto.id)),
            );
            // _checkPortfolioBeforeAction(() {
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (context) => CryptoDetailPage(cryptoId: crypto.id)),
            //   );
            // });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo/Emoji
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF2A3649),
                  ),
                  child: Center(
                    child: Text(
                      _getCryptoEmoji(crypto.symbol),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Infos crypto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crypto.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        crypto.symbol,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF00B894).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Color(0xFF00B894).withOpacity(0.3)),
                        ),
                        child: Text(
                          crypto.category,
                          style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Prix et variation
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive ? Color(0xFF00B894).withOpacity(0.2) : Color(0xFFFF4D4D).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                            color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${(crypto.dailyPriceChange * 100).toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCryptoEmoji(String symbol) {
    switch (symbol) {
      case 'AFC': return '🪙'; // AfroCoin
      case 'KRC': return '⚡'; // KoraCoin
      case 'NIG': return '🏺'; // NiloGold
      case 'SVT': return '🌍'; // Savannah Token
      case 'TBD': return '💎'; // Timbuktu Dollar
      default: return '🪙';
    }
  }

  void _showCryptoSelection() {
    final marketProvider = Provider.of<CryptoMarketProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A202C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisissez une crypto pour investir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Sélectionnez la cryptomonnaie sur laquelle vous souhaitez investir :',
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: marketProvider.cryptos.length,
                itemBuilder: (context, index) {
                  final crypto = marketProvider.cryptos[index];
                  return _buildCryptoSelectionItem(crypto);
                },
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context),
                  child: Center(
                    child: Text(
                      'ANNULER',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoSelectionItem(CryptoCurrency crypto) {
    final isPositive = crypto.dailyPriceChange >= 0;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF2A3649),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CryptoDetailPage(cryptoId: crypto.id)),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF1A202C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _getCryptoEmoji(crypto.symbol),
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crypto.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        crypto.symbol,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${crypto.currentPrice.toStringAsFixed(2)} FCFA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                          color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${(crypto.dailyPriceChange * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Color(0xFF00B894) : Color(0xFFFF4D4D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeModal() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A202C),
                  Color(0xFF131A26),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Color(0xFF00B894)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '🪙 Bienvenue sur Afrocoin Market',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Iconsax.close_circle, color: Colors.grey[400]),
                      onPressed: () {
                        setState(() {
                          _showWelcomeModal = false;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _buildModalFeature(
                  Iconsax.coin,
                  'Marché Crypto Africain',
                  'Tradez 5 cryptomonnaies uniques inspirées de la richesse culturelle africaine',
                ),
                _buildModalFeature(
                  Iconsax.trend_up,
                  'Opportunités de Trading',
                  'Profitez de la volatilité et de la croissance des cryptos AfroLook',
                ),
                _buildModalFeature(
                  Iconsax.security_safe,
                  'Écosystème Sécurisé',
                  'Transactions transparentes dans l\'écosystème AfroLook',
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Checkbox(
                      value: !_showWelcomeModal,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hasSeenCryptoModal', true);
                        setState(() {
                          _showWelcomeModal = false;
                        });
                      },
                      fillColor: MaterialStateProperty.all(Color(0xFF00B894)),
                    ),
                    Expanded(
                      child: Text(
                        'Ne plus afficher ce message',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (!_acceptedTerms) {
                          _showTermsAndConditions();
                        }
                        setState(() {
                          _showWelcomeModal = false;
                        });
                      },
                      child: Center(
                        child: Text(
                          'DÉCOUVRIR LE MARCHÉ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalFeature(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFF00B894), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWelcomeModalDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildWelcomeModalContent(),
      ),
    );
  }

  Widget _buildWelcomeModalContent() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A202C),
            Color(0xFF131A26),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Color(0xFF00B894)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle, color: Color(0xFF00B894)),
              SizedBox(width: 8),
              Text(
                'À propos d\'Afrocoin Market',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Plateforme de trading de cryptomonnaies virtuelles inspirées de la culture africaine :',
            style: TextStyle(color: Colors.grey[400]),
          ),
          SizedBox(height: 12),
          _buildInfoPoint('• 5 cryptomonnaies uniques avec différentes dynamiques'),
          _buildInfoPoint('• AfroCoin (AFC) - Stable et progressive'),
          _buildInfoPoint('• KoraCoin (KRC) - Volatile pour traders actifs'),
          _buildInfoPoint('• NiloGold (NIG) - Précieuse et rare'),
          _buildInfoPoint('• Savannah Token (SVT) - Communautaire'),
          _buildInfoPoint('• Timbuktu Dollar (TBD) - Premium et stable'),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF00B894).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF00B894).withOpacity(0.3)),
            ),
            child: Text(
              'Rejoignez la communauté des traders AfroLook !',
              style: TextStyle(
                color: Color(0xFF00B894),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.arrow_right, color: Color(0xFF00B894), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300]),
            ),
          ),
        ],
      ),
    );
  }
}