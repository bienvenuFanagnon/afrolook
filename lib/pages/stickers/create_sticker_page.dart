import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'sticker_widgets.dart';

const int _kStillMaxBytes = 300 * 1024;
const int _kAnimMaxBytes = 600 * 1024;
const int _kVideoMaxBytes = 3 * 1024 * 1024;
// 3 s exigées ; une petite marge absorbe l'arrondi des caméras (ex. 3,02 s).
const int _kVideoMaxMs = 3150;

enum _Kind { none, still, anim, video }

/// « Créer mon sticker » : image (recadrage carré + WebP ≤ 300 Ko), GIF / WebP animé (≤ 600 Ko)
/// ou vidéo de 3 s maximum (compressée puis convertie par le serveur). Réservé aux abonnés.
/// Se ferme avec `true` quand un sticker a été ajouté.
class CreateStickerPage extends StatefulWidget {
  const CreateStickerPage({super.key});

  @override
  State<CreateStickerPage> createState() => _CreateStickerPageState();
}

class _CreateStickerPageState extends State<CreateStickerPage> {
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _cropKey = GlobalKey();

  _Kind _kind = _Kind.none;
  Uint8List? _bytes; // image fixe (source) ou animation
  String _animMime = 'image/gif';
  XFile? _video;
  VideoPlayerController? _videoCtrl;

  bool _busy = false;
  String _status = '';
  String? _error;
  bool? _added;
  String _resultText = '';

  int _count = 0;
  int _quota = 0;
  bool _loadedCount = false;

