# Copie corrigée de tapjoy_offerwall 14.6.0 (Afrolook)

Le plugin publié convertit de force l'activité principale en `FlutterActivity` (`binding.activity as FlutterActivity`) et fait planter
l'application dès le lancement quand l'activité est d'un autre type. Afrolook utilise `AudioServiceFragmentActivity` (lecture de musique en
arrière-plan, `local_auth`).

Correction (fichier `android/src/main/kotlin/com/tapjoy/flutter/TapjoyOfferwallPlugin.kt`) : l'activité est gardée comme `android.app.Activity`,
et le cycle de vie n'est observé que si l'activité est un `LifecycleOwner`. Rien d'autre n'est changé.
À retirer (revenir à la version publiée) si Tapjoy corrige ce point.
