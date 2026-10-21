import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../layout/centered_content.dart';
import '../../models/news_article.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../news/news_detail_page.dart';

/// Administration des actualités : interrupteurs, création des agents, statistiques par agent (information : les cadeaux reçus par les agents
/// vont à l'application) et publication d'un article d'essai pour voir la carte du fil et la page de détail avant le pipeline automatique.
class NewsAdminPage extends StatefulWidget {
  const NewsAdminPage({super.key});

  @override
  State<NewsAdminPage> createState() => _NewsAdminPageState();
}

class _NewsAdminPageState extends State<NewsAdminPage> {
  bool _enabled = true;
  bool _feedEnabled = false;
  bool _pipelineEnabled = false;
  final _countriesCtrl = TextEditingController();
  List<Map<String, dynamic>> _sources = [];
  String? _runReport;
  List<Map<String, dynamic>> _agents = [];
  bool _loading = false;
  String? _status;

  String _agentKey = 'sport';
  String _level = 'country';
  final _country = TextEditingController();
  final _continent = TextEditingController(text: 'AF');
  final _title = TextEditingController();
  final _chapo = TextEditingController();
  final _section = TextEditingController();
  final _s1Name = TextEditingController();
  final _s1Url = TextEditingController();
  final _s2Name = TextEditingController();
  final _s2Url = TextEditingController();
  final _image = TextEditingController();
  String? _lastId;
  final _life = TextEditingController();
  List<Map<String, dynamic>> _articles = [];
  bool _articlesLoaded = false;
  String? _confirmId; // article dont la suppression attend une seconde confirmation

  @override
  void initState() {
    super.initState();
    final code = context.read<UserAuthProvider>().loginUserData.countryData?['countryCode'];
    _country.text = (code ?? 'TG').toUpperCase();
    _loadStats();
  }

