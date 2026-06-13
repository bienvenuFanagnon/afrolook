import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';

/// Petit lien "Voir la traduction" façon Facebook : tap → appelle la Cloud
/// Function `translatePostDescription`, affiche un loader puis remplace
/// [originalText] par la traduction (mise en cache côté serveur dans
/// `Posts/{postId}.translations.{targetLang}`). Un nouveau tap revient au
/// texte original ("Voir l'original").
///
/// Ce widget ne ré-affiche pas le texte original lui-même : il est conçu
/// pour être placé juste sous le `Text`/`HashTagText` existant. Quand une
/// traduction est affichée, [onTranslated] est appelé avec le texte traduit
/// (ou `null` pour revenir au texte original) afin que le parent puisse
/// mettre à jour l'affichage du texte principal.
class TranslatableDescription extends StatefulWidget {
  final String postId;
  final String text;
  final String targetLang;
  final void Function(String? translatedText) onToggle;
  final TextStyle? style;

  const TranslatableDescription({
    super.key,
    required this.postId,
    required this.text,
    required this.targetLang,
    required this.onToggle,
    this.style,
  });

  @override
  State<TranslatableDescription> createState() => _TranslatableDescriptionState();
}

class _TranslatableDescriptionState extends State<TranslatableDescription> {
  bool _isLoading = false;
  bool _showingTranslation = false;
  String? _translatedText;

  Future<void> _onTap() async {
    if (_showingTranslation) {
      setState(() => _showingTranslation = false);
      widget.onToggle(null);
      return;
    }

    if (_translatedText != null) {
      setState(() => _showingTranslation = true);
      widget.onToggle(_translatedText);
      return;
    }

    if (widget.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('translatePostDescription');
      final result = await callable.call(<String, dynamic>{
        'postId': widget.postId,
        'text': widget.text,
        'targetLang': widget.targetLang,
      });

      final translated = (result.data as Map?)?['translatedText'] as String?;
      if (!mounted) return;

      if (translated != null && translated.trim().isNotEmpty) {
        setState(() {
          _translatedText = translated;
          _showingTranslation = true;
          _isLoading = false;
        });
        widget.onToggle(translated);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    if (widget.text.trim().isEmpty) return const SizedBox.shrink();

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.translating,
              style: (widget.style ?? const TextStyle()).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: _onTap,
        child: Text(
          _showingTranslation ? l10n.seeOriginal : l10n.seeTranslation,
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
