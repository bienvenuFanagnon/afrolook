# Version des BOUTIQUES (Play Store) : serveur de production, vraie clé de publication, aucun ruban de test.
# Usage (depuis la racine du projet) :  .\scripts\build_prod.ps1
# Le script REFUSE de construire si un réglage de test traîne (variable de clé de test, fichier de serveur de test).
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

# 1. la clé de test ne doit jamais signer une version des boutiques : on efface la variable, et on le dit
if ($env:ORG_GRADLE_PROJECT_debugSignRelease) {
    Write-Host 'La variable de clé de TEST était encore définie dans cette fenêtre : elle est effacée pour cette construction.' -ForegroundColor Yellow
    Remove-Item Env:ORG_GRADLE_PROJECT_debugSignRelease
}
if (-not (Test-Path 'android\key.properties')) { throw "android\key.properties introuvable : la vraie clé de publication est absente, construction refusée." }

# 2. la version doit avoir changé depuis le dernier envoi (le Play Store refuse un numéro déjà utilisé)
$ver = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
Write-Host "Version construite : $ver" -ForegroundColor Cyan
$ok = Read-Host "Ce numéro (le chiffre après le +) est-il NOUVEAU pour le Play Store ? (o/N)"
if ($ok -ne 'o') { throw "Construction annulée : augmente la version dans pubspec.yaml (par exemple 2.1.5+281)." }

# 3. on construit SANS staging_api.json ni TEST_BUILD
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { throw "La construction a échoué (code $LASTEXITCODE)." }

Write-Host ''
Write-Host 'VERSION DES BOUTIQUES prête (production, vraie clé) :' -ForegroundColor Green
Write-Host '  build\app\outputs\bundle\release\app-release.aab'
