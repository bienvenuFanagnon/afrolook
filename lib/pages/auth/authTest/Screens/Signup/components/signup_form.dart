import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/widgets/language_selector.dart';
import 'package:afrotok/pages/auth/authTest/components/google_sign_in_button.dart';
import 'package:afrotok/services/auth/google_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:afrotok/widgets/name_preview.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/utils/pseudo_format.dart';
import 'dart:math';
import 'package:afrotok/layout/branding_carousel_panel.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/pages/auth/eula_screen.dart';
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
  /// Compte déjà connecté avec Google mais sans profil Afrolook : on ne demande ni e-mail ni mot de passe.
  final User? googleUser;
  SignUpScreen({Key? key, this.googleUser}) : super(key: key);

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

  bool get _google => widget.googleUser != null;

  /// Abandon en cours d'inscription Google : on supprime le compte sans profil puis on revient en arrière.
  Future<void> _leave() async {
    if (_google) await GoogleAuthService.abandon();
    if (mounted) Navigator.pop(context);
  }

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
    // Règle des pseudos : minuscules avec points. On teste aussi l'ancienne forme (underscores)
    // tant que la migration n'a pas converti tous les comptes.
    final n = normalizePseudo(nom);
    final snap = await firestore.collection("Pseudo")
        .where('name', whereIn: [n, n.replaceAll('.', '_')])
        .limit(1)
        .getM('signup_form.dart:82');

    if (snap.docs.isEmpty) return false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).signupPseudoExists, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    return true;
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
    // Règle App Store 1.2 : conditions acceptées avant toute connexion ou inscription.
    WidgetsBinding.instance.addPostFrameCallback((_) => EulaGate.ensureAccepted(context));
    authProvider.initializeData();
    is_open = false;
    if (_google) emailController.text = widget.googleUser!.email ?? '';
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
    // Compte Google sans profil : le retour (bouton ou geste Android) abandonne proprement l'inscription.
    return PopScope(
      canPop: !_google,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _buildScreen(context),
    );
  }

  /// Bloc « Continuer avec Google » (inscription classique) ou rappel du compte Google (profil à compléter).
  Widget _googleHeader(AppColors colors) {
    if (_google) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(
          'Connecté avec Google (${widget.googleUser!.email ?? ''}). Il ne reste qu’à créer votre profil Afrolook : pas de mot de passe à choisir.',
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
        ),
      );
    }
    if (!GoogleAuthService.isAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          const GoogleSignInButton(),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Divider(color: colors.textSecondary.withOpacity(0.3))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('ou', style: TextStyle(color: colors.textSecondary))),
            Expanded(child: Divider(color: colors.textSecondary.withOpacity(0.3))),
          ]),
        ],
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
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
          onPressed: _leave,
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: LanguageSelectorButton()))],
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
              SizedBox(height: 24),
              _googleHeader(colors),
              SizedBox(height: 6),

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

                    // Champ email (compte Google : déjà connu)
                    if (!_google) ...[
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

                    ],
                    // Champ pseudo
                    _buildTextField(
                      context: context,
                      controller: pseudoController,
                      hintText: l10n.signupPseudoUnique,
                      prefixIcon: Icons.person_outline,
                      inputFormatters: [PseudoInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupPseudoRequired;
                        }
                        if (value.length < kPseudoMinLength || value.length > kPseudoMaxLength) {
                          return l10n.signupPseudoTooShort;
                        }
                        return null;
                      },
                    ),
