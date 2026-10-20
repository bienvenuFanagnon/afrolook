# Appodeal sur iPhone : étapes à faire sur un Mac (non testées depuis Windows)

L'application utilise Appodeal pour les bannières sur **Android**. Sur iPhone, les bannières restent sur AdMob en direct tant que ces étapes ne sont pas faites
et validées, puis activées par Firestore (`AppConfig/ads` → `appodealIos: true`, voir `tools/ads/set_config.js`).

Clé d'application Appodeal iOS : `47013088991ce1f20343b13078a4c981027aff2aa7ca05c6` (app « Afrolook », bundle `com.afrotok.afrotok`) ; elle est déjà
dans `lib/ads/appodeal_service.dart`.

1. `ios/Podfile` : (plateforme 17.0 et `use_frameworks!` déjà en place) ajouter en tête, avant `target 'Runner'` :

       source 'https://github.com/appodeal/CocoaPods.git'
       source 'https://github.com/bidon-io/CocoaPods-Specs.git'
       source 'https://cdn.cocoapods.org'
       install! 'cocoapods', :deterministic_uuids => false, :warn_for_multiple_pod_sources => false

       def appodeal
         pod 'Appodeal', '4.3.0'
         pod 'AppodealGoogleAdMobAdapter', '13.5.0.0'
         pod 'AppodealAppLovinAdapter', '13.6.4.0'
         pod 'AppodealBidMachineAdapter', '3.7.1.0'
         pod 'AppodealBidonAdapter', '0.15.0.0'
         pod 'AppodealBigoAdsAdapter', '5.2.1.0'
         pod 'AppodealDTExchangeAdapter', '8.4.7.0'
         pod 'AppodealInMobiAdapter', '11.3.0.0'
         pod 'AppodealIronSourceAdapter', '9.4.0.0.0'
         pod 'AppodealUnityAdapter', '4.17.0.0'
         pod 'AppodealIABAdapter', '3.5.2.0'
       end

   puis appeler `appodeal` dans `target 'Runner' do … end` (versions du README de `stack_appodeal_flutter` 4.3.1 ; à comparer avec le
   générateur de dépendances Appodeal si une version change).
2. `cd ios && pod install --repo-update`, ouvrir `Runner.xcworkspace`.
3. Point de vigilance : l'adaptateur AppodealGoogleAdMobAdapter 13.5 et le plugin `google_mobile_ads` 6 doivent s'accorder sur la version du SDK Google
   (`Google-Mobile-Ads-SDK`). Si CocoaPods signale un conflit, aligner les versions (ou retirer l'adaptateur AdMob d'Appodeal côté iOS).
4. `Info.plist` : `GADApplicationIdentifier` est déjà présent ; `SKAdNetworkItems` contient déjà 65 identifiants (Appodeal en recommande davantage :
   liste à jour dans sa documentation) ; Appodeal demande aussi `NSAppTransportSecurity › NSAllowsArbitraryLoads = true` (à valider avec les règles de
   l'App Store avant de l'ajouter).
5. Tester en Debug (pubs de test), puis publier la version iOS, puis activer `appodealIos` dans Firestore.
