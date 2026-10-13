'use strict';
/**
 * characterEngine.js — Moteur de personnages 2.5D — Studio Film Afrolook
 *
 * Directions : E = profil droit | W = profil gauche | S = face (RPG top-down)
 * Types : adulte-femme | adulte-homme | enfant-fille | enfant-garcon | ancien
 * États : idle | walk | run | talk | wave | sit | lie | sleep | dance | crouch | point
 */

const CHAR_DEF = {
  'adulte-femme': {
    hMult: 1.0, headR: 26, shoulderW: 30, hipW: 26, torsoH: 48, legLen: 82, armLen: 56,
    skin: '#8B5E3C', hairCol: '#150800', hair: 'afro', earrings: true,
    clothes: { top: '#CF5C1A', bot: '#1e2a5e', acc: '#e8a020' }, gender: 'f',
  },
  'adulte-homme': {
    hMult: 1.07, headR: 25, shoulderW: 38, hipW: 24, torsoH: 50, legLen: 88, armLen: 62,
    skin: '#6B4020', hairCol: '#150800', hair: 'short',
    clothes: { top: '#1e6040', bot: '#2a1a6e', acc: '#e8a020' }, gender: 'm',
  },
  'enfant-fille': {
    hMult: 0.63, headR: 23, shoulderW: 20, hipW: 18, torsoH: 32, legLen: 52, armLen: 34,
    skin: '#9B6A42', hairCol: '#150800', hair: 'braids',
    clothes: { top: '#e8208a', bot: '#e8a020', acc: '#fff' }, gender: 'f',
  },
  'enfant-garcon': {
    hMult: 0.63, headR: 22, shoulderW: 22, hipW: 18, torsoH: 32, legLen: 52, armLen: 34,
    skin: '#7B5030', hairCol: '#150800', hair: 'short',
    clothes: { top: '#2050e0', bot: '#606060', acc: '#fff' }, gender: 'm',
  },
  'ancien': {
    hMult: 0.92, headR: 24, shoulderW: 28, hipW: 22, torsoH: 44, legLen: 74, armLen: 52,
    skin: '#6a4420', hairCol: '#c0b8b0', hair: 'beard', hat: true, lean: 10,
    clothes: { top: '#f0e0c0', bot: '#8a7060', acc: '#c8a040' }, gender: 'm',
  },
};

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

function shade(hex, amt) {
  const rv = Math.max(0, Math.min(255, parseInt(hex.slice(1, 3), 16) + amt));
  const gv = Math.max(0, Math.min(255, parseInt(hex.slice(3, 5), 16) + amt));
  const bv = Math.max(0, Math.min(255, parseInt(hex.slice(5, 7), 16) + amt));
  return '#' + [rv, gv, bv].map((v) => v.toString(16).padStart(2, '0')).join('');
}

