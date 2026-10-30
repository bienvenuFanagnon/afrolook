// Afrolook Ads : documentation d'intégration pour les diffuseurs (sites et applications) et page publique des règles des diffuseurs.
// Les chiffres (durées de vue, intervalles, prix) sont ceux du serveur : functions/src/ads/adsEngine_logic.ts (FORMATS). À mettre à jour ensemble.
import { ico, G, adsSubnav } from './ads.mjs';
import { RULES, CATS, esc, rulesHtml } from './ads_data.mjs';

export const RULES_META = { title: 'Règles des diffuseurs | Afrolook Ads', desc: 'Les règles à accepter pour afficher les annonces Afrolook Ads sur ton site ou ton application : audience, comptage, rémunération, catégories, données.' };
export const DOCS_META = { title: 'Documentation d\'intégration | Afrolook Ads', desc: 'Afficher les annonces Afrolook Ads sur un site ou une application : balise web, exemple Flutter, API, formats, comptage, catégories et ciblage.' };

const code = (lang, text) => `<pre class="doc-code" data-lang="${lang}"><code>${esc(text.replace(/^\n/, ''))}</code></pre>`;

export function adsRulesPage() {
  return `${adsSubnav('regles')}<section class="adsp"><div class="wrap doc">
 <span class="kicker">Afrolook Ads · Diffuseurs</span><h1 class="h2" style="margin-top:6px">Règles des diffuseurs</h1>
 <p class="sub">Version <b>${esc(RULES.version)}</b>. Tu les acceptes en créant ton profil de diffuseur ; si elles changent, la version change et tu dois les accepter de nouveau pour ajouter un site ou une application.</p>
 <div class="rules">${rulesHtml()}</div>
 <p class="adnote">Contenus refusés pour tous les annonceurs : ${esc(CATS.forbidden.join(', '))}.</p>
 <div class="cta"><a class="btn btn-primary adbig" href="/ads/diffuseur/">Devenir diffuseur</a><a class="btn btn-line adbig" href="/ads/diffuseur/documentation/">Documentation d'intégration</a></div>
</div></section>`;
}

const FMT = [
  ['Bannière', 'banner', '1 s', '30 s', '1 000 F', 'oui'], ['Bandeau collant', 'sticky', '1 s', '30 s', '1 250 F', 'oui'], ['Carte native', 'native', '1 s', '20 s', '1 500 F', 'oui'],
  ['Carrousel', 'carousel', '1 s', '20 s', '1 800 F', 'API'], ['Affiche', 'poster', '1 s', '20 s', '2 000 F', 'oui'], ['Vidéo dans le fil', 'video', '2 s', '20 s', '2 500 F', 'API'],
  ['Interstitiel', 'interstitial', '1 s', '10 min', '3 000 F', 'API'], ['Récompensée', 'rewarded', '1 s, puis lecture complète', '5 min', '3 500 F (vue complète)', 'API'],
];

/** Part du diffuseur (65 %) d'un prix annonceur écrit « 1 250 F » ou « 3 500 F (vue complète) » : arrondie vers le bas au demi-franc, jamais au-dessus. */
const share = (p) => {
  const n = Math.floor(parseInt(String(p).replace(/[^\d]/g, ''), 10) * 0.65 * 2) / 2;
  const txt = (n % 1 ? n.toFixed(2) : String(n)).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '\u00a0');
  return txt + ' F' + (/complète/.test(p) ? ' (vue complète)' : '');
};

