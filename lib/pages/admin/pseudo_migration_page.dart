import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/canal_tag.dart';
import '../../widgets/pseudo_tag.dart';

/// Admin — Migration des pseudos vers le format « prenom.nom » (une seule exécution).
///
/// 1) « Simuler » parcourt tous les comptes SANS rien écrire et montre ce qui changerait.
/// 2) « Lancer la migration » applique par lots ; le serveur la verrouille une fois terminée.
/// Règle : minuscules, espaces / _ / - → point, accents retirés, seuls a-z 0-9 « . ».
class PseudoMigrationPage extends StatefulWidget {
  /// true : migration des noms de canaux (fonction migrateCanalNames) au lieu des pseudos.
  final bool canaux;
  const PseudoMigrationPage({super.key, this.canaux = false});

  @override
  State<PseudoMigrationPage> createState() => _PseudoMigrationPageState();
}

class _PseudoMigrationPageState extends State<PseudoMigrationPage> {
  final _fn = FirebaseFunctions.instance;

  Map<String, dynamic>? _status; // état enregistré côté serveur
  bool _busy = false;
  String _progress = '';
  String? _error;

  // Résultat de la dernière simulation
  int _scanned = 0, _changed = 0, _skipped = 0;
  final List<Map<String, dynamic>> _sample = [];
  final List<Map<String, dynamic>> _skippedList = [];
  bool _simulated = false;

  bool get _done => _status?['status'] == 'done';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final res = await _fn.httpsCallable(widget.canaux ? 'migrateCanalNames' : 'migratePseudos', options: HttpsCallableOptions(timeout: const Duration(minutes: 9))).call(data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> _loadStatus() async {
    try {
      final r = await _call({'action': 'status'});
      if (mounted) setState(() => _status = Map<String, dynamic>.from((r['status'] as Map?) ?? {}));
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  String _msg(Object e) => e is FirebaseFunctionsException ? (e.message ?? e.code) : '$e';

  Future<void> _run({required bool dryRun}) async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = dryRun ? 'Simulation en cours…' : 'Migration en cours…';
      if (dryRun) {
        _scanned = _changed = _skipped = 0;
        _sample.clear();
        _skippedList.clear();
        _simulated = false;
      }
    });
    try {
      String? cursor = dryRun ? null : (_status?['lastCursor'] as String?);
      var batches = 0;
      while (true) {
        final r = await _call({'dryRun': dryRun, 'limit': 300, if (cursor != null) 'cursor': cursor});
        batches++;
        _scanned += (r['scanned'] as num?)?.toInt() ?? 0;
        _changed += (r['changed'] as num?)?.toInt() ?? 0;
        _skipped += (r['skipped'] as num?)?.toInt() ?? 0;
        if (dryRun) {
          for (final c in (r['changes'] as List? ?? [])) {
            if (_sample.length < 40) _sample.add(Map<String, dynamic>.from(c as Map));
          }
          for (final c in (r['skippedList'] as List? ?? [])) {
            if (_skippedList.length < 40) _skippedList.add(Map<String, dynamic>.from(c as Map));
          }
        }
        if (mounted) setState(() => _progress = '${dryRun ? 'Simulation' : 'Migration'} : $_scanned comptes parcourus…');
        if (r['done'] == true) break;
        cursor = r['nextCursor'] as String?;
        if (cursor == null || batches > 500) break;
      }
      if (dryRun) _simulated = true;
      await _loadStatus();
      if (mounted) setState(() => _progress = dryRun ? 'Simulation terminée.' : 'Migration terminée.');
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndRun() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lancer la migration ?'),
        content: Text('$_changed ${widget.canaux ? 'nom(s) de canal' : 'pseudo(s)'} vont être modifiés. Cette opération ne peut être faite qu\'une seule fois. '
            'Pense à avoir sauvegardé Firestore avant.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lancer')),
        ],
      ),
    );
    if (ok == true) _run(dryRun: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final st = (_status?['status'] as String?) ?? 'never';
    final label = {
      'never': 'Jamais lancée',
      'running': 'En cours (interrompue ? relance pour reprendre)',
      'done': 'Terminée — verrouillée',
    }[st] ?? st;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(widget.canaux ? 'Migration des canaux' : 'Migration des pseudos'),
      ),
      body: CenteredContent(
        maxWidth: 700,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _card(c, [
            Row(children: [
              Icon(_done ? Icons.check_circle_rounded : Icons.schedule_rounded, color: _done ? c.primary : c.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
            const SizedBox(height: 8),
            Text(widget.canaux
                ? 'Format cible : mot.mot (minuscules, points, 3 à 30 caractères). Exemple : Mode Afro → mode.afro.'
                : 'Format cible : prenom.nom (minuscules, points, 3 à 20 caractères). Exemple : Olivier_Bernard → olivier.bernard.',
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            if (_status != null && st != 'never') ...[
              const SizedBox(height: 8),
              Text('Modifiés : ${_status!['changed'] ?? 0} · avec numéro : ${_status!['suffixed'] ?? 0} · ignorés : ${_status!['skipped'] ?? 0}',
                  style: TextStyle(color: c.textPrimary, fontSize: 13)),
            ],
          ]),
          const SizedBox(height: 12),
          if (!_done) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(dryRun: true),
              icon: const Icon(Icons.search_rounded),
              label: const Text('1. Simuler (rien n\'est modifié)'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.danger),
              onPressed: (_busy || !_simulated) ? null : _confirmAndRun,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_simulated ? '2. Lancer la migration (une seule fois)' : '2. Lancer — simule d\'abord'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_progress.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_progress, style: TextStyle(color: c.textSecondary))),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700))),
          if (_simulated) ...[
            const SizedBox(height: 16),
            _card(c, [
              Text('Résultat de la simulation', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$_scanned comptes parcourus · $_changed à modifier · $_skipped ignorés (trop courts)',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              for (final s in _sample)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text('${s['from']}', style: TextStyle(color: c.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(child: (widget.canaux ? CanalTag(label: '#${s['to']}', style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)) : PseudoTag(label: '@${s['to']}', style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)))),
                  ]),
                ),
              if (_skippedList.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Ignorés :', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                for (final s in _skippedList) Text('${s['pseudo']} — ${s['reason']}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ],
              const SizedBox(height: 6),
              Text('(aperçu limité aux 40 premiers)', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _card(AppColors c, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