  @override
  void dispose() {
    for (final c in [_life, _countriesCtrl, _country, _continent, _title, _chapo, _section, _s1Name, _s1Url, _s2Name, _s2Url, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final res = await FirebaseFunctions.instance.httpsCallable(name).call(data ?? <String, dynamic>{});
    return Map<String, dynamic>.from(res.data as Map);
  }

  String _err(Object e) {
    if (e is FirebaseFunctionsException) {
      if (e.code == 'not-found') return 'Fonction pas encore déployée.';
      return '${e.code} : ${e.message ?? ''}';
    }
    return '$e';
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final d = await _call('newsAgentStats');
      final cfg = Map<String, dynamic>.from(d['config'] as Map);
      setState(() {
        _enabled = cfg['enabled'] == true;
        _feedEnabled = cfg['feedEnabled'] == true;
        _pipelineEnabled = cfg['pipelineEnabled'] == true;
        if (_countriesCtrl.text.isEmpty) _countriesCtrl.text = ((cfg['countries'] as List?) ?? const []).join(', ');
        _agents = (d['agents'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _status = null;
      });
    } catch (e) {
      setState(() => _status = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setConfig(Map<String, dynamic> patch) async {
    try {
      await _call('newsSetConfig', patch);
    } catch (e) {
      setState(() => _status = _err(e));
    }
    await _loadStats();
  }

  Future<void> _seed() async {
    setState(() => _loading = true);
    try {
      await _call('newsSeedAgents');
      _status = 'Agents créés ou mis à jour.';
    } catch (e) {
      _status = _err(e);
    }
    await _loadStats();
  }

  void _fillExample() {
    final a = newsAgentOf(_agentKey);
    setState(() {
      _title.text = '[ESSAI] Les Éperviers préparent leur match de qualification';
      _chapo.text = 'Le sélectionneur a dévoilé sa liste de 24 joueurs. Trois absents sont à signaler avant le déplacement de samedi.';
      _section.text = 'Le sélectionneur a retenu vingt-quatre joueurs pour la double confrontation, avec trois absents confirmés par la fédération. '
          'Le groupe se retrouve dès demain pour une dernière séance avant le départ.';
      _s1Name.text = 'Africanews';
      _s1Url.text = 'https://www.africanews.com/';
      _s2Name.text = 'RFI Sport';
      _s2Url.text = 'https://www.rfi.fr/fr/sport/';
      _status = 'Exemple rempli pour ${a.pseudo}. Modifie ce que tu veux puis publie.';
    });
  }

  String? _aiReport;

  /// Lit chaque source depuis le serveur (sans IA, sans rien publier) : celles qui répondent peuvent être activées.
  Future<void> _testSources() async {
    setState(() => _loading = true);
    try {
      final d = await _call('newsSourcesTest');
      setState(() => _sources = (d['sources'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      setState(() => _status = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleSource(Map<String, dynamic> s, bool on) async {
    setState(() => s['active'] = on);
    try {
      await _call('newsSetConfig', {'sourcesOn': {s['id']: on}});
    } catch (e) {
      if (mounted) {
        setState(() {
          s['active'] = !on;
          _status = _err(e);
        });
      }
    }
  }

  Future<void> _saveCountries() async {
    final codes = _countriesCtrl.text.split(RegExp(r'[,\s]+')).where((c) => c.trim().isNotEmpty).map((c) => c.trim().toUpperCase()).toList();
    await _setConfig({'countries': codes});
    if (mounted) setState(() => _status = 'Pays enregistrés : ${_countriesCtrl.text}');
  }

  /// Essai sans IA (`dryRun`) : montre ce qui serait publié ; sinon un vrai passage (3 articles au plus).
  Future<void> _runPipeline({required bool dryRun}) async {
    setState(() {
      _loading = true;
      _runReport = null;
    });
    try {
      final d = await _call('newsRunPipeline', {'dryRun': dryRun, 'maxPublish': 3});
      final lines = <String>[];
      if (d['skipped'] != null) lines.add('Ignoré : ${d['skipped']}');
      final src = Map<String, dynamic>.from(d['sources'] as Map);
      lines.add('Sources lues : ${src['ok']}, en erreur : ${(src['failed'] as List).length} · ${d['fetched']} articles · ${d['topics']} sujets');
      for (final f in (src['failed'] as List)) {
        final m = Map<String, dynamic>.from(f as Map);
        lines.add('  ⚠️ ${m['id']} : ${m['error']}');
      }
      if (dryRun) {
        lines.add('Seraient publiés (${(d['planned'] as List).length}) :');
        for (final p in (d['planned'] as List)) {
          final m = Map<String, dynamic>.from(p as Map);
          lines.add('  • [${m['key']}] ${m['title']} (${m['sources']} sources, score ${m['score']})');
        }
      } else {
        lines.add('Publiés : ${(d['published'] as List).length}');
        for (final p in (d['published'] as List)) {
          final m = Map<String, dynamic>.from(p as Map);
          lines.add('  ✅ ${m['title']} (${m['scope']})');
        }
        for (final f in (d['failed'] as List)) {
          final m = Map<String, dynamic>.from(f as Map);
          lines.add('  ❌ ${m['title']} : ${m['reason']}');
        }
        if (d['quotaHit'] == true) lines.add('⚠️ Quota Cloudflare atteint : le passage s\'est arrêté.');
        lines.add('Neurons consommés : ${d['neurons']} · ${d['ms']} ms');
      }
      setState(() => _runReport = lines.join('\n'));
    } catch (e) {
      setState(() => _runReport = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _health = {};
  bool _logsLoaded = false;

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Journal : appels à l'IA (réussis ou en erreur), articles publiés, incidents ; et état de chaque compte Cloudflare.
  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final d = await _call('newsLogs', {'limit': 60});
      setState(() {
        _logs = (d['logs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _health = Map<String, dynamic>.from(d['health'] as Map);
        _logsLoaded = true;
      });
    } catch (e) {
      setState(() => _status = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Teste chaque compte Cloudflare (une toute petite question) et montre la consommation du jour ; aucune clé n'est affichée.
  Future<void> _checkAi() async {
    setState(() {
      _loading = true;
      _aiReport = null;
    });
    try {
      final d = await _call('newsCheckAi');
      final lines = <String>['Comptes configurés : ${d['configured']}'];
      for (final r in (d['results'] as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        lines.add(m['ok'] == true
            ? '✅ ${m['account']} : fonctionne (${(m['model'] as String).split('/').last}, ${m['neurons']} neurons, ${m['ms']} ms)'
            : '❌ ${m['account']} : ${m['error']}');
      }
      for (final t in (d['today'] as List)) {
        final m = Map<String, dynamic>.from(t as Map);
        lines.add('Aujourd\'hui ${m['account']} : ${m['neurons']} / ${m['cap']} neurons');
      }
      lines.add('Plafond total du jour : ${d['dailyCap']} neurons');
      if ((d['configured'] as num) == 0) lines.add('Aucun compte lisible : lance tools\\news\\set_cf_accounts.ps1 puis redéploie les fonctions.');
      setState(() => _aiReport = lines.join('\n'));
    } catch (e) {
      setState(() => _aiReport = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Les 40 derniers articles, avec leur fin de vie et leur engagement.
  Future<void> _loadArticles() async {
    setState(() => _loading = true);
    try {
      final d = await _call('newsListArticles');
      setState(() {
        _articles = (d['articles'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _articlesLoaded = true;
        _confirmId = null;
      });
    } catch (e) {
      setState(() => _status = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Suppression en deux temps : un premier toucher demande confirmation, le second supprime (l'article, ses commentaires et sa place dans le fil).
  Future<void> _deleteArticle(String id) async {
    if (_confirmId != id) {
      setState(() => _confirmId = id);
      return;
    }
    try {
      await _call('newsDeleteArticle', {'id': id});
      _status = 'Article supprimé.';
    } catch (e) {
      _status = _err(e);
    }
    await _loadArticles();
  }

  Future<void> _extendArticle(String id) async {
    try {
      await _call('newsExtendArticle', {'id': id, 'days': 7});
      _status = 'Article prolongé de 7 jours.';
    } catch (e) {
      _status = _err(e);
    }
    await _loadArticles();
  }

  String _remaining(int exp) {
    if (exp <= 0) return 'sans fin';
    final ms = exp - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return 'expiré (supprimé au prochain nettoyage)';
    final h = ms ~/ 3600000;
    return h < 48 ? 'encore $h h' : 'encore ${h ~/ 24} j';
  }

  Future<void> _publish() async {
    final sources = <Map<String, String>>[
      if (_s1Url.text.trim().isNotEmpty) {'name': _s1Name.text.trim(), 'url': _s1Url.text.trim()},
      if (_s2Url.text.trim().isNotEmpty) {'name': _s2Name.text.trim(), 'url': _s2Url.text.trim()},
    ];
    setState(() => _loading = true);
    try {
      final d = await _call('newsPublishManual', {
        'agentKey': _agentKey,
        'level': _level,
        'country': _country.text.trim(),
        'continent': _continent.text.trim(),
        'title': _title.text.trim(),
        'chapo': _chapo.text.trim(),
        'sections': [
          {'titre': '', 'texte': _section.text.trim()}
        ],
        'retenir': ['Liste de 24 joueurs', 'Trois absents confirmés', 'Match prévu samedi'],
        'sources': sources,
        'image': _image.text.trim(),
        if (int.tryParse(_life.text.trim()) != null) 'lifeDays': int.parse(_life.text.trim()),
      });
      _lastId = d['id']?.toString();
      _status = 'Article publié (${d['scope']}). ${_feedEnabled ? '' : 'Active « Cartes dans le fil » pour le voir dans le fil.'}';
    } catch (e) {
      _status = _err(e);
    }
    await _loadStats();
  }

  Future<void> _delete() async {
    final id = _lastId;
    if (id == null) return;
    try {
      await _call('newsDeleteArticle', {'id': id});
      _lastId = null;
      _status = 'Article supprimé.';
    } catch (e) {
      _status = _err(e);
    }
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget card(Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: child,
        );
    Text title(String t) => Text(t, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5));
    Widget field(String label, TextEditingController ctrl, {int lines = 1}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: ctrl,
            maxLines: lines,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
          ),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: const Text('Actualités (agents)'),
        actions: [IconButton(onPressed: _loading ? null : _loadStats, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: CenteredContent(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_loading) const LinearProgressIndicator(),
          if (_status != null)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_status!, style: TextStyle(color: c.warning, fontSize: 12.5))),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Réglages'),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Actualités actives', style: TextStyle(color: c.textPrimary, fontSize: 13)),
              value: _enabled,
              onChanged: (v) => _setConfig({'enabled': v}),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Cartes dans le fil', style: TextStyle(color: c.textPrimary, fontSize: 13)),
              subtitle: Text('Désactivé : rien n\'apparaît dans le fil, quel que soit le nombre d\'articles.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              value: _feedEnabled,
              onChanged: (v) => _setConfig({'feedEnabled': v}),
            ),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Agents'),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: _loading ? null : _seed, icon: const Icon(Icons.group_add_rounded), label: const Text('Créer ou mettre à jour les agents')),
            ),
            const SizedBox(height: 6),
            if (_agents.isEmpty) Text('Aucune donnée pour le moment.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            for (final a in _agents)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: AgentAvatarMini(agentKey: '${a['key']}'),
                title: Text('${a['pseudo']}${a['seeded'] == true ? '' : '  (non créé)'}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text(
                  '${a['articles']} articles · ${(a['recent'] as Map)['views']} vues · ${(a['recent'] as Map)['loves']} j\'aime · ${(a['recent'] as Map)['comments']} commentaires\n'
                  'Cadeaux reçus (information) : ${a['giftCoins']} pièces, ${a['giftCount']} cadeaux',
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
                ),
                isThreeLine: true,
              ),
            Text('Vues, j\'aime et commentaires : sur les 200 derniers articles.', style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Génération des articles'),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Génération automatique (toutes les 2 heures)', style: TextStyle(color: c.textPrimary, fontSize: 13)),
              subtitle: Text(_pipelineEnabled ? 'Activée : un passage toutes les 2 heures. Plafonds : 60 articles par jour, 2 par agent et périmètre.' : 'Désactivée : rien n\'est publié tant que tu ne l\'actives pas.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              value: _pipelineEnabled,
              onChanged: (v) => _setConfig({'pipelineEnabled': v}),
            ),
            field('Pays suivis (codes séparés par des virgules, ex. TG, BJ, CI)', _countriesCtrl),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _loading ? null : _saveCountries, child: const Text('Enregistrer les pays'))),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _loading ? null : () => _runPipeline(dryRun: true), child: const Text('Essai sans IA'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _loading ? null : () => _runPipeline(dryRun: false), child: const Text('Lancer (3 articles)'))),
            ]),
            if (_runReport != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_runReport!, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.4))),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: title('Sources d\'actualités')),
              TextButton(onPressed: _loading ? null : _testSources, child: const Text('Tester les sources')),
            ]),
            if (_sources.isEmpty) Text('Teste les sources : chacune est lue depuis le serveur, et tu actives celles qui répondent.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            for (final src in _sources)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: src['active'] == true,
                onChanged: src['ok'] == true || src['active'] == true ? (v) => _toggleSource(src, v) : null,
                title: Text('${src['ok'] == true ? '✅' : '❌'} ${src['name']} · ${src['id']}', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
                subtitle: Text(
                  src['ok'] == true ? '${src['items']} articles · ${src['ms']} ms' : '${src['error']}',
                  style: TextStyle(color: src['ok'] == true ? c.textSecondary : c.danger, fontSize: 11),
                ),
              ),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('IA (comptes Cloudflare)'),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: _loading ? null : _checkAi, icon: const Icon(Icons.bolt_rounded), label: const Text('Tester les comptes IA')),
            ),
            if (_aiReport != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_aiReport!, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4))),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: title('Journal de l\'IA et des articles')),
              TextButton(onPressed: _loading ? null : _loadLogs, child: Text(_logsLoaded ? 'Actualiser' : 'Afficher')),
            ]),
            if (!_logsLoaded) Text('Appels à l\'IA, articles publiés et incidents, avec l\'état de chaque compte Cloudflare.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            if (_logsLoaded) ...[
              if (_health.isEmpty) Text('Aucun appel à l\'IA enregistré pour le moment.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              for (final e in _health.entries)
                Builder(builder: (_) {
                  final h = Map<String, dynamic>.from(e.value as Map);
                  final okAt = (h['lastOkAt'] as num?)?.toInt() ?? 0;
                  final errAt = (h['lastErrorAt'] as num?)?.toInt() ?? 0;
                  final bad = errAt > okAt; // la dernière tentative a échoué
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${bad ? '⚠️' : '✅'} Compte ${e.key} : ${h['okCount'] ?? 0} réussites, ${h['errCount'] ?? 0} erreurs'
                      '${okAt > 0 ? ' · dernier succès ${_when(okAt)}' : ''}'
                      '${errAt > 0 ? '\nDernière erreur ${_when(errAt)} : ${h['lastError']}' : ''}',
                      style: TextStyle(color: bad ? c.danger : c.textPrimary, fontSize: 12, height: 1.35),
                    ),
                  );
                }),
              const Divider(height: 18),
              if (_logs.isEmpty) Text('Journal vide.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              for (final l in _logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_when((l['at'] as num).toInt())}  ${l['ok'] == true ? '✅' : '❌'} ${l['kind']}'
                    '${l['account'] != null ? ' · ${l['account']}' : ''}'
                    '${l['neurons'] != null ? ' · ${l['neurons']} neurons' : ''}'
                    '${l['ms'] != null ? ' · ${l['ms']} ms' : ''}\n${l['message']}',
                    style: TextStyle(color: l['ok'] == true ? c.textSecondary : c.danger, fontSize: 11.5, height: 1.3),
                  ),
                ),
            ],
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: title('Articles en ligne')),
              TextButton(onPressed: _loading ? null : _loadArticles, child: Text(_articlesLoaded ? 'Actualiser' : 'Afficher')),
            ]),
            Text('Un article disparaît à la fin de sa vie : 4 jours pour le sport, 7 pour la politique, 10 la musique, 14 la culture et la tech, 21 le voyage. '
                'Très aimé ou très commenté, il est prolongé une fois (jamais au-delà de 45 jours).',
                style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35)),
            if (_articlesLoaded && _articles.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucun article.', style: TextStyle(color: c.textSecondary, fontSize: 12))),
            for (final a in _articles)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text(
                    '${newsAgentOf('${a['agentKey']}').pseudo} · ${a['scope']} · ${newsAgo((a['createdAt'] as num).toInt())} · ${_remaining((a['expiresAt'] as num).toInt())}\n'
                    '${a['views']} vues · ${a['loves']} j\'aime · ${a['comments']} commentaires · ${a['gifts']} cadeaux',
                    style: TextStyle(color: c.textSecondary, fontSize: 11, height: 1.35),
                  ),
                  Row(children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: '${a['id']}'))),
                      child: const Text('Voir'),
                    ),
                    TextButton(onPressed: () => _extendArticle('${a['id']}'), child: const Text('Prolonger de 7 jours')),
                    TextButton(
                      onPressed: () => _deleteArticle('${a['id']}'),
                      child: Text(_confirmId == a['id'] ? 'Confirmer la suppression' : 'Supprimer', style: TextStyle(color: c.danger)),
                    ),
                  ]),
                  Divider(color: c.border, height: 1),
                ]),
              ),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Publier un article d\'essai'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _agentKey,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Agent', isDense: true, border: OutlineInputBorder()),
                  items: [for (final a in kNewsAgents) DropdownMenuItem(value: a.key, child: Text(a.pseudo))],
                  onChanged: (v) => setState(() => _agentKey = v ?? 'sport'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _level,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Niveau', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'country', child: Text('Pays')),
                    DropdownMenuItem(value: 'continent', child: Text('Continent')),
                    DropdownMenuItem(value: 'world', child: Text('Monde')),
                  ],
                  onChanged: (v) => setState(() => _level = v ?? 'country'),
                ),
              ),
            ]),
            if (_level == 'country') field('Pays (code à 2 lettres, ex. TG)', _country),
            if (_level == 'continent') field('Continent (AF, EU, AS, NA, SA, OC)', _continent),
            field('Titre (10 à 140 caractères)', _title),
            field('Chapô (40 à 320 caractères)', _chapo, lines: 2),
            field('Texte (40 caractères ou plus)', _section, lines: 4),
            field('Source 1 : nom', _s1Name),
            field('Source 1 : lien https', _s1Url),
            field('Source 2 : nom (facultatif)', _s2Name),
            field('Source 2 : lien https (facultatif)', _s2Url),
            field('Image : lien https (facultatif)', _image),
            field('Durée de vie en jours (facultatif, 1 à 45 ; sinon selon le domaine)', _life),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _fillExample, child: const Text('Remplir un exemple'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: _loading ? null : _publish, child: const Text('Publier'))),
            ]),
            if (_lastId != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: _lastId!))),
                    child: const Text('Voir la page de détail'),
                  ),
                ),
                Expanded(child: TextButton(onPressed: _delete, child: Text('Supprimer', style: TextStyle(color: c.danger)))),
              ]),
            ],
          ])),
        ]),
      ),
    );
  }
}

/// Petite icône d'agent pour les listes de l'administration.
class AgentAvatarMini extends StatelessWidget {
  final String agentKey;
  const AgentAvatarMini({super.key, required this.agentKey});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final agent = newsAgentOf(agentKey);
    return CircleAvatar(radius: 16, backgroundColor: agent.color(c).withOpacity(0.18), child: Icon(agent.icon, size: 17, color: agent.color(c)));
  }
}