// ── TÊTE : vue profil 3/4 (E/W) ───────────────────────────────────────────
function drawHeadE(ctx, cx, cy, def, opts) {
  const r = def.headR;
  const sk = opts.skin;
  const talking = opts.talking;
  const mo = opts.mouthAmt || 0;
  const sleeping = opts.sleeping || false;

  ctx.save();
  ctx.translate(cx, cy);

  ctx.fillStyle = def.hairCol;
  if (def.hair === 'afro') {
    const balls = [
      [-r * 0.7, -r * 0.28, r * 0.46], [-r * 0.25, -r * 0.9, r * 0.5],
      [r * 0.15, -r * 0.98, r * 0.5],  [r * 0.55, -r * 0.82, r * 0.45],
      [r * 0.78, -r * 0.38, r * 0.4],  [r * 0.68, r * 0.1, r * 0.35],
      [-r * 0.42, -r * 0.6, r * 0.42], [r * 0.28, -r * 1.02, r * 0.4],
    ];
    balls.forEach(([bx, by, br]) => {
      ctx.beginPath(); ctx.arc(bx, by, br, 0, Math.PI * 2); ctx.fill();
    });
  } else if (def.hair === 'short') {
    ctx.beginPath(); ctx.arc(r * 0.05, -r * 0.12, r * 1.02, Math.PI * 1.0, 0); ctx.fill();
    ctx.beginPath(); ctx.arc(r * 0.05, -r * 0.05, r * 1.0, 0, Math.PI * 2); ctx.fill();
  } else if (def.hair === 'braids') {
    ctx.beginPath(); ctx.arc(0, -r * 0.15, r * 1.05, Math.PI * 0.88, 0); ctx.fill();
    [[-r * 0.72, r * 0.15], [-r * 0.28, r * 0.1], [r * 0.12, r * 0.05]].forEach(([bx, by]) => {
      ctx.beginPath(); ctx.ellipse(bx, by + r * 0.85, r * 0.11, r * 0.65, 0, 0, Math.PI * 2); ctx.fill();
    });
  } else if (def.hair === 'beard') {
    ctx.beginPath(); ctx.arc(0, -r * 0.1, r * 1.04, Math.PI * 1.1, 0); ctx.fill();
    ctx.beginPath(); ctx.ellipse(r * 0.28, r * 0.52, r * 0.52, r * 0.38, Math.PI * 0.05, 0, Math.PI * 2);
    ctx.fillStyle = shade(def.hairCol, 30); ctx.fill();
  }

  ctx.beginPath(); ctx.ellipse(r * 0.04, 0, r, r * 0.93, 0, 0, Math.PI * 2);
  ctx.fillStyle = sk; ctx.fill();
  ctx.beginPath(); ctx.ellipse(r * 0.26, r * 0.44, r * 0.58, r * 0.38, 0, 0, Math.PI * 2);
  ctx.fillStyle = sk; ctx.fill();

  ctx.beginPath(); ctx.ellipse(-r * 0.9, r * 0.1, r * 0.14, r * 0.22, 0, 0, Math.PI * 2);
  ctx.fillStyle = sk; ctx.fill();
  ctx.beginPath(); ctx.ellipse(-r * 0.9, r * 0.1, r * 0.07, r * 0.13, 0, 0, Math.PI * 2);
  ctx.fillStyle = shade(sk, -22); ctx.fill();
  if (def.earrings) {
    ctx.strokeStyle = '#e8a020'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(-r * 0.9, r * 0.3, r * 0.1, 0, Math.PI * 2); ctx.stroke();
  }

  ctx.strokeStyle = shade(def.hairCol, 25); ctx.lineCap = 'round';
  ctx.lineWidth = r * 0.11;
  ctx.beginPath(); ctx.moveTo(r * 0.07, -r * 0.3); ctx.quadraticCurveTo(r * 0.4, -r * 0.48, r * 0.72, -r * 0.3); ctx.stroke();
  ctx.lineWidth = r * 0.08;
  ctx.beginPath(); ctx.moveTo(-r * 0.36, -r * 0.28); ctx.quadraticCurveTo(-r * 0.14, -r * 0.42, r * 0.04, -r * 0.28); ctx.stroke();

  // Yeux
  if (sleeping) {
    ctx.strokeStyle = shade(def.hairCol, 30); ctx.lineWidth = r * 0.13; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(r * 0.2, -r * 0.1); ctx.quadraticCurveTo(r * 0.44, r * 0.01, r * 0.68, -r * 0.1); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(-r * 0.24, -r * 0.12); ctx.quadraticCurveTo(-r * 0.14, -r * 0.02, r * 0.0, -r * 0.12); ctx.stroke();
  } else {
    ctx.fillStyle = '#fff';
    ctx.beginPath(); ctx.ellipse(r * 0.44, -r * 0.12, r * 0.25, r * 0.22, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = shade(def.hairCol, 30);
    ctx.beginPath(); ctx.arc(r * 0.44, -r * 0.12, r * 0.15, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#060200';
    ctx.beginPath(); ctx.arc(r * 0.44, -r * 0.12, r * 0.08, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.82)';
    ctx.beginPath(); ctx.arc(r * 0.51, -r * 0.18, r * 0.06, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.beginPath(); ctx.ellipse(-r * 0.14, -r * 0.14, r * 0.14, r * 0.17, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = shade(def.hairCol, 30);
    ctx.beginPath(); ctx.arc(-r * 0.14, -r * 0.14, r * 0.09, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#060200';
    ctx.beginPath(); ctx.arc(-r * 0.14, -r * 0.14, r * 0.05, 0, Math.PI * 2); ctx.fill();
  }

  ctx.strokeStyle = shade(sk, -38); ctx.lineWidth = r * 0.1; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(r * 0.2, -r * 0.04); ctx.quadraticCurveTo(r * 0.9, r * 0.06, r * 0.84, r * 0.24); ctx.stroke();
  ctx.fillStyle = shade(sk, -28);
  ctx.beginPath(); ctx.arc(r * 0.75, r * 0.24, r * 0.1, 0, Math.PI * 2); ctx.fill();

  const mY = r * 0.45;
  if (sleeping) {
    ctx.strokeStyle = '#6a2818'; ctx.lineWidth = r * 0.08;
    ctx.beginPath(); ctx.moveTo(r * 0.18, mY); ctx.quadraticCurveTo(r * 0.38, mY + r * 0.08, r * 0.58, mY); ctx.stroke();
  } else if (talking && mo > 0) {
    ctx.fillStyle = '#6a2818';
    ctx.beginPath(); ctx.ellipse(r * 0.38, mY, r * 0.3, r * (0.1 + mo * 0.3), 0, 0, Math.PI * 2); ctx.fill();
    if (mo > 0.25) {
      ctx.fillStyle = '#180808';
      ctx.beginPath(); ctx.ellipse(r * 0.38, mY + r * 0.02, r * 0.2, r * mo * 0.26, 0, 0, Math.PI * 2); ctx.fill();
    }
  } else {
    ctx.strokeStyle = '#6a2818'; ctx.lineWidth = r * 0.1; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(r * 0.12, mY - r * 0.04); ctx.quadraticCurveTo(r * 0.38, mY + r * 0.18, r * 0.68, mY - r * 0.04); ctx.stroke();
  }

  ctx.fillStyle = 'rgba(200,80,40,.1)';
  ctx.beginPath(); ctx.ellipse(r * 0.65, r * 0.14, r * 0.24, r * 0.14, 0, 0, Math.PI * 2); ctx.fill();

  if (def.hat) {
    ctx.fillStyle = def.clothes.acc;
    ctx.beginPath(); ctx.ellipse(0, -r * 0.88, r * 1.12, r * 0.2, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = shade(def.clothes.top, 20);
    rr(ctx, -r * 0.62, -r * 1.55, r * 1.24, r * 0.72, 4); ctx.fill();
    ctx.fillStyle = def.clothes.acc;
    ctx.fillRect(-r * 0.62, -r * 0.88, r * 1.24, r * 0.06);
  }
  ctx.restore();
}

// ── TÊTE : vue face (S) ───────────────────────────────────────────────────
function drawHeadS(ctx, cx, cy, def, opts) {
  const r = def.headR;
  const sk = opts.skin;
  const talking = opts.talking;
  const mo = opts.mouthAmt || 0;
  const sleeping = opts.sleeping || false;

  ctx.save(); ctx.translate(cx, cy);

  ctx.fillStyle = def.hairCol;
  if (def.hair === 'afro' || def.hair === 'braids') {
    const balls = [
      [-r * 0.62, -r * 0.82, r * 0.5], [-r * 0.12, -r * 0.96, r * 0.52],
      [r * 0.48, -r * 0.86, r * 0.5],  [r * 0.78, -r * 0.42, r * 0.44],
      [r * 0.72, r * 0.04, r * 0.38],  [-r * 0.72, r * 0.02, r * 0.4],
      [r * 0.18, -r * 1.02, r * 0.44], [-r * 0.32, -r * 0.56, r * 0.44],
    ];
    balls.forEach(([bx, by, br]) => {
      ctx.beginPath(); ctx.arc(bx, by, br, 0, Math.PI * 2); ctx.fill();
    });
    if (def.hair === 'braids') {
      [[-r * 0.82, r * 0.05], [r * 0.82, r * 0.05]].forEach(([bx, by]) => {
        ctx.beginPath(); ctx.ellipse(bx, by + r * 0.9, r * 0.11, r * 0.7, 0, 0, Math.PI * 2); ctx.fill();
      });
    }
  } else if (def.hair === 'short' || def.hair === 'beard') {
    ctx.beginPath(); ctx.arc(0, -r * 0.18, r, Math.PI * 1.06, Math.PI * 1.94); ctx.fill();
    ctx.beginPath(); ctx.arc(0, -r * 0.1, r * 0.98, 0, Math.PI * 2); ctx.fill();
  }
  if (def.hair === 'beard') {
    ctx.fillStyle = shade(def.hairCol, 28);
    ctx.beginPath(); ctx.ellipse(0, r * 0.52, r * 0.48, r * 0.36, 0, 0, Math.PI * 2); ctx.fill();
  }

  ctx.beginPath(); ctx.ellipse(0, 0, r, r * 0.9, 0, 0, Math.PI * 2);
  ctx.fillStyle = sk; ctx.fill();

  [[-r * 0.96, r * 0.06], [r * 0.96, r * 0.06]].forEach(([ex, ey]) => {
    ctx.beginPath(); ctx.ellipse(ex, ey, r * 0.14, r * 0.22, 0, 0, Math.PI * 2);
    ctx.fillStyle = sk; ctx.fill();
    ctx.beginPath(); ctx.ellipse(ex, ey, r * 0.07, r * 0.13, 0, 0, Math.PI * 2);
    ctx.fillStyle = shade(sk, -20); ctx.fill();
  });
  if (def.earrings) {
    ctx.strokeStyle = '#e8a020'; ctx.lineWidth = 1.5;
    [[-r * 0.96, r * 0.28], [r * 0.96, r * 0.28]].forEach(([ex, ey]) => {
      ctx.beginPath(); ctx.arc(ex, ey, r * 0.1, 0, Math.PI * 2); ctx.stroke();
    });
  }

  ctx.strokeStyle = shade(def.hairCol, 22); ctx.lineCap = 'round'; ctx.lineWidth = r * 0.1;
  ctx.beginPath(); ctx.moveTo(-r * 0.56, -r * 0.28); ctx.quadraticCurveTo(-r * 0.22, -r * 0.46, r * 0.04, -r * 0.28); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(r * 0.08, -r * 0.28); ctx.quadraticCurveTo(r * 0.38, -r * 0.46, r * 0.6, -r * 0.28); ctx.stroke();

  if (sleeping) {
    ctx.strokeStyle = shade(def.hairCol, 30); ctx.lineWidth = r * 0.13;
    [[-r * 0.32, -r * 0.12], [r * 0.32, -r * 0.12]].forEach(([ex, ey]) => {
      ctx.beginPath(); ctx.moveTo(ex - r * 0.2, ey); ctx.quadraticCurveTo(ex, ey + r * 0.12, ex + r * 0.2, ey); ctx.stroke();
    });
  } else {
    [[-r * 0.32, -r * 0.12], [r * 0.32, -r * 0.12]].forEach(([ex, ey]) => {
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.ellipse(ex, ey, r * 0.2, r * 0.23, 0, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = shade(def.hairCol, 30);
      ctx.beginPath(); ctx.arc(ex, ey, r * 0.13, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#060200';
      ctx.beginPath(); ctx.arc(ex, ey, r * 0.07, 0, Math.PI * 2); ctx.fill();
    });
    ctx.fillStyle = 'rgba(255,255,255,.8)';
    ctx.beginPath(); ctx.arc(-r * 0.26, -r * 0.17, r * 0.05, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(r * 0.38, -r * 0.17, r * 0.05, 0, Math.PI * 2); ctx.fill();
  }

  ctx.strokeStyle = shade(sk, -35); ctx.lineWidth = r * 0.08; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(-r * 0.08, r * 0.0); ctx.quadraticCurveTo(-r * 0.18, r * 0.18, -r * 0.14, r * 0.28); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(r * 0.08, r * 0.0); ctx.quadraticCurveTo(r * 0.18, r * 0.18, r * 0.14, r * 0.28); ctx.stroke();

  if (sleeping) {
    ctx.strokeStyle = '#6a2818'; ctx.lineWidth = r * 0.08;
    ctx.beginPath(); ctx.moveTo(-r * 0.18, r * 0.44); ctx.quadraticCurveTo(0, r * 0.52, r * 0.18, r * 0.44); ctx.stroke();
  } else if (talking && mo > 0) {
    ctx.fillStyle = '#6a2818';
    ctx.beginPath(); ctx.ellipse(0, r * 0.44, r * 0.32, r * (0.1 + mo * 0.28), 0, 0, Math.PI * 2); ctx.fill();
    if (mo > 0.2) {
      ctx.fillStyle = '#180808';
      ctx.beginPath(); ctx.ellipse(0, r * 0.45, r * 0.22, r * mo * 0.22, 0, 0, Math.PI * 2); ctx.fill();
    }
  } else {
    ctx.strokeStyle = '#6a2818'; ctx.lineWidth = r * 0.1;
    ctx.beginPath(); ctx.arc(0, r * 0.38, r * 0.3, 0.15, Math.PI - 0.15); ctx.stroke();
  }

  if (def.hat) {
    ctx.fillStyle = def.clothes.acc;
    ctx.beginPath(); ctx.ellipse(0, -r * 0.88, r * 1.12, r * 0.22, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = shade(def.clothes.top, 20);
    rr(ctx, -r * 0.62, -r * 1.55, r * 1.24, r * 0.72, 4); ctx.fill();
    ctx.fillStyle = def.clothes.acc;
    ctx.fillRect(-r * 0.62, -r * 0.88, r * 1.24, r * 0.06);
  }
  ctx.restore();
}

// ── CORPS + MEMBRES : vue profil E ────────────────────────────────────────
function drawBodyE(ctx, gx, gy, def, state, phase, flipX, skin) {
  const walking   = state === 'walk' || state === 'run';
  const waving    = state === 'wave';
  const sitting   = state === 'sit';
  const crouching = state === 'crouch';
  const dancing   = state === 'dance';
  const pointing  = state === 'point';
  const amp       = state === 'run' ? 1.6 : dancing ? 1.35 : 1.0;

  // Swing : fort pour marche/danse, quasi nul pour les autres (micro-oscillation)
  const swing = (walking || dancing)
    ? Math.sin(phase * Math.PI * 2) * amp
    : Math.sin(phase * Math.PI * 2) * 0.055;

  // Bob vertical : respiration organique même en idle
  const bob = walking ? Math.abs(Math.sin(phase * Math.PI * 2)) * 3
            : dancing ? Math.abs(Math.sin(phase * Math.PI * 2)) * 4.5
            : Math.sin(phase * Math.PI * 1.55) * 0.75; // respiration universelle

  const cl = def.clothes;
  const { shoulderW: sw, hipW: hw, torsoH: th, legLen: ll, armLen: al } = def;
  const lean = def.lean || 0;

  ctx.save();
  ctx.translate(gx, gy);
  if (flipX) ctx.scale(-1, 1);
  if (lean) ctx.rotate(lean * Math.PI / 180);
  if (dancing) ctx.rotate(Math.sin(phase * Math.PI * 2) * 0.08);

  // Ombre au sol
  const shadowY = sitting ? ll * 0.6 : crouching ? ll * 0.15 : 3;
  ctx.beginPath(); ctx.ellipse(4, shadowY, sw * (crouching || sitting ? 1.0 : 0.7), sw * 0.22, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.fill();

  // ── JAMBES ───────────────────────────────────────────────────────────────
  if (sitting) {
    // Jambe ARRIÈRE assise (cuisse horizontale → jambe vers le bas)
    ctx.save();
    ctx.translate(-hw * 0.28, 0);
    ctx.rotate(80 * Math.PI / 180);
    ctx.fillStyle = shade(cl.bot, -18);
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.5, 4); ctx.fill();
    ctx.translate(0, ll * 0.5); ctx.rotate(-75 * Math.PI / 180);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.46, 4); ctx.fill();
    ctx.translate(0, ll * 0.44);
    ctx.fillStyle = shade(skin, -12);
    ctx.beginPath(); ctx.ellipse(hw * 0.1, ll * 0.08, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Jambe AVANT assise
    ctx.save();
    ctx.translate(hw * 0.12, 0);
    ctx.rotate(86 * Math.PI / 180);
    ctx.fillStyle = cl.bot;
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.5, 4); ctx.fill();
    ctx.translate(0, ll * 0.5); ctx.rotate(-78 * Math.PI / 180);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.46, 4); ctx.fill();
    ctx.translate(0, ll * 0.44);
    ctx.fillStyle = skin;
    ctx.beginPath(); ctx.ellipse(hw * 0.2, ll * 0.08, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

  } else if (crouching) {
    // Jambe ARRIÈRE accroupie (très fléchie)
    ctx.save();
    ctx.translate(-hw * 0.32, 0);
    ctx.rotate(46 * Math.PI / 180);
    ctx.fillStyle = shade(cl.bot, -18);
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.42, 4); ctx.fill();
    ctx.translate(0, ll * 0.42); ctx.rotate(-88 * Math.PI / 180);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.36, 4); ctx.fill();
    ctx.translate(0, ll * 0.34);
    ctx.fillStyle = shade(skin, -12);
    ctx.beginPath(); ctx.ellipse(0, ll * 0.08, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Jambe AVANT accroupie
    ctx.save();
    ctx.translate(hw * 0.18, 0);
    ctx.rotate(54 * Math.PI / 180);
    ctx.fillStyle = cl.bot;
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.42, 4); ctx.fill();
    ctx.translate(0, ll * 0.42); ctx.rotate(-96 * Math.PI / 180);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.36, 4); ctx.fill();
    ctx.translate(0, ll * 0.34);
    ctx.fillStyle = skin;
    ctx.beginPath(); ctx.ellipse(hw * 0.15, ll * 0.08, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

  } else {
    // JAMBES NORMALES
    const jaAngle = (-swing * 28) * Math.PI / 180;
    ctx.save();
    ctx.translate(-hw * 0.32, -bob);
    ctx.rotate(jaAngle);
    ctx.fillStyle = shade(cl.bot, -18);
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.52, 4); ctx.fill();
    ctx.translate(0, ll * 0.5); ctx.rotate(-jaAngle * 0.62);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.48, 4); ctx.fill();
    ctx.translate(0, ll * 0.46);
    ctx.fillStyle = shade(skin, -12);
    ctx.beginPath(); ctx.ellipse(jaAngle < 0 ? hw * 0.3 : -hw * 0.05, ll * 0.1, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    const jfAngle = (swing * 28) * Math.PI / 180;
    ctx.save();
    ctx.translate(hw * 0.2, -bob);
    ctx.rotate(jfAngle);
    ctx.fillStyle = cl.bot;
    rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.52, 4); ctx.fill();
    ctx.translate(0, ll * 0.5); ctx.rotate(-jfAngle * 0.62);
    rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.48, 4); ctx.fill();
    ctx.translate(0, ll * 0.46);
    ctx.fillStyle = skin;
    ctx.beginPath(); ctx.ellipse(jfAngle > 0 ? hw * 0.3 : -hw * 0.05, ll * 0.1, hw * 0.52, hw * 0.24, 0, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  }

  // ── TORSE ─────────────────────────────────────────────────────────────────
  const torsoLean = crouching ? 16 * Math.PI / 180 : 0;
  const ty = sitting ? -(th + bob * 0.3) : crouching ? -(th * 0.68) : -(th + bob);
  const thA = crouching ? th * 0.82 : th; // hauteur torse ajustée

  ctx.save();
  if (torsoLean) ctx.rotate(torsoLean);
  ctx.beginPath();
  ctx.moveTo(-sw * 0.52, ty); ctx.lineTo(-sw * 0.42, ty + thA);
  ctx.lineTo(sw * 0.58, ty + thA); ctx.lineTo(sw * 0.68, ty);
  ctx.closePath(); ctx.fillStyle = cl.top; ctx.fill();

  if (def.gender === 'f') {
    ctx.fillStyle = cl.acc;
    ctx.fillRect(-sw * 0.42, ty + thA * 0.14, sw * 1.02, thA * 0.24);
    ctx.fillStyle = cl.top;
    for (let kx = -sw * 0.3; kx < sw * 0.6; kx += sw * 0.22) {
      ctx.beginPath();
      ctx.moveTo(kx, ty + thA * 0.14); ctx.lineTo(kx + sw * 0.1, ty + thA * 0.26);
      ctx.lineTo(kx, ty + thA * 0.38); ctx.lineTo(kx - sw * 0.1, ty + thA * 0.26);
      ctx.closePath(); ctx.fill();
    }
    ctx.fillStyle = cl.acc; ctx.fillRect(-sw * 0.42, ty + thA * 0.4, sw * 1.02, thA * 0.08);
    ctx.fillStyle = cl.bot; ctx.fillRect(-sw * 0.42, ty + thA * 0.5, sw * 1.02, thA * 0.06);
  } else {
    ctx.fillStyle = cl.acc;
    ctx.fillRect(-sw * 0.48, ty + thA * 0.12, sw * 1.18, thA * 0.08);
    ctx.fillRect(-sw * 0.48, ty + thA * 0.24, sw * 1.18, thA * 0.06);
    if (def.gender === 'm' && def.hair !== 'beard') {
      ctx.fillStyle = cl.top;
      ctx.beginPath(); ctx.moveTo(-sw * 0.1, ty); ctx.lineTo(0, ty + thA * 0.2); ctx.lineTo(sw * 0.1, ty); ctx.closePath(); ctx.fill();
    }
  }
  ctx.fillStyle = skin;
  rr(ctx, -sw * 0.12, ty - def.headR * 0.38, sw * 0.24, def.headR * 0.42, 3); ctx.fill();
  ctx.restore();

  // ── BRAS ARRIÈRE ───────────────────────────────────────────────────────────
  const baAngle = waving ? (-27) * Math.PI / 180
    : sitting   ? (22 + Math.sin(phase * Math.PI * 1.4) * 3) * Math.PI / 180
    : crouching ? 32 * Math.PI / 180
    : pointing  ? 15 * Math.PI / 180
    : (walking || dancing) ? (-swing * 32 + 10) * Math.PI / 180
    : (Math.sin(phase * Math.PI * 1.5 + 0.3) * 3 + 10) * Math.PI / 180;

  ctx.save();
  ctx.translate(-sw * 0.38, ty + thA * 0.18);
  ctx.rotate(baAngle);
  ctx.fillStyle = shade(skin, -18);
  rr(ctx, -al * 0.1, 0, al * 0.22, al * 0.48, 3); ctx.fill();
  ctx.translate(0, al * 0.45); ctx.rotate(-baAngle * 0.55);
  rr(ctx, -al * 0.09, 0, al * 0.2, al * 0.44, 3); ctx.fill();
  ctx.translate(0, al * 0.4);
  ctx.beginPath(); ctx.arc(0, 0, al * 0.11, 0, Math.PI * 2); ctx.fill();
  ctx.restore();

  // ── BRAS AVANT ─────────────────────────────────────────────────────────────
  const faAngle = waving
    ? (-58 - Math.sin(phase * Math.PI * 4) * 16) * Math.PI / 180
    : sitting   ? (-14 + Math.sin(phase * Math.PI * 1.4) * 4) * Math.PI / 180
    : crouching ? -22 * Math.PI / 180
    : pointing  ? -84 * Math.PI / 180
    : (walking || dancing) ? (swing * 32 - 10) * Math.PI / 180
    : (Math.sin(phase * Math.PI * 1.5) * 4 - 10) * Math.PI / 180;

  ctx.save();
  ctx.translate(sw * 0.52, ty + thA * 0.18);
  ctx.rotate(faAngle);
  ctx.fillStyle = skin;
  rr(ctx, -al * 0.11, 0, al * 0.24, al * 0.48, 3); ctx.fill();
  ctx.translate(0, al * 0.45);
  ctx.rotate(waving ? 30 * Math.PI / 180 : pointing ? 0 : -faAngle * 0.55);
  rr(ctx, -al * 0.1, 0, al * 0.22, al * 0.44, 3); ctx.fill();
  ctx.translate(0, al * 0.4);
  ctx.beginPath(); ctx.arc(0, 0, al * 0.12, 0, Math.PI * 2); ctx.fill();
  if (waving) {
    for (let fi = -7; fi <= 7; fi += 3.5) {
      ctx.beginPath(); ctx.ellipse(fi, al * 0.14, 2.5, 5.5, 0, 0, Math.PI * 2); ctx.fill();
    }
  }
  if (pointing) {
    ctx.fillStyle = skin;
    rr(ctx, -al * 0.07, 0, al * 0.14, al * 0.3, 2); ctx.fill();
  }
  ctx.restore();

  ctx.restore();
}

// ── CORPS + MEMBRES : vue face S ──────────────────────────────────────────
function drawBodyS(ctx, gx, gy, def, state, phase, skin) {
  const walking   = state === 'walk' || state === 'run';
  const waving    = state === 'wave';
  const sitting   = state === 'sit';
  const crouching = state === 'crouch';
  const dancing   = state === 'dance';
  const amp       = state === 'run' ? 1.5 : dancing ? 1.35 : 1.0;

  const swing = (walking || dancing)
    ? Math.sin(phase * Math.PI * 2) * amp
    : Math.sin(phase * Math.PI * 2) * 0.055;

  const bob = walking ? Math.abs(Math.sin(phase * Math.PI * 2)) * 3
            : dancing ? Math.abs(Math.sin(phase * Math.PI * 2)) * 4
            : Math.sin(phase * Math.PI * 1.55) * 0.75;

  const cl = def.clothes;
  const { shoulderW: sw, hipW: hw, torsoH: th, legLen: ll, armLen: al } = def;

  ctx.save(); ctx.translate(gx, gy);
  if (dancing) ctx.rotate(Math.sin(phase * Math.PI * 2) * 0.07);

  ctx.beginPath(); ctx.ellipse(0, sitting ? ll * 0.6 : 3, sw * 0.9, sw * 0.28, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.fill();

  if (sitting) {
    // Jambes en S (face) : cuisses sur les côtés, jambes vers le bas
    [[-hw * 0.44, 78], [hw * 0.44, 78]].forEach(([ox, ang]) => {
      ctx.save(); ctx.translate(ox, 0); ctx.rotate(ang * Math.PI / 180 * Math.sign(ox));
      ctx.fillStyle = shade(cl.bot, -10);
      rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.48, 4); ctx.fill();
      ctx.translate(0, ll * 0.48); ctx.rotate(-ang * 0.9 * Math.PI / 180 * Math.sign(ox));
      rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.44, 4); ctx.fill();
      ctx.translate(0, ll * 0.42);
      ctx.fillStyle = shade(skin, -8);
      ctx.beginPath(); ctx.ellipse(0, ll * 0.08, hw * 0.55, hw * 0.22, 0, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    });
  } else if (crouching) {
    [[-hw * 0.52, 48], [hw * 0.52, 48]].forEach(([ox, ang]) => {
      ctx.save(); ctx.translate(ox, 0); ctx.rotate(ang * Math.PI / 180 * Math.sign(ox));
      ctx.fillStyle = shade(cl.bot, -12);
      rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.38, 4); ctx.fill();
      ctx.translate(0, ll * 0.38); ctx.rotate(-92 * Math.PI / 180 * Math.sign(ox));
      rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.34, 4); ctx.fill();
      ctx.translate(0, ll * 0.32);
      ctx.fillStyle = shade(skin, -8);
      ctx.beginPath(); ctx.ellipse(0, ll * 0.06, hw * 0.55, hw * 0.22, 0, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    });
  } else {
    [[-hw * 0.52, -swing * 24], [hw * 0.52, swing * 24]].forEach(([ox, la]) => {
      const ang = la * Math.PI / 180;
      ctx.save(); ctx.translate(ox, -bob); ctx.rotate(ang);
      ctx.fillStyle = shade(cl.bot, -15);
      rr(ctx, -hw * 0.38, 0, hw * 0.72, ll * 0.52, 4); ctx.fill();
      ctx.translate(0, ll * 0.5); ctx.rotate(-ang * 0.6);
      rr(ctx, -hw * 0.32, 0, hw * 0.62, ll * 0.48, 4); ctx.fill();
      ctx.translate(0, ll * 0.46);
      ctx.fillStyle = shade(skin, -10);
      ctx.beginPath(); ctx.ellipse(ang < 0 ? hw * 0.28 : 0, ll * 0.08, hw * 0.55, hw * 0.22, 0, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    });
  }

  const ty = sitting ? -(th + bob * 0.3) : crouching ? -(th * 0.72) : -(th + bob);
  const thA = crouching ? th * 0.84 : th;
  ctx.beginPath();
  ctx.moveTo(-sw * 0.7, ty); ctx.lineTo(-sw * 0.56, ty + thA);
  ctx.lineTo(sw * 0.56, ty + thA); ctx.lineTo(sw * 0.7, ty);
  ctx.closePath(); ctx.fillStyle = cl.top; ctx.fill();
  ctx.fillStyle = cl.acc;
  ctx.fillRect(-sw * 0.65, ty + thA * 0.38, sw * 1.3, thA * 0.12);

  ctx.fillStyle = skin;
  rr(ctx, -sw * 0.13, ty - def.headR * 0.38, sw * 0.26, def.headR * 0.42, 3); ctx.fill();

  [
    [sw * 0.68, ty + thA * 0.15, waving ? (-56 - Math.sin(phase * Math.PI * 4) * 16) * Math.PI / 180
      : sitting ? (-14 + Math.sin(phase * Math.PI * 1.4) * 4) * Math.PI / 180
      : (walking || dancing) ? (-swing * 28 - 12) * Math.PI / 180
      : (Math.sin(phase * Math.PI * 1.5) * 4 - 10) * Math.PI / 180, waving],
    [-sw * 0.68, ty + thA * 0.15, sitting ? (16 + Math.sin(phase * Math.PI * 1.4) * 3) * Math.PI / 180
      : (walking || dancing) ? (swing * 28 + 12) * Math.PI / 180
      : (Math.sin(phase * Math.PI * 1.5 + 0.3) * 3 + 10) * Math.PI / 180, false],
  ].forEach(([ox, oy, ang, wave]) => {
    ctx.save(); ctx.translate(ox, oy); ctx.rotate(ang);
    ctx.fillStyle = skin;
    rr(ctx, -al * 0.11, 0, al * 0.23, al * 0.46, 3); ctx.fill();
    ctx.translate(0, al * 0.42); ctx.rotate(wave ? 28 * Math.PI / 180 : -ang * 0.5);
    rr(ctx, -al * 0.1, 0, al * 0.21, al * 0.42, 3); ctx.fill();
    ctx.translate(0, al * 0.38);
    ctx.beginPath(); ctx.arc(0, 0, al * 0.12, 0, Math.PI * 2); ctx.fill();
    if (wave) {
      for (let fi = -7; fi <= 7; fi += 3.5) {
        ctx.beginPath(); ctx.ellipse(fi, al * 0.14, 2.5, 5.5, 0, 0, Math.PI * 2); ctx.fill();
      }
    }
    ctx.restore();
  });

  ctx.restore();
}

// ── FONCTION PRINCIPALE EXPORTÉE ──────────────────────────────────────────
/**
 * drawChar
 *
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} x           position X centre
 * @param {number} groundY     sol (bas des pieds) — ou niveau de l'assise pour state='sit'
 * @param {object} opts
 *   .type     'adulte-femme'|'adulte-homme'|'enfant-fille'|'enfant-garcon'|'ancien'
 *   .dir      'E'|'W'|'S'
 *   .state    'idle'|'walk'|'run'|'talk'|'wave'|'sit'|'lie'|'sleep'|'dance'|'crouch'|'point'
 *   .phase    0..1
 *   .scale    number
 *   .skin     '#...'
 *   .mouthAmt 0..1
 */
function drawChar(ctx, x, groundY, opts = {}) {
  const type  = opts.type  || 'adulte-femme';
  const def   = CHAR_DEF[type] || CHAR_DEF['adulte-femme'];
  const dir   = opts.dir   || 'E';
  const state = opts.state || 'idle';
  const phase = opts.phase || 0;
  const sc    = (opts.scale || 1) * def.hMult;
  const skin  = opts.skin  || def.skin;
  const mo    = opts.mouthAmt || 0;

  // ── Couché / endormi : rotation globale du personnage ────────────────────
  if (state === 'lie' || state === 'sleep') {
    const charH = (def.headR * 2 + def.torsoH + def.legLen) * sc;
    ctx.save();
    ctx.translate(x, groundY - charH / 2);
    ctx.rotate(dir === 'W' ? -Math.PI / 2 : Math.PI / 2);
    ctx.scale(sc, sc);
    const localGY = charH / (2 * sc);
    const localHeadY = -(def.legLen + def.torsoH + def.headR * 0.9);
    drawBodyE(ctx, 0, localGY, def, 'idle', phase, false, skin);
    drawHeadE(ctx, 0, localHeadY, def, { skin, talking: false, mouthAmt: 0, sleeping: state === 'sleep' });
    ctx.restore();
    return;
  }

  const walking = state === 'walk' || state === 'run';
  const dancing = state === 'dance';
  const bob = walking ? Math.abs(Math.sin(phase * Math.PI * 2)) * 3 * sc
            : dancing ? Math.abs(Math.sin(phase * Math.PI * 2)) * 4.5 * sc
            : Math.sin(phase * Math.PI * 1.55) * 0.75 * sc;
  const lean = def.lean || 0;

  ctx.save();
  ctx.scale(sc, sc);
  const xs = x / sc;
  const ys = groundY / sc;
  const leanOff = lean ? Math.sin(lean * Math.PI / 180) * (def.torsoH + def.legLen) : 0;
  const bodyY = ys;

  // headBaseY dépend de la posture
  let headBaseY;
  if (state === 'sit') {
    headBaseY = bodyY - (def.torsoH + def.headR * 0.9) - (bob / sc);
  } else if (state === 'crouch') {
    headBaseY = bodyY - (def.legLen * 0.62 + def.torsoH * 0.82 + def.headR * 0.9) - (bob / sc);
  } else {
    headBaseY = bodyY - (def.legLen + def.torsoH + def.headR * 0.9) - (bob / sc);
  }
  const headX = xs + leanOff;
  const headOpts = { skin, talking: state === 'talk', mouthAmt: mo };

  if (dir === 'E' || dir === 'W') {
    drawBodyE(ctx, xs, bodyY, def, state, phase, dir === 'W', skin);
    headOpts.flipX = dir === 'W';
    drawHeadE(ctx, dir === 'W' ? xs - leanOff : headX, headBaseY, def, headOpts);
  } else {
    drawBodyS(ctx, xs, bodyY, def, state, phase, skin);
    drawHeadS(ctx, xs, headBaseY, def, headOpts);
  }

  ctx.restore();
}

function totalHeight(type, state) {
  const def = CHAR_DEF[type] || CHAR_DEF['adulte-femme'];
  const base = (def.headR * 2 + def.torsoH + def.legLen) * def.hMult;
  if (state === 'sit') return (def.torsoH + def.headR * 2) * def.hMult;
  if (state === 'crouch') return base * 0.65;
  if (state === 'lie' || state === 'sleep') return base;
  return base;
}

module.exports = { drawChar, totalHeight, CHAR_DEF };
