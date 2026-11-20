# SwiftUI — PokéApp

Projet SwiftUI avec cinq cibles :

| Cible | Plateforme | Rôle |
|---|---|---|
| `AlexisAsya` | iOS | App Pokémon d'origine (recherche, filtres, favoris) |
| `AlexisAsyaWidget` | iOS 17+ | Widgets écran d'accueil et écran verrouillé |
| `AlexisAsyaWatch` | watchOS 10+ | App Watch : Pokémon aléatoire, recherche (nom/n° + type), fiche détail (stats, capacités, taille, poids, EXP), favoris locaux |
| `AlexisAsyaWatchComplication` | watchOS 10+ | Widget / complication pour le cadran de la montre |
| `AlexisAsyaTests` | iOS | Tests unitaires (anti-double-clic, favoris, filtres, concurrence) |

## Nom et icône

Sur l'écran d'accueil (iPhone et Watch), l'app s'appelle **PokéApp** : `INFOPLIST_KEY_CFBundleDisplayName` est défini dans les configurations Debug/Release des cibles `AlexisAsya` et `AlexisAsyaWatch`. Le nom technique (`PRODUCT_NAME`, schéma Xcode) reste `AlexisAsya`, et le bundle identifier `com.AA.AlexisAsya`.

L'icône est un Pokéball généré localement : `AppIcon.png` (1024 × 1024, opaque) dans `AlexisAsya/Assets.xcassets/AppIcon.appiconset` et `AlexisAsyaWatch/Assets.xcassets/AppIcon.appiconset`.

## Lancer l'app sur le simulateur Apple Watch

1. Accepter la licence Xcode (une seule fois, avec droits admin) :

   ```bash
   sudo xcodebuild -license accept
   ```

2. Installer le runtime watchOS si nécessaire : `Xcode › Settings › Components › watchOS …`, ou :

   ```bash
   xcodebuild -downloadPlatform watchOS
   ```

3. Ouvrir `AlexisAsya.xcodeproj`.
4. Sélectionner le schéma **`AlexisAsyaWatch`**.
5. Choisir un simulateur Apple Watch (par ex. *Apple Watch Series 10 — 42 mm*) dans la liste des destinations.
6. Appuyer sur `Cmd + R`.

La complication se teste en lançant le schéma **`AlexisAsyaWatchComplication`**, ou en installant l'app Watch puis en personnalisant un cadran (appui long sur le cadran › Personnaliser › Complications › PokéApp).

## Ce que fait la complication

Le widget fournit trois familles de complications :

- `.accessoryCircular` — Pokémon + icône
- `.accessoryRectangular` — nom, numéro et type
- `.accessoryInline` — version texte pour les cadrans compacts

La timeline est générée localement (8 entrées, renouvelées toutes les 30 minutes) : aucun réseau ni permission n'est nécessaire pour le widget. L'app Watch, elle, récupère un Pokémon aléatoire via l'API PokeAPI avec un Pokémon de secours hors-ligne.

## Fiche Pokémon sur l'Apple Watch

La fiche détail — accessible depuis un résultat de recherche ou en touchant la carte d'accueil — affiche désormais les **mêmes informations que l'iPhone** :

- **Taille**, **poids** et **expérience de base** ;
- **6 statistiques** (PV, ATQ, DÉF, ATQ SPÉ, DÉF SPÉ, VIT) avec barres colorées selon le type du Pokémon ;
- **Capacités**, avec la mention *(cachée)* pour les talents cachés.

Les champs sont décodés depuis PokeAPI (`base_stat`, `base_experience`, `is_hidden`). Le Pokémon de secours hors-ligne (Pikachu) contient déjà toutes ces valeurs : la fiche reste donc complète même sans réseau. La carte d'accueil est maintenant un lien vers cette fiche.

## Widgets sur l'iPhone

La cible **`AlexisAsyaWidget`** fournit cinq familles :

- `.systemSmall` et `.systemMedium` — écran d'accueil (dégradé à la couleur du type) ;
- `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` — écran verrouillé.

Chaque entrée affiche désormais :