  @override
  void initState() {
    super.initState();
    _quota = StickerService.personalQuota(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);
    _loadCount();
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  String get _uid => Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id ?? '';

  Future<void> _loadCount() async {
    try {
      final list = await StickerService.instance.loadUserStickers(_uid);
      if (mounted) setState(() {
        _count = list.length;
        _loadedCount = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadedCount = true);
    }
  }

  String _kb(int bytes) => '${(bytes / 1024).round()} Ko';

  void _reset() {
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _kind = _Kind.none;
    _bytes = null;
    _video = null;
    _error = null;
    _added = null;
    _resultText = '';
  }

  // ── Choix du fichier ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    final anim = _animatedKind(bytes);
    setState(() {
      _reset();
      _bytes = bytes;
      if (anim == null) {
        _kind = _Kind.still;
      } else if (bytes.length > _kAnimMaxBytes) {
        _bytes = null;
        _error = context.tr('Cette animation pèse {a} : le maximum est 600 Ko. Choisis-en une plus légère.', {'a': _kb(bytes.length)});
      } else {
        _kind = _Kind.anim;
        _animMime = anim;
      }
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    final ctrl = VideoPlayerController.file(File(x.path));
    try {
      await ctrl.initialize();
    } catch (_) {
      await ctrl.dispose();
      if (mounted) setState(() {
        _reset();
        _error = context.tr('Impossible de lire cette vidéo.');
      });
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    final ms = ctrl.value.duration.inMilliseconds;
    if (ms > _kVideoMaxMs) {
      await ctrl.dispose();
      setState(() {
        _reset();
        _error = context.tr('La vidéo dure {a} s : un sticker fait 3 secondes au maximum.', {'a': (ms / 1000).toStringAsFixed(1)});
      });
      return;
    }
    await ctrl.setLooping(true);
    await ctrl.setVolume(0);
    await ctrl.play();
    setState(() {
      _reset();
      _video = x;
      _videoCtrl = ctrl;
      _kind = _Kind.video;
    });
  }

  /// 'image/gif' ou 'image/webp' si les octets sont une animation, sinon null.
  String? _animatedKind(Uint8List b) {
    if (b.length > 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return 'image/gif';
    if (b.length > 30 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP' &&
        String.fromCharCodes(b.sublist(12, 16)) == 'VP8X' &&
        (b[20] & 0x02) != 0) {
      return 'image/webp';
    }
    return null;
  }

  // ── Création ───────────────────────────────────────────────────────────────

  Future<void> _create() async {
    if (_busy || _kind == _Kind.none) return;
    if (_quota > 0 && _loadedCount && _count >= _quota) {
      setState(() => _error = context.tr('Quota atteint : supprime un sticker pour en créer un autre.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _added = null;
      _resultText = '';
    });
    try {
      if (_kind == _Kind.video) {
        await _createFromVideo();
      } else {
        await _createFromImage();
      }
    } catch (e) {
      debugPrint('[Stickers] création échouée: $e');
      if (mounted) setState(() => _error = context.tr('Création impossible. Vérifie ta connexion et réessaie.'));
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _status = '';
      });
    }
  }

  /// Image fixe : recadrage carré -> WebP ≤ 300 Ko. Animation : envoyée telle quelle.
  Future<void> _createFromImage() async {
    Uint8List data;
    String mime = 'image/webp';
    if (_kind == _Kind.still) {
      setState(() => _status = context.tr('Recadrage et compression…'));
      final png = await _captureCrop();
      if (png == null) {
        setState(() => _error = context.tr('Recadrage impossible, réessaie.'));
        return;
      }
      final webp = await _compressStill(png);
      if (webp == null) {
        setState(() => _error = context.tr('Impossible de descendre sous 300 Ko. Essaie une image plus simple.'));
        return;
      }
      data = webp;
    } else {
      data = _bytes!;
      mime = _animMime;
      if (data.length > _kAnimMaxBytes) {
        setState(() => _error = context.tr('Cette animation pèse {a} : le maximum est 600 Ko.', {'a': _kb(data.length)}));
        return;
      }
    }

    setState(() => _status = context.tr('Envoi…'));
    final uid = _uid;
    final db = FirebaseFirestore.instance;
    final ref = db.collection('UserStickers').doc();
    final path = 'user_stickers/$uid/${ref.id}.webp';
    final file = FirebaseStorage.instance.ref(path);
    await file.putData(data, SettableMetadata(contentType: mime));
    final url = await file.getDownloadURL();
    await ref.set({
      'ownerId': uid,
      'storagePath': path,
      'url': url,
      'thumbUrl': url,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    if (mounted) setState(() => _status = context.tr('Vérification par Afrolook…'));
    final verdict = await _waitVerdict(ref);
    if (!mounted) return;
    if (verdict == 'ok') {
      _finish(true, data.length);
    } else if (verdict == 'refused') {
      setState(() {
        _added = false;
        _resultText = context.tr('Refusé (quota, poids ou abonnement)');
      });
      _loadCount();
    } else {
      setState(() {
        _added = null;
        _resultText = context.tr('Vérification en cours : ton sticker apparaîtra dans Mes stickers s\'il est accepté.');
      });
    }
  }

  void _finish(bool ok, int bytes) {
    final left = (_quota - (_count + 1)).clamp(0, _quota);
    setState(() {
      _added = ok;
      _count += 1;
      _resultText = context.tr('Ajouté à Mes stickers') +
          '\n' +
          context.tr('Poids final : {a}', {'a': _kb(bytes)}) +
          ' · ' +
          context.tr('Il te reste {a} sur {b}', {'a': left, 'b': _quota});
    });
  }

  /// Le serveur passe le document à `active` ou le supprime : on écoute quelques secondes.
  Future<String> _waitVerdict(DocumentReference<Map<String, dynamic>> ref) async {
    final done = Completer<String>();
    var seen = false;
    final sub = ref.snapshots().listen((s) {
      if (done.isCompleted) return;
      if (s.exists) {
        seen = true;
        if (s.data()?['status'] == 'active') done.complete('ok');
      } else if (seen) {
        done.complete('refused');
      }
    }, onError: (_) {
      if (!done.isCompleted) done.complete('timeout');
    });
    final res = await done.future.timeout(const Duration(seconds: 20), onTimeout: () => 'timeout');
    await sub.cancel();
    return res;
  }

  /// Capture la zone de recadrage carrée (512 px) en PNG.
  Future<Uint8List?> _captureCrop() async {
    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final side = boundary.size.width;
      final image = await boundary.toImage(pixelRatio: 512 / side);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// WebP ≤ 300 Ko : on baisse la qualité puis la taille jusqu'à passer sous la limite.
  Future<Uint8List?> _compressStill(Uint8List png) async {
    for (final dim in const [512, 384, 256]) {
      for (final q in const [90, 80, 70, 60, 50, 40, 30]) {
        final out = await FlutterImageCompress.compressWithList(
          png,
          format: CompressFormat.webp,
          quality: q,
          minWidth: dim,
          minHeight: dim,
        );
        if (out.isNotEmpty && out.length <= _kStillMaxBytes) return out;
      }
    }
    return null;
  }

  /// Vidéo : compression (qualité basse, sans son), envoi dans Storage puis conversion serveur.
  Future<void> _createFromVideo() async {
    final v = _video;
    if (v == null) return;
    setState(() => _status = context.tr('Compression de la vidéo…'));
    await _videoCtrl?.pause();
    final info = await VideoCompress.compressVideo(
      v.path,
      quality: VideoQuality.LowQuality,
      includeAudio: false,
      deleteOrigin: false,
    );
    final out = info?.file;
    if (out == null) {
      setState(() => _error = context.tr('Compression impossible pour cette vidéo.'));
      return;
    }
    final size = await out.length();
    if (size > _kVideoMaxBytes) {
      setState(() => _error = context.tr('La vidéo compressée pèse {a} : le maximum est 3 Mo.', {'a': _kb(size)}));
      return;
    }

    setState(() => _status = context.tr('Envoi…'));
    final uid = _uid;
    final id = FirebaseFirestore.instance.collection('UserStickers').doc().id;
    final path = 'sticker_video_uploads/$uid/$id.mp4';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(out, SettableMetadata(contentType: 'video/mp4'));

    if (mounted) setState(() => _status = context.tr('Conversion en sticker animé…'));
    try {
      await FirebaseFunctions.instance
          .httpsCallable('convertStickerVideo')
          .call<dynamic>({'path': path}).timeout(const Duration(seconds: 150));
    } on FirebaseFunctionsException catch (e) {
      try {
        await ref.delete();
      } catch (_) {}
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'resource-exhausted':
          msg = context.tr('Quota atteint : supprime un sticker pour en créer un autre.');
          break;
        case 'permission-denied':
          msg = context.tr('Les stickers sont réservés aux abonnés Premium');
          break;
        case 'unavailable':
        case 'unimplemented':
        case 'not-found':
        case 'deadline-exceeded':
          msg = context.tr('La conversion des vidéos n\'est pas disponible pour le moment. Réessaie plus tard ou choisis une image ou un GIF.');
          break;
        default:
          msg = (e.message ?? '').isNotEmpty ? e.message! : context.tr('Création impossible. Vérifie ta connexion et réessaie.');
      }
      setState(() => _error = msg);
      return;
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _added = null;
          _resultText = context.tr('Conversion en cours : ton sticker apparaîtra dans Mes stickers dans un instant.');
        });
      }
      return;
    }
    if (!mounted) return;
    _finish(true, size);
  }

  // ── Interface ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_quota <= 0) {
      return Scaffold(
        backgroundColor: c.surface,
        appBar: _appBar(c),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sticky_note_2_outlined, color: kStickerGold, size: 46),
                const SizedBox(height: 12),
                Text(context.tr('Créer ses stickers, c\'est Premium'),
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
                  onPressed: () => showStickerPremiumInvite(context),
                  child: Text(context.tr('Voir les abonnements')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.surface,
      appBar: _appBar(c),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              _loadedCount
                  ? context.tr('Mes stickers {a} / {b}', {'a': _count, 'b': _quota})
                  : context.tr('Mes stickers'),
              style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildPreview(c),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _pickButton(c, Icons.image_outlined, context.tr('Image, GIF ou WebP'), _busy ? null : _pickImage)),
                if (!kIsWeb) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _pickButton(c, Icons.videocam_outlined, context.tr('Vidéo (3 s max)'), _busy ? null : _pickVideo)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Image fixe : recadrée en carré, WebP de 300 Ko maximum. GIF ou WebP animé : 600 Ko maximum. Vidéo : 3 secondes, sans son.'),
              style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _banner(c, _error!, c.danger, Icons.error_outline_rounded),
            ],
            if (_resultText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _banner(
                c,
                _resultText,
                _added == true ? c.success : (_added == false ? c.danger : c.textSecondary),
                _added == true ? Icons.check_circle_outline_rounded : (_added == false ? Icons.block_rounded : Icons.hourglass_bottom_rounded),
              ),
            ],
            const SizedBox(height: 16),
            if (_added == true)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr('Terminé'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: (_busy || _kind == _Kind.none) ? null : _create,
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary)),
                            const SizedBox(width: 10),
                            Flexible(child: Text(_status, overflow: TextOverflow.ellipsis)),
                          ],
                        )
                      : Text(context.tr('Créer mon sticker'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(AppColors c) => AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr('Créer mon sticker'),
            style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        leading: BackButton(onPressed: () => Navigator.pop(context, _added == true)),
      );

  Widget _pickButton(AppColors c, IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.primary.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _banner(AppColors c, String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35))),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColors c) {
    final side = (MediaQuery.of(context).size.width - 32).clamp(200.0, 320.0);
    Widget frame(Widget child) => Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        );
    switch (_kind) {
      case _Kind.none:
        return frame(Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_reaction_outlined, size: 46, color: c.textSecondary.withOpacity(0.6)),
              const SizedBox(height: 8),
              Text(context.tr('Choisis une image, un GIF ou une vidéo'), style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ],
          ),
        ));
      case _Kind.still:
        // Zone carrée : pincer pour zoomer, glisser pour cadrer ; la capture donne l'image finale.
        return Column(
          children: [
            Center(
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: RepaintBoundary(
                  key: _cropKey,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Image.memory(_bytes!, fit: BoxFit.contain, width: side, height: side),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(context.tr('Pince pour zoomer, glisse pour recadrer en carré'),
                style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          ],
        );
      case _Kind.anim:
        return Column(
          children: [
            frame(Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true)),
            const SizedBox(height: 6),
            Text(context.tr('Animation de {a}', {'a': _kb(_bytes!.length)}), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          ],
        );
      case _Kind.video:
        final ctrl = _videoCtrl!;
        return Column(
          children: [
            frame(FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            )),
            const SizedBox(height: 6),
            Text(
              context.tr('Vidéo de {a} s, sans son', {'a': (ctrl.value.duration.inMilliseconds / 1000).toStringAsFixed(1)}),
              style: TextStyle(color: c.textSecondary, fontSize: 11.5),
            ),
          ],
        );
    }
  }
}
