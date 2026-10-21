# Règles R8 supplémentaires (ajoutées au build release avec proguard-rules.pro).
#
# Le plugin google_sign_in (connexion Google) tire une version récente de play-services-auth, qui ne contient plus
# l'ancienne API « Smart Lock / Credentials » (com.google.android.gms.auth.api.credentials). La bibliothèque smart_auth
# (utilisée par pinput pour lire le SMS de vérification) la mentionne encore pour une seule fonction, la demande du
# numéro de téléphone, que l'application n'appelle pas. R8 refusait donc de compiler (« Missing class »).
# Liste produite par Gradle (missing_rules.txt), regroupée en une ligne.
-dontwarn com.google.android.gms.auth.api.credentials.**

# Adaptateur Meta (Audience Network) d'Appodeal : il mentionne des annotations de compilation (Nullsafe) absentes de l'application ;
# ce ne sont que des annotations, sans effet à l'exécution. Liste produite par Gradle (missing_rules.txt).
-dontwarn com.facebook.infer.annotation.**