export function adsDocsPage(api) {
  const A = api || 'https://us-central1-afrolooki.cloudfunctions.net';
  return `${adsSubnav('docs')}<section class="adsp"><div class="wrap doc">
 <span class="kicker">Afrolook Ads · Diffuseurs</span><h1 class="h2" style="margin-top:6px">Documentation d'intégration</h1>
 <p class="sub">Afficher les annonces Afrolook Ads sur ton site ou dans ton application. Les annonces sont choisies, signées et comptées par les serveurs d'Afrolook Ads : ton code se contente de les afficher.</p>
 <nav class="doc-toc" aria-label="Sommaire"><a href="#demarrer">1. Démarrer</a><a href="#balise">2. Balise web</a><a href="#flutter">3. Application (Flutter)</a><a href="#api">4. API</a><a href="#formats">5. Formats</a><a href="#categories">6. Catégories et ciblage</a><a href="#comptage">7. Comptage et fraude</a><a href="#mesure">8. Mesures et paiement</a><a href="#faq">9. Questions fréquentes</a></nav>

 <section class="doc-s" id="demarrer"><h2>1. Démarrer</h2>
  <ol class="doc-steps">
   <li><b>Crée ton profil de diffuseur</b> et accepte les <a href="/ads/diffuseur/regles/">règles</a> dans <a href="/ads/diffuseur/">ton espace diffuseur</a> (connexion Google). Notre équipe le valide.</li>
   <li><b>Ajoute ton site ou ton application</b> (en ligne obligatoirement) : adresse du site, ou lien Google Play ou App Store ; audience mensuelle ; pays ; <b>catégories d'annonces que tu acceptes</b>.</li>
   <li><b>Prouve que le site est à toi</b> : ajoute la balise de vérification affichée dans ton espace dans la page d'accueil, ou le code seul dans le fichier <code>/afrolook-ads.txt</code>. Elle doit rester en place : retirée 3 jours de suite, la diffusion est suspendue.</li>
   <li><b>Après validation</b>, ton site ou ton application reçoit son <b>identifiant publicitaire</b> <code>ap_xxxxxxxxxx</code>. C'est lui qu'on met dans la balise ou dans l'appel à l'API.</li>
  </ol>
  <div class="ok">L'identifiant ne marche que sur le site ou l'application déclaré. Utilisé depuis un autre domaine, il est refusé et l'essai est enregistré. Ne le publie pas ailleurs et ne le partage pas.</div>
 </section>

 <section class="doc-s" id="balise"><h2>2. Balise web (le plus simple)</h2>
  <p>Colle ces deux lignes là où l'annonce doit apparaître. La balise s'occupe de tout : demande, affichage, mesure de la vue, clic.</p>
  ${code('html', `
<ins class="afl-ad" data-pub="ap_xxxxxxxxxx" data-slot="fil-principal" data-format="native"></ins>
<script async src="https://afrolookmedia.com/ads/tag.js"></script>`)}
  <ul class="list">
   <li><code>data-pub</code> : ton identifiant publicitaire. <code>data-slot</code> : le nom de l'emplacement (lettres, chiffres, - et _), pour tes statistiques. <code>data-format</code> : <code>banner</code>, <code>native</code>, <code>poster</code> ou <code>sticky</code> (bandeau collant en bas de l'écran, fermable).</li>
   <li>Une seule annonce par emplacement et par chargement de page, <b>3 emplacements au plus par page</b>. Pas de rafraîchissement automatique.</li>
   <li>Si aucune annonce ne convient au visiteur (pays, langue, catégories que tu acceptes…), l'emplacement reste vide : rien n'est compté, rien n'est payé.</li>
   <li>Si ton site a une politique de sécurité de contenu (CSP) : autorise <code>script-src https://afrolookmedia.com</code>, <code>connect-src ${esc(A)}</code> et <code>img-src https://firebasestorage.googleapis.com</code>.</li>
   <li>Visiteurs avec « Ne pas suivre » : l'annonce s'affiche, mais ni la vue ni le clic ne sont enregistrés.</li>
  </ul>
  <p>Pour afficher plusieurs emplacements, ajoute plusieurs balises <code>&lt;ins class="afl-ad"&gt;</code> (un seul <code>&lt;script&gt;</code> suffit). Les formats vidéo, carrousel, interstitiel et récompensée passent aujourd'hui par l'API (section 4).</p>
 </section>

 <section class="doc-s" id="flutter"><h2>3. Application (composant Flutter prêt à l'emploi)</h2>
  <p>Un composant prêt à l'emploi gère tout : demande de l'annonce à la bonne taille, bannière prête ou mise en page automatique (image entière sur fond flouté), mention « Annonce », vue envoyée au bon moment, clic par le lien d'Afrolook Ads, actualisation, fermeture. <b><a href="/ads/afrolook_ads_banner.dart" download>Télécharge afrolook_ads_banner.dart</a></b>, copie-le dans ton projet et ajoute les paquets <code>http</code>, <code>url_launcher</code> et <code>visibility_detector</code>.</p>
  ${code('dart', `
// Mini bannière fixe en bas d'un écran (320 × 50, fermable) : l'emplacement des mini bannières d'AdMob
Scaffold(
  body: …,
  bottomNavigationBar: const AfrolookAdsBanner.bottom(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiantDeVisiteur),
);

// Rectangle moyen dans le contenu (300 × 250), grande bannière (large) ou leaderboard (tablette)
const AfrolookAdsBanner(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiantDeVisiteur, size: AdsBannerSize.medium, slot: 'liste');`)}
  <ul class="list">
   <li><code>visitorId</code> : une chaîne de 12 à 64 caractères (lettres, chiffres, tirets), <b>stable</b> d'une session à l'autre (garde-la dans les préférences). Pas de données personnelles.</li>
   <li>Tailles : <code>AdsBannerSize.mini</code> (320×50), <code>large</code> (320×100), <code>medium</code> (300×250), <code>leaderboard</code> (728×90). Chaque taille demande au moteur une bannière prête à cette taille ; sans bannière, l'annonce est mise en page automatiquement.</li>
   <li><code>slot</code> : un nom différent par emplacement de l'écran ; <code>refresh</code> : au moins 30 secondes ; <code>headers</code> : en-têtes ajoutés aux appels (attestation de l'application).</li>
   <li>S'il n'y a pas d'annonce ou en cas d'erreur réseau, le composant ne prend aucune place et ne lève aucune exception.</li>
  </ul>
  <p>Tu préfères dessiner toi-même l'annonce ? Voici le principe, en quelques lignes :</p>
  ${code('dart', `
class AfrolookAd extends StatefulWidget {
  const AfrolookAd({super.key, required this.pub, this.slot = 'main', this.format = 'native'});
  final String pub, slot, format; // pub : ton identifiant publicitaire (ap_...)
  @override
  State<AfrolookAd> createState() => _AfrolookAdState();
}

class _AfrolookAdState extends State<AfrolookAd> {
  static const _host = 'us-central1-afrolooki.cloudfunctions.net';
  Map<String, dynamic>? _ad;
  String _vid = '';
  Timer? _timer;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _vid = prefs.getString('aflv') ?? List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16)).join();
    await prefs.setString('aflv', _vid);
    final r = await http.get(Uri.https(_host, '/adsServe', {'pub': widget.pub, 'fmt': widget.format, 'slot': widget.slot, 'vid': _vid}));
    final ad = (jsonDecode(r.body) as Map<String, dynamic>)['ad'];
    if (mounted && ad != null) setState(() => _ad = ad as Map<String, dynamic>);
  }

  // Une vue = au moins la moitié de l'annonce visible, sans interruption, pendant ad['viewMs'] millisecondes.
  void _visibility(VisibilityInfo info) {
    final ad = _ad;
    if (ad == null || _sent) return;
    _timer?.cancel();
    if (info.visibleFraction >= 0.5) {
      _timer = Timer(Duration(milliseconds: (ad['viewMs'] as int) + 50), () {
        _sent = true;
        http.post(Uri.parse(ad['event'] as String), headers: {'Content-Type': 'text/plain'},
            body: jsonEncode({'t': ad['token'], 'e': 'view', 'ms': (ad['viewMs'] as int) + 50, 'vid': _vid}));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink(); // aucune annonce : emplacement vide
    final media = ad['media'] as Map<String, dynamic>;
    return VisibilityDetector(
      key: Key(ad['id'] as String),
      onVisibilityChanged: _visibility,
      child: InkWell(
        // Le clic passe TOUJOURS par le lien d'Afrolook Ads : c'est lui qui compte le clic puis ouvre l'annonceur.
        onTap: () => launchUrl(Uri.parse(ad['click'] as String), mode: LaunchMode.externalApplication),
        child: Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(8), child: Text('Annonce', style: TextStyle(fontSize: 11))), // mention obligatoire
          // image TOUJOURS entière (jamais rognée) : posée sur une copie floutée d'elle-même, quel que soit son format
          SizedBox(height: 176, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
            ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Image.network((media['thumb'] ?? media['url']) as String, fit: BoxFit.cover, color: Colors.black45, colorBlendMode: BlendMode.darken)),
            Image.network((media['thumb'] ?? media['url']) as String, fit: BoxFit.contain),
          ])),
          ListTile(title: Text(ad['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text((ad['text'] ?? '') as String, maxLines: 2, overflow: TextOverflow.ellipsis)),
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: SizedBox(width: double.infinity, height: 44, // bouton d'au moins 44 px
            child: FilledButton(onPressed: () => launchUrl(Uri.parse(ad['click'] as String), mode: LaunchMode.externalApplication), child: Text((ad['cta'] ?? 'En savoir plus') as String)))),
        ])),
      ),
    );
  }
}`)}
  <p class="adnote">Applications : les annonces s'affichent et sont comptées, mais une application n'est rémunérée qu'après la vérification de son authenticité (attestation de l'application, étape prévue). Les applications du réseau Afrolook Ads envoient en plus le jeton de vérification de l'application (Firebase App Check) dans l'en-tête <code>X-Firebase-AppCheck</code>.</p>
 </section>

 <section class="doc-s" id="api"><h2>4. API</h2>
  <h3>Obtenir une annonce</h3>
  ${code('http', `