- la **vraie image officielle** du Pokémon (téléchargée depuis PokeAPI puis réduite à 200 × 200 px) ;
- les **6 statistiques** (PV, ATQ, DÉF, ATQ SPÉ, DÉF SPÉ, VIT) avec barres de progression — 2 barres en petit format, 3 en moyen ;
- les **capacités** (2 premières) ;
- la **taille**, le **poids** et l'**expérience de base** (format moyen) ;
- les types avec leurs noms français, le numéro et la meilleure stat (format circulaire / inline).

Le rendu est immédiat grâce à **8 Pokémon de secours complets** (stats, capacités, couleurs). Le provider enrichit ensuite ces entrées via PokeAPI ; si le réseau échoue, le widget reste lisible avec la Pokéball dessinée en SwiftUI à la place de la photo. Aucune permission n'est nécessaire.

Pour l'ajouter sur le simulateur : lancer le schéma **`AlexisAsya`** (le widget est embarqué dans `AlexisAsya.app/PlugIns/AlexisAsyaWidget.appex`), puis appui long sur l'écran d'accueil › **+** › rechercher **PokéApp**. Pour l'écran verrouillé : personnaliser le cadran › ajouter le widget PokéApp.

⚠️ **Important si vous compilez en ligne de commande :** ne désactivez pas la signature (`CODE_SIGNING_ALLOWED=NO`). Une extension non signée est bien détectée par `pluginkit`, mais `chronod` ne parvient pas à la lancer (`LaunchServicesDataMismatch`) et la galerie affiche un écran noir. Utilisez une signature ad-hoc :

```bash
xcodebuild -project AlexisAsya.xcodeproj -scheme AlexisAsya \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- \
  build
```

La timeline commence volontairement 60 secondes dans le passé : une première entrée datée de « maintenant » peut être considérée comme absente par WidgetKit et provoquer le même écran de chargement.

### 💥« SpringBoard a quitté de manière imprévue » sur le simulateur

Sur iOS 26 Simulator, l'ouverture de la galerie de widgets peut faire crasher **SpringBoard lui-même** (`EXC_BAD_ACCESS` dans `SpringBoardHome → -[SBHRippleSimulation clear]`), même avec les widgets d'Apple. Le simulateur affiche alors un écran noir de chargement avant de rouvrir l'écran d'accueil : ce n'est **pas** un bug de l'extension. `Réduire les animations` et le flag `SBH_HOME_WIDGET_RIPPLE_ANIMATION` ne contournent pas le problème. Pour valider le rendu, utilisez le `#Preview(as:)` de `PokemonWidget.swift` dans Xcode, ou installez l'app sur un iPhone physique.

## Recherche sur la Watch

La barre de recherche est **tout en haut de la page d'accueil**, au-dessus du Pokémon aléatoire :

