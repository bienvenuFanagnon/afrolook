/* Refonte 2026 : téléphones qui changent d'écran, histoire de l'application, Studio, drapeau du pays, lancement de campagne.
   Généré à partir de la maquette validée. */
(function(){
'use strict';
if(!document.querySelector('.v2'))return;

/* ---- Anglais : les écrans dessinés et les textes composés par le script sont traduits ici ---- */
const EN_=(document.documentElement.lang||'fr').slice(0,2)==='en';
const L=(fr,en)=>EN_?en:fr;
const EN={
'Messages':'Messages','Vidéos':'Videos','Créer':'Create','✨ Pour toi':'✨ For you','🔥 Viral':'🔥 Viral','🏆 Défis':'🏆 Challenges','Ma chronique':'My chronicle','il y a 2 h':'2 h ago',
'Abonnés':'Following','Pour toi':'For you','Offrir':'Gift','Partager':'Share','Dakar, ce soir. Ça se passe sur la corniche.':'Dakar tonight. It all happens on the seafront.','Musique libre de droits':'Royalty-free music',
'Awa en direct':'Awa is live','Soirée musique':'Music night',' a offert':' sent','une rose':'a rose','Quelle ambiance !':'What a vibe!','On est là depuis Abidjan':'Watching from Abidjan','Bravo Awa':'Well done Awa',
'Écris un commentaire…':'Write a comment…','Mon portefeuille':'My wallet','Pièces gagnées · exemple':'Coins earned · example','pièces':'coins','Cadeaux':'Gifts','Canal privé':'Private channel',
'Retirer mes gains':'Withdraw my earnings','Virement':'Bank transfer','Annonce':'Ad','Portraits et vidéos pour ta marque':'Portraits and videos for your brand','Visiter le site':'Visit the site',
'Groupe du quartier':'Neighborhood group','Portraits et vidéos pour ta marque.':'Portraits and videos for your brand.',"Ouvrir l'annonce":'Open the ad','Merci, je regarde tout de suite !':'Thanks, I am looking right now!',
'Offre du mois chez Kofi Studio.':'Offer of the month at Kofi Studio.','Mes annonces':'My ads','En ligne':'Live','Visiter le site · 14 jours':'Visit the site · 14 days','En validation':'In review',
'Réserver · 14 jours':'Book · 14 days','Terminée':'Ended','Installer · 14 jours':'Install · 14 days','2 480 vues':'2,480 views','1 946 vues':'1,946 views','+ Nouvelle annonce':'+ New ad',
'Publier':'Publish','UN FILM DE @AMINATA_K':'A FILM BY @AMINATA_K','MON ANNÉE':'MY YEAR','Avec':'With','mes amis et ma famille':'my friends and family','Musique':'Music','Piste libre de droits':'Royalty-free track',
'Un grand merci':'Big thanks','à toute ma communauté':'to my whole community','Fin':'The end','Mon anniversaire':'My birthday','Plus que quelques jours':'Only a few days left','Compte à rebours':'Countdown',
'J-3':'D-3','Samedi 20 h':'Saturday 8 pm','Compte à rebours : 2 j 4 h':'Countdown: 2 d 4 h','Lieu':'Place',"Place de l'Indépendance, Dakar":'Independence Square, Dakar','Répondre sur WhatsApp':'Reply on WhatsApp',
'UN FILM DE AMINATA ET KOFI':'A FILM BY AMINATA AND KOFI','MON':'MY','MARIAGE':'WEDDING','Médias':'Media','Filtres':'Filters','Texte':'Text',
'Piste libre de droits · ambiance film':'Royalty-free track · film mood','Piste libre de droits · fête':'Royalty-free track · party','Piste libre de droits · énergie':'Royalty-free track · energy','Piste libre de droits · douce':'Royalty-free track · soft',
'Le fil':'The feed','Les vidéos':'Videos','Les lives':'Lives','Le Studio':'The Studio','Ton post décolle':'Your post is taking off','Cadeau reçu de Koffi':'Gift received from Koffi',
'Une vidéo qui plaît va plus loin':'A video people like goes further','Awa est en direct':'Awa is live','Une rose offerte':'A rose sent','Modèle « Mon année »':'“My year” template','Filtre appliqué':'Filter applied',
'Dans le fil Afrolook':'In the Afrolook feed','Partagée sur WhatsApp':'Shared on WhatsApp','Suivie dans ton espace':'Tracked in your space','Visite valide':'Valid visit','Anti-fraude':'Anti-fraud',
'Partagé sur WhatsApp':'Shared on WhatsApp','Suivi en direct':'Live tracking','Annonce gratuite : 14 jours':'Free ad: 14 days'
};
const tr=s=>EN_?(EN[s]||s):s;
function trNode(n){
  if(n.nodeType===3){const raw=n.nodeValue,t=raw.trim();if(t&&EN[t]&&EN[t]!==t){n.nodeValue=raw.replace(t,EN[t]);}return;}
  if(n.nodeType===1){
    ['aria-label','alt'].forEach(a=>{const v=n.getAttribute&&n.getAttribute(a);if(v&&EN[v])n.setAttribute(a,EN[v]);});
    n.childNodes.forEach(trNode);
  }
}
if(EN_){
  const root=document.querySelector('.v2');
  new MutationObserver(ms=>ms.forEach(m=>{m.addedNodes.forEach(trNode);if(m.type==='characterData'&&m.target.parentNode)trNode(m.target);})).observe(root,{childList:true,subtree:true,characterData:true});
}
const FN_EN={tg:'Togo',ci:"Côte d'Ivoire",bj:'Benin',cm:'Cameroon',bf:'Burkina Faso',sn:'Senegal',ml:'Mali',ne:'Niger',gh:'Ghana',ng:'Nigeria',cd:'DR Congo',ga:'Gabon',gn:'Guinea',cg:'Congo',ma:'Morocco',dz:'Algeria',ke:'Kenya',za:'South Africa'};

const IMGMAP={"logo": "/img/logo.webp", "studio": "/img/studio.webp", "p_slash": "/img/partners/slashatlas.webp", "p_prono": "/img/partners/pronoflash.webp", "p_epargne": "/img/partners/epargneplus.webp", "f_5688730": "/img/people/f_5688730.webp", "h_6774139": "/img/people/h_6774139.webp", "h_2033447": "/img/people/h_2033447.webp", "f_7229044": "/img/people/f_7229044.webp", "f_20169681": "/img/people/f_20169681.webp", "h_31679357": "/img/people/h_31679357.webp", "a_carte": "/img/ads/carte.webp", "a_banniere": "/img/ads/banniere.webp", "a_affiche": "/img/ads/affiche.webp", "a_carrousel": "/img/ads/carrousel.webp", "a_video": "/img/ads/video.webp", "c_neon": "/img/card-neon.webp", "c_film": "/img/card-film.webp", "c_kente": "/img/card-kente.webp", "c_collector": "/img/card-collector.webp", "c_magazine": "/img/card-magazine.webp", "c_glass": "/img/card-glass.webp", "c_passport": "/img/card-passport.webp", "c_tarot": "/img/card-tarot.webp", "c_sport": "/img/card-sport.webp", "c_music": "/img/card-music.webp"};
const IMG=new Proxy({},{get:(_,k)=>k.indexOf('fl_')===0?'/img/flags/'+k.slice(3)+'.svg':IMGMAP[k]});
const P={
heart:'<path d="M12 21s-7-4.5-9.5-9A5.5 5.5 0 0 1 12 6a5.5 5.5 0 0 1 9.5 6C19 16.5 12 21 12 21z"/>',
gift:'<rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13M5 12v8h14v-8M12 8c-2-4-6-3.5-5 0M12 8c2-4 6-3.5 5 0"/>',
chat:'<path d="M4 5h16v11H9l-5 4V5z"/>',
eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
trophy:'<path d="M7 4h10v4a5 5 0 0 1-10 0V4z"/><path d="M5 5H3v2a3 3 0 0 0 3 3M19 5h2v2a3 3 0 0 1-3 3M12 13v4M8 21h8M10 17h4"/>',
tv:'<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/><path d="M10 9.5l4 2-4 2v-4z"/>',
film:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M8 4v5M16 4v5M10 13l4 2.5-4 2.5v-5z"/>',
users:'<circle cx="9" cy="8" r="3.5"/><path d="M2 20a7 7 0 0 1 14 0M16 5a3.5 3.5 0 0 1 0 7M18 20a7 7 0 0 0-3-5.7"/>',
live:'<rect x="3" y="6" width="13" height="12" rx="3"/><path d="M16 10l5-3v10l-5-3"/>',
lock:'<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
link:'<path d="M10 14a4 4 0 0 0 5.5 0l3-3a4 4 0 0 0-5.5-5.5l-1 1M14 10a4 4 0 0 0-5.5 0l-3 3a4 4 0 0 0 5.5 5.5l1-1"/>',
rocket:'<path d="M5 19c0-3 1-4 3-5l5-5M9 15l-3 3M14 4c3 0 6 1 6 1s1 3 1 6l-7 7-6-6 6-8z"/><circle cx="15" cy="9" r="1.2"/>',
coin:'<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5c0-1 1-1.7 2.5-1.7s2.5.7 2.5 1.7-1 1.5-2.5 1.7-2.5.7-2.5 1.7 1 1.7 2.5 1.7 2.5-.7 2.5-1.7M12 6.5v1.3M12 16.2v1.3"/>',
send:'<path d="M3 11l18-8-8 18-2-8-8-2z"/>',
img:'<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-8 9"/>',
cap:'<path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M7 10v5c0 1.5 2.2 3 5 3s5-1.5 5-3v-5"/>',
sparkle:'<path d="M12 3l1.8 4.6L18 9l-4.2 1.4L12 15l-1.8-4.6L6 9l4.2-1.4L12 3zM18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 18l2.2-.8L18 15z"/>',
music:'<path d="M9 18V6l11-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
bell:'<path d="M6 17V11a6 6 0 0 1 12 0v6l2 2H4zM10 21h4"/>',
search:'<circle cx="11" cy="11" r="7"/><path d="M21 21l-5-5"/>',
plus:'<path d="M12 5v14M5 12h14"/>',
home:'<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9z"/>',
user:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
share:'<path d="M4 12v7h16v-7M12 3v12M7 8l5-5 5 5"/>',
msg:'<path d="M4 5h16v11H9l-5 4V5z"/>',
vid:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M10 9l5 3-5 3z"/>',
clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
pin:'<path d="M12 21s7-6 7-11a7 7 0 0 0-14 0c0 5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
wa:'<path d="M4 20l1.3-4A8 8 0 1 1 8 18.7L4 20z"/>',
poll:'<path d="M5 20V10M12 20V4M19 20v-7"/>',
globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
phone:'<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
call:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
shield:'<path d="M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6l8-3z"/><path d="M9 12l2 2 4-4"/>',
check:'<path d="M5 12.5l4.5 4.5L19 7.5"/>',
click:'<path d="M8 3l10 7-4.5 1.5L16 17l-2.5 1-2.5-5.5L8 15V3z"/>'
};
const ic=n=>'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+P[n]+'</svg>';
const im=(k,c='')=>'<img src="'+(IMG[k]||'')+'" alt="" '+(c?'class="'+c+'" ':'')+'>';

const S={};
S.fil=()=>`<div class="v-fill"><span class="v-isl"></span><div class="v-sb"><b>9:41</b><span>5G ▮</span></div>
<div class="v-ab"><b>Afrolook</b><span class="v-ico"><i class="v-bell">${ic('bell')}<u>9+</u></i>${ic('search')}</span></div>
<div class="v-qr"><div>${ic('msg')}Messages</div><div>${ic('vid')}Vidéos</div><div class="v-cr">${ic('plus')}Créer</div><div>${ic('cap')}Quiz</div><div class="v-lv">${ic('live')}Lives</div></div>
<div class="v-tabs"><span class="v-on">✨ Pour toi</span><span>🔥 Viral</span><span>⚽ Sport</span><span>🏆 Défis</span></div>
<div class="v-chr"><div><span class="v-me"><b>+</b></span>Ma chronique</div><div><span class="v-ring">${im('f_5688730')}</span>aminata</div><div><span class="v-ring">${im('h_2033447')}</span>kofi</div><div><span class="v-ring">${im('f_7229044')}</span>awa</div><div><span class="v-ring">${im('h_6774139')}</span>ibra</div></div>
<div class="v-post"><div class="v-ph">${im('f_20169681')}<div><b>Fatou · Abidjan</b><small>il y a 2 h</small></div></div>${im('f_20169681','pimg')}<div class="v-pa"><span class="v-lk">${ic('heart')}2,4 k</span><span>${ic('chat')}186</span><span class="v-gf">${ic('gift')}</span><span style="margin-left:auto">${ic('share')}</span></div></div>
<div class="v-bn"><span class="v-on">${ic('home')}</span>${ic('vid')}<span class="v-pl">${ic('plus')}</span>${ic('msg')}${ic('user')}</div></div>`;
S.video=()=>`<div class="v-fill v-vid"><span class="v-isl"></span>${im('f_5688730')}<div class="v-vtop"><span>Abonnés</span><b>Pour toi</b><span>🔥 Viral</span></div>
<div class="v-rail">${im('h_6774139','av')}<div>${ic('heart')}<br>12,4 k</div><div>${ic('chat')}<br>318</div><div>${ic('gift')}<br>Offrir</div><div>${ic('share')}<br>Partager</div></div>
<div class="v-vcap"><b>@aminata_k</b><span>Dakar, ce soir. Ça se passe sur la corniche.</span><em>${ic('music')}Musique libre de droits</em></div><div class="v-vprog"><i></i></div></div>`;
S.live=()=>`<div class="v-fill v-live"><span class="v-isl"></span>${im('f_7229044')}<div class="v-lhead">${im('f_7229044')}<div><b>Awa en direct</b><small>Soirée musique</small></div><span class="v-eye">${ic('eye')}1,2 k</span><span class="v-pill">LIVE</span></div>
<div class="v-gifts"><i>${ic('gift')}</i><span><b>Koffi</b> a offert<br>une rose</span></div>
<div class="v-cmts"><p><b>Ibra</b> Quelle ambiance !</p><p><b>Fatou</b> On est là depuis Abidjan</p><p><b>Koffi</b> Bravo Awa</p></div>
<div class="v-lbar"><span>Écris un commentaire…</span><i>${ic('gift')}</i></div></div>`;
S.wallet=()=>`<div class="v-fill"><span class="v-isl"></span><div class="v-sb"><b>9:41</b><span>5G ▮</span></div><div class="v-ab"><b>Afrolook</b><span class="v-ico">${ic('bell')}</span></div>
<div class="v-wal"><h4>Mon portefeuille</h4><div class="v-wcard"><small>Pièces gagnées · exemple</small><strong>12 480</strong><span class="v-coin">${ic('coin')}pièces</span></div>
<div class="v-wrow"><i>${ic('heart')}</i><span>Likes</span><b>3 120</b></div><div class="v-wrow"><i class="v-y">${ic('gift')}</i><span>Cadeaux</span><b>5 400</b></div><div class="v-wrow"><i>${ic('tv')}</i><span>Canal privé</span><b>2 460</b></div><div class="v-wrow"><i class="v-r">${ic('live')}</i><span>Lives</span><b>1 500</b></div>
<div class="v-wbtn">Retirer mes gains</div><div class="v-wpay"><span>Mobile Money</span><span>Virement</span><span>PayPal</span></div></div>
<div class="v-bn"><span>${ic('home')}</span>${ic('vid')}<span class="v-pl">${ic('plus')}</span>${ic('msg')}<span class="v-on">${ic('user')}</span></div></div>`;

/* ---- Écrans supplémentaires : Studio (accueil) et Afrolook Ads ---- */
S.studio=()=>'<div class="v-fill v-ed">'+editorInner('film')+'</div>';
S.adfeed=()=>`<div class="v-fill"><span class="v-isl"></span><div class="v-sb"><b>9:41</b><span>5G ▮</span></div>
<div class="v-ab"><b>Afrolook</b><span class="v-ico"><i class="v-bell">${ic('bell')}<u>9+</u></i>${ic('search')}</span></div>
<div class="v-tabs"><span class="v-on">✨ Pour toi</span><span>🔥 Viral</span><span>⚽ Sport</span><span>🏆 Défis</span></div>
<div class="v-post"><div class="v-ph">${im('h_2033447')}<div><b>Kofi Studio<span class="v-spon">Annonce</span></b><small>Portraits et vidéos pour ta marque</small></div></div>${im('a_banniere','pimg')}<div class="v-adbtn">Visiter le site</div></div>
<div class="v-post" style="margin-top:1.2em"><div class="v-ph">${im('f_20169681')}<div><b>Fatou · Abidjan</b><small>il y a 2 h</small></div></div>${im('f_20169681','pimg')}</div>
<div class="v-bn"><span class="v-on">${ic('home')}</span>${ic('vid')}<span class="v-pl">${ic('plus')}</span>${ic('msg')}${ic('user')}</div></div>`;
S.wa=()=>`<div class="v-fill" style="background:#ECE5DD"><span class="v-isl"></span><div class="v-sb" style="background:#075E54;color:#fff"><b>9:41</b><span>5G ▮</span></div>
<div class="v-wah"><b style="font-size:1.4em">‹</b><b>Groupe du quartier</b></div>
<div class="v-wac"><div class="v-bub">${im('a_affiche')}<p><b>Kofi Studio</b><br>Portraits et vidéos pour ta marque.</p><span class="v-lk">Ouvrir l'annonce</span></div>
<div class="v-bub v-out">Merci, je regarde tout de suite !</div>
<div class="v-bub">${im('a_carte')}<p>Offre du mois chez Kofi Studio.</p><span class="v-lk">Ouvrir l'annonce</span></div></div></div>`;
S.adspace=()=>`<div class="v-fill"><span class="v-isl"></span><div class="v-sb"><b>9:41</b><span>5G ▮</span></div><div class="v-ab"><b>Afrolook Ads</b><span class="v-ico">${ic('bell')}</span></div>
<div class="v-wal"><h4>Mes annonces</h4>
<div class="v-ar"><b>Kofi Studio</b><span class="v-st v-ok">En ligne</span><small>Visiter le site · 14 jours</small><span class="v-n">2 480 vues</span></div>
<div class="v-ar"><b>Festival Afro Beats</b><span class="v-st v-wait">En validation</span><small>Réserver · 14 jours</small><span class="v-n">—</span></div>
<div class="v-ar"><b>App Taxi Lomé</b><span class="v-st v-end">Terminée</span><small>Installer · 14 jours</small><span class="v-n">1 946 vues</span></div>
<div class="v-wbtn">+ Nouvelle annonce</div></div></div>`;

/* ---- Téléphone qui change d'écran ---- */
const ROT={
 home:[
  {k:'fil',n:'Le fil',t:[['heart','Ton post décolle'],['gift','Cadeau reçu de Koffi']],c:['c_neon','c_film']},
  {k:'video',n:'Les vidéos',t:[['eye','Une vidéo qui plaît va plus loin'],['music','Musique libre de droits']],c:['c_collector','c_kente']},
  {k:'live',n:'Les lives',t:[['live','Awa est en direct'],['gift','Une rose offerte']],c:['c_magazine','c_glass']},
  {k:'studio',n:'Le Studio',t:[['film','Modèle « Mon année »'],['sparkle','Filtre appliqué']],c:['c_tarot','c_music']}],
 ads:[
  {k:'adfeed',n:'Dans le fil Afrolook',t:[['check','Visite valide'],['shield','Anti-fraude']],c:['a_carte','a_banniere']},
  {k:'wa',n:'Partagée sur WhatsApp',t:[['wa','Partagé sur WhatsApp'],['check','Visite valide']],c:['a_affiche','a_carrousel']},
  {k:'adspace',n:'Suivie dans ton espace',t:[['eye','Suivi en direct'],['gift','Annonce gratuite : 14 jours']],c:['a_video','a_banniere']}]
};
function initRot(stage){
  const slides=ROT[stage.dataset.rot],scr=stage.querySelector('.v-scr'),cards=[...stage.querySelectorAll('.v-fcard')],toasts=[...stage.querySelectorAll('.v-toast')],dots=stage.querySelector('.v-dots');
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  scr.innerHTML=slides.map((s,i)=>'<div class="v-fade'+(i?'':' v-on')+'">'+S[s.k]()+'</div>').join('');
  dots.innerHTML=slides.map(s=>'<button type="button" aria-label="'+tr(s.n)+'"></button>').join('');
  const btns=[...dots.querySelectorAll('button')];
  let cur=-1,hold=0,vis=true;
  function go(i,first){
    if(i===cur)return;cur=i;const s=slides[i];
    [...scr.children].forEach((f,j)=>f.classList.toggle('v-on',j===i));
    btns.forEach((b,j)=>b.setAttribute('aria-current',j===i?'true':'false'));
    cards.forEach((c,j)=>{c.style.opacity=0;setTimeout(()=>{c.src=IMG[s.c[j]]||'';c.style.opacity=1;},first?0:330);});
    toasts.forEach((t,j)=>{t.classList.add('v-sw');setTimeout(()=>{t.querySelector('i').innerHTML=ic(s.t[j][0]);t.querySelector('span').textContent=tr(s.t[j][1]);t.classList.remove('v-sw');},first?0:260);});
  }
  btns.forEach((b,i)=>b.addEventListener('click',()=>{hold=Date.now()+12000;go(i);}));
  stage.addEventListener('pointerenter',()=>{hold=Infinity;});
  stage.addEventListener('pointerleave',()=>{hold=Date.now()+1500;});
  new IntersectionObserver(es=>{vis=es[0].isIntersecting;}).observe(stage);
  if(!reduce)setInterval(()=>{if(document.hidden||!vis||Date.now()<hold)return;go((cur+1)%slides.length);},4200);
  go(0,true);
}


/* ---- Drapeaux de plusieurs pays ---- */
const FLAGS=[['tg','Togo',27,4],['ci',"Côte d'Ivoire",7,8],['bj','Bénin',1,8],['cm','Cameroun',20,5],['bf','Burkina Faso',11,12],['sn','Sénégal',4,4],['ml','Mali',22,9],['ne','Niger',3,8],['gh','Ghana',6,3],['ng','Nigéria',1,10],['cd','RD Congo',30,6],['ga','Gabon',17,8],['gn','Guinée',2,10],['cg','Congo',15,8],['ma','Maroc',30,7],['dz','Algérie',5,7],['ke','Kenya',12,12],['za','Afrique du Sud',27,4]];
if(EN_)FLAGS.forEach(f=>{f[1]=FN_EN[f[0]]||f[1];});
const MOIS=['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
const TZ={'Africa/Lome':'tg','Africa/Abidjan':'ci','Africa/Porto-Novo':'bj','Africa/Douala':'cm','Africa/Ouagadougou':'bf','Africa/Dakar':'sn','Africa/Bamako':'ml','Africa/Niamey':'ne','Africa/Accra':'gh','Africa/Lagos':'ng','Africa/Kinshasa':'cd','Africa/Libreville':'ga','Africa/Conakry':'gn','Africa/Brazzaville':'cg','Africa/Casablanca':'ma','Africa/Algiers':'dz','Africa/Nairobi':'ke','Africa/Johannesburg':'za'};
/* Fêtes nationales [mois, jour] : même table que src/data.mjs (NATIONAL_DAYS). Sert quand le pays de la personne n'est pas dans les pastilles. */
const ND={DZ:[7,5],AO:[11,11],BJ:[8,1],BW:[9,30],BF:[12,11],BI:[7,1],CV:[7,5],CM:[5,20],CF:[12,1],TD:[8,11],KM:[7,6],CG:[8,15],CD:[6,30],CI:[8,7],DJ:[6,27],EG:[7,23],GQ:[10,12],ER:[5,24],SZ:[9,6],GA:[8,17],
GM:[2,18],GH:[3,6],GN:[10,2],GW:[9,24],KE:[12,12],LS:[10,4],LR:[7,26],LY:[12,24],MG:[6,26],MW:[7,6],ML:[9,22],MR:[11,28],MU:[3,12],MA:[7,30],MZ:[6,25],NA:[3,21],NE:[8,3],NG:[10,1],RW:[7,1],ST:[7,12],
SN:[4,4],SC:[6,29],SL:[4,27],SO:[7,1],ZA:[4,27],SS:[7,9],TZ:[12,9],TG:[4,27],TN:[3,20],UG:[10,9],ZM:[10,24],ZW:[4,18],FR:[7,14],BE:[7,21],CA:[7,1],US:[7,4],BR:[9,7],DE:[10,3],IT:[6,2],CH:[8,1],HT:[1,1],JM:[8,6]};
/* Pays vu par le serveur d'après la connexion (réponse du réseau Cloudflare, placé devant le site). Rien n'est enregistré. */
function serverCountry(){
  return fetch('/cdn-cgi/trace',{cache:'no-store'}).then(r=>r.ok?r.text():'').then(t=>{const m=t.match(/^loc=([A-Z]{2})$/m);return m?m[1].toLowerCase():'';}).catch(()=>'');
}
/* Secours quand le serveur ne répond pas : région de la langue, sinon fuseau horaire de l'appareil. */
function deviceCountry(){let c='';try{const m=(navigator.language||'').match(/-([A-Za-z]{2})$/);if(m)c=m[1].toLowerCase();}catch(e){}
  if(!ND[c.toUpperCase()]){try{c=TZ[Intl.DateTimeFormat().resolvedOptions().timeZone]||'';}catch(e){c='';}}
  return c;}
/* Place du pays dans les pastilles ; il y est ajouté en premier s'il a un drapeau et une fête connue. -1 : pays sans drapeau. */
function countryIndex(code){
  if(!code)return -1;
  const i=FLAGS.findIndex(f=>f[0]===code);if(i>=0)return i;
  const nd=ND[code.toUpperCase()];if(!nd)return -1;
  let name=code.toUpperCase();try{name=new Intl.DisplayNames([EN_?'en':'fr'],{type:'region'}).of(code.toUpperCase())||name;}catch(e){}
  FLAGS.unshift([code,name,nd[1],nd[0]]);return 0;
}
const MOIS_EN=['January','February','March','April','May','June','July','August','September','October','November','December'];
const jour=(d,m)=>EN_?MOIS_EN[m-1]+' '+d:(d===1?'1er':d)+' '+MOIS[m-1];
function initFlags(box){
  const big=box.querySelector('.v-bigflag'),nm=box.querySelector('.v-fname'),chips=box.querySelector('.v-fchips'),dl=box.closest('.v-dl');
  const note=document.createElement('p');note.className='v-fdet';box.appendChild(note);
  let cur=-1,bs=[],touched=false;
  function txt(i){const f=FLAGS[i],k=dl&&dl.querySelector('.v-fkick'),u=dl&&dl.querySelector('.v-fsub');if(!dl)return;
    if(dl.dataset.fl==='ads'){k.textContent='Afrolook Ads · '+f[1];u.textContent=L('Choisis les pays à atteindre : '+f[1]+", et d'autres.",'Choose the countries to reach: '+f[1]+', and others.');}
    else{k.textContent='Afrolook · '+f[1];u.textContent=L('Le '+jour(f[2],f[3])+', fête nationale ('+f[1]+'), les styles de cartes drapeau sont offerts.','On '+jour(f[2],f[3])+', national day ('+f[1]+'), all flag card styles are free.');}}
  function go(i,first){if(i===cur)return;cur=i;bs.forEach((b,j)=>b.setAttribute('aria-pressed',j===i));
    const set=()=>{big.src=IMG['fl_'+FLAGS[i][0]];nm.textContent=FLAGS[i][1];big.alt=L('Drapeau : ','Flag: ')+FLAGS[i][1];big.classList.remove('v-sw');txt(i);};
    if(first){set();return;}big.classList.add('v-sw');setTimeout(set,250);}
  function render(){chips.innerHTML=FLAGS.map(f=>'<button type="button" aria-label="'+f[1]+'" aria-pressed="false"><img src="'+IMG['fl_'+f[0]]+'" alt=""></button>').join('');
    bs=[...chips.children];bs.forEach((b,i)=>b.addEventListener('click',()=>{touched=true;go(i);}));}
  /* how : 'server' (connexion), 'device' (appareil) ou '' (inconnu : le Togo) */
  function show(code,how){const i=countryIndex(code);render();cur=-1;go(i>=0?i:0,true);
    note.textContent=i<0?L('Pays inconnu : le Togo s’affiche par défaut. Touche un drapeau pour voir les autres.','Unknown country: Togo is shown by default. Tap a flag to see the others.')
      :how==='server'?L('Pays détecté d’après ta connexion. Touche un drapeau pour en changer.','Country detected from your connection. Tap a flag to change it.')
      :L('Pays détecté sur ton appareil. Touche un drapeau pour en changer.','Country detected on your device. Tap a flag to change it.');}
  const dev=deviceCountry();show(dev,'device');
  /* le serveur a le dernier mot, sauf si la personne a déjà choisi un drapeau ou si son pays n'a pas de drapeau ici */
  serverCountry().then(c=>{if(c&&!touched&&(ND[c.toUpperCase()]||FLAGS.some(f=>f[0]===c)))show(c,'server');});
}

/* ---- Lancer une campagne depuis le site ---- */
(function(){
  const types=document.getElementById('lType');if(!types)return;
  const btn=document.getElementById('lbtn'),sum=document.getElementById('lsum'),rng=document.getElementById('lrange'),aud=document.getElementById('lAud');
  const free=document.getElementById('lfree'),net=document.getElementById('lnet'),share=document.getElementById('lshare');
  const fmt=n=>Math.round(n).toLocaleString(EN_?'en-US':'fr-FR').replace(/[  ]/g,' ');
  function upd(){
    aud.hidden=!share.checked;
    const t=types.querySelector('[aria-pressed="true"]'),n=+rng.value,rows=[[L("Type d'annonce",'Ad type'),t?t.textContent.trim():'—']];
    if(free.checked)rows.push([L('Gratuit sur 4 plateformes','Free on 4 platforms'),'0 FCFA']);
    if(net.checked)rows.push([L('Afrolook et partenaires','Afrolook and partners'),L('Budget au choix','Budget of your choice')]);
    if(share.checked){rows.push([L('Audience du partage','Sharing audience'),fmt(n)+L(' personnes',' people')]);rows.push([L('Prix du partage','Sharing price'),fmt(n/1000*500)+' FCFA']);rows.push([L('Visites estimées (environ 2 %)','Estimated visits (about 2%)'),fmt(n*.02)]);}
    if(!free.checked&&!net.checked&&!share.checked)rows.push([L('Diffusion','Delivery'),L('Choisis une option','Choose an option')]);
    const go=document.getElementById('v-lgo');if(go)go.href='/ads/espace/'+(share.checked?'?aud='+n:'');
    sum.innerHTML=rows.map(r=>'<li><span>'+r[0]+'</span><b>'+r[1]+'</b></li>').join('');
  }
  types.addEventListener('click',e=>{const b=e.target.closest('.v-opt');if(!b)return;
    types.querySelectorAll('.v-opt').forEach(x=>x.setAttribute('aria-pressed',x===b));btn.textContent=b.dataset.b;upd();});
  [free,net,share,rng].forEach(c=>c.addEventListener('input',upd));
  document.querySelectorAll('[data-free]').forEach(a=>a.addEventListener('click',()=>{free.checked=true;upd();}));
  upd();
})();

function fillScreens(){
  document.querySelectorAll('[data-scr]').forEach(el=>{el.innerHTML=S[el.dataset.scr]();});
  const m=document.getElementById('mainScr');
  if(m)m.innerHTML=['fil','video','live','wallet'].map((k,i)=>'<div class="v-fade'+(i?'':' v-on')+'" data-k="'+k+'">'+S[k]()+'</div>').join('');
  
  document.querySelectorAll('[data-ic]').forEach(el=>{el.innerHTML=ic(el.dataset.ic);});
  document.querySelectorAll('[data-li]').forEach(el=>{el.insertAdjacentHTML('afterbegin',ic(el.dataset.li));});
}

/* Éditeur du Studio */
const T={
 film:{img:'h_31679357',ov:'film',title:'MON ANNÉE<br>2026',small:'UN FILM DE @AMINATA_K',clips:['h_31679357','f_5688730','h_2033447','f_7229044','f_20169681'],music:'Piste libre de droits · ambiance film'},
 anniv:{img:'f_5688730',ov:'anniv',clips:['f_5688730','f_20169681','h_6774139'],music:'Piste libre de droits · fête'},
 event:{img:'h_2033447',ov:'event',clips:['h_2033447','h_6774139'],music:'Piste libre de droits · énergie'},
 mariage:{img:'f_20169681',ov:'film',title:'MON<br>MARIAGE',small:'UN FILM DE AMINATA ET KOFI',clips:['f_20169681','f_7229044','h_31679357','f_5688730'],music:'Piste libre de droits · douce'}
};
const credits='<div><b>Avec</b><br>mes amis et ma famille<br><b>Musique</b><br>Piste libre de droits<br><b>Image</b><br>Aminata<br><b>Un grand merci</b><br>à toute ma communauté<br><b>Fin</b></div>';
function ov(t){
  if(t.ov==='film')return `<div class="v-ov v-film v-on"><small>${t.small}</small><h5>${t.title}</h5><div class="v-roll">${credits}</div></div>`;
  if(t.ov==='anniv')return `<div class="v-ov v-on"><div class="v-wd v-t">${ic('gift')}<span><b>Mon anniversaire</b><br>Plus que quelques jours</span></div><div class="v-wd v-big"><span>Compte à rebours</span><strong>J-3</strong></div></div>`;
  return `<div class="v-ov v-on"><div class="v-wd v-t">${ic('clock')}<span><b>Samedi 20 h</b><br>Compte à rebours : 2 j 4 h</span></div><div class="v-wd" style="left:1em;right:1em;bottom:5em">${ic('pin')}<span><b>Lieu</b><br>Place de l'Indépendance, Dakar</span></div><div class="v-wd v-m">${ic('wa')}Répondre sur WhatsApp</div></div>`;
}
function wave(){let h='',s=7;for(let i=0;i<46;i++){s=(s*9301+49297)%233280;const v=.25+.75*Math.abs(Math.sin(i*.55))*(.5+s/466560);h+='<i style="height:'+Math.round(v*100)+'%"></i>';}return h;}
function editorInner(k){
  const t=T[k];
  return `<span class="v-isl"></span><div class="v-sb"><b>9:41</b><span>5G ▮</span></div><div class="v-edt"><b>Studio</b><span>Publier</span></div>
  <div class="v-prev">${im(t.img)}${ov(t)}</div>
  <div class="v-tl"><div class="v-clips">${t.clips.map(c=>im(c)).join('')}</div><div class="v-wave">${wave()}</div><div class="v-wnote">${ic('music')}${t.music}</div></div>
  <div class="v-tools"><div class="v-on">${ic('film')}Médias</div><div>${ic('sparkle')}Filtres</div><div>${ic('music')}Musique</div><div>${ic('poll')}Widgets</div><div>${ic('chat')}Texte</div></div>`;
}
function renderEditor(k){const e=document.getElementById('editor');if(e)e.innerHTML=editorInner(k);}

fillScreens();renderEditor('film');
document.querySelectorAll('[data-rot]').forEach(initRot);
document.querySelectorAll('[data-flags]').forEach(initFlags);

const tplbar=document.querySelector('.v-tplbar');if(tplbar)tplbar.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;
  document.querySelectorAll('.v-tplbar button').forEach(x=>x.setAttribute('aria-pressed',x===b));renderEditor(b.dataset.t);});

/* Histoire de l'application */
const steps=[...document.querySelectorAll('.v-step')];
const io=new IntersectionObserver(es=>{es.forEach(en=>{if(en.isIntersecting){
  steps.forEach(s=>s.classList.toggle('v-on',s===en.target));
  document.querySelectorAll('#mainScr .v-fade').forEach(f=>f.classList.toggle('v-on',f.dataset.k===en.target.dataset.s));}});},{rootMargin:'-45% 0px -45% 0px'});
steps.forEach(s=>io.observe(s));if(steps[0])steps[0].classList.add('v-on');

/* Révélations, filet, parallaxe */
const rm=matchMedia('(prefers-reduced-motion: reduce)').matches;
const rv=new IntersectionObserver(es=>es.forEach(en=>{if(en.isIntersecting){en.target.classList.add('v-in');rv.unobserve(en.target);}}),{threshold:.12});
document.querySelectorAll('.v-rv').forEach(el=>rm?el.classList.add('v-in'):rv.observe(el));
const fil=document.getElementById('v-filet'),par=[...document.querySelectorAll('[data-p]')];
function onScroll(){const h=document.documentElement.scrollHeight-innerHeight;if(fil)fil.style.transform='scaleY('+Math.min(1,Math.max(.02,scrollY/Math.max(1,h)))+')';
  if(!rm&&scrollY<1400)par.forEach(p=>{const v=parseFloat(p.dataset.p)*scrollY;const base=p.classList.contains('v-fcard')||p.classList.contains('v-toast')?'':'';p.style.translate='0 '+v.toFixed(1)+'px';});}
addEventListener('scroll',onScroll,{passive:true});onScroll();


/* ---- Barre collée en bas sur téléphone : visible après le premier écran, cachée près du bloc final et du pied de page ---- */
(function(){
  const bar=document.getElementById('v-stick');if(!bar||!('IntersectionObserver' in window))return;
  const hero=document.querySelector('.v-hero .v-cta'),until=document.getElementById(bar.dataset.until),foot=document.querySelector('footer');
  let past=false,atEnd=false,atFoot=false;
  let off=false;try{off=sessionStorage.getItem('v_dock_off')==='1';}catch(e){}
  if(off)bar.classList.add('v-off');
  const x=document.getElementById('v-dock-x');
  if(x)x.addEventListener('click',()=>{bar.classList.add('v-off');try{sessionStorage.setItem('v_dock_off','1');}catch(e){}});   // fermée : elle ne revient pas pendant la visite
  const upd=()=>bar.classList.toggle('v-show',past&&!atEnd&&!atFoot);
  if(hero)new IntersectionObserver(es=>{past=!es[0].isIntersecting&&es[0].boundingClientRect.top<0;upd();}).observe(hero);
  if(until)new IntersectionObserver(es=>{atEnd=es[0].isIntersecting;upd();}).observe(until);
  if(foot)new IntersectionObserver(es=>{atFoot=es[0].isIntersecting;upd();}).observe(foot);
})();

})();
