import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../component/consoleWidget.dart';
import '../detailsOtherUser.dart';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../component/consoleWidget.dart';
import '../detailsOtherUser.dart';

class AddListAmis extends StatefulWidget {
  const AddListAmis({super.key});

  @override
  State<AddListAmis> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<AddListAmis> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late List<UserData> listUser = [];
  late List<UserData> filteredListUser = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = false;
  bool _hasSearched = false;

  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
    return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
  }

  bool isInvite(List<String> invitationList, String userIdToCheck) {
    return invitationList.any((invid) => invid == userIdToCheck);
  }

  List<String> alphabet = [];

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        filteredListUser = listUser;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      String searchQuery = query.startsWith('@') ? query.substring(1) : query;
      searchQuery = searchQuery.toLowerCase();

      // 🔍 Recherche locale fluide
      List<UserData> localResults = listUser.where((user) {
        return user.pseudo!.toLowerCase().contains(searchQuery);
      }).toList();

      // Si tu veux interroger Firestore en plus (optionnel)
      if (localResults.length < 5) {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .get(); // ⚠️ pas de filtre, on ramène tous les users (à optimiser avec pagination)

        List<UserData> firebaseResults = snapshot.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .where((user) =>
        user.id != authProvider.loginUserData.id &&
            user.pseudo!.toLowerCase().contains(searchQuery))
            .toList();

        // Fusion sans doublons
        Set<UserData> allResults = {...localResults, ...firebaseResults};
        filteredListUser = allResults.toList();
      } else {
        filteredListUser = localResults;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print("Erreur recherche: $e");
      setState(() => _isLoading = false);
    }
  }


  Future<void> _searchUsers2(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        filteredListUser = listUser;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Recherche par pseudo (sans le @) avec correspondance partielle et insensible à la casse
      String searchQuery = query.startsWith('@') ? query.substring(1) : query;
      searchQuery = searchQuery.toLowerCase();

      // Si on a déjà chargé des utilisateurs, on peut d'abord filtrer localement
      List<UserData> localResults = listUser.where((user) {
        return user.pseudo!.toLowerCase().contains(searchQuery);
      }).toList();

      // Si on a moins de 5 résultats locaux, on interroge Firebase pour plus de résultats
      if (localResults.length < 5) {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('pseudo', isGreaterThanOrEqualTo: searchQuery)
            .where('pseudo', isLessThan: searchQuery + 'z')
            .limit(20)
            .get();

        List<UserData> firebaseResults = snapshot.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .where((user) =>
        user.id != authProvider.loginUserData.id &&
            user.pseudo!.toLowerCase().contains(searchQuery))
            .toList();

        // Fusionner les résultats sans doublons
        Set<UserData> allResults = {...localResults, ...firebaseResults};
        filteredListUser = allResults.toList();
      } else {
        filteredListUser = localResults;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur lors de la recherche: $e");
      // En cas d'erreur, on utilise les résultats locaux
      String searchQuery = query.startsWith('@') ? query.substring(1) : query;
      searchQuery = searchQuery.toLowerCase();

      filteredListUser = listUser.where((user) {
        return user.pseudo!.toLowerCase().contains(searchQuery);
      }).toList();

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: DetailsOtherUser(user: user, w: w, h: h),
        );
      },
    );
  }

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${(number / 1000).toStringAsFixed(1)} k";
    } else if (number < 1000000000) {
      return "${(number / 1000000).toStringAsFixed(1)} m";
    } else {
      return "${(number / 1000000000).toStringAsFixed(1)} b";
    }
  }

  Widget otherUsers(UserData user, bool isSearch) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    bool inviteTap = false;
    bool isAbonne = false;

    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showUserDetailsModalDialog(user!, width, height);
              },
              child: Row(
                children: <Widget>[
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage("${user!.imageUrl!}"),
                        maxRadius: isSearch ? 20 : 30,
                      ),
                      Positioned(
                        bottom: -5,
                        left: -5,
                        child: Visibility(
                          visible: user!.isVerify!,
                          child: Card(
                            child: const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '@${user.pseudo}',
                            style: TextStyle(fontSize: isSearch ? 10 : 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '${formatNumber(user.userAbonnesIds!.length!)} abonné(s)',
                            style: TextStyle(
                                fontSize: isSearch ? 8 : 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.normal),
                          ),
                          // TextCustomerUserTitle(
                          //   titre: "${formatNumber(user!.userlikes!)} like(s)",
                          //   fontSize: SizeText.homeProfileTextSize,
                          //   couleur: Colors.green,
                          //   fontWeight: FontWeight.w700,
                          // ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    alphabet = authProvider.appDefaultData.users_id!;
    alphabet.shuffle();
    alphabet = alphabet.length < 100
        ? alphabet.sublist(0, alphabet.length)
        : alphabet.sublist(0, 100);

    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        // Délai pour éviter de faire une requête à chaque frappe
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_searchController.text.isNotEmpty && mounted) {
            _searchUsers(_searchController.text);
          }
        });
      } else {
        setState(() {
          _isSearching = false;
          _hasSearched = false;
          filteredListUser = listUser;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: kPrimaryColor,
      decoration: InputDecoration(
        focusColor: ConstColors.buttonColors,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: kPrimaryColor),
        ),
        hintText: "Rechercher par pseudo (sans @)...",
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.grey.shade600,
          size: 20,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
          icon: Icon(Icons.clear, color: Colors.grey.shade600),
          onPressed: () {
            _searchController.clear();
            setState(() {
              _isSearching = false;
              _hasSearched = false;
            });
          },
        )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: EdgeInsets.all(8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          _searchUsers(value);
        }
      },
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: LoadingAnimationWidget.flickr(
            size: 50,
            leftDotColor: Colors.green,
            rightDotColor: Colors.black,
          ),
        ),
      );
    }

    final usersToDisplay = _isSearching || _hasSearched ? filteredListUser : listUser;

    if (usersToDisplay.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 50, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _isSearching || _hasSearched
                  ? "Aucun utilisateur trouvé"
                  : "Aucun utilisateur à afficher",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.vertical,
      itemCount: usersToDisplay.length,
      shrinkWrap: true,
      padding: EdgeInsets.only(top: 16),
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _showUserDetailsModalDialog(
                usersToDisplay[index],
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height
            );
          },
          child: otherUsers(usersToDisplay[index], false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Nouveau amis",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 16, left: 16, right: 16),
              child: _buildSearchField(),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .where('id', isNotEqualTo: authProvider.loginUserData.id!)
                  .limit(20)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasData) {
                  QuerySnapshot data = snapshot.requireData;
                  List<UserData> list = data.docs
                      .map((doc) =>
                      UserData.fromJson(doc.data() as Map<String, dynamic>))
                      .toList();

                  if (!_isSearching && !_hasSearched) {
                    listUser = list;
                    filteredListUser = list;
                  }

                  return _buildUserList();
                } else if (snapshot.hasError) {
                  print("${snapshot.error}");
                  return Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/404.png',
                          height: 200,
                          width: 200,
                        ),
                        Text(
                          "Erreurs lors du chargement",
                          style: TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          child: Text(
                            'Réessayer',
                            style: TextStyle(color: Colors.green),
                          ),
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  return Skeletonizer(
                    child: Column(
                      children: List.generate(5, (index) => Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                    AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "pseudo",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'abonné(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp, color: Colors.green)
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}