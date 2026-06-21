import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../models/official_account/official_account_enums.dart';
import '../../../models/official_account/official_account_request.dart';
import '../../../providers/authProvider.dart';
import '../../../services/official_account/official_account_service.dart';
import '../../../theme/app_colors.dart';

/// Nombre minimum d'abonnés Afrolook pour les comptes monétisables.
const _kMinFollowersMonetizable = 20;

// 54 pays africains
const _africanCountries = [
  'Afrique du Sud', 'Algérie', 'Angola', 'Bénin', 'Botswana',
  'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cameroun', 'Comores',
  'Congo (Brazzaville)', 'Congo (RDC)', 'Côte d\'Ivoire', 'Djibouti',
  'Égypte', 'Érythrée', 'Éswatini', 'Éthiopie', 'Gabon', 'Gambie',
  'Ghana', 'Guinée', 'Guinée équatoriale', 'Guinée-Bissau', 'Kenya',
  'Lesotho', 'Libéria', 'Libye', 'Madagascar', 'Malawi', 'Mali',
  'Maroc', 'Maurice', 'Mauritanie', 'Mozambique', 'Namibie', 'Niger',
  'Nigeria', 'Ouganda', 'République centrafricaine', 'Rwanda',
  'São Tomé-et-Príncipe', 'Sénégal', 'Seychelles', 'Sierra Leone',
  'Somalie', 'Soudan', 'Soudan du Sud', 'Tanzanie', 'Tchad', 'Togo',
  'Tunisie', 'Zambie', 'Zimbabwe',
];

class RequestOfficialAccountPage extends StatefulWidget {
  /// Si fourni, la page s'ouvre en mode édition (mise à jour d'une demande).
  final OfficialAccountRequest? existingRequest;

  const RequestOfficialAccountPage({super.key, this.existingRequest});

  @override
  State<RequestOfficialAccountPage> createState() =>
      _RequestOfficialAccountPageState();
}

