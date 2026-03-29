// pages/remuneration_home_page.dart

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'mes_gains_post_page.dart';
import 'mes_gains_publicite_page.dart';

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
              const Color(0xFF8B0000), // Rouge foncé
              const Color(0xFFFFD700), // Or/jaune
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // En-tête avec titre
              _buildHeader(),

              const SizedBox(height: 30),

              // Titre principal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ESPACE RÉMUNÉRATION',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.red.shade900,
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Sous-titre
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Gagnez de l\'argent en partageant vos looks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Boutons de rémunération
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Bouton Compte Principal
                      _buildRemunerationButton(
                        context,
                        title: 'COMPTE PRINCIPAL',
                        subtitle: 'Gérez votre solde principal',
                        icon: FontAwesomeIcons.wallet,
                        gradient: const LinearGradient(
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
                              builder: (context) =>  MonetisationPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // Bouton Rémunération des Posts
                      _buildRemunerationButton(
                        context,
                        title: 'RÉMUNÉRATION POSTS',
                        subtitle: 'Vos gains par publication',
                        icon: FontAwesomeIcons.instagram,
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Color(0xFF8B0000), // Rouge foncé
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconColor: const Color(0xFFFFD700),
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

                      const SizedBox(height: 15),

                      // Bouton Gains Publicitaires
                      _buildRemunerationButton(
                        context,
                        title: 'GAINS PUBLICITAIRES',
                        subtitle: 'Gagnez grâce aux pubs Google',
                        icon: FontAwesomeIcons.google,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4285F4), // Bleu Google
                            Color(0xFF34A853), // Vert
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MesGainsPublicitePage(
                                userId: widget.user.id!,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

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
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD700),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Solde: ${widget.user.votre_solde_principal?.toStringAsFixed(2) ?? "0.00"} FCFA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Icône
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Textes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Flèche
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFutureButtonPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PROCHAINEMENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nouveaux modes de rémunération',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.3),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 2,
            width: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.black,
                  Color(0xFFFFD700),
                  Colors.red,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Afrolook Rémunération',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const Text(
            'Gagnez en partageant votre style',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}