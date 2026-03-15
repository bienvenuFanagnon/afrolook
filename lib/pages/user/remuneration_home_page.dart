// pages/remuneration_home_page.dart

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'mes_gains_post_page.dart';

class RemunerationHomePage extends StatefulWidget {
  final UserData user;

  const RemunerationHomePage({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<RemunerationHomePage> createState() => _RemunerationHomePageState();
}

class _RemunerationHomePageState extends State<RemunerationHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black87,
              Color(0xFF8B0000), // Rouge foncé
              Color(0xFFFFD700), // Or/jaune
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // En-tête avec titre
              _buildHeader(),

              SizedBox(height: 40),

              // Titre principal
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ESPACE RÉMUNÉRATION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.red.shade900,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 10),

              // Sous-titre
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Gagnez de l\'argent en partageant vos looks',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 60),

              // Boutons de rémunération
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Bouton Compte Principal
                      _buildRemunerationButton(
                        context,
                        title: 'COMPTE PRINCIPAL',
                        subtitle: 'Gérez votre solde principal',
                        icon: FontAwesomeIcons.wallet,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFD700), // Or
                            Color(0xFFDAA520), // Doré
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconColor: Colors.black,
                        textColor: Colors.black,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MonetisationPage(
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 25),

                      // Bouton Rémunération des Posts
                      _buildRemunerationButton(
                        context,
                        title: 'RÉMUNÉRATION POSTS',
                        subtitle: 'Vos gains par publication',
                        icon: FontAwesomeIcons.instagram,
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade900,
                            Color(0xFF8B0000), // Rouge foncé
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconColor: Color(0xFFFFD700),
                        textColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MesGainsPage(
                                userId: widget.user.id!,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 25),

                      // Placeholder pour futurs boutons
                      _buildFutureButtonPlaceholder(),
                    ],
                  ),
                ),
              ),

              // Pied de page
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo ou icône
          Center(
            child: Row(
              children: [
                IconButton(onPressed: () {
                  Navigator.pop(context);
                }, icon: Icon(Icons.arrow_back),color: Colors.white,),
              ],
            ),
          ),

          // Solde rapide (optionnel)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFFFFD700), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
                SizedBox(width: 5),
                Text(
                  'Solde: ${widget.user.votre_solde_principal } FCFA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemunerationButton(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Gradient gradient,
        required Color iconColor,
        required Color textColor,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Éléments décoratifs
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(25),
              child: Row(
                children: [
                  // Icône
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 35,
                      ),
                    ),
                  ),

                  SizedBox(width: 20),

                  // Textes
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Flèche
                  Icon(
                    Icons.arrow_forward_ios,
                    color: textColor.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFutureButtonPlaceholder() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          style: BorderStyle.solid,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                color: Colors.white.withOpacity(0.3),
                size: 25,
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROCHAINEMENT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Nouveaux modes de rémunération',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 3,
            width: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black,
                  Color(0xFFFFD700),
                  Colors.red.shade900,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Afrolook Rémunération',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          Text(
            'Gagnez en partageant votre style',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}