class _RequestOfficialAccountPageState
    extends State<RequestOfficialAccountPage> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _submitting = false;

  // ── Étape 0 : Catégorie ─────────────────────────────────────────────────
  OfficialAccountCategory? _category;

  // ── Étape 1 : Informations générales ────────────────────────────────────
  final _officialName = TextEditingController();
  final _description = TextEditingController();
  String? _selectedCountry;
  final _city = TextEditingController();
  String _phoneFullNumber = '';
  bool _phoneIsValid = false;
  bool _nameIsAvailable = true; // false = nom déjà pris
  final _email = TextEditingController();
  final _website = TextEditingController();

  // ── Étape 2 : Domaines ──────────────────────────────────────────────────
  final Set<BroadcastDomain> _domains = {};

  // ── Étape 3 : Réseaux sociaux ────────────────────────────────────────────
  final List<SocialNetworkEntry> _socialNetworks = [];

  // ── Étape 4 : Vérification d'identité ───────────────────────────────────
  DateTime? _birthDate;
  IdDocumentType? _idType;
  final _idNumber = TextEditingController();
  String? _idDocumentUrl;

  // ── Étape 5 : CGU ─────────────────────────────────────────────────────
  bool _termsAccepted = false;

  bool get _isEditMode => widget.existingRequest != null;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_officialName, _description, _city, _email, _website, _idNumber]) {
      ctrl.addListener(_onFieldChanged);
    }
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  void _prefill() {
    final r = widget.existingRequest!;
    setState(() {
      _category = r.category;
      _officialName.text = r.officialName;
      _description.text = r.description;
      _selectedCountry = r.country;
      _city.text = r.city;
      _phoneFullNumber = r.phone;
      _phoneIsValid = r.phone.isNotEmpty;
      _nameIsAvailable = true; // le nom est déjà le leur
      _email.text = r.email;
      _website.text = r.website;
      _domains
        ..clear()
        ..addAll(r.broadcastDomains);
      _socialNetworks
        ..clear()
        ..addAll(r.socialNetworks);
      if (r.birthDate != null) _birthDate = DateTime.tryParse(r.birthDate!);
      _idType = r.idDocumentType;
      if (r.idNumber != null) _idNumber.text = r.idNumber!;
      _idDocumentUrl = r.idDocumentUrl;
    });
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final ctrl in [_officialName, _description, _city, _email, _website, _idNumber]) {
      ctrl.removeListener(_onFieldChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  bool get _needsIdVerification => _category?.requiresIdVerification == true;

  int get _myFollowersCount =>
      context.read<UserAuthProvider>().loginUserData.userAbonnesIds?.length ?? 0;

  bool get _meetsFollowerRequirement =>
      _category?.canMonetize != true || _myFollowersCount >= _kMinFollowersMonetizable;

  int get _totalSteps => _needsIdVerification ? 6 : 5;

  bool get _isOver18 {
    if (_birthDate == null) return false;
    final age = DateTime.now().difference(_birthDate!).inDays ~/ 365;
    return age >= 18;
  }

  void _goNext() {
    if (!_canProceed()) return;
    if (_step < _totalSteps - 1) {
      _step++;
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() {});
    }
  }

  void _goBack() {
    if (_step > 0) {
      _step--;
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() {});
    } else {
      Navigator.pop(context);
    }
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _category != null && _meetsFollowerRequirement;
      case 1:
        return _officialName.text.trim().isNotEmpty &&
            (_isEditMode || _nameIsAvailable) &&
            _description.text.trim().isNotEmpty &&
            _selectedCountry != null &&
            _city.text.trim().isNotEmpty &&
            _phoneIsValid &&
            _email.text.trim().isNotEmpty;
      case 2:
        return _domains.isNotEmpty;
      case 3:
        return true; // optionnel
      case 4:
        if (_needsIdVerification) {
          return _birthDate != null &&
              _isOver18 &&
              _idType != null &&
              _idNumber.text.trim().isNotEmpty &&
              _idDocumentUrl != null;
        }
        return true;
      case 5:
        return _termsAccepted;
      default:
        return true;
    }
  }

  static void _showSubmittedModal(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Demande envoyée !',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Votre demande de compte officiel a bien été reçue et sera examinée par notre équipe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si vous n\'avez pas de nouvelles sous 3 jours ouvrés, contactez notre service client.',
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Compris',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_termsAccepted) return;
    setState(() => _submitting = true);
    try {
      final auth = context.read<UserAuthProvider>();
      final me = auth.loginUserData;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_isEditMode) {
        // ── Mode édition : mise à jour de la demande existante ──────────────
        await OfficialAccountService.instance.updateRequest(
          requestId: widget.existingRequest!.id,
          userId: me.id ?? '',
          updatedFields: {
            'description': _description.text.trim(),
            'country': _selectedCountry ?? '',
            'city': _city.text.trim(),
            'phone': _phoneFullNumber,
            'email': _email.text.trim(),
            'website': _website.text.trim(),
            'broadcastDomains': _domains.map((d) => d.id).toList(),
            'socialNetworks': _socialNetworks.map((s) => s.toMap()).toList(),
            'birthDate': _birthDate != null
                ? DateFormat('yyyy-MM-dd').format(_birthDate!)
                : null,
            'idDocumentType': _idType?.id,
            'idNumber': _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
            'idDocumentUrl': _idDocumentUrl,
          },
        );
        if (mounted) {
          Navigator.pop(context);
          _showUpdatedModal(context);
        }
      } else {
        // ── Mode création : nouvelle demande ─────────────────────────────────
        final id = OfficialAccountService.instance.newId();
        final request = OfficialAccountRequest(
          id: id,
          userId: me.id ?? '',
          pseudo: me.pseudo ?? '',
          imageUrl: me.imageUrl ?? '',
          category: _category!,
          officialName: _officialName.text.trim(),
          officialNameSlug: officialNameToSlug(_officialName.text),
          searchKeywords: officialNameToKeywords(_officialName.text),
          description: _description.text.trim(),
          country: _selectedCountry ?? '',
          city: _city.text.trim(),
          phone: _phoneFullNumber,
          email: _email.text.trim(),
          website: _website.text.trim(),
          profilePhotoUrl: me.imageUrl ?? '',
          coverPhotoUrl: '',
          broadcastDomains: _domains.toList(),
          socialNetworks: _socialNetworks,
          birthDate: _birthDate != null
              ? DateFormat('yyyy-MM-dd').format(_birthDate!)
              : null,
          idDocumentType: _idType,
          idNumber: _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
          idDocumentUrl: _idDocumentUrl,
          status: OfficialAccountStatus.pending,
          actionHistory: [],
          createdAt: now,
          updatedAt: now,
          termsAcceptedAt: now,
        );
        await OfficialAccountService.instance.submitRequest(request);
        if (mounted) {
          Navigator.pop(context);
          _showSubmittedModal(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static void _showUpdatedModal(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_rounded, color: Colors.blue, size: 36),
              ),
              const SizedBox(height: 20),
              Text('Demande mise à jour !',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'Vos modifications ont bien été enregistrées. Votre demande repassera en file d\'attente pour être examinée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Compris',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pages = <Widget>[
      _StepCategory(
          selected: _category,
          followersCount: _myFollowersCount,
          onChanged: _isEditMode ? null : (c) => setState(() => _category = c),
          locked: _isEditMode),
      _StepInfo(
          nameCtrl: _officialName,
          descCtrl: _description,
          selectedCountry: _selectedCountry,
          onCountryChanged: (c) => setState(() => _selectedCountry = c),
          cityCtrl: _city,
          onPhoneChanged: (number, isValid) => setState(() {
            _phoneFullNumber = number;
            _phoneIsValid = isValid;
          }),
          onAvailabilityChanged: (v) => setState(() => _nameIsAvailable = v),
          emailCtrl: _email,
          websiteCtrl: _website,
          nameLocked: _isEditMode),
      _StepDomains(
          selected: _domains,
          onToggle: (d) => setState(() =>
              _domains.contains(d) ? _domains.remove(d) : _domains.add(d))),
      _StepSocialNetworks(
          networks: _socialNetworks,
          onAdd: (e) => setState(() => _socialNetworks.add(e)),
          onRemove: (i) => setState(() => _socialNetworks.removeAt(i))),
      if (_needsIdVerification)
        _StepIdentity(
            birthDate: _birthDate,
            idType: _idType,
            idNumberCtrl: _idNumber,
            isOver18: _isOver18,
            idDocumentUrl: _idDocumentUrl,
            onBirthDateChanged: (d) => setState(() => _birthDate = d),
            onIdTypeChanged: (t) => setState(() => _idType = t),
            onDocumentUploaded: (url) => setState(() => _idDocumentUrl = url)),
      _StepTerms(
          category: _category,
          accepted: _termsAccepted,
          onChanged: (v) => setState(() => _termsAccepted = v)),
    ];

    final stepLabels = [
      'Catégorie',
      'Informations',
      'Domaines',
      'Réseaux',
      if (_needsIdVerification) 'Identité',
      'Conditions',
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: _goBack,
        ),
        title: Text(
          _isEditMode ? 'Mettre à jour ma demande' : 'Compte officiel',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _StepIndicator(
              current: _step,
              labels: stepLabels,
              colors: colors,
              onStepTap: (i) {
                if (i < _step) {
                  setState(() => _step = i);
                  _pageCtrl.animateToPage(i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: pages,
            ),
          ),
          _BottomBar(
            step: _step,
            total: _totalSteps,
            canProceed: _canProceed(),
            submitting: _submitting,
            isLastStep: _step == _totalSteps - 1,
            onNext: _goNext,
            onSubmit: _submit,
            colors: colors,
          ),
        ],
      ),
    ));
  }
}

// ── Indicateur d'étapes ─────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  final AppColors colors;
  final ValueChanged<int>? onStepTap;

  const _StepIndicator({
    required this.current,
    required this.labels,
    required this.colors,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final done = i < current;
          final active = i == current;
          final tappable = done && onStepTap != null;
          return Row(
            children: [
              GestureDetector(
                onTap: tappable ? () => onStepTap!(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary
                        : done
                            ? colors.primary.withOpacity(0.2)
                            : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: tappable
                        ? Border.all(color: colors.primary.withOpacity(0.4), width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (done) Icon(Icons.check_rounded, size: 11, color: colors.primary),
                      if (!done)
                        Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : colors.textSecondary)),
                      if (done) const SizedBox(width: 2),
                      const SizedBox(width: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? Colors.white
                                : done
                                    ? colors.primary
                                    : colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < labels.length - 1)
                Container(
                  width: 16, height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: i < current ? colors.primary.withOpacity(0.4) : colors.border,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Barre de navigation bas ──────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step, total;
  final bool canProceed, submitting, isLastStep;
  final VoidCallback onNext, onSubmit;
  final AppColors colors;

  const _BottomBar({
    required this.step,
    required this.total,
    required this.canProceed,
    required this.submitting,
    required this.isLastStep,
    required this.onNext,
    required this.onSubmit,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Text('${step + 1} / $total',
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const Spacer(),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: canProceed && !submitting
                  ? (isLastStep ? onSubmit : onNext)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                disabledBackgroundColor: colors.border,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isLastStep ? 'Envoyer la demande' : 'Continuer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 0 — Catégorie
// ══════════════════════════════════════════════════════════════════════════════

class _StepCategory extends StatelessWidget {
  final OfficialAccountCategory? selected;
  final int followersCount;
  final ValueChanged<OfficialAccountCategory>? onChanged;
  final bool locked;

  const _StepCategory({
    required this.selected,
    required this.followersCount,
    required this.onChanged,
    this.locked = false,
  });

  static const _personal = [
    OfficialAccountCategory.influencer,
    OfficialAccountCategory.artist,
    OfficialAccountCategory.entrepreneur,
    OfficialAccountCategory.publicFigure,
    OfficialAccountCategory.journalist,
  ];

  static const _institutional = [
    OfficialAccountCategory.company,
    OfficialAccountCategory.media,
    OfficialAccountCategory.stateInstitution,
    OfficialAccountCategory.ngo,
    OfficialAccountCategory.association,
    OfficialAccountCategory.other,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Quel type de compte souhaitez-vous créer ?',
            style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Choisissez la catégorie qui correspond le mieux à votre activité.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),

        // Frais info
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFF9A825), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Frais mensuel : 5 000 FCFA/mois pour les comptes non monétisables. '
                  'Gratuit pour les comptes Influenceur, Artiste et Entrepreneur.',
                  style: TextStyle(color: Color(0xFFF57F17), fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        _GroupHeader('Comptes personnels', Icons.person_rounded, colors),
        const SizedBox(height: 10),
        ..._personal.map((cat) => _CategoryTile(
              cat: cat,
              selected: selected,
              followersCount: followersCount,
              onChanged: onChanged,
              colors: colors,
            )),

        const SizedBox(height: 16),
        _GroupHeader('Comptes institutionnels', Icons.business_rounded, colors),
        const SizedBox(height: 10),
        ..._institutional.map((cat) => _CategoryTile(
              cat: cat,
              selected: selected,
              followersCount: followersCount,
              onChanged: onChanged,
              colors: colors,
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppColors colors;

  const _GroupHeader(this.label, this.icon, this.colors);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: colors.textSecondary),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: colors.border.withOpacity(0.4), thickness: 1)),
    ],
  );
}

class _CategoryTile extends StatelessWidget {
  final OfficialAccountCategory cat;
  final OfficialAccountCategory? selected;
  final int followersCount;
  final ValueChanged<OfficialAccountCategory>? onChanged;
  final AppColors colors;

  const _CategoryTile({
    required this.cat,
    required this.selected,
    required this.followersCount,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == cat;
    final isLocked = cat.canMonetize && followersCount < _kMinFollowersMonetizable;
    return GestureDetector(
      onTap: (isLocked || onChanged == null) ? null : () => onChanged!(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isLocked
              ? colors.surfaceVariant.withOpacity(0.5)
              : isSelected
                  ? colors.primary.withOpacity(0.08)
                  : colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isLocked
                ? colors.border.withOpacity(0.2)
                : isSelected
                    ? colors.primary
                    : colors.border.withOpacity(0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(cat.emoji,
                    style: TextStyle(
                        fontSize: 20,
                        color: isLocked ? null : null),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.label,
                          style: TextStyle(
                              color: isLocked
                                  ? colors.textSecondary
                                  : isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (cat.canMonetize)
                            _Tag('Monétisable', const Color(0xFFF9A825), const Color(0xFFFFF8E1))
                          else
                            _Tag('Non monétisé', colors.textSecondary, colors.surfaceVariant),
                          if (cat.requiresIdVerification)
                            _Tag('Vérif. identité', colors.primary, colors.primary.withOpacity(0.08)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(Icons.lock_rounded, size: 16, color: colors.textSecondary),
                if (isSelected && !isLocked)
                  Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
              ],
            ),
            if (isLocked) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_outlined, size: 13, color: Colors.orange),
                    const SizedBox(width: 5),
                    Text(
                      'Minimum $_kMinFollowersMonetizable abonnés requis — vous en avez $followersCount',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _Tag(this.label, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w600)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 1 — Informations générales
// ══════════════════════════════════════════════════════════════════════════════

class _StepInfo extends StatefulWidget {
  final TextEditingController nameCtrl, descCtrl, cityCtrl, emailCtrl, websiteCtrl;
  final String? selectedCountry;
  final ValueChanged<String> onCountryChanged;
  final void Function(String fullNumber, bool isValid) onPhoneChanged;
  final ValueChanged<bool> onAvailabilityChanged;
  final bool nameLocked;

  const _StepInfo({
    required this.nameCtrl,
    required this.descCtrl,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.cityCtrl,
    required this.onPhoneChanged,
    required this.onAvailabilityChanged,
    required this.emailCtrl,
    required this.websiteCtrl,
    this.nameLocked = false,
  });

  @override
  State<_StepInfo> createState() => _StepInfoState();
}

enum _NameStatus { idle, checking, available, taken }

class _StepInfoState extends State<_StepInfo> {
  String _slug = '';
  _NameStatus _nameStatus = _NameStatus.idle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    // En mode édition le nom est verrouillé — pas de vérification de disponibilité
    if (widget.nameLocked) return;

    final s = officialNameToSlug(widget.nameCtrl.text);
    if (s == _slug) return;
    setState(() {
      _slug = s;
      _nameStatus = s.isEmpty ? _NameStatus.idle : _NameStatus.checking;
    });

    _debounce?.cancel();
    if (s.isEmpty) {
      widget.onAvailabilityChanged(true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final ok = await OfficialAccountService.instance.isNameAvailable(s);
      if (!mounted) return;
      setState(() => _nameStatus = ok ? _NameStatus.available : _NameStatus.taken);
      widget.onAvailabilityChanged(ok);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.nameCtrl.removeListener(_onNameChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Informations générales', colors),

        // Nom officiel + aperçu identifiant de recherche
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Nom officiel *',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (widget.nameLocked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 10, color: colors.textSecondary),
                          const SizedBox(width: 3),
                          Text('Non modifiable',
                              style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: widget.nameCtrl,
                readOnly: widget.nameLocked,
                style: TextStyle(
                    color: widget.nameLocked
                        ? colors.textSecondary
                        : colors.textPrimary),
                decoration: _inputDecoration('Ex : Afrolook Media', colors).copyWith(
                  filled: true,
                  fillColor: widget.nameLocked
                      ? colors.surfaceVariant
                      : null,
                ),
              ),
              if (!widget.nameLocked && _slug.isNotEmpty) ...[
                const SizedBox(height: 6),
                _NameAvailabilityBadge(
                  slug: _slug,
                  status: _nameStatus,
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
        _Field(ctrl: widget.descCtrl, label: 'Description *', hint: 'Décrivez votre activité…', maxLines: 4, colors: colors),

        // Sélecteur de pays africain
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pays *',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: widget.selectedCountry,
                isExpanded: true,
                decoration: _inputDecoration('Sélectionner votre pays', colors),
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                hint: Text('Sélectionner votre pays',
                    style: TextStyle(color: colors.textSecondary.withOpacity(0.5), fontSize: 14)),
                items: _africanCountries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) { if (v != null) widget.onCountryChanged(v); },
              ),
            ],
          ),
        ),

        _Field(ctrl: widget.cityCtrl, label: 'Ville *', hint: 'Ex : Abidjan', colors: colors),

        // Téléphone avec indicatif pays
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Téléphone *',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              IntlPhoneField(
                initialCountryCode: 'CI',
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                dropdownTextStyle: TextStyle(color: colors.textPrimary, fontSize: 14),
                dropdownIcon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                decoration: _inputDecoration('07 XX XX XX XX', colors),
                flagsButtonPadding: const EdgeInsets.only(left: 10),
                onChanged: (phone) {
                  final valid = phone.number.trim().isNotEmpty;
                  widget.onPhoneChanged(phone.completeNumber, valid);
                },
                onCountryChanged: (_) {},
                disableLengthCheck: true,
                dropdownDecoration: BoxDecoration(
                  color: isDark ? colors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),

        _Field(ctrl: widget.emailCtrl, label: 'Email *', hint: 'contact@exemple.com',
            keyboard: TextInputType.emailAddress, colors: colors),
        _Field(ctrl: widget.websiteCtrl, label: 'Site web (optionnel)', hint: 'https://exemple.com',
            keyboard: TextInputType.url, colors: colors),
        const SizedBox(height: 8),
        Text('* Champ obligatoire',
            style: TextStyle(color: colors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 2 — Domaines de diffusion
// ══════════════════════════════════════════════════════════════════════════════

class _StepDomains extends StatelessWidget {
  final Set<BroadcastDomain> selected;
  final ValueChanged<BroadcastDomain> onToggle;

  const _StepDomains({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Domaines de diffusion', colors),
        Text('Sélectionnez tous les sujets que vous souhaitez couvrir (minimum 1).',
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BroadcastDomain.values.map((d) {
            final sel = selected.contains(d);
            return GestureDetector(
              onTap: () => onToggle(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? colors.primary : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? colors.primary : colors.border.withOpacity(0.3)),
                ),
                child: Text(d.label,
                    style: TextStyle(
                        color: sel ? Colors.white : colors.textSecondary,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (selected.isNotEmpty)
          Text('${selected.length} domaine(s) sélectionné(s)',
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 3 — Réseaux sociaux
// ══════════════════════════════════════════════════════════════════════════════

class _StepSocialNetworks extends StatefulWidget {
  final List<SocialNetworkEntry> networks;
  final ValueChanged<SocialNetworkEntry> onAdd;
  final ValueChanged<int> onRemove;

  const _StepSocialNetworks({
    required this.networks,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_StepSocialNetworks> createState() => _StepSocialNetworksState();
}

class _StepSocialNetworksState extends State<_StepSocialNetworks> {
  SocialNetworkType _type = SocialNetworkType.instagram;
  final _link = TextEditingController();
  final _followers = TextEditingController();

  void _add() {
    if (_link.text.trim().isEmpty) return;
    widget.onAdd(SocialNetworkEntry(
      type: _type,
      link: _link.text.trim(),
      followers: int.tryParse(_followers.text.replaceAll(' ', '')) ?? 0,
    ));
    _link.clear();
    _followers.clear();
    setState(() => _type = SocialNetworkType.instagram);
  }

  @override
  void dispose() {
    _link.dispose();
    _followers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Réseaux sociaux (optionnel)', colors),
        Text(
          'Ajoutez vos réseaux sociaux pour aider l\'administration à évaluer votre notoriété.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Liste des réseaux ajoutés
        ...widget.networks.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.type.label,
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(e.value.link,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                        if (e.value.followers > 0)
                          Text('${_fmtNum(e.value.followers)} abonnés',
                              style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => widget.onRemove(e.key),
                  ),
                ],
              ),
            )),

        if (widget.networks.isNotEmpty) const SizedBox(height: 8),

        // Formulaire d'ajout
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter un réseau social',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<SocialNetworkType>(
                value: _type,
                decoration: _inputDecoration('Réseau social', colors),
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                items: SocialNetworkType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _link,
                style: TextStyle(color: colors.textPrimary),
                decoration: _inputDecoration('Lien ou @nom_utilisateur', colors),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _followers,
                style: TextStyle(color: colors.textPrimary),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Nombre d\'abonnés actuel', colors),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 4 — Vérification d'identité (influenceur, artiste, entrepreneur)
// ══════════════════════════════════════════════════════════════════════════════

class _StepIdentity extends StatefulWidget {
  final DateTime? birthDate;
  final IdDocumentType? idType;
  final TextEditingController idNumberCtrl;
  final bool isOver18;
  final String? idDocumentUrl;
  final ValueChanged<DateTime> onBirthDateChanged;
  final ValueChanged<IdDocumentType> onIdTypeChanged;
  final ValueChanged<String> onDocumentUploaded;

  const _StepIdentity({
    required this.birthDate,
    required this.idType,
    required this.idNumberCtrl,
    required this.isOver18,
    required this.idDocumentUrl,
    required this.onBirthDateChanged,
    required this.onIdTypeChanged,
    required this.onDocumentUploaded,
  });

  @override
  State<_StepIdentity> createState() => _StepIdentityState();
}

class _StepIdentityState extends State<_StepIdentity> {
  bool _uploading = false;
  String? _fileName;

  Future<void> _pickAndUploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    setState(() { _uploading = true; _fileName = file.name; });
    try {
      final ref = FirebaseStorage.instance
          .ref('id_documents/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await ref.putFile(File(path));
      final url = await ref.getDownloadURL();
      widget.onDocumentUploaded(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final uploaded = widget.idDocumentUrl != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Vérification d\'identité', colors),
        Text(
          'L\'administrateur vérifiera que le numéro, la date de naissance et le nom sur la pièce correspondent aux informations saisies.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Date de naissance
        Text('Date de naissance *',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.light(primary: colors.primary),
                ),
                child: child!,
              ),
            );
            if (date != null) widget.onBirthDateChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  widget.birthDate != null
                      ? DateFormat('dd/MM/yyyy').format(widget.birthDate!)
                      : 'Sélectionner la date',
                  style: TextStyle(
                      color: widget.birthDate != null ? colors.textPrimary : colors.textSecondary,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        if (widget.birthDate != null && !widget.isOver18) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous devez avoir au moins 18 ans.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.birthDate != null && widget.isOver18) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text('Âge validé ✓',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Type de pièce
        DropdownButtonFormField<IdDocumentType>(
          value: widget.idType,
          decoration: _inputDecoration('Type de pièce d\'identité *', colors),
          dropdownColor: colors.surface,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          items: IdDocumentType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
              .toList(),
          onChanged: (v) { if (v != null) widget.onIdTypeChanged(v); },
        ),
        const SizedBox(height: 12),

        // Numéro de pièce
        TextField(
          controller: widget.idNumberCtrl,
          style: TextStyle(color: colors.textPrimary),
          decoration: _inputDecoration('Numéro de la pièce *', colors),
        ),
        const SizedBox(height: 20),

        // Upload document
        Text('Copie de la pièce (PDF, JPG, PNG) *',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _uploading ? null : _pickAndUploadDocument,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: uploaded
                  ? Colors.green.withOpacity(0.06)
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: uploaded
                    ? Colors.green.withOpacity(0.5)
                    : colors.border.withOpacity(0.4),
                width: uploaded ? 1.5 : 1,
              ),
            ),
            child: _uploading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text('Envoi en cours…',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                        size: 22,
                        color: uploaded ? Colors.green : colors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              uploaded ? 'Document envoyé ✓' : 'Appuyer pour choisir un fichier',
                              style: TextStyle(
                                  color: uploaded ? Colors.green.shade700 : colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            if (_fileName != null)
                              Text(_fileName!,
                                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                            if (!uploaded)
                              Text('PDF, JPG ou PNG — max 10 Mo',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (uploaded)
                        TextButton(
                          onPressed: _pickAndUploadDocument,
                          child: Text('Changer', style: TextStyle(color: colors.primary, fontSize: 12)),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Document confidentiel — visible uniquement par l\'administrateur pour vérification.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPE 5 — Conditions d'utilisation
// ══════════════════════════════════════════════════════════════════════════════

class _StepTerms extends StatelessWidget {
  final OfficialAccountCategory? category;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _StepTerms({required this.category, required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isInfluencer = category == OfficialAccountCategory.influencer;
    final needsContact = category != null && !isInfluencer;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('Conditions d\'utilisation', colors),

        if (needsContact) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Justificatifs complémentaires',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Après la soumission de votre demande, des documents justificatifs pourront vous être demandés (acte de création, registre de commerce, arrêté ministériel, etc.).',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: naviguer vers la page Contact
                    },
                    icon: const Icon(Icons.headset_mic_rounded, size: 16),
                    label: const Text('Contacter le service'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Frais d'abonnement mensuel
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment_rounded, color: Color(0xFFF9A825), size: 18),
                  const SizedBox(width: 8),
                  const Text('Frais d\'abonnement mensuel',
                      style: TextStyle(color: Color(0xFFF57F17), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                category?.canMonetize == true
                    ? 'Ce type de compte (${category?.label ?? ''}) bénéficie d\'un accès gratuit — aucun frais mensuel ne vous sera prélevé.'
                    : '5 000 FCFA/mois sont prélevés automatiquement sur votre solde Afrolook à chaque renouvellement. '
                      'Un rappel vous est envoyé à chaque connexion en cas de retard. '
                      'Au-delà de 30 jours de retard, votre compte officiel peut être suspendu par l\'administration.',
                style: const TextStyle(color: Color(0xFFF57F17), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),

        ..._buildTermsBlocks(colors, isInfluencer),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => onChanged(!accepted),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: accepted,
                activeColor: colors.primary,
                onChanged: (v) => onChanged(v ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'J\'ai lu et j\'accepte les conditions d\'utilisation des comptes officiels Afrolook.',
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTermsBlocks(AppColors colors, bool isInfluencer) => [
        _TermsBlock(
          title: 'Responsabilités du compte officiel',
          content: 'Le titulaire d\'un compte officiel s\'engage à publier des informations vérifiées et exactes. Toute publication mensongère ou trompeuse peut entraîner la suspension ou le retrait du statut officiel.',
          colors: colors,
        ),
        _TermsBlock(
          title: 'Règles de publication',
          content: 'Le contenu publié doit respecter les Conditions Générales d\'Utilisation d\'Afrolook, les lois en vigueur et les droits de tiers. Tout contenu illicite, haineux ou trompeur est strictement interdit.',
          colors: colors,
        ),
        _TermsBlock(
          title: 'Retrait du statut',
          content: 'Afrolook se réserve le droit de suspendre ou retirer le statut de compte officiel à tout moment en cas de non-respect des conditions, sans préavis et sans indemnité.',
          colors: colors,
        ),
        if (isInfluencer) ...[
          _TermsBlock(
            title: 'Monétisation',
            content: 'Les créateurs de contenu peuvent bénéficier de la monétisation par vues, des commissions sur les cadeaux reçus en live, et du programme de parrainage, sous réserve du respect de toutes les conditions.',
            colors: colors,
          ),
          _TermsBlock(
            title: 'Cadeaux et parrainage',
            content: 'Les cadeaux reçus en live sont distribués selon la grille en vigueur : 70% créateur, 30% plateforme. Le programme de parrainage génère une commission selon les règles du plan marketing actif.',
            colors: colors,
          ),
        ] else ...[
          _TermsBlock(
            title: 'Monétisation et cadeaux',
            content: 'Les comptes officiels de type ${category?.label ?? 'institutionnel'} ne bénéficient pas de la monétisation, des commissions sur les cadeaux, ni du programme de parrainage. Les cadeaux reçus en live sont intégralement reversés à la plateforme.',
            colors: colors,
          ),
        ],
      ];
}

class _TermsBlock extends StatelessWidget {
  final String title, content;
  final AppColors colors;

  const _TermsBlock({required this.title, required this.content, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Text(content,
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.5)),
          ],
        ),
      );
}

// ── Badge disponibilité nom ──────────────────────────────────────────────────

class _NameAvailabilityBadge extends StatelessWidget {
  final String slug;
  final _NameStatus status;
  final AppColors colors;

  const _NameAvailabilityBadge({
    required this.slug,
    required this.status,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Widget leading;
    final String statusText;

    switch (status) {
      case _NameStatus.checking:
        bgColor = colors.surfaceVariant;
        borderColor = colors.border;
        textColor = colors.textSecondary;
        leading = SizedBox(
          width: 12, height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.textSecondary),
        );
        statusText = 'Vérification…';
      case _NameStatus.available:
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF4CAF50);
        textColor = const Color(0xFF2E7D32);
        leading = const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF4CAF50));
        statusText = 'Disponible';
      case _NameStatus.taken:
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFF44336);
        textColor = const Color(0xFFC62828);
        leading = const Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFF44336));
        statusText = 'Déjà utilisé';
      case _NameStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 6),
          Text('$statusText  •  ',
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              slug,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final AppColors colors;

  const _SectionTitle(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final int maxLines;
  final TextInputType keyboard;
  final AppColors colors;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              keyboardType: keyboard,
              style: TextStyle(color: colors.textPrimary),
              decoration: _inputDecoration(hint, colors),
            ),
          ],
        ),
      );
}

InputDecoration _inputDecoration(String hint, AppColors colors) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.5), fontSize: 14),
      filled: true,
      fillColor: colors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border.withOpacity(0.3))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5)),
    );
