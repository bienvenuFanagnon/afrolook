import 'package:flutter/material.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_screen.dart';

import '../Signup/components/signup_form.dart';

// Couleurs de base Afrolook
const Color primaryGreen = Color(0xFF25D366);
const Color accentYellow = Color(0xFFFFD700);
const Color darkBackground = Color(0xFF121212);
const Color textColor = Colors.white;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkBackground, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildIncomeHighlight(),
                      const SizedBox(height: 30),
                      _buildSupportMessage(),
                    ],
                  ),
                ),
              ),

              // --- Boutons d'action ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginPageUser()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                          shadowColor: primaryGreen.withOpacity(0.5),
                        ),
                        child: const Text(
                          "Se connecter",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    SizedBox(
                      height: 55,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignUpScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: primaryGreen, width: 2),
                          backgroundColor: Colors.black.withOpacity(0.4),
                        ),
                        child: Text(
                          "Créer un compte",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                    Text(
                      "🚀 Commencez aujourd’hui et transformez vos vidéos en revenus !",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logo et titre
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryGreen.withOpacity(0.15),
            border: Border.all(color: primaryGreen, width: 3),
          ),
          child: const Center(
            child: Icon(
              Icons.videocam_rounded,
              size: 55,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "AFROLOOK",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  // Bloc qui met en avant les gains
  Widget _buildIncomeHighlight() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentYellow, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentYellow.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "💰 Gagnez plus de 100 000 FCFA / mois",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentYellow,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Mettez vos vidéos en vente et monétisez votre talent directement sur Afrolook.",
            style: TextStyle(
              fontSize: 16,
              color: textColor.withOpacity(0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Message de soutien aux créateurs
  Widget _buildSupportMessage() {
    return Column(
      children: [
        const SizedBox(height: 15),
        Text(
          "🎭 Soutien aux artistes, comédiens et créateurs africains",
          style: TextStyle(
            color: accentYellow,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          "📲 Publiez vos vidéos exclusives, engagez votre communauté et développez vos revenus.",
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 15,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
