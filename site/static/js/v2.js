/* Refonte 2026 : téléphones qui changent d'écran, histoire de l'application, Studio, drapeau du pays, lancement de campagne.
   Généré à partir de la maquette validée. */
(function(){
'use strict';
if(!document.querySelector('.v2'))return;

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
  dots.innerHTML=slides.map(s=>'<button type="button" aria-label="'+s.n+'"></button>').join('');
  const btns=[...dots.querySelectorAll('button')];
  let cur=-1,hold=0,vis=true;
  function go(i,first){
    if(i===cur)return;cur=i;const s=slides[i];
    [...scr.children].forEach((f,j)=>f.classList.toggle('v-on',j===i));
    btns.forEach((b,j)=>b.setAttribute('aria-current',j===i?'true':'false'));
    cards.forEach((c,j)=>{c.style.opacity=0;setTimeout(()=>{c.src=IMG[s.c[j]]||'';c.style.opacity=1;},first?0:330);});
    toasts.forEach((t,j)=>{t.classList.add('v-sw');setTimeout(()=>{t.querySelector('i').innerHTML=ic(s.t[j][0]);t.querySelector('span').textContent=s.t[j][1];t.classList.remove('v-sw');},first?0:260);});
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
const MOIS=['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
const TZ={'Africa/Lome':'tg','Africa/Abidjan':'ci','Africa/Porto-Novo':'bj','Africa/Douala':'cm','Africa/Ouagadougou':'bf','Africa/Dakar':'sn','Africa/Bamako':'ml','Africa/Niamey':'ne','Africa/Accra':'gh','Africa/Lagos':'ng','Africa/Kinshasa':'cd','Africa/Libreville':'ga','Africa/Conakry':'gn','Africa/Brazzaville':'cg','Africa/Casablanca':'ma','Africa/Algiers':'dz','Africa/Nairobi':'ke','Africa/Johannesburg':'za'};
function detectCountry(){let c='';try{const m=(navigator.language||'').match(/-([A-Za-z]{2})$/);if(m)c=m[1].toLowerCase();}catch(e){}
  if(!FLAGS.some(f=>f[0]===c)){try{c=TZ[Intl.DateTimeFormat().resolvedOptions().timeZone]||'';}catch(e){c='';}}
  return FLAGS.findIndex(f=>f[0]===c);}
const jour=(d,m)=>(d===1?'1er':d)+' '+MOIS[m-1];
function initFlags(box){
  const big=box.querySelector('.v-bigflag'),nm=box.querySelector('.v-fname'),chips=box.querySelector('.v-fchips');
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  chips.innerHTML=FLAGS.map(f=>'<button type="button" aria-label="'+f[1]+'" aria-pressed="false"><img src="'+IMG['fl_'+f[0]]+'" alt=""></button>').join('');
  const bs=[...chips.children];let cur=-1,hold=0,vis=true;
  const dl=box.closest('.v-dl');
  function txt(i){const f=FLAGS[i],k=dl&&dl.querySelector('.v-fkick'),u=dl&&dl.querySelector('.v-fsub');if(!dl)return;
    if(dl.dataset.fl==='ads'){k.textContent='Afrolook Ads · '+f[1];u.textContent='Choisis les pays à atteindre : '+f[1]+", et d'autres.";}
    else{k.textContent='Afrolook · '+f[1];u.textContent='Le '+jour(f[2],f[3])+', fête nationale ('+f[1]+'), les styles de cartes drapeau sont offerts.';}}
  function go(i,first){if(i===cur)return;cur=i;bs.forEach((b,j)=>b.setAttribute('aria-pressed',j===i));
    const set=()=>{big.src=IMG['fl_'+FLAGS[i][0]];nm.textContent=FLAGS[i][1];big.alt='Drapeau : '+FLAGS[i][1];big.classList.remove('v-sw');txt(i);};
    if(first){set();return;}big.classList.add('v-sw');setTimeout(set,250);}
  bs.forEach((b,i)=>b.addEventListener('click',()=>{hold=Date.now()+10000;go(i);}));
  box.addEventListener('pointerenter',()=>{hold=Infinity;});box.addEventListener('pointerleave',()=>{hold=Date.now()+1500;});
  new IntersectionObserver(es=>{vis=es[0].isIntersecting;}).observe(box);
  const det=detectCountry();
  if(det>=0){go(det,true);box.insertAdjacentHTML('beforeend','<p class="v-fdet">Pays détecté sur ton appareil. Touche un drapeau pour en changer.</p>');}
  else{go(0,true);box.insertAdjacentHTML('beforeend','<p class="v-fdet">Pays inconnu : le Togo s’affiche par défaut. Touche un drapeau pour voir les autres.</p>');}
}

/* ---- Lancer une campagne depuis le site ---- */
(function(){
  const types=document.getElementById('lType');if(!types)return;
  const btn=document.getElementById('lbtn'),sum=document.getElementById('lsum'),rng=document.getElementById('lrange'),aud=document.getElementById('lAud');
  const free=document.getElementById('lfree'),net=document.getElementById('lnet'),share=document.getElementById('lshare');
  const fmt=n=>Math.round(n).toLocaleString('fr-FR').replace(/[  ]/g,' ');
  function upd(){
    aud.hidden=!share.checked;
    const t=types.querySelector('[aria-pressed="true"]'),n=+rng.value,rows=[['Type d\'annonce',t?t.textContent.trim():'—']];
    if(free.checked)rows.push(['Gratuit sur 4 plateformes','0 FCFA']);
    if(net.checked)rows.push(['Afrolook et partenaires','Budget au choix']);
    if(share.checked){rows.push(['Audience du partage',fmt(n)+' personnes']);rows.push(['Prix du partage',fmt(n/1000*500)+' FCFA']);rows.push(['Visites estimées (environ 2 %)',fmt(n*.02)]);}
    if(!free.checked&&!net.checked&&!share.checked)rows.push(['Diffusion','Choisis une option']);
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


})();
