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

# Mur de tâches (Tapjoy) : règles usuelles du SDK (à confirmer avec la page « Proguard » de la documentation Tapjoy)
-keep class com.tapjoy.** { *; }
-keep class com.moat.** { *; }
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.tapjoy.**

# Moteur d effets de visage : MediaPipe Tasks (classes appelées par le code natif, protos absents de la bibliothèque)
# (les règles de conservation viennent de la bibliothèque elle-même ; ici seulement les protos absents)
-dontwarn com.google.mediapipe.proto.**

# Lecture de texte ML Kit (contrôle des vidéos d autres réseaux) : le plugin mentionne les modèles chinois, japonais, coréen et devanagari, non inclus
# (l application n utilise que l alphabet latin). Classes absentes seulement mentionnées : sans effet à l exécution.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Filtre de contenu explicite (TensorFlow Lite) : le délégué GPU optionnel est mentionné mais absent
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**
