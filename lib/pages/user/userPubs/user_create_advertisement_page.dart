import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/services/api/boosts_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/media_shrink.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'boost_widgets.dart';

/// Création d'une publicité payante (`POST /ads/boosts`, cible `post` ou `new`) :
///  - [existingPost] non nul : boost d'une publication de la personne ;
///  - [existingPost] nul : nouvelle publicité avec ses images ou sa vidéo (`target = new` : annonce autonome, sans publication dans le fil).
/// Le débit en pièces et la création de l'annonce se font dans UNE SEULE opération côté serveur ; l'annonce attend ensuite la validation
/// de l'équipe. Le prix est donné par le serveur ; en cas d'erreur : message en français + « Réessayer », jamais de repli sur Firebase.
class UserCreateAdvertisementPage extends StatefulWidget {
  final Post? existingPost; // null = nouvelle publicité ; non-null = booster une publication existante

  const UserCreateAdvertisementPage({Key? key, this.existingPost}) : super(key: key);

  @override
  State<UserCreateAdvertisementPage> createState() => _UserCreateAdvertisementPageState();
}

class _UserCreateAdvertisementPageState extends State<UserCreateAdvertisementPage> {
  static const Color _primary = Color(0xFFE21221);

  final _desc = TextEditingController();
  final _url = TextEditingController();
  final _whatsapp = TextEditingController();

  List<AdDuration> _durations = AdConfigService.defaults;
  int? _weeks;
  String? _adType; // 'image' | 'video' (nouvelle publicité seulement)
  String? _actionType; // visit, learn_more, download, whatsapp, none
  bool _combined = false; // boost combiné publication + profil (+ 50 %)
  bool _allCountries = true;
  Set<String> _countries = {};
  final List<File> _images = [];
  File? _video;
  bool _busy = false;
  String _step = '';

  // Reprise après une erreur : les fichiers déjà téléversés ne sont pas renvoyés
  List<String> _imageIds = const [];
  String? _videoId;

  bool get _isBoost => widget.existingPost != null;
  int get _maxImages => (_weeks ?? 0) >= 4 ? 5 : 3;