GET ${A}/adsServe?pub=ap_xxxxxxxxxx&fmt=native&slot=fil-principal&vid=<identifiant-visiteur>&lang=fr`)}
  <ul class="list">
   <li><code>pub</code> (obligatoire) : ton identifiant publicitaire. <code>fmt</code> (obligatoire) : <code>banner</code>, <code>sticky</code>, <code>native</code>, <code>carousel</code>, <code>poster</code>, <code>video</code>, <code>interstitial</code> ou <code>rewarded</code>. <code>size</code> (facultatif) : taille de l'emplacement, <code>728x90</code>, <code>320x50</code>, <code>320x100</code> ou <code>300x250</code> ; si l'annonce a une bannière prête à cette taille, elle est renvoyée dans <code>banner</code>. <code>slot</code> : nom de l'emplacement (1 à 32 caractères : lettres minuscules, chiffres, - et _). <code>vid</code> (obligatoire) : un identifiant anonyme du visiteur, 12 à 64 caractères (lettres, chiffres, -), généré une fois et gardé sur l'appareil. <code>lang</code> : langue du visiteur (2 lettres), facultatif.</li>
   <li>Le <b>pays du visiteur</b> est déterminé par nos serveurs d'après son adresse IP : n'envoie pas de pays.</li>
  </ul>
  <p>Réponse (200) : <code>{"ok":true,"ad":null}</code> s'il n'y a rien à afficher, sinon :</p>
  ${code('json', `
{
  "ok": true,
  "ad": {
    "id": "AbC123…", "format": "native", "label": "Annonce",
    "title": "Boutique Kofi : mode africaine", "text": "Vêtements modernes, livraison à Lomé.", "cta": "Visiter",
    "media": { "type": "image", "url": "https://…", "thumb": "https://…", "images": ["https://…"] },
    "banner": { "url": "https://…", "w": 728, "h": 90 },
    "click": "${A}/adsGo?t=<jeton>&v=<vid>",
    "token": "<jeton signé à usage unique>",
    "event": "${A}/adsEvent",
    "viewMs": 1000, "ttlMs": 1800000
  }
}`)}
  <p>Erreurs : <code>400</code> paramètres invalides ; <code>403</code> identifiant inconnu ou non validé (<code>diffuseur</code>), appel depuis un autre domaine (<code>origine</code>) ; <code>429</code> trop de demandes. Les erreurs ne bloquent jamais ta page : affiche simplement un emplacement vide.</p>

  <h3>Signaler une vue</h3>
  ${code('http', `
