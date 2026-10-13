(function () {
  'use strict';
  import('/js/auth.js');
  var $ = function (s) { return document.querySelector(s); };
  var lang = document.documentElement.lang || 'fr';
  var isFr = lang !== 'en';

  var T = {
    fr: {
      creating: 'Scénario en cours…',
      rendering: 'Génération des images et de la voix…',
      assembling: 'Assemblage de la vidéo…',
      done: 'Votre film est prêt !',
      download: 'Télécharger la vidéo',
      err: 'Une erreur est survenue. Vos crédits n\'ont pas été débités.',
      errCred: 'Crédits insuffisants.',
      credLink: 'Recharger',
      wait: 'La vidéo prend 3 à 6 minutes. Ne fermez pas cette page.',
      steps: ['Scénario', 'Images & voix', 'Assemblage'],
      credModalH: 'Crédits insuffisants',
      credModalP: 'Il vous faut au moins 10 crédits pour créer un film de 2 min. Rechargez facilement via mobile money ou carte bancaire.',
      credMomo: '📱 Mobile Money',
      credCard: '💳 Carte bancaire',
      credClose: 'Fermer',
      seriesH: 'Mes séries',
      seriesSub: 'Continuez une série existante ou créez-en une nouvelle.',
      seriesEp: 'épisode',
      seriesEps: 'épisodes',
      seriesContinue: 'Ajouter un épisode',
      seriesEmpty: 'Aucune série pour l\'instant.',
      seriesNew: '+ Nouvelle série',
      episodeBadge: 'Épisode',
    },
    en: {
      creating: 'Writing the script…',
      rendering: 'Generating images and voice…',
      assembling: 'Assembling the video…',
      done: 'Your film is ready!',
      download: 'Download the video',
      err: 'An error occurred. Your credits were not deducted.',
      errCred: 'Not enough credits.',
      credLink: 'Top up',
      wait: 'The video takes 3 to 6 minutes. Do not close this page.',
      steps: ['Script', 'Images & voice', 'Assembly'],
      credModalH: 'Not enough credits',
      credModalP: 'You need at least 10 credits to create a 2-min film. Top up via mobile money or bank card.',
      credMomo: '📱 Mobile Money',
      credCard: '💳 Bank card',
      credClose: 'Close',
      seriesH: 'My series',
      seriesSub: 'Continue an existing series or start a new one.',
      seriesEp: 'episode',
      seriesEps: 'episodes',
      seriesContinue: 'Add an episode',
      seriesEmpty: 'No series yet.',
      seriesNew: '+ New series',
      episodeBadge: 'Episode',
    },
  }[isFr ? 'fr' : 'en'];

  var packUrl = isFr ? '/generer/' : '/en/generate/';
  var pollTimer = null;
  var currentSeriesId = null; // série sélectionnée pour le prochain épisode
  var uploadedAudioPath = null; // chemin Firebase Storage de l'audio importé

  // ── Calcul dynamique du coût ──────────────────────────────────────────────────
  var FILM_COST = { 2: 10, 3: 15 };
  function recalcCost() {
    var durEl = document.querySelector('input[name="dur"]:checked');
    var dur = durEl ? +durEl.value : 2;
    var wm = $('#film-watermark') ? $('#film-watermark').checked : true;
    var audioToggle = document.getElementById('film-audio-toggle');
    var hasAudio = !!(uploadedAudioPath && audioToggle && audioToggle.checked);
    var cost = FILM_COST[dur] || 10;
    if (wm) cost -= 1;
    if (hasAudio) cost -= 2;
    cost = Math.max(1, cost);
    var costEl = $('#film-cost-val');
    if (costEl) costEl.textContent = String(cost);
    return cost;
  }

  // ── Modal crédits insuffisants ────────────────────────────────────────────────
  var credModal = null;
  function buildCredModal() {
    if (credModal) return;
    credModal = document.createElement('div');
    credModal.className = 'film-cred-modal';
    credModal.innerHTML =
      '<div class="film-cred-inner">' +
        '<button class="film-cred-close" aria-label="' + T.credClose + '">✕</button>' +
        '<div class="film-cred-icon">🪙</div>' +
        '<h3 class="film-cred-h">' + T.credModalH + '</h3>' +
        '<p class="film-cred-p">' + T.credModalP + '</p>' +
        '<div class="film-cred-btns">' +
          '<a class="btn pri film-cred-btn" href="' + packUrl + '">' + T.credMomo + '</a>' +
          '<a class="btn pri film-cred-btn" href="' + packUrl + '">' + T.credCard + '</a>' +
        '</div>' +
      '</div>';
    document.body.appendChild(credModal);
    credModal.querySelector('.film-cred-close').addEventListener('click', closeCredModal);
    credModal.addEventListener('click', function (e) { if (e.target === credModal) closeCredModal(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeCredModal(); });
  }
  function openCredModal() {
    buildCredModal();
    credModal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  function closeCredModal() {
    if (!credModal) return;
    credModal.classList.remove('open');
    document.body.style.overflow = '';
  }

  // ── Progression ───────────────────────────────────────────────────────────────
  function showProgress(step) {
    var res = $('#film-result');
    if (!res) return;
    res.hidden = false;
    var labels = [T.steps[0], T.steps[1], T.steps[2]];
    var html = '<div class="film-progress"><div class="film-progress-steps">';
    for (var i = 0; i < 3; i++) {
      var cls = i < step ? 'done' : i === step && step < 3 ? 'active' : '';
      var icon = i < step ? '✓' : (i === step && step < 3 ? '⏳' : '○');
      html += '<div class="film-ps ' + cls + '"><span class="film-ps-icon">' + icon + '</span>' + labels[i] + '</div>';
    }
    html += '</div>';
    if (step < 3) html += '<p class="hint">' + T.wait + '</p>';
    html += '</div>';
    res.innerHTML = html;
  }

  function showDone(videoUrl, episodeNumber) {
    var res = $('#film-result');
    if (!res) return;
    var epBadge = episodeNumber ? '<span class="film-ep-badge">' + T.episodeBadge + ' ' + episodeNumber + '</span>' : '';
    res.innerHTML = '<div class="film-result-card">' + epBadge + '<h3>' + T.done + '</h3><video src="' + videoUrl + '" controls playsinline></video><a class="btn pri" href="' + videoUrl + '" download>' + T.download + '</a></div>';
    // Rafraîchir la liste des séries après un épisode généré
    if (currentSeriesId) loadSeriesList();
  }

  function showErr(msg) {
    var msg2 = $('#film-msg');
    if (msg2) { msg2.textContent = msg || T.err; msg2.className = 'fmsg'; }
    var sub = $('#film-submit');
    if (sub) { sub.disabled = false; sub.textContent = isFr ? 'Réessayer' : 'Retry'; }
  }

  // ── Polling ───────────────────────────────────────────────────────────────────
  function poll(jobId) {
    window.slashAuth.call('studio-film/status', { jobId: jobId }).then(function (r) {
      if (!r || r.status !== 200) { showErr(); return; }
      var d = r.data;
      if (d.status === 'done') {
        clearTimeout(pollTimer);
        showDone(d.videoUrl, d.episodeNumber);
      } else if (d.status === 'error') {
        clearTimeout(pollTimer);
        showErr(d.message || T.err);
      } else if (d.status === 'rendering') {
        showProgress(1);
        pollTimer = setTimeout(function () { poll(jobId); }, 8000);
      } else if (d.status === 'assembling') {
        showProgress(2);
        pollTimer = setTimeout(function () { poll(jobId); }, 6000);
      } else if (d.status === 'pending_render') {
        showProgress(1);
        pollTimer = setTimeout(function () { poll(jobId); }, 10000);
      } else {
        showProgress(0);
        pollTimer = setTimeout(function () { poll(jobId); }, 8000);
      }
    }).catch(function () {
      pollTimer = setTimeout(function () { poll(jobId); }, 10000);
    });
  }

  // ── Watermark + dur toggles ───────────────────────────────────────────────────
  var wmChk = $('#film-watermark');
  if (wmChk) {
    wmChk.addEventListener('change', recalcCost);
    document.querySelectorAll('input[name="dur"]').forEach(function (r) { r.addEventListener('change', recalcCost); });
    recalcCost();
  }

  // ── Toggle audio : affiche/masque le sélecteur de fichier ────────────────────
  var audioToggleEl = document.getElementById('film-audio-toggle');
  var audioWrapEl = document.getElementById('film-audio-wrap');
  if (audioToggleEl && audioWrapEl) {
    audioToggleEl.addEventListener('change', function () {
      audioWrapEl.hidden = !audioToggleEl.checked;
      if (!audioToggleEl.checked) {
        uploadedAudioPath = null;
        var nameEl = document.getElementById('film-audio-name');
        if (nameEl) nameEl.textContent = '';
      }
      recalcCost();
    });
  }

  // ── Import audio ─────────────────────────────────────────────────────────────
  var audioInput = document.getElementById('film-audio-input');
  if (audioInput) {
    audioInput.addEventListener('change', function () {
      var file = audioInput.files && audioInput.files[0];
      var nameEl = document.getElementById('film-audio-name');
      var sub = $('#film-submit');
      if (!file) { uploadedAudioPath = null; if (nameEl) nameEl.textContent = ''; recalcCost(); return; }
      if (nameEl) nameEl.textContent = isFr ? 'Envoi en cours…' : 'Uploading…';
      if (sub) sub.disabled = true;
      var ct = file.type || 'audio/mpeg';
      window.slashAuth.call('studio-film/upload-url', { contentType: ct }).then(function (r) {
        if (!r || r.status !== 200 || !r.data || !r.data.uploadUrl) {
          uploadedAudioPath = null;
          if (nameEl) nameEl.textContent = isFr ? 'Erreur d\'envoi' : 'Upload error';
          if (sub) sub.disabled = false;
          return;
        }
        return fetch(r.data.uploadUrl, { method: 'PUT', body: file, headers: { 'Content-Type': ct } })
          .then(function (res) {
            if (!res.ok) throw new Error('http ' + res.status);
            uploadedAudioPath = r.data.storagePath;
            if (nameEl) nameEl.textContent = file.name;
            recalcCost();
            if (sub) sub.disabled = false;
          });
      }).catch(function () {
        uploadedAudioPath = null;
        if (nameEl) nameEl.textContent = isFr ? 'Erreur d\'envoi' : 'Upload error';
        if (sub) sub.disabled = false;
      });
    });
  }

  // ── Soumission du formulaire ──────────────────────────────────────────────────
  var form = $('#film-form');
  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var sub = $('#film-submit');
      var msg = $('#film-msg');
      if (msg) { msg.textContent = ''; msg.className = 'fmsg'; }
      sub.disabled = true;
      sub.textContent = T.creating;
      showProgress(0);

      var dur = document.querySelector('input[name="dur"]:checked');
      var wmEl = document.getElementById('film-watermark');
      var payload = {
        title: ($('#film-title') || {}).value || '',
        synopsis: ($('#film-synopsis') || {}).value || '',
        genre: ($('#film-genre') || {}).value || 'film',
        lang: ($('#film-lang') || {}).value || lang,
        duration: dur ? +dur.value : 2,
        watermark: wmEl ? wmEl.checked : true,
      };
      if (uploadedAudioPath) payload.customAudioPath = uploadedAudioPath;
      if (currentSeriesId) payload.seriesId = currentSeriesId;

      window.slashAuth.call('studio-film/create', payload).then(function (r) {
        if (!r) { showErr(); sub.disabled = false; return; }
        if (r.status === 402) {
          sub.disabled = false;
          sub.textContent = isFr ? 'Créer mon film' : 'Create my film';
          openCredModal();
          return;
        }
        if (r.status !== 200) { showErr(r.data && r.data.error); sub.disabled = false; return; }
        var jobId = r.data && r.data.jobId;
        // Sauvegarder le seriesId retourné si c'est une série
        if (r.data && r.data.seriesId) currentSeriesId = r.data.seriesId;
        if (!jobId) { showErr(); sub.disabled = false; return; }
        // Réinitialiser l'audio après soumission
        uploadedAudioPath = null;
        if (audioInput) { audioInput.value = ''; }
        var nameEl2 = document.getElementById('film-audio-name');
        if (nameEl2) nameEl2.textContent = '';
        var tog2 = document.getElementById('film-audio-toggle');
        var wrap2 = document.getElementById('film-audio-wrap');
        if (tog2) { tog2.checked = false; }
        if (wrap2) { wrap2.hidden = true; }
        pollTimer = setTimeout(function () { poll(jobId); }, 5000);
      }).catch(function () { showErr(); sub.disabled = false; });
    });
  }

  // ── Séries : chargement et affichage ─────────────────────────────────────────
  function loadSeriesList() {
    var wrap = document.getElementById('film-series-wrap');
    if (!wrap) return;
    window.slashAuth.call('studio-film/series', {}).then(function (r) {
      if (!r || r.status !== 200 || !r.data) return;
      var series = r.data.series || [];
      if (!series.length) {
        wrap.innerHTML = '<p class="film-series-empty">' + T.seriesEmpty + '</p>';
        return;
      }
      var html = '<div class="film-series-grid">';
      series.forEach(function (s) {
        var epLabel = s.episodeCount === 1 ? '1 ' + T.seriesEp : s.episodeCount + ' ' + T.seriesEps;
        var synopsis = s.synopsis ? s.synopsis.slice(0, 120) + (s.synopsis.length > 120 ? '…' : '') : '';
        html +=
          '<div class="film-series-card" data-sid="' + s.id + '" data-title="' + esc(s.title) + '" data-synopsis="' + esc(s.synopsis) + '" data-genre="serie" data-dur="' + s.duration + '">' +
            '<div class="film-series-top">' +
              '<b class="film-series-name">' + esc(s.title) + '</b>' +
              '<span class="film-series-ep-badge">' + epLabel + '</span>' +
            '</div>' +
            (synopsis ? '<p class="film-series-synopsis">' + esc(synopsis) + '</p>' : '') +
            (s.characters && s.characters.length ? '<p class="film-series-chars">👤 ' + s.characters.slice(0, 4).map(esc).join(', ') + '</p>' : '') +
            '<button class="btn sec film-series-btn" type="button">' + T.seriesContinue + '</button>' +
          '</div>';
      });
      html += '</div>';
      wrap.innerHTML = html;
      wrap.querySelectorAll('.film-series-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
          var card = btn.closest('.film-series-card');
          selectSeries(card.dataset.sid, card.dataset.title, card.dataset.synopsis, card.dataset.genre, card.dataset.dur);
        });
      });
    }).catch(function () {});
  }

  function selectSeries(sid, title, synopsis, genre, dur) {
    currentSeriesId = sid;
    // Pré-remplir : garder le titre de la série mais laisser l'utilisateur saisir le titre de l'épisode
    var titleEl = $('#film-title');
    var synopsisEl = $('#film-synopsis');
    var genreEl = $('#film-genre');
    var durEl = document.querySelector('input[name="dur"][value="' + dur + '"]');
    if (titleEl) titleEl.value = '';  // titre de l'épisode à saisir
    if (synopsisEl) synopsisEl.value = synopsis || '';
    if (genreEl) genreEl.value = 'serie';
    if (durEl) durEl.checked = true;
    // Indicateur série sélectionnée
    var badge = document.getElementById('film-series-badge');
    if (badge) {
      badge.textContent = isFr ? '📺 Suite de : ' + title : '📺 Continuing: ' + title;
      badge.hidden = false;
    }
    var resetBtn = document.getElementById('film-series-reset');
    if (resetBtn) resetBtn.hidden = false;
    // Marquer la carte sélectionnée
    document.querySelectorAll('.film-series-card').forEach(function (c) { c.classList.toggle('selected', c.dataset.sid === sid); });
    // Scroll vers le formulaire
    var formEl = $('#film-form');
    if (formEl) formEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
    // Mettre à jour le label du bouton
    var sub = $('#film-submit');
    if (sub) sub.textContent = isFr ? 'Générer l\'épisode suivant' : 'Generate next episode';
  }

  // Bouton reset série
  var resetBtn = document.getElementById('film-series-reset');
  if (resetBtn) {
    resetBtn.addEventListener('click', function () {
      currentSeriesId = null;
      resetBtn.hidden = true;
      var badge = document.getElementById('film-series-badge');
      if (badge) badge.hidden = true;
      document.querySelectorAll('.film-series-card').forEach(function (c) { c.classList.remove('selected'); });
      var sub = $('#film-submit');
      if (sub) sub.textContent = isFr ? 'Créer mon film' : 'Create my film';
    });
  }

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // ── Cartes d'inspiration ──────────────────────────────────────────────────────
  document.querySelectorAll('.film-idea-card').forEach(function (btn) {
    btn.addEventListener('click', function () {
      currentSeriesId = null;
      var titleEl = $('#film-title');
      var synopsisEl = $('#film-synopsis');
      var genreEl = $('#film-genre');
      var durEl = document.querySelector('input[name="dur"][value="' + btn.dataset.dur + '"]');
      if (titleEl) titleEl.value = btn.dataset.title;
      if (synopsisEl) synopsisEl.value = btn.dataset.synopsis;
      if (genreEl) genreEl.value = btn.dataset.genre;
      if (durEl) durEl.checked = true;
      document.querySelectorAll('.film-idea-card').forEach(function (b) { b.classList.remove('selected'); });
      btn.classList.add('selected');
      // Reset badge série si on clique une idée
      var badge = document.getElementById('film-series-badge');
      if (badge) badge.hidden = true;
      var rst = document.getElementById('film-series-reset');
      if (rst) rst.hidden = true;
      var formEl = $('#film-form');
      if (formEl && !formEl.hidden) {
        formEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } else {
        var formWrap = document.getElementById('film-out');
        if (formWrap) formWrap.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // ── Auth ──────────────────────────────────────────────────────────────────────
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user;
    var wall = $('#film-login-wall');
    var frm = $('#film-form');
    var seriesSection = document.getElementById('film-series-section');
    if (wall) wall.hidden = !!u;
    if (frm) frm.hidden = !u;
    if (seriesSection) seriesSection.hidden = !u;
    if (u) loadSeriesList();
  });
})();
