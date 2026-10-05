import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../services/quiz/quiz_service.dart';
import '../../../theme/app_colors.dart';
import 'hawk_mascot.dart';
import 'quiz_widgets.dart';

const _contact = 'officiel.afrolook@gmail.com';

/// Vérifie que le joueur a accepté l'avertissement du quiz ; sinon l'affiche. Renvoie vrai s'il peut jouer.
Future<bool> quizEnsureConsent(BuildContext context) async {
  if (await QuizService.instance.consentOk()) return true;
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConsentSheet(),
  );
  if (ok == true) {
    await QuizService.instance.acceptConsent();
    return true;
  }
  return false;
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, height: 1.35, fontSize: 13.5))),
          ]),
        );
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const HawkMascot(size: 64, mood: HawkMood.wave),
              const SizedBox(width: 10),
              Expanded(child: Text(context.tr('Avant de jouer'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: c.textPrimary))),
            ]),
            const SizedBox(height: 8),
            point(Icons.menu_book_rounded, context.tr('Le Quiz est un jeu de culture générale. Les questions sont préparées avec soin, mais une erreur est toujours possible.')),
            point(Icons.flag_rounded, context.tr('Si une réponse validée te semble fausse, signale-la avec le bouton « Signaler une erreur » sous la question. Nous vérifions et corrigeons.')),
            point(Icons.mail_rounded, context.tr('Tu peux aussi nous écrire : {mail}', {'mail': _contact})),
            point(Icons.info_outline_rounded, context.tr('Les réponses du Quiz ne constituent pas une source officielle. Les points n\'ont aucune valeur en argent.')),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _agree = !_agree),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Checkbox(value: _agree, activeColor: c.primary, onChanged: (v) => setState(() => _agree = v ?? false)),
                  Expanded(child: Text(context.tr('J\'ai lu et j\'accepte ces conditions.'), style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary))),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            QuizChunkyButton(
              label: context.tr('Commencer'),
              icon: Icons.play_arrow_rounded,
              onPressed: _agree ? () => Navigator.pop(context, true) : null,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Plus tard'), style: TextStyle(color: c.textSecondary)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Petit lien « Signaler une erreur » sous une question corrigée.
class QuizReportButton extends StatelessWidget {
  const QuizReportButton({super.key, required this.kind, required this.question, required this.options, required this.shown, this.chosen, this.n});
  final String kind, question, shown;
  final String? chosen;
  final int? n;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextButton.icon(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      onPressed: () => showQuizReportSheet(context, kind: kind, n: n, question: question, options: options, shown: shown, chosen: chosen),
      icon: Icon(Icons.flag_outlined, size: 16, color: c.textSecondary),
      label: Text(context.tr('Signaler une erreur'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Formulaire de signalement : motif et commentaire facultatif.
Future<void> showQuizReportSheet(
  BuildContext context, {
  required String kind,
  int? n,
  required String question,
  required List<String> options,
  required String shown,
  String? chosen,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(kind: kind, n: n, question: question, options: options, shown: shown, chosen: chosen),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.kind, required this.n, required this.question, required this.options, required this.shown, required this.chosen});
  final String kind, question, shown;
  final String? chosen;
  final int? n;
  final List<String> options;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String _reason = 'wrong';
  final TextEditingController _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await QuizService.instance.report(
        kind: widget.kind,
        n: widget.n,
        question: widget.question,
        options: widget.options,
        shown: widget.shown,
        chosen: widget.chosen,
        reason: _reason,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final c = AppColors.of(context);
      final text = context.tr('Merci ! Nous vérifions cette question.');
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)), backgroundColor: c.primary));
    } on QuizException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      quizToast(context, e.code.contains('TOO_MANY') ? context.tr('Tu as déjà envoyé beaucoup de signalements aujourd\'hui. Merci !') : context.tr('Une erreur est survenue, réessaie.'), error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget reason(String key, String label) => RadioListTile<String>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: c.primary,
          value: key,
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v ?? 'wrong'),
          title: Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Signaler une erreur'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.question, style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary, fontSize: 13, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(context.tr('Réponse validée : {r}', {'r': widget.shown}), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ]),
              ),
              const SizedBox(height: 6),
              reason('wrong', context.tr('La réponse validée est fausse')),
              reason('ambiguous', context.tr('Plusieurs réponses sont possibles')),
              reason('typo', context.tr('Faute ou texte incorrect')),
              reason('other', context.tr('Autre problème')),
              TextField(
                controller: _comment,
                maxLength: 300,
                maxLines: 3,
                minLines: 2,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: context.tr('Explique-nous (facultatif) : quelle est la bonne réponse selon toi ?'),
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              QuizChunkyButton(label: context.tr('Envoyer'), icon: Icons.send_rounded, loading: _sending, onPressed: _sending ? null : _send),
            ]),
          ),
        ),
      ),
    );
  }
}
