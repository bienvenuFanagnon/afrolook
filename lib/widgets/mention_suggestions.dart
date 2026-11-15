import 'dart:async';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Mentions @pseudo (15/11/2026) : mêmes règles que le serveur (`App\Notifications\Mentions`) : 3 à 30 caractères (lettres, chiffres, « _ », « . »),
/// pas précédé d'une lettre, d'un « @ » ou d'un point (une adresse e-mail n'est pas une mention), point final retiré.
final RegExp kMentionRegex = RegExp(r'(?<![\w@.])@([A-Za-z0-9_.]{3,30})');

/// Pseudo cité, sans le point final éventuel (« @ama. » en fin de phrase = « ama »).
String mentionName(Match m) {
  var n = m.group(1)!;
  while (n.endsWith('.')) {
    n = n.substring(0, n.length - 1);
  }
  return n;
}

/// Texte avec les @pseudos en couleur ; toucher un pseudo appelle [onMention].
class MentionText extends StatefulWidget {
  const MentionText(this.text, {super.key, required this.style, required this.mentionColor, this.onMention, this.maxLines, this.overflow});

  final String text;
  final TextStyle style;
  final Color mentionColor;
  final ValueChanged<String>? onMention;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in kMentionRegex.allMatches(widget.text)) {
      final name = mentionName(m);
      final end = m.start + 1 + name.length; // le point final reste du texte normal
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final tap = TapGestureRecognizer()..onTap = () => widget.onMention?.call(name);
      _taps.add(tap);
      spans.add(TextSpan(text: '@$name', style: TextStyle(color: widget.mentionColor, fontWeight: FontWeight.w700), recognizer: widget.onMention == null ? null : tap));
      last = end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(TextSpan(style: widget.style, children: spans), maxLines: widget.maxLines, overflow: widget.overflow ?? (widget.maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis));
  }
}

/// Suggestions de personnes à taguer pendant qu'on écrit « @… » dans [controller] : tout Afrolook, les personnes suivies et les abonnés d'abord
/// (recherche du serveur, comptes bloqués exclus). Toucher une personne remplace « @… » par « @pseudo ». Rien n'est affiché hors d'une mention.
class MentionSuggestions extends StatefulWidget {
  const MentionSuggestions({super.key, required this.controller, this.maxHeight = 220, this.search});

  final TextEditingController controller;
  final double maxHeight;

  /// Recherche (remplaçable dans les tests) ; par défaut `GET /users/search?mention=1`.
  final Future<List<Map<String, dynamic>>> Function(String q)? search;

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  Timer? _debounce;
  String? _query; // texte après « @ » au curseur ; null = pas de mention en cours
  List<Map<String, dynamic>> _items = const [];
  int _seq = 0;

  static final RegExp _atCursor = RegExp(r'(?:^|[\s(])@([A-Za-z0-9_.]{0,30})$');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant MentionSuggestions old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final v = widget.controller.value;
    final cursor = v.selection.baseOffset;
    final before = cursor < 0 || cursor > v.text.length ? v.text : v.text.substring(0, cursor);
    final m = _atCursor.firstMatch(before);
    final q = m?.group(1);
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    if (q == null || q.isEmpty) {
      if (_items.isNotEmpty && mounted) setState(() => _items = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _load(q));
  }

  Future<void> _load(String q) async {
    final seq = ++_seq;
    try {
      final r = await (widget.search ?? UsersApi.mentionSuggestions)(q);
      if (!mounted || seq != _seq || _query != q) return;
      setState(() => _items = r);
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _items = const []);
    }
  }

  void _pick(String username) {
    final v = widget.controller.value;
    final cursor = v.selection.baseOffset < 0 ? v.text.length : v.selection.baseOffset;
    final before = v.text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final insert = '@$username ';
    final text = v.text.replaceRange(at, cursor, insert);
    widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at + insert.length));
    setState(() {
      _items = const [];
      _query = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_query == null || _query!.isEmpty || _items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('mention_suggestions'),
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          type: MaterialType.transparency, // l'effet du toucher des lignes reste visible sur le fond de la boîte
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: .3)),
            itemBuilder: (_, i) {
              final u = _items[i];
              final name = '${u['username'] ?? ''}';
              final display = '${u['display_name'] ?? ''}'.trim();
              final avatar = '${u['avatar_url'] ?? ''}';
              return ListTile(
                key: ValueKey('mention_pick_$name'),
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  onBackgroundImageError: avatar.isNotEmpty ? (_, __) {} : null,
                  child: avatar.isEmpty ? Icon(Icons.person_rounded, size: 18, color: cs.onSurfaceVariant) : null,
                ),
                title: Text('@$name', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
                subtitle: display.isNotEmpty ? Text(display, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)) : null,
                trailing: u['is_following'] == true ? Text(context.tr('Suivi'), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)) : null,
                onTap: () => _pick(name),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ouvre le profil de la personne citée : recherche exacte du pseudo, puis [open] avec son identifiant. Rien si le pseudo n'existe pas (ou est bloqué).
Future<void> openMentionedProfile(String username, void Function(String userId) open) async {
  try {
    final r = await UsersApi.searchUsers(username, limit: 5);
    final hit = r.where((u) => '${u['username'] ?? ''}'.toLowerCase() == username.toLowerCase()).firstOrNull;
    if (hit != null && hit['id'] != null) open('${hit['id']}');
  } catch (_) {}
}
