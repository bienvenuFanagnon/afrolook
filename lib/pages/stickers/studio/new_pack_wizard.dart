import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';

const int _kMaxBytes = 600 * 1024;
const int _kMinStickers = 4;
const int _kMaxStickers = 24;

const List<String> _kCategories = [
  'joie', 'reussite', 'compliments', 'amour', 'surprise', 'taquinerie', 'soutien', 'colere',
  'reponses', 'contenus', 'fetes', 'sport', 'musique', 'afrolook', 'humeur',
];

const List<String> _kRegions = ['universal', 'africa', 'caribbean', 'europe', 'asia', 'latam', 'mena'];

String _categoryLabel(BuildContext context, String cat) {
  switch (cat) {
    case 'joie': return context.tr('Joie');
    case 'reussite': return context.tr('Réussite');
    case 'compliments': return context.tr('Compliments');
    case 'amour': return context.tr('Amour');
    case 'surprise': return context.tr('Surprise');
    case 'taquinerie': return context.tr('Taquinerie');
    case 'soutien': return context.tr('Soutien');
    case 'colere': return context.tr('Colère');
    case 'reponses': return context.tr('Réponses');
    case 'contenus': return context.tr('Contenus');
    case 'fetes': return context.tr('Fêtes');
    case 'sport': return context.tr('Sport');
    case 'musique': return context.tr('Musique');
    case 'afrolook': return context.tr('Afrolook');
    default: return context.tr('Humeur');
  }
}

String _regionLabel(BuildContext context, String r) {
  switch (r) {
    case 'africa': return context.tr('Afrique');
    case 'caribbean': return context.tr('Caraïbes');
    case 'europe': return context.tr('Europe');
    case 'asia': return context.tr('Asie');
    case 'latam': return context.tr('Amérique latine');
    case 'mena': return context.tr('Moyen-Orient');
    default: return context.tr('Universel');
  }
}

class _Item {
  final Uint8List bytes;
  final String contentType;
  String category = 'reponses';
  final TextEditingController caption = TextEditingController();
  final TextEditingController gift = TextEditingController();
  _Item(this.bytes, this.contentType);
}

/// Assistant de dépôt d'un pack de stickers (Studio créateur).
/// Retourne `true` à la fermeture si le pack a été envoyé.
class NewPackWizard extends StatefulWidget {
  const NewPackWizard({super.key});

  @override
  State<NewPackWizard> createState() => _NewPackWizardState();
}

