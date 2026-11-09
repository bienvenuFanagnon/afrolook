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
# Correctif (09/11/2026) : l'essai sur téléphone (APK release) donnait « initialisation : com.google.mediapipe.framework.Graph ». Le fichier mapping.txt du build montre que R8
# avait renommé ou supprimé 186 classes de MediaPipe (MediaPipeException, ProtoUtil, Graph$PacketBufferItem, les « Options » de calculateurs…) alors que le code natif
# (libmediapipe_tasks_vision_jni.so) les cherche PAR LEUR NOM : la bibliothèque ne les protège donc pas assez. On garde tout MediaPipe tel quel (quelques centaines de Ko).
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.proto.**
# Seconde cause trouvée au journal du téléphone (09/11/2026, Pixel 8 Pro, APK release) : Graph.<clinit> échouait avec « IllegalStateException: no caller found on the stack for: e7.d ».
# e7.d est la classe FluentLogger (Flogger, le journal interne de Google embarqué par MediaPipe) : elle retrouve la classe appelante en lisant la pile par NOM de classe, ce que
# le renommage de R8 casse. On garde Flogger tel quel (quelques dizaines de Ko).
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**

# Lecture de texte ML Kit (contrôle des vidéos d autres réseaux) : le plugin mentionne les modèles chinois, japonais, coréen et devanagari, non inclus
# (l application n utilise que l alphabet latin). Classes absentes seulement mentionnées : sans effet à l exécution.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Filtre de contenu explicite (TensorFlow Lite) : le délégué GPU optionnel est mentionné mais absent
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.**
