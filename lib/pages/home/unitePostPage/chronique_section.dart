import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../pages/chronique/chroniquedetails.dart';
import '../../../pages/chronique/chroniqueform.dart';
import '../../../pages/chronique/chroniquehome.dart';
import '../../../pages/chronique/chronique_widgets.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Bloc « Chroniques » du fil : des anneaux, un par personne.
/// - anneau vert et jaune qui tourne doucement = chroniques pas encore vues (un segment par chronique) ; gris = déjà vues ;
/// - « Moi » toujours en premier : mon anneau si j'ai une chronique active, sinon « + Ma chronique » ;
/// - jamais de bloc vide : sans chronique, une invitation à publier la première.
class ChroniqueSectionComponent extends StatefulWidget {
  final Map<String, Uint8List> videoThumbnails;
  final Map<String, bool> userVerificationStatus;
  final Map<String, UserData> userDataCache;
  final bool isLoadingChroniques;
  final Map<String, List<Chronique>> groupedChroniques;

  const ChroniqueSectionComponent({
    Key? key,
    required this.videoThumbnails,
    required this.userVerificationStatus,
    required this.userDataCache,
    required this.isLoadingChroniques,
    required this.groupedChroniques,
  }) : super(key: key);

  @override
  State<ChroniqueSectionComponent> createState() => _ChroniqueSectionComponentState();
}

class _ChroniqueSectionComponentState extends State<ChroniqueSectionComponent> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void initState() {
    super.initState();
    _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _create() => Navigator.push(context, MaterialPageRoute(builder: (_) => AddChroniquePage()));

  void _openAll() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChroniqueHomePage()));

  void _open(List<Chronique> group, List<List<Chronique>> all) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChroniqueDetailPage(initialChroniqueId: group.first.id!, allGroups: all, startUserId: group.first.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final uid = context.read<UserAuthProvider>().loginUserData.id;
    final reduce = MediaQuery.of(context).disableAnimations;
    final groups = [
      for (final g in widget.groupedChroniques.values)
        if (g.isNotEmpty) ([...g]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
    ];
    final mine = groups.where((g) => g.first.userId == uid).toList();
    final others = groups.where((g) => g.first.userId != uid).toList()
      ..sort((a, b) {
        final sa = chroniqueGroupSeen(a, uid) ? 1 : 0;
        final sb = chroniqueGroupSeen(b, uid) ? 1 : 0;
        if (sa != sb) return sa - sb; // les neuves d'abord
        return b.first.createdAt.compareTo(a.first.createdAt);
      });
    final ordered = [...mine, ...others];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(children: [
            Text('Chroniques', style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            if (!widget.isLoadingChroniques && others.isNotEmpty)
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('${others.length} active${others.length > 1 ? 's' : ''}', style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ]),
            const Spacer(),
            GestureDetector(
              onTap: _openAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  Text('Tout voir', style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, color: colors.primary, size: 14),
                ]),
              ),
            ),
          ]),
        ),
        if (widget.isLoadingChroniques)
          const ChroniqueRingsSkeleton()
        else
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (mine.isEmpty)
                  ChroniqueAddRing(onTap: _create)
                else
                  ChroniqueRing(group: mine.first, seen: false, spin: null, label: 'Moi', addBadge: false, onTap: () => _open(mine.first, ordered)),
                const SizedBox(width: 12),
                if (others.isEmpty)
                  SizedBox(
                    width: 200,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        mine.isEmpty ? 'Personne n\'a publié aujourd\'hui. Sois le premier à raconter ta journée.' : 'Pas d\'autre chronique pour le moment.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ),
                for (final g in others) ...[
                  ChroniqueRing(
                    group: g,
                    seen: chroniqueGroupSeen(g, uid),
                    spin: reduce ? null : _spin,
                    onTap: () => _open(g, ordered),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
