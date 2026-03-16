import 'package:afrotok/pages/UserServices/detailsUserService.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/postProvider.dart';
import '../component/consoleWidget.dart';
import '../component/showUserDetails.dart';
import 'newUserService.dart';

import 'package:cached_network_image/cached_network_image.dart';

class UserServiceListPage extends StatefulWidget {
  @override
  State<UserServiceListPage> createState() => _UserServiceListPageState();
}

class _UserServiceListPageState extends State<UserServiceListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingMore = false;
  bool _showFilters = false;
  bool _isInitialLoad = true;
  bool _isLoadingServices = false;
  bool _isNavigatingToDetail = false; // Pour éviter les doubles navigations

  @override
  void initState() {
    super.initState();
    _initializeWithUserCountry();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Initialisation avec le pays de l'utilisateur
  Future<void> _initializeWithUserCountry() async {
    setState(() {
      _isInitialLoad = true;
      _isLoadingServices = true;
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // Récupérer le code du pays de l'utilisateur
      final userCountryCode = authProvider.loginUserData?.countryData?['countryCode'] ?? 'TG';

      // Obtenir le nom complet du pays à partir du code
      final userCountry = _getCountryNameFromCode(userCountryCode);

      if (userCountry.isNotEmpty) {
        print('🌍 Filtrage par pays utilisateur: $userCountry ($userCountryCode)');

        // Appliquer le filtre par pays
        await postProvider.getUserServices(
          country: userCountry,
          fromUserCountry: true, // Nouveau paramètre pour indiquer que c'est un filtre par pays utilisateur
        );

        // Si aucun service trouvé pour son pays, recharger sans filtre
        if (postProvider.userServices.isEmpty) {
          print('⚠️ Aucun service trouvé pour le pays $userCountry, chargement sans filtre');
           postProvider.resetServicePagination();
          await postProvider.getUserServices();
        }
      } else {
        // Si pas de pays trouvé, charger normalement
        await postProvider.getUserServices();
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      // En cas d'erreur, charger normalement
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      await postProvider.getUserServices();
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoadingServices = false;
        });
      }
    }
  }

  // Convertir le code pays en nom complet
  String _getCountryNameFromCode(String countryCode) {
    final countryMap = {
      'BJ': 'Bénin',
      'TG': 'Togo',
      'GH': 'Ghana',
      'NG': 'Nigeria',
      'CI': 'Côte d\'Ivoire',
      'SN': 'Sénégal',
      'CM': 'Cameroun',
      'CG': 'Congo',
      'GA': 'Gabon',
      'ML': 'Mali',
      'BF': 'Burkina Faso',
      'NE': 'Niger',
      'TD': 'Tchad',
      'RW': 'Rwanda',
      'BI': 'Burundi',
      'KE': 'Kenya',
      'TZ': 'Tanzanie',
      'UG': 'Ouganda',
      'ET': 'Éthiopie',
      'SO': 'Somalie',
      'MA': 'Maroc',
      'DZ': 'Algérie',
      'TN': 'Tunisie',
      'EG': 'Égypte',
      'SD': 'Soudan',
      'ZA': 'Afrique du Sud',
      'AO': 'Angola',
      'MZ': 'Mozambique',
      'ZM': 'Zambie',
      'ZW': 'Zimbabwe',
    };
    return countryMap[countryCode] ?? '';
  }

  void _loadInitialServices() {
    // Cette méthode n'est plus utilisée car nous avons _initializeWithUserCountry
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreServices();
    }
  }

  void _loadMoreServices() async {
    if (_isLoadingMore) return;

    final postProvider = Provider.of<PostProvider>(context, listen: false);
    if (!postProvider.hasMoreServices || postProvider.isLoadingServices) return;

    setState(() {
      _isLoadingMore = true;
    });

    await postProvider.getUserServices(loadMore: true);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _performSearch() {
    setState(() {
      _isLoadingServices = true;
    });

    final postProvider = Provider.of<PostProvider>(context, listen: false);
    postProvider.getUserServices(searchQuery: _searchController.text.trim()).then((_) {
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
        });
      }
    });
  }

  void _applyFilters({
    String? category,
    String? country,
    String? city,
  }) {
    setState(() {
      _isLoadingServices = true;
    });

    final postProvider = Provider.of<PostProvider>(context, listen: false);
    postProvider.getUserServices(
      category: category,
      country: country,
      city: city,
      searchQuery: _searchController.text.trim(),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
        });
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _isLoadingServices = true;
      _showFilters = false;
    });

    _searchController.clear();
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    postProvider.resetServicePagination();

    // Revenir au filtre par pays utilisateur si disponible
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userCountryCode = authProvider.loginUserData?.countryData?['countryCode'] ?? 'TG';
    final userCountry = _getCountryNameFromCode(userCountryCode);

    if (userCountry.isNotEmpty) {
      postProvider.getUserServices(country: userCountry).then((_) {
        if (postProvider.userServices.isEmpty) {
          // Si aucun service trouvé pour son pays, recharger sans filtre
          postProvider.resetServicePagination();
          postProvider.getUserServices().then((_) {
            if (mounted) {
              setState(() {
                _isLoadingServices = false;
              });
            }
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingServices = false;
            });
          }
        }
      });
    } else {
      postProvider.getUserServices().then((_) {
        if (mounted) {
          setState(() {
            _isLoadingServices = false;
          });
        }
      });
    }
  }

  Future<void> launchWhatsApp(String phone, UserServiceData data, String urlService) async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        );
      },
    );

    String url = "whatsapp://send?phone=" + phone + "&text="
        + "Bonjour *${data.user!.nom!}*,\n\n"
        + "Je m'appelle *@${Provider.of<UserAuthProvider>(context, listen: false).loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
        + "Je vous contacte concernant votre service :\n\n"
        + "*Titre* : *${data.titre!.toUpperCase()}*\n"
        + "*Description* : *${data.description}*\n\n"
        + "Je suis très intéressé(e) par ce que vous proposez et j'aimerais en savoir plus.\n"
        + "Vous pouvez voir le service ici : ${urlService}\n\n"
        + "Merci et à bientôt !";

    try {
      if (!await launchUrl(Uri.parse(url))) {
        Navigator.pop(context); // Fermer le dialogue de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 2),
            content: Text(
              "Impossible d'ouvrir WhatsApp",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
        throw Exception('Impossible d\'ouvrir WhatsApp');
      } else {
        // Incrémenter le compteur WhatsApp
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

        await postProvider.getUserServiceById(data.id!).then((value) async {
          if (value.isNotEmpty) {
            data = value.first;
            data.contactWhatsapp = (data.contactWhatsapp ?? 0) + 1;

            if (!_isIn(data.usersContactId!, authProvider.loginUserData.id!)) {
              data.usersContactId!.add(authProvider.loginUserData.id!);
            }

            await postProvider.updateUserService(data, context);
          }
        });

        Navigator.pop(context); // Fermer le dialogue de chargement
      }
    } catch (e) {
      Navigator.pop(context); // Fermer le dialogue de chargement en cas d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            "Erreur lors de l'ouverture de WhatsApp",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  bool _isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  void _navigateToDetail(UserServiceData service) async {
    if (_isNavigatingToDetail) return; // Éviter les doubles clics

    setState(() {
      _isNavigatingToDetail = true;
    });

    // Afficher un loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        );
      },
    );

    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    try {
      await postProvider.getUserServiceById(service.id!).then((value) async {
        if (value.isNotEmpty) {
          service = value.first;
          service.vues = (service.vues ?? 0) + 1;

          if (!_isIn(service.usersViewId!, authProvider.loginUserData.id!)) {
            service.usersViewId!.add(authProvider.loginUserData.id!);
          }

          await postProvider.updateUserService(service, context);

          Navigator.pop(context); // Fermer le dialogue de chargement

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailUserServicePage(data: service),
            ),
          ).then((_) {
            setState(() {
              _isNavigatingToDetail = false;
            });
          });
        } else {
          Navigator.pop(context); // Fermer le dialogue de chargement
          setState(() {
            _isNavigatingToDetail = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Service non trouvé"),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      Navigator.pop(context); // Fermer le dialogue de chargement en cas d'erreur
      setState(() {
        _isNavigatingToDetail = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du chargement du service"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);

    // Afficher un loader pendant l'initialisation
    if (_isInitialLoad) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            'Services & Jobs 🛠️',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 16),
              Text(
                'Chargement des services...',
                style: TextStyle(color: Colors.yellow),
              ),
              SizedBox(height: 8),
              Text(
                'Recherche dans votre pays',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Services & Jobs 🛠️',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.yellow),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.yellow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserServiceForm()),
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '🔍 Rechercher services, villes, métiers...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.green),
                    onPressed: _performSearch,
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
          ),

          // Filtres
          if (_showFilters) _buildFiltersSection(postProvider),

          // Indication du filtre actif
          if (postProvider.selectedCountry != null && !_showFilters)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.green.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Filtre actif: ${postProvider.selectedCountry}',
                      style: TextStyle(color: Colors.yellow, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),

          // Indicateur de chargement global
          if (_isLoadingServices)
            LinearProgressIndicator(
              backgroundColor: Colors.grey[900],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),

          // Contenu principal
          Expanded(
            child: _isLoadingServices && postProvider.userServices.isEmpty
                ? _buildFullPageLoader()
                : postProvider.userServices.isEmpty && !_isLoadingServices
                ? _buildEmptyState()
                : _buildServicesGrid(authProvider, postProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(PostProvider postProvider) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.green)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Catégorie',
                  items: ServiceConstants.categories,
                  value: postProvider.selectedCategory,
                  onChanged: (value) => _applyFilters(category: value),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Pays',
                  items: ServiceConstants.africanCountries,
                  value: postProvider.selectedCountry,
                  onChanged: (value) => _applyFilters(country: value),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FutureBuilder<List<String>>(
            future: postProvider.getServiceCities(),
            builder: (context, snapshot) {
              final cities = snapshot.data ?? [];
              return _buildFilterDropdown(
                label: 'Ville',
                items: cities,
                value: postProvider.selectedCity,
                onChanged: (value) => _applyFilters(city: value),
              );
            },
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.yellow,
                    side: BorderSide(color: Colors.yellow),
                  ),
                  child: Text('EFFACER'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() { _showFilters = false; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                  ),
                  child: Text('APPLIQUER'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.yellow, fontSize: 12),
        ),
        SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: Colors.white, fontSize: 12),
            icon: Icon(Icons.arrow_drop_down, color: Colors.yellow, size: 16),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Tous', style: TextStyle(color: Colors.grey)),
              ),
              ...items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildFullPageLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des services...',
            style: TextStyle(color: Colors.yellow),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final postProvider = Provider.of<PostProvider>(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final userCountry = authProvider.loginUserData?.countryData?['countryCode'] ?? 'TG';
    final userCountryName = _getCountryNameFromCode(userCountry);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              postProvider.selectedCountry != null
                  ? 'Aucun service trouvé pour ${postProvider.selectedCountry}'
                  : 'Aucun service trouvé',
              style: TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              postProvider.selectedCountry != null && postProvider.selectedCountry == userCountryName
                  ? 'Aucun service disponible dans votre pays pour le moment.\nAffichage de tous les services...'
                  : 'Essayez de modifier vos filtres ou créez votre propre service',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (postProvider.selectedCountry != null) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                ),
                child: Text('VOIR TOUS LES SERVICES'),
              ),
            ],
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserServiceForm()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
              ),
              child: Text('CRÉER UN SERVICE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid(UserAuthProvider authProvider, PostProvider postProvider) {
    return Column(
      children: [
        // Compteur de résultats avec indication du filtre
        if (postProvider.userServices.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${postProvider.userServices.length} service(s) trouvé(s)',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
                if (postProvider.selectedCountry != null ||
                    postProvider.selectedCategory != null ||
                    postProvider.selectedCity != null)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Text(
                      'Effacer les filtres',
                      style: TextStyle(color: Colors.yellow, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

        // Grille des services
        Expanded(
          child: RefreshIndicator(
            backgroundColor: Colors.green,
            color: Colors.yellow,
            onRefresh: () async {
              setState(() {
                _isLoadingServices = true;
              });

              final postProvider = Provider.of<PostProvider>(context, listen: false);
              await postProvider.getUserServices();

              if (mounted) {
                setState(() {
                  _isLoadingServices = false;
                });
              }
            },
            child: GridView.builder(
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              padding: EdgeInsets.all(8),
              itemCount: postProvider.userServices.length + 1,
              itemBuilder: (context, index) {
                if (index == postProvider.userServices.length) {
                  return _buildLoadMoreIndicator();
                }
                return ServiceGridCard(
                  service: postProvider.userServices[index],
                  authProvider: authProvider,
                  onTap: () => _navigateToDetail(postProvider.userServices[index]),
                  onContact: (service) async {
                    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
                    await authProvider.createServiceLink(true, service).then((url) async {
                      await launchWhatsApp(service.contact!, service, url);
                    });
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    return _isLoadingMore
        ? Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.yellow, fontSize: 12),
            ),
          ],
        ),
      ),
    )
        : SizedBox();
  }
}

class ServiceGridCard extends StatelessWidget {
  final UserServiceData service;
  final UserAuthProvider authProvider;
  final VoidCallback onTap;
  final Function(UserServiceData) onContact;

  const ServiceGridCard({
    Key? key,
    required this.service,
    required this.authProvider,
    required this.onTap,
    required this.onContact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasValidImage = service.imageCourverture != null &&
        service.imageCourverture!.isNotEmpty &&
        service.imageCourverture!.startsWith('http');

    final hasLocation = (service.city != null && service.city!.isNotEmpty) ||
        (service.country != null && service.country!.isNotEmpty);
    final hasCategory = service.category != null && service.category != 'Autre';

    return Container(
      margin: EdgeInsets.all(4),
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 3,
        shadowColor: Colors.green.withOpacity(0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION IMAGE AVEC OVERLAY
                Stack(
                  children: [
                    // Image principale avec gradient overlay
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasValidImage
                            ? CachedNetworkImage(
                          imageUrl: service.imageCourverture!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildImagePlaceholder(),
                          errorWidget: (context, url, error) => _buildImagePlaceholder(),
                        )
                            : _buildImagePlaceholder(),
                      ),
                    ),

                    // Gradient overlay pour le texte
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.95),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Titre superposé sur l'image
                    Positioned(
                      bottom: 28,
                      left: 6,
                      right: 6,
                      child: Text(
                        service.titre ?? 'Service',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Badge pays en haut à gauche
                    if (service.country != null && service.country!.isNotEmpty)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getCountryFlag(service.country!),
                                style: TextStyle(fontSize: 8),
                              ),
                              SizedBox(width: 2),
                              Text(
                                _getCountryAbbreviation(service.country!),
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 6,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Bouton WhatsApp en haut à droite
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onContact(service),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            FontAwesome.whatsapp,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 6),

                // SECTION STATS COMPACTES
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCompactStat(Icons.remove_red_eye, service.vues ?? 0, 'Vues'),
                      _buildCompactStat(FontAwesome.whatsapp, service.contactWhatsapp ?? 0, 'Contacts'),
                      _buildCompactStat(FontAwesome.heart, service.like ?? 0, 'Likes'),
                    ],
                  ),
                ),
                SizedBox(height: 5,),

                // SECTION INFOS LOCALISATION ET CATÉGORIE
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catégorie
                    if (hasCategory)
                      Container(
                        margin: EdgeInsets.only(bottom: 2),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.category!,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Localisation
                    if (hasLocation)
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green, size: 8),
                          SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              _getLocationText(),
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, color: Colors.green, size: 30),
            SizedBox(height: 4),
            Text(
              'SERVICE',
              style: TextStyle(
                color: Colors.green,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green, size: 8),
            SizedBox(width: 2),
            Text(
              _formatCount(count),
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 6,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}K';
    if (count < 1000000) return '${(count ~/ 1000)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _getLocationText() {
    if (service.city != null && service.country != null) {
      return '${service.city!}, ${service.country!}';
    } else if (service.city != null) {
      return service.city!;
    } else if (service.country != null) {
      return service.country!;
    }
    return '';
  }

  String _getCountryAbbreviation(String country) {
    final abbreviations = {
      'Bénin': 'BJ',
      'Togo': 'TG',
      'Ghana': 'GH',
      'Nigeria': 'NG',
      'Côte d\'Ivoire': 'CI',
      'Sénégal': 'SN',
      'Cameroun': 'CM',
      'Congo': 'CG',
      'Gabon': 'GA',
      'Mali': 'ML',
      'Burkina Faso': 'BF',
      'Niger': 'NE',
      'Tchad': 'TD',
      'Rwanda': 'RW',
      'Burundi': 'BI',
      'Kenya': 'KE',
      'Tanzanie': 'TZ',
      'Ouganda': 'UG',
      'Éthiopie': 'ET',
      'Somalie': 'SO',
      'Maroc': 'MA',
      'Algérie': 'DZ',
      'Tunisie': 'TN',
      'Égypte': 'EG',
      'Soudan': 'SD',
      'Afrique du Sud': 'ZA',
      'Angola': 'AO',
      'Mozambique': 'MZ',
      'Zambie': 'ZM',
      'Zimbabwe': 'ZW',
    };

    return abbreviations[country] ?? country.substring(0, 2).toUpperCase();
  }

  String _getCountryFlag(String country) {
    final flagEmojis = {
      'Bénin': '🇧🇯',
      'Togo': '🇹🇬',
      'Ghana': '🇬🇭',
      'Nigeria': '🇳🇬',
      'Côte d\'Ivoire': '🇨🇮',
      'Sénégal': '🇸🇳',
      'Cameroun': '🇨🇲',
      'Congo': '🇨🇬',
      'Gabon': '🇬🇦',
      'Mali': '🇲🇱',
      'Burkina Faso': '🇧🇫',
      'Niger': '🇳🇪',
      'Tchad': '🇹🇩',
      'Rwanda': '🇷🇼',
      'Burundi': '🇧🇮',
      'Kenya': '🇰🇪',
      'Tanzanie': '🇹🇿',
      'Ouganda': '🇺🇬',
      'Éthiopie': '🇪🇹',
      'Somalie': '🇸🇴',
      'Maroc': '🇲🇦',
      'Algérie': '🇩🇿',
      'Tunisie': '🇹🇳',
      'Égypte': '🇪🇬',
      'Soudan': '🇸🇩',
      'Afrique du Sud': '🇿🇦',
      'Angola': '🇦🇴',
      'Mozambique': '🇲🇿',
      'Zambie': '🇿🇲',
      'Zimbabwe': '🇿🇼',
    };

    return flagEmojis[country] ?? '🇦🇫';
  }
}

// import 'package:afrotok/pages/UserServices/detailsUserService.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
// import 'package:like_button/like_button.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../../models/model_data.dart';
// import '../../providers/postProvider.dart';
// import '../component/consoleWidget.dart';
// import '../component/showUserDetails.dart';
// import 'newUserService.dart';
//
// import 'package:cached_network_image/cached_network_image.dart';
//
//
// class UserServiceListPage extends StatefulWidget {
//   @override
//   State<UserServiceListPage> createState() => _UserServiceListPageState();
// }
//
// class _UserServiceListPageState extends State<UserServiceListPage> {
//   final ScrollController _scrollController = ScrollController();
//   final TextEditingController _searchController = TextEditingController();
//   bool _isLoadingMore = false;
//   bool _showFilters = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialServices();
//     _scrollController.addListener(_scrollListener);
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   void _loadInitialServices() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final postProvider = Provider.of<PostProvider>(context, listen: false);
//       postProvider.getUserServices();
//     });
//   }
//
//   void _scrollListener() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200) {
//       _loadMoreServices();
//     }
//   }
//
//   void _loadMoreServices() async {
//     if (_isLoadingMore) return;
//
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//     if (!postProvider.hasMoreServices || postProvider.isLoadingServices) return;
//
//     setState(() {
//       _isLoadingMore = true;
//     });
//
//     await postProvider.getUserServices(loadMore: true);
//
//     setState(() {
//       _isLoadingMore = false;
//     });
//   }
//
//   void _performSearch() {
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//     postProvider.getUserServices(searchQuery: _searchController.text.trim());
//   }
//
//   void _applyFilters({
//     String? category,
//     String? country,
//     String? city,
//   }) {
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//     postProvider.getUserServices(
//       category: category,
//       country: country,
//       city: city,
//       searchQuery: _searchController.text.trim(),
//     );
//   }
//
//   void _clearFilters() {
//     _searchController.clear();
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//     postProvider.resetServicePagination();
//     postProvider.getUserServices();
//     setState(() {
//       _showFilters = false;
//     });
//   }
//
//   Future<void> launchWhatsApp(String phone, UserServiceData data, String urlService) async {
//     String url = "whatsapp://send?phone=" + phone + "&text="
//         + "Bonjour *${data.user!.nom!}*,\n\n"
//         + "Je m'appelle *@${Provider.of<UserAuthProvider>(context, listen: false).loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
//         + "Je vous contacte concernant votre service :\n\n"
//         + "*Titre* : *${data.titre!.toUpperCase()}*\n"
//         + "*Description* : *${data.description}*\n\n"
//         + "Je suis très intéressé(e) par ce que vous proposez et j'aimerais en savoir plus.\n"
//         + "Vous pouvez voir le service ici : ${urlService}\n\n"
//         + "Merci et à bientôt !";
//
//     if (!await launchUrl(Uri.parse(url))) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           duration: Duration(seconds: 2),
//           content: Text(
//             "Impossible d'ouvrir WhatsApp",
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       throw Exception('Impossible d\'ouvrir WhatsApp');
//     } else {
//       // Incrémenter le compteur WhatsApp
//       final postProvider = Provider.of<PostProvider>(context, listen: false);
//       final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//       await postProvider.getUserServiceById(data.id!).then((value) async {
//         if (value.isNotEmpty) {
//           data = value.first;
//           data.contactWhatsapp = (data.contactWhatsapp ?? 0) + 1;
//
//           if (!_isIn(data.usersContactId!, authProvider.loginUserData.id!)) {
//             data.usersContactId!.add(authProvider.loginUserData.id!);
//           }
//
//           await postProvider.updateUserService(data, context);
//         }
//       });
//     }
//   }
//
//   bool _isIn(List<String> users_id, String userIdToCheck) {
//     return users_id.any((item) => item == userIdToCheck);
//   }
//
//   void _navigateToDetail(UserServiceData service) async {
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//     await postProvider.getUserServiceById(service.id!).then((value) async {
//       if (value.isNotEmpty) {
//         service = value.first;
//         service.vues = (service.vues ?? 0) + 1;
//
//         if (!_isIn(service.usersViewId!, authProvider.loginUserData.id!)) {
//           service.usersViewId!.add(authProvider.loginUserData.id!);
//         }
//
//         await postProvider.updateUserService(service, context);
//
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => DetailUserServicePage(data: service),
//           ),
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<UserAuthProvider>(context);
//     final postProvider = Provider.of<PostProvider>(context);
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         title: Text(
//           'Services & Jobs 🛠️',
//           style: TextStyle(
//             color: Colors.yellow,
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.filter_list, color: Colors.yellow),
//             onPressed: () {
//               setState(() {
//                 _showFilters = !_showFilters;
//               });
//             },
//           ),
//           IconButton(
//             icon: Icon(Icons.add, color: Colors.yellow),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => UserServiceForm()),
//               );
//             },
//           ),
//         ],
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           // Barre de recherche
//           Padding(
//             padding: EdgeInsets.all(12),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.grey[900],
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: TextField(
//                 controller: _searchController,
//                 style: TextStyle(color: Colors.white),
//                 decoration: InputDecoration(
//                   hintText: '🔍 Rechercher services, villes, métiers...',
//                   hintStyle: TextStyle(color: Colors.grey),
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   suffixIcon: IconButton(
//                     icon: Icon(Icons.search, color: Colors.green),
//                     onPressed: _performSearch,
//                   ),
//                 ),
//                 onSubmitted: (_) => _performSearch(),
//               ),
//             ),
//           ),
//
//           // Filtres
//           if (_showFilters) _buildFiltersSection(postProvider),
//
//           // Indicateur de chargement initial
//           if (postProvider.isLoadingServices && postProvider.userServices.isEmpty)
//             _buildLoadingIndicator(),
//
//           // Grille des services
//           Expanded(
//             child: postProvider.userServices.isEmpty && !postProvider.isLoadingServices
//                 ? _buildEmptyState()
//                 : _buildServicesGrid(authProvider, postProvider),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFiltersSection(PostProvider postProvider) {
//     return Container(
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         border: Border(bottom: BorderSide(color: Colors.green)),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: _buildFilterDropdown(
//                   label: 'Catégorie',
//                   items: ServiceConstants.categories,
//                   value: postProvider.selectedCategory,
//                   onChanged: (value) => _applyFilters(category: value),
//                 ),
//               ),
//               SizedBox(width: 8),
//               Expanded(
//                 child: _buildFilterDropdown(
//                   label: 'Pays',
//                   items: ServiceConstants.africanCountries,
//                   value: postProvider.selectedCountry,
//                   onChanged: (value) => _applyFilters(country: value),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 8),
//           FutureBuilder<List<String>>(
//             future: postProvider.getServiceCities(),
//             builder: (context, snapshot) {
//               final cities = snapshot.data ?? [];
//               return _buildFilterDropdown(
//                 label: 'Ville',
//                 items: cities,
//                 value: postProvider.selectedCity,
//                 onChanged: (value) => _applyFilters(city: value),
//               );
//             },
//           ),
//           SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: _clearFilters,
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: Colors.yellow,
//                     side: BorderSide(color: Colors.yellow),
//                   ),
//                   child: Text('EFFACER'),
//                 ),
//               ),
//               SizedBox(width: 8),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: () => setState(() { _showFilters = false; }),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.black,
//                   ),
//                   child: Text('APPLIQUER'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFilterDropdown({
//     required String label,
//     required List<String> items,
//     required String? value,
//     required Function(String?) onChanged,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(color: Colors.yellow, fontSize: 12),
//         ),
//         SizedBox(height: 4),
//         Container(
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: Colors.green),
//           ),
//           child: DropdownButtonFormField<String>(
//             value: value,
//             isExpanded: true,
//             decoration: InputDecoration(
//               border: InputBorder.none,
//               contentPadding: EdgeInsets.symmetric(horizontal: 8),
//             ),
//             dropdownColor: Colors.grey[900],
//             style: TextStyle(color: Colors.white, fontSize: 12),
//             icon: Icon(Icons.arrow_drop_down, color: Colors.yellow, size: 16),
//             items: [
//               DropdownMenuItem<String>(
//                 value: null,
//                 child: Text('Tous', style: TextStyle(color: Colors.grey)),
//               ),
//               ...items.map((item) {
//                 return DropdownMenuItem<String>(
//                   value: item,
//                   child: Text(
//                     item,
//                     style: TextStyle(color: Colors.white, fontSize: 12),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 );
//               }).toList(),
//             ],
//             onChanged: onChanged,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Padding(
//       padding: EdgeInsets.all(16),
//       child: Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.work_outline, size: 64, color: Colors.green),
//           SizedBox(height: 16),
//           Text(
//             'Aucun service trouvé',
//             style: TextStyle(color: Colors.yellow, fontSize: 16),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Essayez de modifier vos filtres',
//             style: TextStyle(color: Colors.grey),
//           ),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => UserServiceForm()),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               foregroundColor: Colors.black,
//             ),
//             child: Text('CRÉER UN SERVICE'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildServicesGrid(UserAuthProvider authProvider, PostProvider postProvider) {
//     return Column(
//       children: [
//         // Compteur de résultats
//         if (postProvider.userServices.isNotEmpty)
//           Container(
//             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//             color: Colors.grey[900],
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '${postProvider.userServices.length} service(s) trouvé(s)',
//                   style: TextStyle(color: Colors.green, fontSize: 12),
//                 ),
//                 if (postProvider.selectedCategory != null ||
//                     postProvider.selectedCountry != null ||
//                     postProvider.selectedCity != null)
//                   GestureDetector(
//                     onTap: _clearFilters,
//                     child: Text(
//                       'Effacer les filtres',
//                       style: TextStyle(color: Colors.yellow, fontSize: 12),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//         // Grille des services
//         Expanded(
//           child: RefreshIndicator(
//             backgroundColor: Colors.green,
//             color: Colors.yellow,
//             onRefresh: () async {
//               final postProvider = Provider.of<PostProvider>(context, listen: false);
//               await postProvider.getUserServices();
//             },
//             child: GridView.builder(
//               controller: _scrollController,
//               physics: AlwaysScrollableScrollPhysics(),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 8,
//                 mainAxisSpacing: 8,
//                 childAspectRatio: 0.85,
//               ),
//               padding: EdgeInsets.all(8),
//               itemCount: postProvider.userServices.length + 1,
//               itemBuilder: (context, index) {
//                 if (index == postProvider.userServices.length) {
//                   return _buildLoadMoreIndicator();
//                 }
//                 return ServiceGridCard(
//                   service: postProvider.userServices[index],
//                   authProvider: authProvider,
//                   onTap: () => _navigateToDetail(postProvider.userServices[index]),
//                   onContact: (service) async {
//                     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//                     await authProvider.createServiceLink(true, service).then((url) async {
//                       await launchWhatsApp(service.contact!, service, url);
//                     });
//                   },
//                 );
//               },
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLoadMoreIndicator() {
//     return _isLoadingMore
//         ? Center(
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//         ),
//       ),
//     )
//         : SizedBox();
//   }
// }
//
// class ServiceGridCard extends StatelessWidget {
//   final UserServiceData service;
//   final UserAuthProvider authProvider;
//   final VoidCallback onTap;
//   final Function(UserServiceData) onContact;
//
//   const ServiceGridCard({
//     Key? key,
//     required this.service,
//     required this.authProvider,
//     required this.onTap,
//     required this.onContact,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final hasValidImage = service.imageCourverture != null &&
//         service.imageCourverture!.isNotEmpty &&
//         service.imageCourverture!.startsWith('http');
//
//     final hasLocation = (service.city != null && service.city!.isNotEmpty) ||
//         (service.country != null && service.country!.isNotEmpty);
//     final hasCategory = service.category != null && service.category != 'Autre';
//
//     return Container(
//       margin: EdgeInsets.all(4),
//       child: Card(
//         color: Colors.grey[900],
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         elevation: 3,
//         shadowColor: Colors.green.withOpacity(0.3),
//         child: InkWell(
//           borderRadius: BorderRadius.circular(16),
//           onTap: onTap,
//           child: Container(
//             padding: EdgeInsets.all(6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // SECTION IMAGE AVEC OVERLAY
//                 Stack(
//                   children: [
//                     // Image principale avec gradient overlay
//                     Container(
//                       height: 130,
//                       width: double.infinity,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(12),
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Colors.transparent,
//                             Colors.black.withOpacity(0.7),
//                           ],
//                         ),
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: hasValidImage
//                             ? CachedNetworkImage(
//                           imageUrl: service.imageCourverture!,
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => _buildImagePlaceholder(),
//                           errorWidget: (context, url, error) => _buildImagePlaceholder(),
//                         )
//                             : _buildImagePlaceholder(),
//                       ),
//                     ),
//
//                     // Gradient overlay pour le texte
//                     Positioned(
//                       bottom: 0,
//                       left: 0,
//                       right: 0,
//                       child: Container(
//                         height: 50, // Augmenté pour plus d'espace texte
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.only(
//                             bottomLeft: Radius.circular(12),
//                             bottomRight: Radius.circular(12),
//                           ),
//                           gradient: LinearGradient(
//                             begin: Alignment.topCenter,
//                             end: Alignment.bottomCenter,
//                             colors: [
//                               Colors.transparent,
//                               Colors.black.withOpacity(0.95),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//
//                     // Titre superposé sur l'image
//                     Positioned(
//                       bottom: 28, // Remonté pour laisser place aux infos
//                       left: 6,
//                       right: 6,
//                       child: Text(
//                         service.titre ?? 'Service',
//                         style: TextStyle(
//                           color: Colors.yellow,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           height: 1.1,
//                           shadows: [
//                             Shadow(
//                               blurRadius: 4,
//                               color: Colors.black,
//                             ),
//                           ],
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//
//
//
//                     // Badge pays en haut à gauche
//                     if (service.country != null && service.country!.isNotEmpty)
//                       Positioned(
//                         top: 4,
//                         left: 4,
//                         child: Container(
//                           padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: Colors.black.withOpacity(0.8),
//                             borderRadius: BorderRadius.circular(6),
//                             border: Border.all(
//                               color: Colors.green.withOpacity(0.5),
//                               width: 0.5,
//                             ),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 _getCountryFlag(service.country!),
//                                 style: TextStyle(fontSize: 8),
//                               ),
//                               SizedBox(width: 2),
//                               Text(
//                                 _getCountryAbbreviation(service.country!),
//                                 style: TextStyle(
//                                   color: Colors.green,
//                                   fontSize: 6,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//
//                     // Bouton WhatsApp en haut à droite
//                     Positioned(
//                       top: 4,
//                       right: 4,
//                       child: GestureDetector(
//                         onTap: () => onContact(service),
//                         child: Container(
//                           padding: EdgeInsets.all(4),
//                           decoration: BoxDecoration(
//                             color: Colors.green,
//                             shape: BoxShape.circle,
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.green.withOpacity(0.5),
//                                 blurRadius: 4,
//                                 spreadRadius: 1,
//                               ),
//                             ],
//                           ),
//                           child: Icon(
//                             FontAwesome.whatsapp,
//                             color: Colors.white,
//                             size: 10,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//
//                 SizedBox(height: 6),
//
//                 // SECTION STATS COMPACTES
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 4),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       _buildCompactStat(Icons.remove_red_eye, service.vues ?? 0, 'Vues'),
//                       _buildCompactStat(FontAwesome.whatsapp, service.contactWhatsapp ?? 0, 'Contacts'),
//                       _buildCompactStat(FontAwesome.heart, service.like ?? 0, 'Likes'),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 5,),
//
//                 // SECTION INFOS LOCALISATION ET CATÉGORIE
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Catégorie
//                     if (hasCategory)
//                       Container(
//                         margin: EdgeInsets.only(bottom: 2),
//                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.yellow.withOpacity(0.9),
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                         child: Text(
//                           service.category!,
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontSize: 7,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//
//                     // Localisation
//                     if (hasLocation)
//                       Row(
//                         children: [
//                           Icon(Icons.location_on, color: Colors.green, size: 8),
//                           SizedBox(width: 2),
//                           Expanded(
//                             child: Text(
//                               _getLocationText(),
//                               style: TextStyle(
//                                 color: Colors.green,
//                                 fontSize: 7,
//                                 fontWeight: FontWeight.w600,
//                                 shadows: [
//                                   Shadow(
//                                     blurRadius: 4,
//                                     color: Colors.black,
//                                   ),
//                                 ],
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildImagePlaceholder() {
//     return Container(
//       color: Colors.grey[800],
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.work_outline, color: Colors.green, size: 30),
//             SizedBox(height: 4),
//             Text(
//               'SERVICE',
//               style: TextStyle(
//                 color: Colors.green,
//                 fontSize: 8,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCompactStat(IconData icon, int count, String label) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, color: Colors.green, size: 8),
//             SizedBox(width: 2),
//             Text(
//               _formatCount(count),
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 8,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 1),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey[400],
//             fontSize: 6,
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _formatCount(int count) {
//     if (count < 1000) return count.toString();
//     if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}K';
//     if (count < 1000000) return '${(count ~/ 1000)}K';
//     return '${(count / 1000000).toStringAsFixed(1)}M';
//   }
//
//   String _getLocationText() {
//     if (service.city != null && service.country != null) {
//       return '${service.city!}, ${service.country!}';
//     } else if (service.city != null) {
//       return service.city!;
//     } else if (service.country != null) {
//       return service.country!;
//     }
//     return '';
//   }
//
//   String _getCountryAbbreviation(String country) {
//     final abbreviations = {
//       'Bénin': 'BJ',
//       'Togo': 'TG',
//       'Ghana': 'GH',
//       'Nigeria': 'NG',
//       'Côte d\'Ivoire': 'CI',
//       'Sénégal': 'SN',
//       'Cameroun': 'CM',
//       'Congo': 'CG',
//       'Gabon': 'GA',
//       'Mali': 'ML',
//       'Burkina Faso': 'BF',
//       'Niger': 'NE',
//       'Tchad': 'TD',
//       'Rwanda': 'RW',
//       'Burundi': 'BI',
//       'Kenya': 'KE',
//       'Tanzanie': 'TZ',
//       'Ouganda': 'UG',
//       'Éthiopie': 'ET',
//       'Somalie': 'SO',
//       'Maroc': 'MA',
//       'Algérie': 'DZ',
//       'Tunisie': 'TN',
//       'Égypte': 'EG',
//       'Soudan': 'SD',
//       'Afrique du Sud': 'ZA',
//       'Angola': 'AO',
//       'Mozambique': 'MZ',
//       'Zambie': 'ZM',
//       'Zimbabwe': 'ZW',
//     };
//
//     return abbreviations[country] ?? country.substring(0, 2).toUpperCase();
//   }
//
//   String _getCountryFlag(String country) {
//     final flagEmojis = {
//       'Bénin': '🇧🇯',
//       'Togo': '🇹🇬',
//       'Ghana': '🇬🇭',
//       'Nigeria': '🇳🇬',
//       'Côte d\'Ivoire': '🇨🇮',
//       'Sénégal': '🇸🇳',
//       'Cameroun': '🇨🇲',
//       'Congo': '🇨🇬',
//       'Gabon': '🇬🇦',
//       'Mali': '🇲🇱',
//       'Burkina Faso': '🇧🇫',
//       'Niger': '🇳🇪',
//       'Tchad': '🇹🇩',
//       'Rwanda': '🇷🇼',
//       'Burundi': '🇧🇮',
//       'Kenya': '🇰🇪',
//       'Tanzanie': '🇹🇿',
//       'Ouganda': '🇺🇬',
//       'Éthiopie': '🇪🇹',
//       'Somalie': '🇸🇴',
//       'Maroc': '🇲🇦',
//       'Algérie': '🇩🇿',
//       'Tunisie': '🇹🇳',
//       'Égypte': '🇪🇬',
//       'Soudan': '🇸🇩',
//       'Afrique du Sud': '🇿🇦',
//       'Angola': '🇦🇴',
//       'Mozambique': '🇲🇿',
//       'Zambie': '🇿🇲',
//       'Zimbabwe': '🇿🇼',
//     };
//
//     return flagEmojis[country] ?? '🇦🇫';
//   }
// }
