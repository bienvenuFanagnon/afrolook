import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/tr.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/canaux_api.dart';
import '../../theme/app_colors.dart';

/// « Voir la traduction » sous un message texte reçu (discussions privées et groupes, 21/11/2026).
///
/// Les messages sont chiffrés : seule l'application a le texte. Il n'est envoyé à l'API (`POST /translate/text`, même service et mêmes
/// limites que les commentaires) que lorsque la personne appuie sur le lien ; le serveur n'enregistre rien. La traduction est gardée en
/// mémoire le temps de la session, et s'affiche sous le message ; « Voir l'original » la masque.
class ChatMessageTranslation extends StatefulWidget {
  const ChatMessageTranslation({super.key, required this.text, this.compact = false});

  final String text;
  final bool compact;

  /// Traductions déjà faites pendant la session (texte + langue -> traduction).
  static final Map<String, String> _cache = {};

  /// Texte qui vaut la peine d'être traduit : pas vide, pas chiffré, pas seulement des emojis ou des chiffres.
  static bool worth(String text) {
    final t = text.trim();
    if (t.isEmpty || t.startsWith('enc:')) return false;
    return RegExp(r'[A-Za-zÀ-ÿ؀-ۿ一-鿿]').hasMatch(t);
  }

  @override
  State<ChatMessageTranslation> createState() => _ChatMessageTranslationState();
}

class _ChatMessageTranslationState extends State<ChatMessageTranslation> {
  bool _loading = false;
  bool _shown = false;
  String? _translated;

  String get _lang => Localizations.localeOf(context).languageCode;
  String get _key => '$_lang|${widget.text}';

  Future<void> _toggle() async {
    if (_shown) {
      setState(() => _shown = false);
      return;
    }
    final cached = _translated ?? ChatMessageTranslation._cache[_key];
    if (cached != null) {
      setState(() {
        _translated = cached;
        _shown = true;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiGateway.instance.client.post('/translate/text', body: {'text': widget.text, 'target_lang': _lang});
      final d = ApiClient.data(r);
      final t = d is Map ? d['translated_text'] as String? : null;
      if (!mounted) return;
      if (t != null && t.trim().isNotEmpty) {
        ChatMessageTranslation._cache[_key] = t;
        setState(() {
          _translated = t;
          _shown = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(CanauxApi.message(e, fallback: context.tr('Traduction impossible pour le moment.')))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ChatMessageTranslation.worth(widget.text)) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final linkStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_shown && _translated != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: c.accentText, width: 2)),
            ),
            child: Text(_translated!, style: TextStyle(fontSize: widget.compact ? 13 : 14, color: c.textPrimary, height: 1.35)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _loading
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: c.textSecondary)),
                  const SizedBox(width: 5),
                  Text(l10n.translating, style: linkStyle.copyWith(fontWeight: FontWeight.w500)),
                ])
              : GestureDetector(
                  onTap: _toggle,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.translate_rounded, size: 12, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Text(_shown ? l10n.seeOriginal : l10n.seeTranslation, style: linkStyle),
                  ]),
                ),
        ),
      ],
    );
  }
}
