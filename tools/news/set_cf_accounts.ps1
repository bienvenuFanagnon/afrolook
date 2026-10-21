# Enregistre les comptes Cloudflare d'Afro Journal dans le secret Firebase CF_NEWS_ACCOUNTS.
# Le script ne contient aucune clé : il demande l'identifiant et le token de chaque compte (le token est masqué à la saisie),
# écrit un fichier temporaire hors du projet, l'envoie à Firebase puis le supprime.
#
# Utilisation, depuis la racine du projet :
#   powershell -ExecutionPolicy Bypass -File tools\news\set_cf_accounts.ps1
param([string]$Project = "afrolooki")

$accounts = @()
while ($true) {
  $n = $accounts.Count + 1
  $id = Read-Host "Identifiant du compte Cloudflare n°$n (laisser vide pour terminer)"
  if ([string]::IsNullOrWhiteSpace($id)) { break }
  $id = $id.Trim()
  if ($id -notmatch '^[a-fA-F0-9]{32}$') {
    Write-Host "Identifiant invalide : il doit faire 32 caractères (chiffres et lettres a à f) et celui-ci en a $($id.Length). Recommence ce compte."
    continue
  }
  $secure = Read-Host "Token d'API du compte n°$n (la saisie est masquée)" -AsSecureString
  $token = [System.Net.NetworkCredential]::new("", $secure).Password
  if ([string]::IsNullOrWhiteSpace($token)) { Write-Host "Token vide : compte ignoré."; continue }
  $accounts += @{ id = $id; token = $token.Trim() }
}

if ($accounts.Count -eq 0) {
  Write-Host "Aucun compte saisi : rien n'a été enregistré."
  exit 1
}

$json = ConvertTo-Json -InputObject @($accounts) -Compress
$tmp = Join-Path $env:TEMP ("cf_news_" + [guid]::NewGuid().ToString("N") + ".json")
try {
  # UTF-8 sans BOM : un BOM rendrait le JSON illisible pour les fonctions
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
  firebase functions:secrets:set CF_NEWS_ACCOUNTS --project $Project --data-file $tmp
} finally {
  if (Test-Path $tmp) { Remove-Item $tmp -Force }
}
Write-Host ""
Write-Host "$($accounts.Count) compte(s) enregistré(s) dans CF_NEWS_ACCOUNTS. Le fichier temporaire a été supprimé."