  @override
  void initState() {
    super.initState();
    AdConfigService.getDurations().then((d) {
      if (mounted) setState(() => _durations = d);
    });
    final p = widget.existingPost;
    if (p != null) {
      final text = (p.description ?? '').trim();
      _desc.text = text.length > 220 ? text.substring(0, 220) : text;
      final link = (p.urlLink ?? '').trim();
      if (link.startsWith('https://')) {
        _url.text = link;
        _actionType = 'visit';
      }
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    _url.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  void _say(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: Colors.red));

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) return _say('Maximum $_maxImages images pour cette durée');
    final remaining = _maxImages - _images.length;
    final List<XFile> picked;
    if (remaining == 1) {
      final one = await ImagePicker().pickImage(source: ImageSource.gallery);
      picked = one == null ? const [] : [one];
    } else {
      picked = await ImagePicker().pickMultiImage(limit: remaining);
    }
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final x in picked) {
        if (_images.length < _maxImages) _images.add(File(x.path));
      }
      _imageIds = const [];
    });
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() {
      _video = File(x.path);
      _videoId = null;
    });
  }

  String? _actionUrl() {
    switch (_actionType) {
      case 'none':
        return null;
      case 'whatsapp':
        final n = _whatsapp.text.replaceAll(RegExp(r'[^0-9]'), '');
        return 'https://wa.me/$n';
      default:
        return _url.text.trim();
    }
  }

  String _actionLabel() => switch (_actionType) {
        'visit' => 'Visiter',
        'learn_more' => 'En savoir plus',
        'download' => 'Télécharger',
        'whatsapp' => 'WhatsApp',
        _ => '',
      };

  Future<void> _submit() async {
    final me = context.read<UserAuthProvider>().loginUserData;
    if (!_isBoost && _adType == null) return _say('Choisis le type de publicité');
    if (_actionType == null) return _say('Choisis un type d\'action');
    if (_weeks == null) return _say('Choisis la durée');
    if (_desc.text.trim().isEmpty) return _say('La description est obligatoire');
    if (_actionType == 'whatsapp') {
      if (_whatsapp.text.replaceAll(RegExp(r'[^0-9]'), '').length < 6) return _say('Numéro WhatsApp requis (avec l\'indicatif du pays)');
    } else if (_actionType != 'none' && !_url.text.trim().startsWith('https://')) {
      return _say('Lien valide requis (il doit commencer par https://)');
    }
    if (!_isBoost) {
      if (_adType == 'image' && _images.isEmpty) return _say('Sélectionne au moins une image');
      if (_adType == 'video' && _video == null) return _say('Sélectionne une vidéo');
    }
    if (!_allCountries && _countries.isEmpty) return _say('Choisis au moins un pays');

    setState(() {
      _busy = true;
      _step = 'Calcul du prix…';
    });
    try {
      final coins = await BoostUi.quote('ad', _weeks!, _durations, combined: _isBoost && _combined);
      if (!mounted) return;
      final ok = await BoostUi.confirmPrice(
        context,
        title: _isBoost && _combined ? 'Publicité + boost de profil' : 'Payer la publicité',
        coins: coins,
        detail: 'La publicité est validée par l\'équipe avant sa diffusion.',
      );
      if (!ok || !mounted) return;

      // Nouvelle publicité : les fichiers sont téléversés (puis conservés pour un nouvel essai), l'annonce est créée SEULE par le serveur
      // (target = new), dans la même opération que le débit : aucune publication visible dans le fil.
      if (!_isBoost && _imageIds.isEmpty && _videoId == null) {
        setState(() => _step = 'Envoi des fichiers…');
        if (_adType == 'image') {
          final ids = <String>[];
          for (final f in _images) {
            ids.add(await UploadsApi.upload(await MediaShrink.file(f)));
          }
          _imageIds = ids;
        } else {
          _videoId = await UploadsApi.upload(await MediaShrink.file(_video!));
        }
      }
      if (!mounted) return;
      setState(() => _step = 'Paiement…');
      final name = '${me.prenom ?? ''} ${me.nom ?? ''}'.trim();
      // Une seule opération côté serveur : débit en pièces ET annonce en attente de validation par l'équipe
      await BoostsApi.create(
        target: _isBoost ? 'post' : 'new',
        targetId: _isBoost ? widget.existingPost!.id! : null,
        weeks: _weeks!,
        combined: _isBoost && _combined,
        countries: _allCountries ? const [] : _countries.toList(),
        actionText: _actionLabel(),
        actionUrl: _actionUrl(),
        description: _desc.text,
        title: name.isNotEmpty ? name : me.pseudo,
        imageUploadIds: _isBoost ? const [] : _imageIds,
        videoUploadId: _isBoost ? null : _videoId,
      );
      if (!mounted) return;
      await BoostUi.refreshBalance(context);
      if (!mounted) return;
      await _showDone();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('UserCreateAdvertisementPage._submit : $e');
      if (mounted) BoostUi.showError(context, e, _submit, fallback: 'Impossible d\'envoyer la publicité. Réessaie.');
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _step = '';
      });
    }
  }

  Future<void> _showDone() {
    final c = AppColors.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text('Publicité soumise !', style: TextStyle(color: c.textPrimary))),
        ]),
        content: Text(
          'Ta publicité a bien été soumise : l\'équipe va l\'examiner. Tu peux suivre son état et ses statistiques dans « Mes publicités ».',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Widget _section(AppColors c, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _existingPostCard(AppColors c) {
    final p = widget.existingPost!;
    final imgs = (p.images ?? const <String>[]).where((u) => u.isNotEmpty).toList();
    final thumb = (p.thumbnail ?? '').isNotEmpty ? p.thumbnail! : (imgs.isNotEmpty ? imgs.first : '');
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: thumb.isEmpty ? Container(color: c.surfaceVariant, child: Icon(Icons.article_outlined, color: c.textSecondary)) : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            (p.description ?? '').trim().isEmpty ? 'Ma publication' : p.description!.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary),
          ),
        ),
      ]),
    );
  }

  Widget _mediaPicker(AppColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: [
        ChoiceChip(
          label: const Text('Images'),
          selected: _adType == 'image',
          onSelected: _busy ? null : (_) => setState(() { _adType = 'image'; _videoId = null; }),
        ),
        ChoiceChip(
          label: const Text('Vidéo'),
          selected: _adType == 'video',
          onSelected: _busy ? null : (_) => setState(() { _adType = 'video'; _imageIds = const []; }),
        ),
      ]),
      const SizedBox(height: 10),
      if (_adType == 'image') ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _images.length; i++)
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_images[i], width: 84, height: 84, fit: BoxFit.cover)),
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: _busy ? null : () => setState(() {
                    _images.removeAt(i);
                    _imageIds = const [];
                  }),
                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 13, color: Colors.white)),
                ),
              ),
            ]),
          if (_images.length < _maxImages)
            InkWell(
              onTap: _busy ? null : _pickImages,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                child: Icon(Icons.add_photo_alternate_outlined, color: c.textSecondary),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text('Jusqu\'à $_maxImages images (5 à partir d\'un mois).', style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ],
      if (_adType == 'video')
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickVideo,
          icon: const Icon(Icons.video_library_outlined),
          label: Text(_video == null ? 'Choisir une vidéo' : 'Vidéo choisie : ${_video!.path.split(RegExp(r'[\\/]')).last}'),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(_isBoost ? 'Booster ma publication' : 'Nouvelle publicité'),
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        if (_isBoost) _existingPostCard(c) else _section(c, 'Contenu de la publicité', _mediaPicker(c)),
        _section(
          c,
          'Texte de la publicité',
          TextField(controller: _desc, maxLines: 4, maxLength: 220, enabled: !_busy, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Décris ton offre, ton événement ou ton service')),
        ),
        _section(
          c,
          'Bouton d\'action',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in BoostUi.actionLabels.entries)
                ChoiceChip(label: Text(e.value), selected: _actionType == e.key, onSelected: _busy ? null : (_) => setState(() => _actionType = e.key)),
            ]),
            if (_actionType == 'whatsapp') ...[
              const SizedBox(height: 10),
              TextField(controller: _whatsapp, keyboardType: TextInputType.phone, enabled: !_busy, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Numéro avec indicatif (ex. 22890000000)')),
            ] else if (_actionType != null && _actionType != 'none') ...[
              const SizedBox(height: 10),
              TextField(controller: _url, keyboardType: TextInputType.url, enabled: !_busy, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'https://…')),
            ],
          ]),
        ),
        _section(c, 'Durée', BoostDurationChips(durations: _durations, selected: _weeks, combined: _isBoost && _combined, color: _primary, onSelected: (w) => setState(() {
              _weeks = w;
              if (_images.length > _maxImages) _images.removeRange(_maxImages, _images.length);
            }))),
        if (_isBoost) SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _combined,
          onChanged: _busy ? null : (v) => setState(() => _combined = v),
          title: Text('Ajouter le boost de mon profil (+ 50 %)', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text('Ton profil est mis en avant avec la publicité.', style: TextStyle(color: c.textSecondary)),
        ),
        const SizedBox(height: 8),
        BoostCountriesField(
          allCountries: _allCountries,
          countries: _countries,
          onAllChanged: (v) => setState(() => _allCountries = v),
          onCountriesChanged: (s) => setState(() => _countries = s),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? (_step.isEmpty ? 'Envoi…' : _step) : 'Payer et lancer la publicité', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le prix est calculé par le serveur et débité de tes pièces au moment du paiement. La publicité est validée par l\'équipe avant sa diffusion.',
          style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
        ),
      ]),
    );
  }
}