class _NewPackWizardState extends State<NewPackWizard> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  String _region = 'universal';
  bool _rights = false;
  bool _busy = false;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  final List<_Item> _items = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    for (final i in _items) {
      i.caption.dispose();
      i.gift.dispose();
    }
    super.dispose();
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i + 1).toLowerCase();
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      final problems = <String>[];
      for (final f in files) {
        if (_items.length >= _kMaxStickers) {
          problems.add(context.tr('Maximum {n} stickers par pack', {'n': _kMaxStickers}));
          break;
        }
        final name = f.name.isNotEmpty ? f.name : f.path;
        final ext = _ext(name);
        if (!['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) {
          problems.add(context.tr('{f} : format non accepté (PNG, JPG, WebP ou GIF)', {'f': name}));
          continue;
        }
        Uint8List bytes = await f.readAsBytes();
        final type = ext == 'gif' ? 'image/gif' : 'image/webp';
        if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
          final out = await _toWebp(f.path, bytes);
          if (out == null) {
            problems.add(context.tr('{f} : impossible de passer sous 600 Ko', {'f': name}));
            continue;
          }
          bytes = out;
        } else if (bytes.length > _kMaxBytes) {
          problems.add(context.tr('{f} : {n} Ko, maximum 600 Ko (réduis la taille ou la durée)',
              {'f': name, 'n': (bytes.length / 1024).round()}));
          continue;
        }
        if (bytes.length > _kMaxBytes) {
          problems.add(context.tr('{f} : impossible de passer sous 600 Ko', {'f': name}));
          continue;
        }
        _items.add(_Item(bytes, type));
      }
      if (problems.isNotEmpty) _error = problems.join('\n');
    } catch (e) {
      _error = context.tr('Impossible de lire les fichiers choisis');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Convertit une image fixe en WebP en réduisant qualité puis taille jusqu'à passer sous 600 Ko.
  Future<Uint8List?> _toWebp(String path, Uint8List original) async {
    const steps = [
      [90, 1024],
      [80, 1024],
      [70, 800],
      [55, 640],
      [40, 512],
    ];
    for (final s in steps) {
      try {
        final out = await FlutterImageCompress.compressWithList(
          original,
          format: CompressFormat.webp,
          quality: s[0],
          minWidth: s[1],
          minHeight: s[1],
        );
        if (out.isNotEmpty && out.length <= _kMaxBytes) return out;
      } catch (_) {}
    }
    return null;
  }

  int _parse(String s) => int.tryParse(s.trim()) ?? 0;

  String? _validate() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2 || name.length > 40) return context.tr('Le nom du pack doit faire entre 2 et 40 caractères');
    final price = int.tryParse(_priceCtrl.text.trim());
    if (price == null || price < 0 || price > 1000) return context.tr('Le prix du pack doit être entre 0 et 1000 pièces');
    if (_items.length < _kMinStickers) {
      return context.tr('Ajoute au moins {n} stickers', {'n': _kMinStickers});
    }
    for (final i in _items) {
      final g = i.gift.text.trim();
      if (g.isNotEmpty) {
        final v = int.tryParse(g);
        if (v == null || v < 0 || v > 500) return context.tr('Le prix d\'un sticker-cadeau doit être entre 0 et 500 pièces');
      }
    }
    if (!_rights) return context.tr('Tu dois certifier détenir tous les droits sur ces stickers');
    return null;
  }

  List<String> _keywords(String caption) {
    return caption
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 2)
        .take(6)
        .toList();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    final lang = trCurrentLanguage;
    try {
      const uuid = Uuid();
      final payload = <Map<String, dynamic>>[];
      for (var n = 0; n < _items.length; n++) {
        final it = _items[n];
        final path = 'sticker_submissions/$uid/${uuid.v4()}.webp';
        final task = FirebaseStorage.instance.ref(path).putData(it.bytes, SettableMetadata(contentType: it.contentType));
        task.snapshotEvents.listen((s) {
          if (!mounted || s.totalBytes == 0) return;
          setState(() => _progress = (n + s.bytesTransferred / s.totalBytes) / _items.length);
        });
        await task;
        final cap = it.caption.text.trim();
        payload.add({
          'path': path,
          'category': it.category,
          'captions': cap.isEmpty ? <String, String>{} : {lang: cap},
          'keywords': cap.isEmpty ? <String>[] : _keywords(cap),
          'giftPriceCoins': _parse(it.gift.text).clamp(0, 500),
        });
      }
      if (mounted) setState(() => _progress = 1);
      final r = await FirebaseFunctions.instance.httpsCallable('submitStickerPack').call({
        'name': _nameCtrl.text.trim(),
        'region': _region,
        'priceCoins': _parse(_priceCtrl.text).clamp(0, 1000),
        'stickers': payload,
      });
      final needsReview = (r.data is Map) && (r.data as Map)['needsReview'] == true;
      if (!mounted) return;
      var msg = context.tr('Pack envoyé : il sera vérifié avant publication');
      if (needsReview) msg += '. ${context.tr('Une vérification supplémentaire est nécessaire')}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _serverError(e);
      });
    } on FirebaseException catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.tr('Envoi des fichiers impossible, vérifie ta connexion et réessaie');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.tr('Une erreur est survenue, réessaie');
      });
    }
  }

  String _serverError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return context.tr('Pour déposer un pack, il faut un abonnement Premium ou Gold et un compte de plus de 30 jours');
      case 'already-exists':
        return context.tr('Un de tes stickers est une copie exacte d\'un sticker déjà présent dans Afrolook');
      case 'resource-exhausted':
        return context.tr('Tu as déjà 3 packs en attente de validation');
      case 'invalid-argument':
        return e.message ?? context.tr('Pack invalide');
      default:
        return e.message ?? context.tr('Une erreur est survenue, réessaie');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          elevation: 0,
          title: Text(context.tr('Déposer un pack'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _label(c, context.tr('Nom du pack')),
            TextField(
              controller: _nameCtrl,
              enabled: !_busy,
              maxLength: 40,
              style: TextStyle(color: c.textPrimary),
              decoration: _dec(c, context.tr('Ex. : Ambiance Abidjan')),
            ),
            _label(c, context.tr('Région')),
            DropdownButtonFormField<String>(
              value: _region,
              dropdownColor: c.surface,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: _dec(c, ''),
              items: [for (final r in _kRegions) DropdownMenuItem(value: r, child: Text(_regionLabel(context, r)))],
              onChanged: _busy ? null : (v) => setState(() => _region = v ?? 'universal'),
            ),
            _label(c, context.tr('Prix du pack en pièces (0 = gratuit)')),
            TextField(
              controller: _priceCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              style: TextStyle(color: c.textPrimary),
              decoration: _dec(c, '0 - 1000'),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Text(
                  context.tr('Stickers ({a}/{b})', {'a': _items.length, 'b': _kMaxStickers}),
                  style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: (_busy || _picking || _items.length >= _kMaxStickers) ? null : _pick,
                icon: _picking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: Text(context.tr('Choisir des fichiers')),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              context.tr('Entre 4 et 24 fichiers PNG, JPG, WebP ou GIF, 600 Ko maximum chacun.'),
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _items.length; i++) _itemCard(c, i),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _rights,
              onChanged: _busy ? null : (v) => setState(() => _rights = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: c.primary,
              title: Text(context.tr('Je certifie détenir tous les droits sur ces stickers'),
                  style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 13)),
              ),
            const SizedBox(height: 14),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress, color: c.primary, backgroundColor: c.surfaceVariant, minHeight: 6),
              const SizedBox(height: 6),
              Text(
                _progress >= 1
                    ? context.tr('Envoi du pack…')
                    : context.tr('Envoi des fichiers… {n} %', {'n': (_progress * 100).round()}),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(context.tr('Envoyer pour validation'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(AppColors c, int i) {
    final it = _items[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 72,
              color: c.surfaceVariant,
              child: Image.memory(it.bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded)),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(it.bytes.length / 1024).round()} Ko', style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: it.category,
              isDense: true,
              dropdownColor: c.surface,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: _dec(c, context.tr('Catégorie')),
              items: [for (final k in _kCategories) DropdownMenuItem(value: k, child: Text(_categoryLabel(context, k)))],
              onChanged: _busy ? null : (v) => setState(() => it.category = v ?? 'reponses'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: it.caption,
              enabled: !_busy,
              maxLength: 40,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: _dec(c, context.tr('Légende (facultatif)')).copyWith(counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: it.gift,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: _dec(c, context.tr('Prix sticker-cadeau, 0 à 500 pièces (facultatif)')),
            ),
          ]),
        ),
        IconButton(
          tooltip: context.tr('Enlever ce sticker'),
          icon: Icon(Icons.close_rounded, color: c.textSecondary),
          onPressed: _busy
              ? null
              : () => setState(() => _items.removeAt(i)),
        ),
      ]),
    );
  }

  Widget _label(AppColors c, String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint.isEmpty ? null : hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        filled: true,
        fillColor: c.surfaceVariant,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}
