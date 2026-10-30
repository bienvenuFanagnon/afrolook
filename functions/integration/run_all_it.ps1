# Lance les tests d'intégration contre l'émulateur Firestore (un à la fois, le port 8080 est libéré entre chaque).
# Utilisation (PowerShell), depuis n'importe où :  .\functions\integration\run_all_it.ps1
# Prérequis : « npm run build » dans functions/ (les tests lisent functions/lib/), Firebase CLI et Java installés.
# Les journaux sont écrits dans le dossier temporaire ($env:TEMP\afrolook_it). Chaque test affiche « N réussis, 0 échoués ».
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$fn = Split-Path -Parent $here
$logs = Join-Path $env:TEMP 'afrolook_it'
New-Item -ItemType Directory -Force $logs | Out-Null
function Free {
  Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 2
}
Set-Location $fn
foreach ($t in 'adv_it', 'watch_it', 'pub_it', 'engine_it', 'share_it') {
  Free
  Write-Output "=== $t"
  $log = Join-Path $logs ($t + '.log')
  $cmd = 'firebase emulators:exec --only firestore --project afrolooki-it "node ' + (Join-Path $here ($t + '.cjs')) + '" > "' + $log + '" 2>&1'
  cmd /c $cmd
  Select-String -Path $log -Pattern 'réussis|✗|ERREUR|Could not start' | Select-Object -First 8 | ForEach-Object { $_.Line }
}
Free
npx jest 2>&1 | Select-String 'Tests:|Suites:|FAIL'
