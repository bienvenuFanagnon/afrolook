const { chromium } = require('playwright-core');
const path = require('path'); const fs = require('fs');
(async () => {
  const mode = process.argv[2] || 'test';
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox', '--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.log('PAGEERR', e.message));
  await page.goto('file://' + path.join(__dirname, 'index_h.html'));
  await page.evaluate(() => document.fonts.ready);
  if (mode === 'test') {
    const times = (process.argv[3] || '0.5,3,4.6,6.5,8,9.4,10.2,11.2,12.6,13.5,16.8,18,21.6,23,26,30').split(',').map(Number);
    fs.mkdirSync('test_h', { recursive: true });
    for (const t of times) { await page.evaluate(t => window.render(t), t); await page.screenshot({ path: `test_h/t_${String(t).replace('.', '_')}.png` }); }
  } else {
    const FPS = 30, T = 32.5, N = Math.round(T * FPS);
    fs.mkdirSync('frames_h', { recursive: true });
    for (let i = 0; i < N; i++) {
      await page.evaluate(t => window.render(t), i / FPS);
      await page.screenshot({ path: `frames_h/f${String(i).padStart(4, '0')}.jpg`, type: 'jpeg', quality: 93 });
      if (i % 90 === 0) console.log('frame', i, '/', N);
    }
  }
  await browser.close();
})();
