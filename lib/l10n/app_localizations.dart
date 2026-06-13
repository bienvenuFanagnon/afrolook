import 'package:flutter/material.dart';

/// Point d'entrée : AppLocalizations.of(context).nomDeLaChaîne
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  String get _lang => locale.languageCode;

  // ── Navigation ────────────────────────────────────────────────────────────
  String get navHome        => _lang == 'fr' ? 'Accueil'       : 'Home';
  String get navVideos      => _lang == 'fr' ? 'Vidéos'        : 'Videos';
  String get navLives       => 'Lives';
  String get navMessages    => _lang == 'fr' ? 'Messages'      : 'Messages';
  String get navCreate      => _lang == 'fr' ? 'Créer'         : 'Create';
  String get navInvitations => _lang == 'fr' ? 'Invitations'   : 'Invitations';
  String get navProfile     => _lang == 'fr' ? 'Profil'        : 'Profile';
  String get navSettings    => _lang == 'fr' ? 'Paramètres'    : 'Settings';
  String get navNotifications => _lang == 'fr' ? 'Notifications' : 'Notifications';
  String get navShop        => _lang == 'fr' ? 'Boutique'      : 'Shop';
  String get navDating      => _lang == 'fr' ? 'Rencontres'    : 'Dating';

  // ── Filtres du feed ───────────────────────────────────────────────────────
  String get feedAll        => _lang == 'fr' ? 'Tous'          : 'All';
  String get feedTrending   => _lang == 'fr' ? 'Tendances'     : 'Trending';
  String get feedFollowing  => _lang == 'fr' ? 'Abonnements'   : 'Following';
  String get feedPronostics => _lang == 'fr' ? 'Pronostics'    : 'Pronostics';
  String get feedVip        => 'Zone VIP';
  String get feedCanal      => _lang == 'fr' ? 'Canaux'        : 'Channels';
  String get feedSport      => _lang == 'fr' ? 'Sport'         : 'Sport';
  String get feedLooks      => 'Looks';
  String get feedSuggestions => _lang == 'fr' ? 'Suggestions'  : 'Suggestions';

  // ── Onglets de la page d'accueil ──────────────────────────────────────────
  String get tabHome        => _lang == 'fr' ? '🏠 Accueil'     : '🏠 Home';
  String get tabSport       => '⚽ Sport';
  String get tabVibe        => _lang == 'fr' ? '📱 Vibe vidéos' : '📱 Vibe videos';
  String get tabEvents      => _lang == 'fr' ? '📅 Événements'  : '📅 Events';
  String get tabVip         => _lang == 'fr' ? '🪙 Zone VIP'    : '🪙 VIP Zone';
  String get tabChallenges  => '🏆 Challenges';
  String get tabChroniques  => _lang == 'fr' ? '🌟 Chroniques'  : '🌟 Chronicles';
  String get tabPopular     => _lang == 'fr' ? '🔥 Populaires'  : '🔥 Popular';

  // ── Boutons communs ───────────────────────────────────────────────────────
  String get btnAccept      => _lang == 'fr' ? 'Accepter'       : 'Accept';
  String get btnRefuse      => _lang == 'fr' ? 'Refuser'        : 'Decline';
  String get btnSend        => _lang == 'fr' ? 'Envoyer'        : 'Send';
  String get btnSave        => _lang == 'fr' ? 'Enregistrer'    : 'Save';
  String get btnCancel      => _lang == 'fr' ? 'Annuler'        : 'Cancel';
  String get btnDelete      => _lang == 'fr' ? 'Supprimer'      : 'Delete';
  String get btnReply       => _lang == 'fr' ? 'Répondre'       : 'Reply';
  String get btnCreate      => _lang == 'fr' ? 'Créer'          : 'Create';
  String get btnViewProfile => _lang == 'fr' ? 'Voir mon profil': 'View my profile';

  // ── Chat ──────────────────────────────────────────────────────────────────
  String get chatMessage    => _lang == 'fr' ? 'Message...'     : 'Message...';
  String get chatRecording  => _lang == 'fr' ? 'Enregistrement' : 'Recording';
  String get chatReplyTo    => _lang == 'fr' ? 'Répondre à:'    : 'Reply to:';

  // ── Notifications ─────────────────────────────────────────────────────────
  String get notifTitle     => _lang == 'fr' ? 'Notifications'  : 'Notifications';
  String get notifMarkRead  => _lang == 'fr' ? 'Tout marquer comme lu' : 'Mark all as read';

  // ── Profil ────────────────────────────────────────────────────────────────
  String get profileTitle       => _lang == 'fr' ? 'Mon Profil'      : 'My Profile';
  String get amisTabFriends     => _lang == 'fr' ? 'Mes Amis'        : 'My Friends';
  String get profileInvites     => _lang == 'fr' ? 'Mes Invitations' : 'My Invitations';
  String get profileSubscribers => _lang == 'fr' ? 'abonné(s)'       : 'subscriber(s)';

  // ── Auth — Inscription ────────────────────────────────────────────────────
  String get authSignIn         => _lang == 'fr' ? 'Se connecter'           : 'Sign in';
  String get authSignUp         => _lang == 'fr' ? 'Créer un compte'        : 'Create account';
  String get authEmail          => _lang == 'fr' ? 'Adresse email'          : 'Email address';
  String get authPassword       => _lang == 'fr' ? 'Mot de passe'           : 'Password';
  String get authForgotPassword => _lang == 'fr' ? 'Mot de passe oublié ?'  : 'Forgot password?';
  String get authSlogan         => _lang == 'fr' ? 'Votre popularité est à la une' : 'Your popularity in the spotlight';
  String get authConnecting     => _lang == 'fr' ? 'Connexion...'           : 'Signing in...';
  String get authEmailInvalid   => _lang == 'fr' ? 'Adresse email invalide'  : 'Invalid email address';
  String get authEmailRequired  => _lang == 'fr' ? 'Veuillez entrer votre adresse email' : 'Please enter your email';
  String get authPasswordRequired => _lang == 'fr' ? 'Veuillez entrer votre mot de passe' : 'Please enter your password';
  String get authPasswordTooShort => _lang == 'fr' ? 'Le mot de passe doit contenir au moins 6 caractères' : 'Password must be at least 6 characters';
  String get authContact        => _lang == 'fr' ? 'Nous contacter'         : 'Contact us';
  String get authNeedHelp       => _lang == 'fr' ? 'Besoin d\'aide ?'        : 'Need help?';
  String get commonOr           => _lang == 'fr' ? 'Ou'                      : 'Or';

  // ── Auth — Inscription ────────────────────────────────────────────────────
  String get signupTitle        => _lang == 'fr' ? 'Inscription'            : 'Sign up';
  String get signupFirstName    => _lang == 'fr' ? 'Prénom'                 : 'First name';
  String get signupLastName     => _lang == 'fr' ? 'Nom'                    : 'Last name';
  String get signupPseudo       => _lang == 'fr' ? 'Pseudo'                 : 'Username';
  String get signupPhone        => _lang == 'fr' ? 'Téléphone'              : 'Phone';
  String get signupCountry      => _lang == 'fr' ? 'Pays'                   : 'Country';
  String get signupRegister     => _lang == 'fr' ? 'S\'inscrire'            : 'Register';
  String get signupAlreadyAccount => _lang == 'fr' ? 'Déjà un compte ?'     : 'Already have an account?';

  // ── Posts ─────────────────────────────────────────────────────────────────
  String get postLike           => _lang == 'fr' ? 'J\'aime'               : 'Like';
  String get postComment        => _lang == 'fr' ? 'Commenter'              : 'Comment';
  String get postShare          => _lang == 'fr' ? 'Partager'               : 'Share';
  String get postSave           => _lang == 'fr' ? 'Enregistrer'            : 'Save';
  String get postReport         => _lang == 'fr' ? 'Signaler'               : 'Report';
  String get postDelete         => _lang == 'fr' ? 'Supprimer'              : 'Delete';
  String get postEdit           => _lang == 'fr' ? 'Modifier'               : 'Edit';
  String get postViews          => _lang == 'fr' ? 'vues'                   : 'views';
  String get postComments       => _lang == 'fr' ? 'commentaires'           : 'comments';
  String get postLikes          => _lang == 'fr' ? 'j\'aime'                : 'likes';
  String get postSponsored      => _lang == 'fr' ? 'SPONSORISÉ'             : 'SPONSORED';
  String get postWriteComment   => _lang == 'fr' ? 'Écrire un commentaire...' : 'Write a comment...';
  String get postSuggestions    => _lang == 'fr' ? 'Suggestions'            : 'Suggestions';
  String get postPublish        => _lang == 'fr' ? 'Publier'                : 'Publish';
  String get postDescription    => _lang == 'fr' ? 'Description...'         : 'Description...';
  String get postAddMedia       => _lang == 'fr' ? 'Ajouter un média'       : 'Add media';

  // ── Pronostics ────────────────────────────────────────────────────────────
  String get pronoTitle         => _lang == 'fr' ? '⚽ Pronostics du moment' : '⚽ Current Predictions';
  String get pronoPlay          => _lang == 'fr' ? 'Jouer maintenant'       : 'Play now';
  String get pronoOpen          => _lang == 'fr' ? 'OUVERT'                 : 'OPEN';
  String get pronoInProgress    => _lang == 'fr' ? 'EN COURS'               : 'IN PROGRESS';
  String get pronoJackpot       => _lang == 'fr' ? 'FCFA à partager'        : 'FCFA to share';
  String get pronoLoading       => _lang == 'fr' ? 'Jouez et gagnez jusqu\'à 50 000 FCFA' : 'Play and win up to 50,000 FCFA';

  // ── Dating ────────────────────────────────────────────────────────────────
  String get datingTitle        => 'AfroLove';
  String get datingSubtitle     => _lang == 'fr' ? 'Des profils qui pourraient vous correspondre' : 'Profiles that might match you';
  String get datingSeeMore      => _lang == 'fr' ? 'Voir plus'              : 'See more';
  String get datingMeetLove     => _lang == 'fr' ? '✨ Rencontrer l\'amour ✨' : '✨ Find love ✨';

  // ── Zone VIP ──────────────────────────────────────────────────────────────
  String get vipSeeMore         => _lang == 'fr' ? 'Voir plus'              : 'See more';
  String get vipNew             => _lang == 'fr' ? 'Nouveautés'             : 'New';
  String get vipFree            => _lang == 'fr' ? 'Gratuit'                : 'Free';
  String get vipSeries          => _lang == 'fr' ? 'Série'                  : 'Series';
  String get vipEbook           => 'Ebook';
  String get vipVideo           => _lang == 'fr' ? 'Vidéo'                  : 'Video';

  // ── Canaux ────────────────────────────────────────────────────────────────
  String get canalSubscribe     => _lang == 'fr' ? 'S\'abonner'             : 'Subscribe';
  String get canalSubscribed    => _lang == 'fr' ? 'Abonné'                 : 'Subscribed';
  String get canalMembers       => _lang == 'fr' ? 'membres'                : 'members';

  // ── Sections de la page d'accueil ───────────────────────────────────────
  String get sectionBoostedProducts  => _lang == 'fr' ? '🔥 Produits Boostés'     : '🔥 Boosted Products';
  String get sectionDiscoverProfiles => _lang == 'fr' ? '👑 Profils à découvrir'  : '👑 Profiles to discover';
  String get sectionAfrolookCanal    => _lang == 'fr' ? '📺 Afrolook Canal'       : '📺 Afrolook Channel';
  String get sectionBoutiques        => _lang == 'fr' ? 'Boutiques'              : 'Shops';
  String get menuMyChroniques        => _lang == 'fr' ? 'Mes chroniques'         : 'My chronicles';
  String get menuCanaux              => _lang == 'fr' ? 'Canaux'                 : 'Channels';

  // ── Menu latéral (suite) ──────────────────────────────────────────────────
  String get menuDarkMode            => _lang == 'fr' ? 'Mode sombre'            : 'Dark mode';
  String get menuLightMode           => _lang == 'fr' ? 'Mode clair'             : 'Light mode';
  String get menuLanguage            => _lang == 'fr' ? 'Langue'                 : 'Language';
  String get menuSearchUsers         => _lang == 'fr' ? 'Rechercher un utilisateur' : 'Search users';
  String get menuProfile             => _lang == 'fr' ? 'Profil'                 : 'Profile';
  String get menuTopPostsMonth       => _lang == 'fr' ? 'Meilleurs Posts du mois' : 'Top Posts of the Month';
  String get menuFriends             => _lang == 'fr' ? 'Amis'                   : 'Friends';
  String get menuMarketing           => _lang == 'fr' ? 'Marketing'              : 'Marketing';
  String get menuTopStars            => _lang == 'fr' ? 'TOP 10 Afrolooks Stars' : 'TOP 10 Afrolook Stars';
  String get menuPronosticsBetting   => _lang == 'fr' ? 'Pronostics & Betting'   : 'Predictions & Betting';
  String get menuFavorites           => _lang == 'fr' ? 'Mes favoris'            : 'My favorites';
  String get menuServicesJobs        => _lang == 'fr' ? '🛠️Services & Jobs 💼'   : '🛠️Services & Jobs 💼';
  String get menuServicesJobsSubtitle => _lang == 'fr' ? 'Chercher des gens pour bosser' : 'Find people to work with';
  String get menuAfroshopMarket      => _lang == 'fr' ? 'Afroshop Market'        : 'Afroshop Market';
  String get menuAfroCoinMarket      => _lang == 'fr' ? 'AfroCoin Market'        : 'AfroCoin Market';
  String get menuMyLives             => _lang == 'fr' ? 'Mes lives'              : 'My lives';
  String get menuMyChallenges        => _lang == 'fr' ? 'Mes challenges'         : 'My challenges';
  String get menuNewsInfo            => _lang == 'fr' ? 'Actus & Infos AfroLook' : 'AfroLook News & Info';
  String get menuContacts            => _lang == 'fr' ? 'Nos Contactes'          : 'Our Contacts';
  String get menuShareApp            => _lang == 'fr' ? 'Partager l\'application' : 'Share the app';
  String get menuLogout              => _lang == 'fr' ? 'Déconnecter'            : 'Log out';

  // ── Profil ────────────────────────────────────────────────────────────────
  String get profileFollow      => _lang == 'fr' ? 'Suivre'                 : 'Follow';
  String get profileFollowing   => _lang == 'fr' ? 'Abonné'                 : 'Following';
  String get profileMessage     => _lang == 'fr' ? 'Message'                : 'Message';
  String get profilePosts       => _lang == 'fr' ? 'Publications'           : 'Posts';
  String get profileFollowers   => _lang == 'fr' ? 'Abonnés'               : 'Followers';
  String get profileFriends     => _lang == 'fr' ? 'Amis'                   : 'Friends';
  String get profilePopularity  => _lang == 'fr' ? 'Popularité'             : 'Popularity';
  String get profileReferrals   => _lang == 'fr' ? 'Parrainages'            : 'Referrals';
  String get profileLikes       => _lang == 'fr' ? 'Likes profil'           : 'Profile likes';
  String get profileInvite      => _lang == 'fr' ? 'Inviter'                : 'Invite';
  String get profileInviteSent  => _lang == 'fr' ? 'Invitation envoyée'     : 'Invitation sent';
  String get profileSubscribe   => _lang == 'fr' ? 'S\'abonner'             : 'Subscribe';
  String get profileSubscribed  => _lang == 'fr' ? 'Abonné'                 : 'Subscribed';
  String get profileSeeFullProfile => _lang == 'fr' ? 'Voir le profil complet' : 'See full profile';
  String get profileLiked       => _lang == 'fr' ? 'Aimé'                   : 'Liked';
  String get profileLike        => _lang == 'fr' ? 'Like'                   : 'Like';
  String get profilePleaseWait  => _lang == 'fr' ? 'Patientez...'           : 'Please wait...';
  String get profileDefaultUser => _lang == 'fr' ? 'Utilisateur'            : 'User';
  String get profileLikeError   => _lang == 'fr' ? 'Erreur lors du like'    : 'Error while liking';

  // ── Splash / Chargement ───────────────────────────────────────────────────
  String get splashInit         => _lang == 'fr' ? 'Initialisation...'      : 'Initializing...';
  String get splashLoading      => _lang == 'fr' ? 'Chargement des données...' : 'Loading data...';
  String get splashConnecting   => _lang == 'fr' ? 'Connexion...'           : 'Connecting...';
  String get splashError        => _lang == 'fr' ? 'Une erreur est survenue' : 'An error occurred';
  String get splashGoBack       => _lang == 'fr' ? 'Retour à l\'accueil'    : 'Back to home';
  String get splashContentReady => _lang == 'fr' ? 'Contenu prêt !'        : 'Content ready!';
  String get splashRedirecting  => _lang == 'fr' ? 'Redirection...'         : 'Redirecting...';
  String get splashLoadingContent => _lang == 'fr' ? 'Chargement du contenu...' : 'Loading content...';

  // ── Commun ────────────────────────────────────────────────────────────────
  String get commonCancel       => _lang == 'fr' ? 'Annuler'                : 'Cancel';
  String get commonConfirm      => _lang == 'fr' ? 'Confirmer'              : 'Confirm';
  String get commonOk           => 'OK';
  String get commonClose        => _lang == 'fr' ? 'Fermer'                 : 'Close';
  String get commonSave         => _lang == 'fr' ? 'Enregistrer'            : 'Save';
  String get commonSend         => _lang == 'fr' ? 'Envoyer'                : 'Send';
  String get commonSearch       => _lang == 'fr' ? 'Rechercher'             : 'Search';
  String get commonSeeMore      => _lang == 'fr' ? 'Voir plus'              : 'See more';
  String get commonSeeLess      => _lang == 'fr' ? 'Voir moins'             : 'See less';
  String get commonLoading      => _lang == 'fr' ? 'Chargement...'          : 'Loading...';
  String get commonError        => _lang == 'fr' ? 'Une erreur est survenue' : 'An error occurred';
  String get commonRetry        => _lang == 'fr' ? 'Réessayer'              : 'Retry';
  String get commonDelete       => _lang == 'fr' ? 'Supprimer'              : 'Delete';
  String get commonEdit         => _lang == 'fr' ? 'Modifier'               : 'Edit';
  String get commonYes          => _lang == 'fr' ? 'Oui'                    : 'Yes';
  String get commonNo           => _lang == 'fr' ? 'Non'                    : 'No';
  String get commonNoContent    => _lang == 'fr' ? 'Aucun contenu'          : 'No content';
  String get commonSeeAll       => _lang == 'fr' ? 'Voir tout'              : 'See all';
  String get commonRefresh      => _lang == 'fr' ? 'Actualiser'             : 'Refresh';
  String get commonLoadingError => _lang == 'fr' ? 'Erreur de chargement'   : 'Loading error';

  // ── Langue ────────────────────────────────────────────────────────────────
  String get langFrench         => _lang == 'fr' ? 'Français'               : 'French';
  String get langEnglish        => _lang == 'fr' ? 'Anglais'                : 'English';
  String get langChoose         => _lang == 'fr' ? 'Choisir la langue'      : 'Choose language';

  // ── Thème ─────────────────────────────────────────────────────────────────
  String get themeDark          => _lang == 'fr' ? 'Mode sombre'            : 'Dark mode';
  String get themeLight         => _lang == 'fr' ? 'Mode clair'             : 'Light mode';

  // ── Feed Sport : filtres & soutien ──────────────────────────────────────────
  String get feedFilterByCountry => _lang == 'fr' ? '🌍 Filtrer par pays'    : '🌍 Filter by country';
  String get feedSearchCountry   => _lang == 'fr' ? 'Rechercher un pays...' : 'Search for a country...';
  String get feedAllFilter       => _lang == 'fr' ? 'Tous'                  : 'All';
  String get feedMyCountry       => _lang == 'fr' ? 'Mon pays'              : 'My country';
  String get feedMixFilter       => _lang == 'fr' ? 'Mix'                   : 'Mix';
  String get feedChooseCountry   => _lang == 'fr' ? 'Choisir un pays'       : 'Choose a country';
  String get feedCountriesSuffix => _lang == 'fr' ? 'pays'                  : 'countries';
  String get feedNoCountryFound  => _lang == 'fr' ? 'Aucun pays trouvé'     : 'No country found';
  String get feedTryAnotherSearch => _lang == 'fr' ? 'Essayez une autre recherche' : 'Try another search';
  String get feedYourCountry     => _lang == 'fr' ? 'Votre pays'            : 'Your country';
  String get feedChooseType      => _lang == 'fr' ? '📝 Choisir un type'    : '📝 Choose a type';
  String get feedSearchType      => _lang == 'fr' ? 'Rechercher un type...' : 'Search for a type...';
  String get feedAvailableTypes  => _lang == 'fr' ? 'Types disponibles'     : 'Available types';
  String get feedTypesSuffix     => _lang == 'fr' ? 'types'                 : 'types';
  String get feedFilterLabel     => _lang == 'fr' ? 'Filtre'                : 'Filter';
  String get feedCountryLabel    => _lang == 'fr' ? 'Pays'                  : 'Country';
  String get feedOtherFilter     => _lang == 'fr' ? 'Autre'                 : 'Other';

  String get supportTitle        => _lang == 'fr' ? 'Soutenez Afrolook !'   : 'Support Afrolook!';
  String get supportMessage      => _lang == 'fr'
      ? 'Chers membres, Afrolook grandit grâce à vous ! 🌍\n\n'
          'Chaque publicité que vous regardez nous rapporte un petit revenu. Cela nous permet de :\n'
          '• Améliorer l\'application et ajouter de nouvelles fonctionnalités\n'
          '• Maintenir des serveurs stables pour une expérience fluide\n'
          '• Continuer à vous offrir du contenu de qualité gratuitement\n'
          '• Rémunérer les créateurs de contenu que vous aimez !\n\n'
          'Ce n\'est pas obligatoire, mais votre soutien est précieux. Merci d\'avance ! 🙏'
      : 'Dear members, Afrolook grows thanks to you! 🌍\n\n'
          'Every ad you watch earns us a little revenue. This allows us to:\n'
          '• Improve the app and add new features\n'
          '• Keep stable servers for a smooth experience\n'
          '• Keep offering you quality content for free\n'
          '• Pay the content creators you love!\n\n'
          'It\'s not mandatory, but your support is precious. Thanks in advance! 🙏';
  String get supportBecomePremium => _lang == 'fr' ? 'Devenez Premium'      : 'Become Premium';
  String get supportPremiumPrice  => _lang == 'fr' ? '200 F/mois 😊 • Plus aucune publicité' : '200 F/month 😊 • No more ads';
  String get supportPremiumDesc   => _lang == 'fr' ? 'Soutenez directement les créateurs de contenu !' : 'Directly support content creators!';
  String get supportWatchAd       => _lang == 'fr' ? 'Regarder la pub'      : 'Watch the ad';
  String get supportThankYouAd    => _lang == 'fr' ? 'Merci d\'avoir regardé la publicité ! Votre soutien est précieux.' : 'Thanks for watching the ad! Your support is precious.';
  String get feedPostButton       => _lang == 'fr' ? 'Poster'               : 'Post';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
