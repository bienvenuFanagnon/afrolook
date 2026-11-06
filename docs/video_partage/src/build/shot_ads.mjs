// Capture de la vraie page https://afrolookmedia.com/ads/ (téléphone) pour la vidéo aux annonceurs.
import puppeteer from 'puppeteer-core';
import path from 'node:path';
const out = path.resolve(process.argv[2]);
const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--hide-scrollbars'] });
const page = await browser.newPage();
await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2.5846, isMobile: true, hasTouch: true });
await page.setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Mobile Safari/537.36');
await page.goto('https://afrolookmedia.com/ads/', { waitUntil: 'networkidle2', timeout: 90000 });
await new Promise(r => setTimeout(r, 2500));
await page.screenshot({ path: path.join(out, 'ads_accueil.png'), type: 'png' });
await page.evaluate(() => window.scrollTo(0, 900)); await new Promise(r => setTimeout(r, 1500));
await page.screenshot({ path: path.join(out, 'ads_simulateur.png'), type: 'png' });
await browser.close();
console.log('captures écrites dans', out);
