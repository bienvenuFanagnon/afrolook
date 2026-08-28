import 'dart:math';
import 'package:afrotok/layout/branding_carousel_panel.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import '../../../../../../models/model_data.dart';
import '../../../../../../providers/authProvider.dart';
import '../../../../../../providers/userProvider.dart';
import '../../Login/loginPageUser.dart';
import '../signup_up_form_step_2.dart';
import '../../../../../../theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../regles_confidentialite_page.dart';

// Couleurs de base
const Color primaryGreen = Color(0xFF25D366);

class SignUpScreen extends StatefulWidget {
  SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController pseudoController = TextEditingController();
  final TextEditingController motDePasseController = TextEditingController();
  final TextEditingController confirmMotDePasseController = TextEditingController();
  final TextEditingController code_parrainageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool onTap = false;
  bool _acceptedTerms = false;
  bool is_open = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> genres = ['Homme', 'Femme'];
  String? selectedGenre;

  int genererNombreAleatoire() {
    Random random = Random();
    return random.nextInt(100000);
  }

  Future<bool> verifierPseudo(String nom) async {
    CollectionReference pseudos = firestore.collection("Pseudo");
    QuerySnapshot snapshot = await pseudos.get();
    final list = snapshot.docs.map((doc) =>
        UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe = list.any((e) => (e.name ?? '').toLowerCase() == nom.toLowerCase());

    if (!existe) {
      try {
        return false;
      } on FirebaseException catch(error) {
        return true;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).signupPseudoExists, style: TextStyle(color: Colors.red)),
        ),
      );
      return true;
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
    return emailRegExp.hasMatch(email);
  }
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  @override
  void initState() {
    super.initState();
    authProvider.initializeData();
    is_open = false;
  }

  @override
  void dispose() {
    telephoneController.dispose();
    pseudoController.dispose();
    motDePasseController.dispose();
    confirmMotDePasseController.dispose();
    code_parrainageController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    if (AppLayout.isWide(context)) {
      return _buildWideLayout(context, colors, l10n);
    }
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),

              // Titre
              Text(
                l10n.signupCreateAccountTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 5),
              Text(
                l10n.signupJoinCommunity,
                style: TextStyle(
                  fontSize: 16,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: 30),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ téléphone
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IntlPhoneField(
                        onChanged: (phone) {
                          telephoneController.text = phone.completeNumber;
                        },
                        decoration: InputDecoration(
                          hintText: l10n.signupPhoneHint,
                          hintStyle: TextStyle(color: colors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        initialCountryCode: 'TG',
                        style: TextStyle(color: colors.textPrimary),
                        dropdownTextStyle: TextStyle(color: colors.textPrimary),
                        validator: (value) {
                          if (value == null || value.number.isEmpty) {
                            return l10n.signupPhoneRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 15),

                    // Champ code parrainage
                    _buildTextField(
                      context: context,
                      controller: code_parrainageController,
                      hintText: l10n.signupReferralCodeOptional,
                      prefixIcon: Icons.person_add_alt_1_outlined,
                    ),
                    SizedBox(height: 15),

                    // Champ email
                    _buildTextField(
                      context: context,
                      controller: emailController,
                      hintText: l10n.authEmail,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupEmailRequired;
                        }
                        if (!isValidEmail(value)) {
                          return l10n.signupEmailInvalidShort;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Champ pseudo
                    _buildTextField(
                      context: context,
                      controller: pseudoController,
                      hintText: l10n.signupPseudoUnique,
                      prefixIcon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupPseudoRequired;
                        }
                        if (value.length < 3) {
                          return l10n.signupPseudoTooShort;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Sélecteur de genre
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: DropdownButtonFormField<String>(
                        value: selectedGenre,
                        dropdownColor: colors.surface,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.signupGenreLabel,
                          hintStyle: TextStyle(color: colors.textSecondary),
                          prefixIcon: Icon(Icons.person_outline, color: primaryGreen),
                        ),
                        items: genres.map((genre) {
                          final label = genre == 'Homme' ? l10n.signupGenreMale : l10n.signupGenreFemale;
                          return DropdownMenuItem(
                            value: genre,
                            child: Text(label, style: TextStyle(color: colors.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedGenre = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.signupGenreRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 15),

                    // Champ mot de passe
                    _buildPasswordField(
                      context: context,
                      controller: motDePasseController,
                      hintText: l10n.signupPasswordHint,
                      obscureText: _obscurePassword,
                      onToggle: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupPasswordRequired;
                        }
                        if (value.length < 8) {
                          return l10n.signupPasswordTooShort;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Champ confirmation mot de passe
                    _buildPasswordField(
                      context: context,
                      controller: confirmMotDePasseController,
                      hintText: l10n.signupConfirmPasswordHint,
                      obscureText: _obscureConfirmPassword,
                      onToggle: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupConfirmPasswordRequired;
                        }
                        if (value.length < 8) {
                          return l10n.signupPasswordTooShort;
                        }
                        if (value != motDePasseController.text) {
                          return l10n.signupPasswordsDontMatch;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Acceptation des conditions
                    InkWell(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _acceptedTerms,
                                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                                activeColor: primaryGreen,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                children: [
                                  Text(
                                    'En créant ce compte vous acceptez nos ',
                                    style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReglesConfidentialitePage())),
                                    child: const Text(
                                      'Règles & Confidentialité',
                                      style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 14),

                    // Bouton suivant
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (onTap || !_acceptedTerms) ? null : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => onTap = true);
                          try {
                            final pseudoPris = await verifierPseudo(pseudoController.text);
                            if (!pseudoPris) {
                              await authProvider.getAppData();
                              authProvider.initializeData();
                              authProvider.registerUser.numeroDeTelephone = telephoneController.text;
                              authProvider.registerUser.codeParrain = code_parrainageController.text.trim();
                              authProvider.registerUser.codeParrainage = "${pseudoController.text}${genererNombreAleatoire()}".replaceAll(' ', '');
                              authProvider.registerUser.pseudo = pseudoController.text.trim().replaceAll(' ', '_');
                              authProvider.registerUser.genre = selectedGenre;
                              authProvider.registerUser.password = motDePasseController.text;
                              authProvider.registerUser.email = emailController.text;
                              authProvider.registerUser.acceptedTermsAt = DateTime.now().millisecondsSinceEpoch;
                              authProvider.registerUser.acceptedCommunityRulesAt = DateTime.now().millisecondsSinceEpoch;

                              if (!mounted) return;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignUpFormEtap3()),
                              );
                            }
                          } catch (e, stack) {
                            debugPrint('🔴 [SignUp] Erreur inscription: $e');
                            debugPrint('$stack');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur : $e'),
                                  duration: const Duration(seconds: 8),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => onTap = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: onTap
                            ? LoadingAnimationWidget.threeRotatingDots(
                          color: Colors.white,
                          size: 24,
                        )
                            : Text(
                          l10n.signupNext,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Lien de connexion
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.signupAlreadyHaveAccount,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LoginPageUser()),
                            );
                          },
                          child: Text(
                            l10n.signupLoginLink,
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, AppColors colors, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Row(
          children: [
            // ── Colonne gauche — carousel branding ────────────────────
            const Expanded(
              child: BrandingCarouselPanel(),
            ),
            // ── Colonne droite — formulaire ────────────────────────────
            Container(
              width: 420,
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: colors.surface,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(-4, 0))],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre navigation : retour + toggle thème
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: primaryGreen),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Consumer<ThemeProvider>(
                          builder: (ctx, tp, _) {
                            final isDark = tp.themeMode == ThemeMode.dark;
                            return GestureDetector(
                              onTap: () => tp.toggleTheme(),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: colors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(l10n.signupCreateAccountTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            const SizedBox(height: 5),
                            Text(l10n.signupJoinCommunity, style: TextStyle(fontSize: 14, color: colors.textSecondary)),
                            const SizedBox(height: 24),
                            Form(
                              key: _formKey,
                              child: Column(children: _buildFormFields(context, colors, l10n)),
                            ),
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
      ),
    );
  }

  /// Liste des champs de formulaire — utilisée dans le layout wide.
  List<Widget> _buildFormFields(BuildContext context, AppColors colors, AppLocalizations l10n) {
    return [
      Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(15)),
        child: IntlPhoneField(
          onChanged: (phone) => telephoneController.text = phone.completeNumber,
          decoration: InputDecoration(
            hintText: l10n.signupPhoneHint,
            hintStyle: TextStyle(color: colors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
          initialCountryCode: 'TG',
          style: TextStyle(color: colors.textPrimary),
          dropdownTextStyle: TextStyle(color: colors.textPrimary),
          validator: (v) => (v == null || v.number.isEmpty) ? l10n.signupPhoneRequired : null,
        ),
      ),
      const SizedBox(height: 15),
      _buildTextField(context: context, controller: code_parrainageController, hintText: l10n.signupReferralCodeOptional, prefixIcon: Icons.person_add_alt_1_outlined),
      const SizedBox(height: 15),
      _buildTextField(
        context: context, controller: emailController, hintText: l10n.authEmail,
        keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined,
        validator: (v) => (v == null || v.isEmpty) ? l10n.signupEmailRequired : (!isValidEmail(v) ? l10n.signupEmailInvalidShort : null),
      ),
      const SizedBox(height: 15),
      _buildTextField(
        context: context, controller: pseudoController, hintText: l10n.signupPseudoUnique, prefixIcon: Icons.person_outline,
        validator: (v) => (v == null || v.isEmpty) ? l10n.signupPseudoRequired : (v.length < 3 ? l10n.signupPseudoTooShort : null),
      ),
      const SizedBox(height: 15),
      Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: DropdownButtonFormField<String>(
          value: selectedGenre,
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            border: InputBorder.none, hintText: l10n.signupGenreLabel,
            hintStyle: TextStyle(color: colors.textSecondary),
            prefixIcon: const Icon(Icons.person_outline, color: primaryGreen),
          ),
          items: genres.map((g) {
            final label = g == 'Homme' ? l10n.signupGenreMale : l10n.signupGenreFemale;
            return DropdownMenuItem(value: g, child: Text(label, style: TextStyle(color: colors.textPrimary)));
          }).toList(),
          onChanged: (v) => setState(() => selectedGenre = v),
          validator: (v) => (v == null || v.isEmpty) ? l10n.signupGenreRequired : null,
        ),
      ),
      const SizedBox(height: 15),
      _buildPasswordField(
        context: context, controller: motDePasseController, hintText: l10n.signupPasswordHint,
        obscureText: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        validator: (v) => (v == null || v.isEmpty) ? l10n.signupPasswordRequired : (v.length < 8 ? l10n.signupPasswordTooShort : null),
      ),
      const SizedBox(height: 15),
      _buildPasswordField(
        context: context, controller: confirmMotDePasseController, hintText: l10n.signupConfirmPasswordHint,
        obscureText: _obscureConfirmPassword, onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        validator: (v) {
          if (v == null || v.isEmpty) return l10n.signupConfirmPasswordRequired;
          if (v.length < 8) return l10n.signupPasswordTooShort;
          if (v != motDePasseController.text) return l10n.signupPasswordsDontMatch;
          return null;
        },
      ),
      const SizedBox(height: 30),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onTap ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => onTap = true);
            try {
              final pseudoPris = await verifierPseudo(pseudoController.text);
              if (!pseudoPris) {
                await authProvider.getAppData();
                authProvider.initializeData();
                authProvider.registerUser.numeroDeTelephone = telephoneController.text;
                authProvider.registerUser.codeParrain = code_parrainageController.text.trim();
                authProvider.registerUser.codeParrainage = "${pseudoController.text}${genererNombreAleatoire()}".replaceAll(' ', '');
                authProvider.registerUser.pseudo = pseudoController.text.trim().replaceAll(' ', '_');
                authProvider.registerUser.genre = selectedGenre;
                authProvider.registerUser.password = motDePasseController.text;
                authProvider.registerUser.email = emailController.text;
                if (!mounted) return;
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpFormEtap3()));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade700));
            } finally {
              if (mounted) setState(() => onTap = false);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
          child: onTap
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text(l10n.signupNext, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.signupAlreadyHaveAccount, style: TextStyle(color: colors.textSecondary)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPageUser())),
            child: Text(l10n.signupLoginLink, style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      const SizedBox(height: 30),
    ];
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final colors = AppColors.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surface,
        hintText: hintText,
        hintStyle: TextStyle(color: colors.textSecondary),
        prefixIcon: Icon(prefixIcon, color: primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    final colors = AppColors.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surface,
        hintText: hintText,
        hintStyle: TextStyle(color: colors.textSecondary),
        prefixIcon: Icon(Icons.lock_outline, color: primaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: primaryGreen,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: validator,
    );
  }
}