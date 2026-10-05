import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/tr.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/hawk_mascot.dart';
import '../quiz/widgets/quiz_widgets.dart';

/// Diplôme ou attestation Afrolook Étude. Document de progression Afrolook, sans valeur officielle.
class EtudeDiplomaPage extends StatelessWidget {
  const EtudeDiplomaPage({super.key, required this.diploma});
  final Map<String, dynamic> diploma;

  String get _title => '${diploma['title'] ?? ''}';
  String get _serial => '${diploma['serial'] ?? ''}';
  int get _pct => (diploma['pct'] as num?)?.toInt() ?? 0;
  bool get _isCert => diploma['kind'] == 'cert';

  String _date() {
    final ms = (diploma['at'] as num?)?.toInt() ?? 0;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final gold = const Color(0xFFD4A017);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr(_isCert ? 'Mon attestation' : 'Mon diplôme'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold, width: 3),
            boxShadow: [BoxShadow(color: gold.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            Text('AFROLOOK ÉTUDE', style: TextStyle(color: gold, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 12)),
            const SizedBox(height: 10),
            const HawkMascot(mood: HawkMood.cheer, size: 110, accessory: 'acc_cap'),
            const SizedBox(height: 6),
            Text(context.tr(_isCert ? 'Attestation de réussite' : 'Diplôme de réussite'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(_title, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 22, height: 1.25)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              QuizPill(icon: Icons.percent_rounded, label: context.tr('Note : {p} %', {'p': '$_pct'}), color: c.primary),
              QuizPill(icon: Icons.calendar_today_rounded, label: _date(), color: c.info),
            ]),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _serial));
                quizToast(context, context.tr('Numéro copié'));
              },
              child: Text(_serial, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 2)),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Document de progression Afrolook, sans valeur de diplôme officiel. Son numéro peut être vérifié dans l\'application.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.4),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        QuizChunkyButton(
          label: context.tr('Partager'),
          icon: Icons.share_rounded,
          color: c.primary,
          textColor: c.onPrimary,
          onPressed: () => Share.share(context.tr('J\'ai obtenu « {t} » sur Afrolook Étude avec {p} % ! Numéro {s}', {'t': _title, 'p': '$_pct', 's': _serial})),
        ),
      ]),
    );
  }
}

/// Liste des diplômes et attestations déjà obtenus.
class EtudeDiplomaTile extends StatelessWidget {
  const EtudeDiplomaTile({super.key, required this.diploma});
  final Map<String, dynamic> diploma;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeDiplomaPage(diploma: diploma))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD4A017).withOpacity(0.6))),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4A017), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${diploma['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              Text('${diploma['serial']} · ${(diploma['pct'] as num?)?.toInt() ?? 0} %', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }
}

/// Ensemble des diplômes pour l'état courant (utilisé par la page d'accueil).
List<EtudeTrack> etudeCerts(List<EtudeTrack> all) => all.where((t) => !t.isCycle && t.cert != null).toList();
