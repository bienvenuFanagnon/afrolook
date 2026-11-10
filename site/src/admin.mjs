// Tableau de bord de l'administration (11/2026) : page réservée à l'équipe, en consultation seule. Toutes les données viennent de l'API Afrolook (`/v1/admin/dashboard/...`), jamais de Firebase :
// Firebase ne sert qu'à connecter la personne avec son compte Google, comme dans les espaces annonceur et diffuseur. Le contenu est dessiné par /js/admin.js.
import { adminNav } from './adminnav.mjs';

export const ADMIN_DASH_META = {
  title: 'Tableau de bord | Administration Afrolook',
  desc: 'Inscriptions, connexions, meilleurs utilisateurs, annonceurs et diffuseurs : consultation réservée à l’équipe Afrolook.',
};

export function adminDashboardPage(fbConfig, api) {
  return `${adminNav('dash')}<section class="adm" id="adm" data-api="${api}"><div class="wrap">
 <script type="application/json" id="fbcfg">${JSON.stringify(fbConfig)}</script>
 <div class="adm-top"><div><span class="kicker">Administration</span><h1 class="h2" style="margin-top:6px">Tableau de bord</h1></div>
  <div class="adm-user" id="adm-user" hidden><span id="adm-mail"></span><button class="adm-btn" id="adm-out" type="button">Déconnexion</button></div></div>
 <div class="adm-card adm-gate" id="adm-gate"><h2>Réservé à l’équipe</h2><p>Connecte-toi avec ton compte Google d’équipe. Cette page est en consultation seule : aucune opération n’y est possible.</p>
  <button class="btn btn-primary" id="adm-in" type="button">Se connecter avec Google</button><p class="adm-err" id="adm-gerr" role="alert" hidden></p></div>
 <div id="adm-app" hidden><nav class="adm-tabs" id="adm-tabs" aria-label="Sections du tableau de bord"></nav><div id="adm-main" aria-live="polite"></div></div>
</div></section>
<script src="/js/admin.js?v=__ASSET_V__" type="module"></script>`;
}
