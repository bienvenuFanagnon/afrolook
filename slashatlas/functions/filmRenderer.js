'use strict';
// Tous les genres (film, série, conte, animation) utilisent le renderer animation 2.5D canvas africaine

async function renderFilm(jobId, cfAccountId, cfApiToken) {
  const { renderAnimation } = require('./animationRenderer');
  return renderAnimation(jobId, cfAccountId, cfApiToken);
}

module.exports = { renderFilm };
