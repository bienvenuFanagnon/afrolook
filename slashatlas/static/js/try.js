(function () {
  'use strict';
  var q = new URLSearchParams(location.search).get('c');
  var box = document.getElementById('trysel');
  if (!box || !q) return;
  var map = {}; try { map = JSON.parse(box.dataset.map); } catch (e) {}
  var c = map[q]; if (!c) return;
  box.hidden = false;
  document.getElementById('try-code').textContent = c.code;
  var a = document.createElement('a'); a.href = c.href; a.textContent = c.title; document.getElementById('try-title').appendChild(a);
  fetch(c.href).then(function (r) { return r.text(); }).then(function (h) {
    var m = h.match(/<pre id="p-[^"]+">([\s\S]*?)<\/pre>/); if (!m) return;
    var t = document.createElement('textarea'); t.innerHTML = m[1];
    document.getElementById('p-try').textContent = t.value;
    document.getElementById('try-cmd').hidden = false;
  }).catch(function () {});
})();
