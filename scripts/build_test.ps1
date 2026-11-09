# APK de TEST : branchée sur le serveur de test (api-staging), ruban orange « TEST ». Signée avec la clé de PRODUCTION, comme toutes les versions (une seule clé).
# Usage (depuis la racine du projet) :  .\scripts\build_test.ps1
# Ne jamais envoyer ce fichier sur les boutiques (il parle au serveur de test). Pour les boutiques : .\scripts\build_prod.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path 'staging_api.json')) { throw "staging_api.json introuvable : lance le script depuis le projet afrolookofficiel_v2." }
if (-not (Test-Path 'android\key.properties')) { throw "android\key.properties introuvable : la clé de publication est absente, construction refusée." }

# une seule clé : la variable de clé de test ne doit jamais être définie
if ($env:ORG_GRADLE_PROJECT_debugSignRelease) {
    Write-Host 'La variable de clé de TEST était définie dans cette fenêtre : elle est effacée (une seule clé, celle de production).' -ForegroundColor Yellow
    Remove-Item Env:ORG_GRADLE_PROJECT_debugSignRelease
}

flutter build apk --release --dart-define-from-file=staging_api.json --dart-define=TEST_BUILD=true
if ($LASTEXITCODE -ne 0) { throw "La construction a échoué (code $LASTEXITCODE)." }

Write-Host ''
Write-Host 'APK DE TEST prête (serveur de test, ruban TEST, clé de production) :' -ForegroundColor Green
Write-Host '  build\app\outputs\flutter-apk\app-release.apk'
Write-Host '  Installer : adb install -r build\app\outputs\flutter-apk\app-release.apk'
Write-Host '  Elle s''installe PAR-DESSUS l''application des boutiques (même clé) : reconnecte-toi ensuite, la session du serveur de test est différente.'
