import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/studio_subtitles_api.dart';
import '../../theme/app_colors.dart';
import 'trim_sheet.dart';

/// Feuille de relecture des sous-titres : la voix a été reconnue, la personne corrige chaque phrase (ou la retire), puis valide pour les incruster dans la vidéo.
/// Rend la liste corrigée, ou null si la feuille est fermée. Couleurs du thème (clair et sombre).
Future<List<SubtitleSegment>?> showSubtitlesSheet(BuildContext context, List<SubtitleSegment> segments) {
  final c = AppColors.of(context);
  final items = [for (final s in segments) SubtitleSegment(startMs: s.startMs, endMs: s.endMs, text: s.text)];
  final ctrls = [for (final s in items) TextEditingController(text: s.text)];
  return showModalBottomSheet<List<SubtitleSegment>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: Text(context.tr('Relis tes sous-titres'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: Text(context.tr('Corrige un mot si besoin, ou retire une phrase.'), style: TextStyle(color: c.textSecondary, fontSize: 13))),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 14, right: 10), child: Text(trimClock(items[i].startMs), style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                    Expanded(
                      child: TextField(
                        key: ValueKey('subtitle_$i'),
                        controller: ctrls[i],
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 200,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        style: TextStyle(color: c.textPrimary, fontSize: 14.5),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: c.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => items[i].text = v,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('subtitle_del_$i'),
                      tooltip: context.tr('Retirer'),
                      icon: Icon(Icons.delete_outline_rounded, color: c.textSecondary),
                      onPressed: () => setM(() {
                        items.removeAt(i);
                        ctrls.removeAt(i).dispose();
                      }),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const ValueKey('subtitles_ok'),
                  onPressed: () {
                    final out = [for (var i = 0; i < items.length; i++) SubtitleSegment(startMs: items[i].startMs, endMs: items[i].endMs, text: ctrls[i].text.trim())].where((s) => s.text.isNotEmpty).toList();
                    Navigator.pop(ctx, out);
                  },
                  style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(context.tr('Ajouter les sous-titres'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}