POST ${A}/adsEvent        (Content-Type: text/plain)
{"t":"<jeton>", "e":"view", "ms":1050, "vid":"<identifiant-visiteur>"}`)}
  <ul class="list">
   <li><code>e</code> : <code>view</code> (vue) ou <code>complete</code> (lecture complète d'une vidéo, pour les formats vidéo et récompensée, après une vue valide). <code>ms</code> : durée pendant laquelle l'annonce est restée visible (à moitié au moins) ; elle ne peut pas dépasser le temps écoulé depuis la demande.</li>
   <li>Réponse : <code>{"ok":true,"counted":true}</code> ou <code>{"ok":true,"counted":false,"reason":"…"}</code> avec le motif : <code>not_visible</code>, <code>too_fast</code>, <code>expired</code>, <code>replay</code>, <code>interval</code>, <code>ad_cap</code>, <code>device_cap</code>, <code>ip_cap</code>, <code>bot</code>, <code>origine</code>, <code>ad_inactive</code>.</li>
  </ul>

  <h3>Le clic</h3>
  <p>Le bouton de l'annonce pointe <b>toujours</b> vers le lien <code>click</code> reçu (<code>adsGo</code>) : Afrolook Ads y compte le clic puis redirige vers l'annonceur. N'appelle jamais ce lien toi-même et ne le remplace pas par l'adresse de l'annonceur : un clic qui ne passe pas par Afrolook Ads n'existe pas.</p>

  <h3>Limites et durées</h3>
  <ul class="list"><li>Le jeton ne vaut que pour <b>une seule vue</b> et expire au bout de 30 minutes (2 heures pour le clic).</li><li>Au plus <b>3 vues de la même annonce par visiteur et par jour</b>, 300 affichages par visiteur et par jour, un intervalle minimum entre deux annonces d'un même emplacement (tableau ci-dessous).</li><li>Les demandes en rafale sont limitées (par adresse et par visiteur).</li></ul>
 </section>

 <section class="doc-s" id="formats"><h2>5. Formats</h2>
  <div class="tablewrap"><table class="doc-table"><thead><tr><th>Format</th><th>Code</th><th>Vue comptée après</th><th>Intervalle minimum</th><th>Prix payé par l'annonceur (pour 1 000)</th><th>Tu reçois (65 %)</th><th>Balise web</th></tr></thead><tbody>
   ${FMT.map(([n, c, v, i, p, t]) => `<tr><td>${n}</td><td><code>${c}</code></td><td>${v}</td><td>${i}</td><td>${p}</td><td><b>${share(p)}</b></td><td>${t}</td></tr>`).join('')}
  </tbody></table></div>
  <p class="adnote">Prix de lancement : pendant le <b>premier mois</b> de l'offre Réseau, les annonceurs paient <b>30 % de moins</b> ; ta part de 65 % est alors calculée sur le prix réellement payé. Les prix du tableau sont ceux que paient les annonceurs : tu en reçois 65 % (colonne « Tu reçois »). Tu reçois 65 % du budget des annonces de l'offre Réseau réellement affichées chez toi, sur les seuls affichages valides. Les annonces gratuites ne rémunèrent pas les diffuseurs. L'offre Réseau n'est pas encore ouverte : tes affichages sont comptés dès maintenant, la rémunération démarre à son ouverture.</p>
  <p>Mention <b>« Annonce »</b> toujours visible, fermeture possible pour le bandeau collant et l'interstitiel, pas de son qui démarre seul, jamais plus de 3 emplacements par page.</p>
  <h3 id="tailles">Tailles d'affichage et images (sites et applications)</h3>
  <p>Un annonceur dépose <b>une seule annonce</b> (jusqu'à 5 images ou une vidéo de 15 s au plus) : le moteur la sert dans le format de ton emplacement. <b>L'image est toujours affichée entière</b>, jamais rognée : si son format diffère de celui de l'emplacement, le reste se remplit d'une copie floutée de la même image (comme AdMob). Les annonceurs sont invités à fournir une <b>image carrée de 1080 × 1080 px</b>, sujet et texte au centre.</p>
  <div class="tablewrap"><table class="doc-table"><thead><tr><th>Emplacement</th><th>Taille de l'emplacement</th><th>Image conseillée</th><th>Texte affiché</th></tr></thead><tbody>
   <tr><td>Grande bannière (<code>banner</code>)</td><td>320 × 100 (téléphone) · 728 × 90 (ordinateur)</td><td>Carré 1:1, au moins 600 × 600 px (affiché en 76 à 84 px)</td><td>Titre sur 2 lignes + description sur 2 lignes + bouton</td></tr>
   <tr><td>Bandeau collant (<code>sticky</code>)</td><td>320 × 50, fermable</td><td>Carré 1:1, au moins 300 × 300 px</td><td>Titre court (40 caractères) + bouton</td></tr>
   <tr><td>Rectangle moyen (<code>native</code> / <code>banner</code>)</td><td>300 × 250 (jusqu'à 336 de large)</td><td>Paysage 1,91:1 : 1200 × 628 px</td><td>Titre, description, bouton pleine largeur</td></tr>
   <tr><td>Carte native (<code>native</code>)</td><td>Dans une liste, largeur de la colonne</td><td>Portrait 4:5 : 1080 × 1350 px</td><td>Titre, description, bouton</td></tr>
   <tr><td>Affiche (<code>poster</code>)</td><td>Pleine largeur</td><td>Portrait 4:5 : 1080 × 1350 px</td><td>Titre + bouton</td></tr>
   <tr><td>Interstitiel (<code>interstitial</code>)</td><td>Plein écran de l'application</td><td>Vertical 9:16 : 1080 × 1920 px (ou 4:5 centré)</td><td>Titre + bouton, croix de fermeture</td></tr>
   <tr><td>Vidéo (<code>video</code>)</td><td>Largeur de la colonne, 15 s au plus</td><td>MP4 16:9, 1:1 ou 9:16, 25 Mo au plus</td><td>Titre + bouton</td></tr>
  </tbody></table></div>
  <h3 id="bannieres">Bannières prêtes à l'emploi (image seule)</h3>
  <p>Comme sur AdMob ou Adsterra, un annonceur peut déposer des <b>bannières déjà dessinées</b> aux tailles standard. Demande-les avec <code>size</code> : si l'annonce servie en a une, la réponse contient <code>banner</code> (<code>url</code>, <code>w</code>, <code>h</code>) : affiche cette image <b>en entier, sans rien ajouter</b> (juste la mention « Annonce »), cliquable vers le lien <code>click</code>. Sinon, utilise le titre, le texte et l'image comme ci-dessus.</p>
  <div class="tablewrap"><table class="doc-table"><thead><tr><th>Taille (<code>size</code>)</th><th>Nom</th><th>Où l'utiliser</th></tr></thead><tbody>
   <tr><td><code>728x90</code></td><td>Leaderboard</td><td>Haut ou bas d'une page sur ordinateur</td></tr>
   <tr><td><code>320x100</code></td><td>Grande bannière</td><td>Dans une page sur téléphone</td></tr>
   <tr><td><code>320x50</code></td><td>Mini bannière</td><td>Bandeau fixe en bas d'une application (comme les mini bannières d'AdMob)</td></tr>
   <tr><td><code>300x250</code></td><td>Rectangle moyen</td><td>Dans le contenu, sur ordinateur et téléphone</td></tr>
  </tbody></table></div>
  <p class="adnote">Dans une application, dimensionne l'emplacement comme dans ce tableau, laisse le contenu s'adapter (image <code>BoxFit.contain</code> sur sa copie floutée) et ne rogne jamais l'image de l'annonceur. Taille minimale du texte : 12 px ; bouton d'action de 44 px de haut au moins sur téléphone. L'exemple ci-dessus utilise <code>ImageFilter</code> : ajoute <code>import 'dart:ui' show ImageFilter;</code>.</p>
 </section>

 <section class="doc-s" id="categories"><h2>6. Catégories et ciblage</h2>
  <ul class="list">
   <li><b>Chaque annonce a une catégorie</b> choisie par l'annonceur et vérifiée par notre équipe : commerce, restauration, mode et beauté, technologie, finance, paris et jeux d'argent, alcool et tabac, médicaments, rencontres, <b>contenu sensuel</b> (corps dénudé ou suggestif), politique, religion, loteries…</li>
   <li><b>Tu choisis les catégories que tu acceptes</b> pour chaque site ou application, dans ton espace. Seules celles-là s'affichent chez toi. Les catégories courantes sont acceptées par défaut ; <b>les catégories sensibles ne s'affichent jamais sans ton accord explicite</b>. Une annonce sans catégorie n'est jamais diffusée chez un diffuseur externe.</li>
   <li>Le contenu sexuellement explicite, les armes, les drogues et les arnaques sont interdits pour tous.</li>
   <li><b>Le ciblage est défini par l'annonceur</b> et nous le respectons : pays ou toute l'Afrique ou le monde entier, langues, appareils (téléphone, ordinateur), types de sites. Quand une annonce vise des pays précis, <b>au plus 40 % de ses vues peuvent venir d'autres pays</b> ; le pays du visiteur est déterminé par nos serveurs.</li>
   <li>Conséquence pour toi : un visiteur n'est pas toujours éligible à toutes les annonces. C'est normal, et c'est ce qui rend les annonces pertinentes pour tes visiteurs.</li>
  </ul>
 </section>

 <section class="doc-s" id="comptage"><h2>7. Comptage et fraude</h2>
  <ul class="list">
   <li>Une <b>vue valide</b> : jeton signé, récent et jamais utilisé ; annonce visible à moitié pendant la durée du format ; intervalles et plafonds respectés ; visiteur réel (pas un robot) ; site déclaré.</li>
   <li>Tout le reste est du <b>trafic invalide</b> : il n'est ni facturé à l'annonceur ni payé au diffuseur. Tu vois ton taux de trafic invalide dans ton espace : moins de 10 % normal, de 10 à 25 % alerte, plus de 25 % emplacement suspendu.</li>
   <li><b>Interdit</b> : cliquer sur tes propres annonces ou inciter à cliquer, acheter du trafic, robots et rafraîchissements automatiques, cadres cachés ou empilés, modifier ou masquer une annonce ou la mention « Annonce », faire appeler le serveur par d'autres sites ou applications que ceux déclarés.</li>
   <li>Les appels faits avec ton identifiant depuis un autre domaine sont refusés et comptés : tu les vois dans tes mesures.</li>
   <li>Aucun cookie, aucun suivi d'un site à l'autre : le visiteur est reconnu par un identifiant propre à ton site. Ta politique de confidentialité doit mentionner l'affichage d'annonces par Afrolook Ads.</li>
  </ul>
 </section>

 <section class="doc-s" id="mesure"><h2>8. Mesures et paiement</h2>
  <ul class="list">
   <li>Pour chaque site, ton espace montre <b>l'audience réelle mesurée par Afrolook Ads sur 30 et 60 jours</b> (personnes différentes pour lesquelles la balise a été chargée), comparée à l'audience que tu as déclarée, jour par jour, avec la répartition par pays et les affichages valides.</li>
   <li>L'<b>audience retenue</b> est fixée par Afrolook Ads et ne dépasse jamais la déclarée. En cas d'écart important et durable, elle est ajustée.</li>
   <li>Gains bloqués 30 jours avant retrait, avec une réserve de 10 % pendant 90 jours ; retrait minimum 10 000 F par Mobile Money ; les frais de retrait sont payés par l'annonceur.</li>
  </ul>
 </section>

 <section class="doc-s" id="faq"><h2>9. Questions fréquentes</h2>
  <div class="faq">
   <details><summary>Aucune annonce ne s'affiche.</summary><p>Plusieurs raisons normales : pas d'annonce disponible pour ce visiteur (pays, langue, appareil), aucune annonce d'une catégorie que tu acceptes, intervalle minimum non écoulé, ou site pas encore validé. Une erreur <code>403 diffuseur</code> signifie que l'identifiant est inconnu ou que le site n'est pas encore validé ; <code>403 origine</code>, que l'appel ne vient pas du domaine déclaré.</p></details>
   <details><summary>Puis-je mettre la balise sur plusieurs sites ?</summary><p>Non : chaque site ou application déclaré a son propre identifiant. Ajoute chaque site dans ton espace (jusqu'à 10) pour recevoir un identifiant par site.</p></details>
   <details><summary>Puis-je choisir les annonces affichées ?</summary><p>Tu choisis les catégories acceptées et tes formats. Le choix de l'annonce dans ces limites est fait par Afrolook Ads, selon le ciblage de chaque annonceur.</p></details>
   <details><summary>Que se passe-t-il si mon audience est plus petite que celle déclarée ?</summary><p>Tu le vois dans ton espace. Un écart important est signalé ; l'audience retenue peut être ajustée, et la diffusion suspendue en cas d'écart durable ou de déclaration manifestement fausse.</p></details>
   <details><summary>Où trouver de l'aide ?</summary><p><a href="/contact/">Écris-nous</a> avec ton identifiant publicitaire.</p></details>
  </div>
 </section>
 <div class="cta"><a class="btn btn-primary adbig" href="/ads/diffuseur/">${G} Ouvrir mon espace diffuseur</a><a class="btn btn-line adbig" href="/ads/diffuseur/regles/">${ico('shield', 18)} Règles des diffuseurs</a></div>
</div></section>`;
}


