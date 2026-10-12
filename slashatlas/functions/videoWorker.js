'use strict';
// Fil de travail : dessine une tranche d'images de la vidéo (voir video.js, render).
const { parentPort, workerData } = require('worker_threads');
const video = require('./video');
video.renderSegment(workerData).then(() => parentPort.postMessage({ ok: true }), (e) => parentPort.postMessage({ error: String((e && e.stack) || e) }));
