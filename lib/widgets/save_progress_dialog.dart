import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

class _SaveState {
  const _SaveState({this.progress = 0, this.step = '', this.finished = false, this.error});
  final double progress;
  final String step;
  final bool finished;
  final String? error;
}

/// Fenêtre d'enregistrement dans la galerie (10/11/2026) : une barre de progression et l'étape en cours, impossible à fermer pendant le travail, puis un résultat CLAIR
/// (✅ enregistré, ou ❌ avec la raison) qui reste affiché jusqu'au « OK ». Avant, une simple feuille se fermait au bout de quelques secondes : la personne ne savait pas si c'était
/// enregistré, et le fichier n'arrivait dans la galerie que bien plus tard (le temps de la signature Afrolook).
class SaveProgressDialog {
  SaveProgressDialog._();

  /// Lance [task] sous la fenêtre. [task] rend null si tout s'est bien passé, sinon le message d'erreur à montrer ; elle appelle `report(progression 0 à 1, étape)` au fil du travail.
  /// Rend vrai si l'enregistrement a réussi. [doneText] : la phrase de réussite.
  static Future<bool> run(BuildContext context, {required String doneText, required Future<String?> Function(void Function(double progress, String step) report) task}) async {
    final state = ValueNotifier<_SaveState>(const _SaveState());
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(canPop: false, child: _SaveDialog(state: state, doneText: doneText, onClose: () => Navigator.of(ctx).pop())),
    );
    String? error;
    try {
      error = await task((p, s) => state.value = _SaveState(progress: p.clamp(0.0, 1.0).toDouble(), step: s));
    } catch (_) {
      error = tr('L\'enregistrement a échoué. Réessaie dans un instant.');
    }
    state.value = _SaveState(progress: 1, finished: true, error: error);
    await dialog;
    state.dispose();
    return error == null;
  }
}

class _SaveDialog extends StatelessWidget {
  const _SaveDialog({required this.state, required this.doneText, required this.onClose});
  final ValueNotifier<_SaveState> state;
  final String doneText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<_SaveState>(
      valueListenable: state,
      builder: (_, s, __) {
        final ok = s.finished && s.error == null;
        final failed = s.finished && s.error != null;
        return AlertDialog(
          key: const ValueKey('save_progress_dialog'),
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : (failed ? Icons.error_rounded : Icons.download_rounded), color: ok ? const Color(0xFF2ECC71) : (failed ? c.danger : c.accentText)),
            const SizedBox(width: 10),
            Expanded(child: Text(ok ? tr('Enregistré ✅') : (failed ? tr('Échec de l\'enregistrement') : tr('Enregistrement en cours…')), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 17))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!s.finished) ...[
              Text(s.step.isEmpty ? tr('Préparation…') : s.step, style: TextStyle(color: c.textPrimary, height: 1.35)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(key: const ValueKey('save_progress_bar'), value: s.progress <= 0 ? null : s.progress, minHeight: 10, color: c.primary, backgroundColor: c.border),
              ),
              const SizedBox(height: 6),
              Text(s.progress <= 0 ? '' : '${(s.progress * 100).round()} %', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              Text(tr('Patiente un instant : ne ferme pas l\'application. Le fichier arrive dans ta galerie dès que c\'est terminé.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
            ] else
              Text(ok ? doneText : (s.error ?? ''), key: ValueKey(ok ? 'save_done_text' : 'save_error_text'), style: TextStyle(color: c.textPrimary, height: 1.4)),
          ]),
          actions: s.finished ? [FilledButton(key: const ValueKey('save_progress_ok'), onPressed: onClose, style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.black), child: const Text('OK'))] : null,
        );
      },
    );
  }
}
