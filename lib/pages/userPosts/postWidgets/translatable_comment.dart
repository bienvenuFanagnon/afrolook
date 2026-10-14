import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';

/// Lien "Voir la traduction" pour les commentaires et réponses.
/// Appelle `translateComment` (CF), met en cache côté serveur dans
/// `PostComments/{commentId}.translations.{targetLang}` (ou
/// `replyTranslations.{replyId}.{targetLang}` pour une réponse).
/// [onToggle] est appelé avec le texte traduit ou `null` pour revenir à
/// l'original.
class TranslatableComment extends StatefulWidget {
  final String commentId;
  final String text;
  final String targetLang;
  final void Function(String? translatedText) onToggle;
  final String? replyId;
  final TextStyle? style;

  const TranslatableComment({
    super.key,
    required this.commentId,
    required this.text,
    required this.targetLang,
    required this.onToggle,
    this.replyId,
    this.style,
  });

  @override
  State<TranslatableComment> createState() => _TranslatableCommentState();
}

class _TranslatableCommentState extends State<TranslatableComment> {
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
      final callable = FirebaseFunctions.instance.httpsCallable('translateComment');
      final result = await callable.call(<String, dynamic>{
        'commentId': widget.commentId,
        'text': widget.text,
        'targetLang': widget.targetLang,
        if (widget.replyId != null) 'replyId': widget.replyId,
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
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.textSecondary),
            ),
            const SizedBox(width: 5),
            Text(
              l10n.translating,
              style: (widget.style ?? const TextStyle()).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: GestureDetector(
        onTap: _onTap,
        child: Text(
          _showingTranslation ? l10n.seeOriginal : l10n.seeTranslation,
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