- dès la **première lettre**, les Pokémon dont le nom **commence** par cette lettre s'affichent directement sur la page (ex. `pik` → Pikachu) ; un chiffre filtre sur le numéro du Pokédex (`25`, `001`) ;
- chaque résultat affiche une **pastille de la couleur de son type** à la place du numéro de série (rouge/orange pour `fire`, bleu pour `water`, jaune pour `electric`…) ; les 18 types sont chargés en arrière-plan et mis en cache ;
- le **filtre par type** reste disponible juste sous la barre (les 18 types, comme sur l'iPhone) ; la liste des Pokémon du type est récupérée depuis PokeAPI ;
- un appui sur un résultat ouvre sa fiche (image, types, stats, capacités, ajout aux favoris) ;
- les listes (noms et types) sont mises en cache dans `UserDefaults` : la recherche fonctionne ensuite hors-ligne.

## Authentification (Firebase)

L'app affiche un **écran de connexion** tant qu'aucun utilisateur n'est connecté (`AlexisAsya/view/LoginView.swift`) :

- **E-mail / mot de passe** : inscription (`Créer un compte`) et connexion ;
- **Continuer avec Google** : connexion via le flux OAuth web officiel de Firebase Auth (`OAuthProvider(providerID: "google.com")`). Aucun SDK Google supplémentaire n'est nécessaire : le schéma d'URL `app-1-972791352558-ios-a2092bc11167ae02f1f7ff` est déclaré dans `Configuration/AlexisAsya-Info.plist`, fusionné avec l'`Info.plist` généré par Xcode ;
- **Continuer avec Apple** : bouton natif `ASAuthorizationAppleIDProvider` (`AlexisAsya/viewmodel/AppleSignInCoordinator.swift`). Le nonce est haché en SHA-256 pour Apple et transmis brut à Firebase (`OAuthProvider.credential(providerID: .apple, idToken:rawNonce:)`). La capability est déclarée dans `Configuration/AlexisAsya.entitlements` via `CODE_SIGN_ENTITLEMENTS` ;
- la session est **restaurée au lancement** (`restoreSession()`), et un bouton **Déconnexion** est disponible dans la barre du haut de la liste ;
- **les favoris sont propres à chaque compte** : `PokemonFavoriteViewModel(userID: uid)` lit/écrit dans `UserDefaults` sous `pokeapp.favorites.<uid>`. Changer de compte recrée le view model (`onChange(of: authViewModel.user?.uid)` dans `AbApp.swift`), donc les favoris de l'utilisateur précédent ne sont jamais affichés. Sans compte (tests), les favoris restent uniquement en mémoire.

Côté projet :

- dépendances SPM **`FirebaseCore` + `FirebaseAuth`** sur la cible `AlexisAsya`, figées en **12.19.3** (la 13.2.0 télécharge un binaire `grpc` invalide avec Xcode 26.3) ;
- `GoogleService-Info.plist` (projet `pokeapp-17bf6`, bundle `com.AA.AlexisAsya`) ajouté aux ressources de la cible iOS ;
- `FirebaseApp.configure()` est appelé dans l'`init()` de `AlexisAsya/app/AbApp.swift`, avant tout accès à `Auth.auth()` ;
- Analytics reste **désactivé** : il n'est pas nécessaire pour l'authentification.

⚠️ **Pour tester le bouton Apple dans Xcode :** la signature ad-hoc utilisée en ligne de commande ne conserve pas l'entitlement `com.apple.developer.applesignin`. Il faut ouvrir le projet dans Xcode, sélectionner la cible `AlexisAsya` › **Signing & Capabilities** › choisir un **Team**, puis vérifier que la capability **Sign in with Apple** est présente. **Celle-ci exige un compte Apple Developer Program payant** : un *Personal Team* gratuit ne la propose pas. Sans cela, le bouton s'affiche mais la feuille Apple refusera de s'ouvrir. Les parcours **email** et **Google** fonctionnent, eux, sans Team.

### Conformité au TP (les 12 étapes demandées)

État vérifié dans le code **et** dans la console Firebase (interrogée par API) :

| Étape du TP | État | Détail |
|---|---|---|
| 1. Créer le projet Firebase + enregistrer l'app iOS | ✅ | Projet `pokeapp-17bf6`, app iOS enregistrée avec le bundle `com.AA.AlexisAsya` (identique à Xcode). Analytics désactivé, comme demandé. |
| 2. Ajouter `GoogleService-Info.plist` | ✅ | Nom exact, à la racine, cochée dans les ressources de la cible `AlexisAsya`. |
| 3. Installer le SDK via SPM | ✅ | `FirebaseCore` + `FirebaseAuth` sur la cible iOS ; `Cmd + B` compile. |
| 4. `FirebaseApp.configure()` dans `init()` | ✅ | `AlexisAsya/app/AbApp.swift`. |
| 5. Activer les 3 fournisseurs | ⚠️ | **Email/Password ✅** (l'API répond `WEAK_PASSWORD`) ; **Google ✅** (l'API renvoie une URL Google valide) ; **Apple ❌** (l'API répond `OPERATION_NOT_ALLOWED : Code flow is not enabled for Apple.`). |
| 6. `AuthManager` (`ObservableObject`) | ⚠️ | Voir « Choix techniques » ci-dessous. |
| 7. Écran de connexion (`AuthView`) | ✅ | `LoginView.swift` : champs en `@State`, boutons *Se connecter* / *Créer un compte* qui appellent bien le gestionnaire d'auth. |
| 8. `ContentView` racine + `HomeView` + déconnexion | ⚠️ | Aiguillage fait dans `AbApp.swift`, écran connecté = `ContentView.swift` (pas de `HomeView.swift`). Bouton **Déconnexion** présent et `signOut()` remet l'utilisateur à `nil`. L'**email de l'utilisateur n'est pas affiché** sur cet écran. |
| 9. GoogleSignIn-iOS + `-ObjC` + `REVERSED_CLIENT_ID` | ⚠️ | Voir « Choix techniques » : connexion Google fonctionnelle mais **sans** le SDK Google. |
| 10. Relier Google à Firebase | ✅ | `signInWithGoogle()` + `.onOpenURL { Auth.auth().canHandle($0) }` + `Auth.auth().signIn(with: credential)`. Parcours testé avec un vrai compte Google. |
| 11. Capability Sign in with Apple + config Firebase | ❌ | Capability **déclarée** dans `Configuration/AlexisAsya.entitlements` (`CODE_SIGN_ENTITLEMENTS`), mais aucun `DEVELOPMENT_TEAM` dans Xcode et aucun Service ID / Team ID / Key ID / clé privée renseignés côté Firebase. Le fournisseur Apple n'est donc pas activé. |
| 12. Nonce + credential Apple | ✅ | `AppleSignInCoordinator.swift` : nonce brut conservé, hash SHA-256 envoyé à Apple, `OAuthProvider.credential(providerID: .apple, idToken:rawNonce:)`. Non testable en l'état (voir étape 11). |

**Bilan : les parcours Email et Google sont réels et testés ; le parcours Apple est prêt côté code mais bloqué côté configuration.** Le TP prévoit explicitement ce cas : *« Prérequis : un compte Apple Developer Program payant. Sans lui, terminez Email + Google et revenez plus tard. »*

#### Choix techniques à expliquer au correcteur

- **Google sans le SDK `GoogleSignIn-iOS` (étapes 8 et 9).** Le `GoogleService-Info.plist` fourni est une version ancienne, sans `CLIENT_ID` ni `REVERSED_CLIENT_ID`. Plutôt que de retélécharger le fichier et d'ajouter un second package + le flag `-ObjC`, l'app utilise le **flux OAuth web officiel de Firebase Auth** : `OAuthProvider(providerID: "google.com").credential(with: nil)`. Le schéma d'URL déclaré, `app-1-972791352558-ios-a2092bc11167ae02f1f7ff`, est le callback Firebase (dérivé du `GOOGLE_APP_ID`), équivalent fonctionnel au `REVERSED_CLIENT_ID` pour ce flux. Résultat observé : le sélecteur de compte Google s'ouvre et l'utilisateur est bien connecté dans Firebase.
- **`@Observable` plutôt que `ObservableObject` (étape 6).** API d'observation SwiftUI moderne (iOS 17+), équivalent à `ObservableObject`/`@Published`. Les trois propriétés demandées sont présentes dans `AuthViewModel` : `user`, `isAuthenticated`, `errorMessage`. `LoginView` reçoit le gestionnaire via `@Bindable`, l'écran principal via `@Environment`.
- **`Firebase` figé en 12.19.3 (étape 3).** La version 13.2.0 échoue à l'installation sous Xcode 26.3 avec `downloaded archive of binary target 'grpcpp' ... does not contain a binary artifact.` La 12.19.3 est la dernière version compatible avec cet environnement.
- **Favoris par compte (bonus hors TP).** `PokemonFavoriteViewModel(userID: uid)` stocke les favoris sous `pokeapp.favorites.<uid>` ; changer de compte recrée le view model, donc les favoris d'un autre utilisateur ne sont jamais affichés.
- **Concurrence corrigée.** `PokemonListViewModel` est annoté `@MainActor` : le préchargement des types en tâche de fond et `cacheTypes(for:)` n'écrivent plus le même dictionnaire en parallèle (cela provoquait un `SIGABRT` aléatoire). Les requêtes réseau restent parallèles via une fonction `nonisolated` avec son propre client `PokemonAPI`.

## Tests & résistance aux clics multiples

Deux garde-fous sont partagés entre l'iPhone et la Watch (`Shared/ActionGuard.swift`) :

- **`DebouncedAction`** — une action répétée dans une fenêtre de 0,35 s n'est exécutée qu'une fois. La fenêtre est **par clé** (identifiant du Pokémon), donc deux Pokémon différents tapés rapidement ne se bloquent pas mutuellement. Protège le bouton favori (iPhone et Watch).
- **`SingleFlightAction`** — ignore tout nouvel appel tant que le précédent n'est pas terminé. Protège les chargements réseau : liste, types, fiche détaillée, Pokémon aléatoire.

Corrections associées :

- l'icône étoile de `PokemonView` lit désormais directement `favoriteViewModel.isFavorite(...)` au lieu d'un `@State` local qui pouvait se désynchroniser lors de tapes rapides ;
- **ouverture/fermeture en boucle** : la cible iOS avait `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, ce qui rendait le `deinit` de toutes les classes (view models, gardes) `@MainActor`. Sur le runtime iOS 26.3, ce saut d'exécuteur plantait avec `malloc: pointer being freed was not allocated`, et l'app se relançait à chaque tap. Ce réglage a été retiré ; `DebouncedAction` est également devenu un `struct` pour supprimer tout `deinit` de classe inutile. Les vues SwiftUI, elles, restent sur le thread principal.

La cible **`AlexisAsyaTests`** contient les tests correspondants :

| Fichier | Ce qui est vérifié |
|---|---|
| `DebouncedActionTests.swift` | 8 tests : premier clic, 10 clics rapides = 1, valeurs de retour, limites de la fenêtre, `reset`, clés indépendantes |
| `SingleFlightActionTests.swift` | 4 tests : appels concurrents fusionnés, drapeau `running`, nouvel appel après fin, appel pendant une tâche en cours |
| `PokemonFavoriteViewModelTests.swift` | 7 tests : doublons, 10 tapes rapides, même ID, Pokémon distincts, suppression, état, second clic après délai |
| `PokemonListFilterTests.swift` | 8 tests : préfixe, casse/espaces, requête vide, aucun résultat, filtre par type, type absent, filtres combinés, appels répétés |
| `PerUserFavoritesTests.swift` | 1 test : favoris isolés entre deux UID Firebase, puis relus après recréation du view model |

Lancer les tests dans Xcode : sélectionner le schéma **`AlexisAsyaTests`** › `Cmd + U`. En ligne de commande :

```bash
xcodebuild -project AlexisAsya.xcodeproj -scheme AlexisAsyaTests \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- \
  test
```

Une réussite affiche `Executed 28 tests, with 0 failures` puis `** TEST SUCCEEDED **`.

Pour retrouver les résultats :

- dans Xcode : **`⌘ + 9`** (Report navigator) › session *Test AlexisAsyaTests*, ou **`⌘ + 6`** pour les pastilles vertes/rouges par test ;
- le rapport natif est un `.xcresult` dans `~/Library/Developer/Xcode/DerivedData/AlexisAsya-…/Logs/Test/` ;
- pour obtenir un fichier texte sur le Bureau, ajoute `| tee ~/Desktop/PokeApp-tests.log` à la commande ci-dessus.

## Fichiers ajoutés

```
Shared/
  ActionGuard.swift               DebouncedAction + SingleFlightAction (iPhone & Watch)

AlexisAsya/
  viewmodel/AuthViewModel.swift        session Firebase (email, Google, Apple, déconnexion)
  viewmodel/AppleSignInCoordinator.swift  bouton natif Apple + nonce SHA-256
  view/LoginView.swift                 écran de connexion

AlexisAsyaTests/
  DebouncedActionTests.swift      tests de l'anti-double-clic
  SingleFlightActionTests.swift   tests du garde anti-concurrence
  PokemonFavoriteViewModelTests.swift
  PokemonListFilterTests.swift
  PerUserFavoritesTests.swift     isolation des favoris par compte

AlexisAsyaWidget/
  PokemonWidgetBundle.swift       @main du widget iOS
  PokemonWidget.swift             provider, timeline et vues (5 familles)
  WidgetPokemonData.swift         modèle, données de secours et récupération PokeAPI
Configuration/
  AlexisAsyaWidget-Info.plist     point d'extension WidgetKit (iOS)
  AlexisAsyaWatchComplication-Info.plist

AlexisAsyaWatch/
  AlexisAsyaWatchApp.swift        @main de l'app watchOS
  WatchPokemonView.swift          accueil, recherche, filtre par type, fiche détail (stats/capacités), favoris
  WatchPokemonService.swift       modèle enrichi, recherche, cache et chargement réseau
  Assets.xcassets/                icône et couleur d'accent

AlexisAsyaWatchComplication/
  PokemonComplicationBundle.swift @main du widget
  PokemonComplication.swift       provider, timeline et vues
```