NamePreview(controller: pseudoController),
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
                          hintText: '${l10n.signupGenreLabel} (optionnel)',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          prefixIcon: Icon(Icons.person_outline, color: primaryGreen),
                        ),
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.signupGenreLabel, style: TextStyle(color: colors.textSecondary))),
                          ...genres.map((genre) {
                            final label = genre == 'Homme' ? l10n.signupGenreMale : l10n.signupGenreFemale;
                            return DropdownMenuItem(
                              value: genre,
                              child: Text(label, style: TextStyle(color: colors.textPrimary)),
                            );
                          }),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedGenre = newValue;
                          });
                        },
                        validator: null,
                      ),
                    ),
                    SizedBox(height: 15),

                    // Mots de passe (compte Google : aucun)
                    if (!_google) ...[
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
                    ],
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
                              authProvider.registerUser.codeParrainage = "${normalizePseudo(pseudoController.text)}${genererNombreAleatoire()}".replaceAll(' ', '');
                              authProvider.registerUser.pseudo = normalizePseudo(pseudoController.text);
                              authProvider.registerUser.genre = selectedGenre;
                              authProvider.registerUser.password = _google ? '' : motDePasseController.text;
                              authProvider.registerUser.email = _google ? (widget.googleUser!.email ?? emailController.text) : emailController.text;
                              authProvider.registerUser.acceptedTermsAt = DateTime.now().millisecondsSinceEpoch;
                              authProvider.registerUser.acceptedCommunityRulesAt = DateTime.now().millisecondsSinceEpoch;

                              if (!mounted) return;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignUpFormEtap3(googleUser: widget.googleUser)),
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
                    if (!_google) Row(
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
                    // Choix de la langue
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Align(alignment: Alignment.centerRight, child: LanguageSelectorButton()),
                    ),
                    // Barre navigation : retour + toggle thème
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: primaryGreen),
                          onPressed: _leave,
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
                            const SizedBox(height: 20),
                            _googleHeader(colors),
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
      if (!_google) ...[
      _buildTextField(
        context: context, controller: emailController, hintText: l10n.authEmail,
        keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined,
        validator: (v) => (v == null || v.isEmpty) ? l10n.signupEmailRequired : (!isValidEmail(v) ? l10n.signupEmailInvalidShort : null),
      ),
      const SizedBox(height: 15),
      ],
      _buildTextField(
        context: context, controller: pseudoController, hintText: l10n.signupPseudoUnique, prefixIcon: Icons.person_outline,
        inputFormatters: [PseudoInputFormatter()],
        validator: (v) => (v == null || v.isEmpty) ? l10n.signupPseudoRequired : ((v.length < kPseudoMinLength || v.length > kPseudoMaxLength) ? l10n.signupPseudoTooShort : null),
      ),
NamePreview(controller: pseudoController),
      const SizedBox(height: 15),
      Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: DropdownButtonFormField<String>(
          value: selectedGenre,
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            border: InputBorder.none, hintText: '${l10n.signupGenreLabel} (optionnel)',
            hintStyle: TextStyle(color: colors.textSecondary),
            prefixIcon: const Icon(Icons.person_outline, color: primaryGreen),
          ),
          items: [
            DropdownMenuItem<String>(value: null, child: Text(l10n.signupGenreLabel, style: TextStyle(color: colors.textSecondary))),
            ...genres.map((g) {
              final label = g == 'Homme' ? l10n.signupGenreMale : l10n.signupGenreFemale;
              return DropdownMenuItem(value: g, child: Text(label, style: TextStyle(color: colors.textPrimary)));
            }),
          ],
          onChanged: (v) => setState(() => selectedGenre = v),
          validator: null,
        ),
      ),
      const SizedBox(height: 15),
      if (!_google) ...[
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
      ],
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
                authProvider.registerUser.codeParrainage = "${normalizePseudo(pseudoController.text)}${genererNombreAleatoire()}".replaceAll(' ', '');
                authProvider.registerUser.pseudo = normalizePseudo(pseudoController.text);
                authProvider.registerUser.genre = selectedGenre;
                authProvider.registerUser.password = _google ? '' : motDePasseController.text;
                authProvider.registerUser.email = _google ? (widget.googleUser!.email ?? emailController.text) : emailController.text;
                if (!mounted) return;
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpFormEtap3(googleUser: widget.googleUser)));
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
      if (!_google) Row(
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    final colors = AppColors.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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