<p align="center">
  <img src="https://github.com/Noamcreator/jwlife/blob/main/assets/icons/jw_life.png?raw=true" alt="JW Life Logo" width="150">
</p>

# JW Life

JW Life est une application mobile développée avec Flutter pour enrichir la vie spirituelle d'un Témoin de Jéhovah.  
Ce projet propose une alternative moderne à JW Library, avec une interface fluide, une navigation intuitive et des outils supplémentaires adaptés au quotidien théocratique.

---

## ✨ Présentation

**JW Life** vise à :
- Corriger certains bugs et limitations rencontrés dans JW Library,
- Ajouter des fonctionnalités utiles et adaptées à la vie spirituelle,
- Offrir une interface agréable, moderne, et personnalisable,
- Rassembler tous les outils nécessaires à un Témoin de Jéhovah dans une seule application.

---

## 📱 Fonctionnalités principales

La structure de l'application (basée sur les dossiers dans `lib/features/`) suggère les fonctionnalités suivantes :

*   **Accueil (`home`)**: Tableau de bord principal.
*   **Audio (`audio`)**: Lecture de contenus audio.
*   **Bible (`bible`)**: Consultation et étude des Écritures.
*   **Vidéo (`video`)**: Visionnage de contenus vidéo.
*   **Bibliothèque (`library`)**: Accès aux publications et médias.
*   **Réunions (`meetings`)**: Gestion des programmes et notes.
*   **Personnel (`personal`)**: Contenus et organisation personnels.
*   **Prédication (`predication`)**: Outils pour l'activité de prédication.
*   **Publication (`publication`)**: Consultation des publications.
*   **Congrégation (`congregation`)**: Informations liées à la congrégation.
*   **Visionneuse d'images (`image_viewer`)**: Affichage d'images.
*   **Paramètres (`settings`)**:
    *   Personnalisation de l'apparence (plusieurs styles et thèmes clair/sombre/système).
    *   Réglages généraux et gestion des données.

*(Cette liste est déduite des noms de dossiers. D'autres fonctionnalités peuvent exister ou être en cours de développement.)*

---

## 🛠️ Tech Stack & Architecture

-   **Langage & Framework**: Dart & Flutter
-   **Gestion d'état**:
    *   `flutter_bloc` (basé sur la présence de `BlocProvider` dans `main.dart`) - pour la logique métier des fonctionnalités.
    *   `provider` (ajouté récemment) - notamment pour la gestion du thème.
-   **Base de données locale**:
    *   `sqflite`: Pour le stockage de données SQL structurées.
    *   `realm`: Une base de données mobile rapide et moderne.
    *   `shared_preferences`: Pour le stockage de préférences simples.
-   **Réseau**:
    *   `http`: Requêtes HTTP de base.
    *   `dio`: Client HTTP plus avancé.
    *   `connectivity_plus`: Vérification de la connectivité réseau.
-   **Médias**:
    *   `just_audio` & `just_audio_background`: Lecture audio avancée et en arrière-plan.
    *   `video_player`: Lecture vidéo.
    *   `palette_generator`: Extraction des couleurs dominantes d'une image.
-   **Interface Utilisateur & UX**:
    *   `flutter_svg`: Affichage d'images vectorielles SVG.
    *   `flutter_settings_ui`: Création d'écrans de paramètres (déduit de l'utilisation récente).
    *   `flutter_screenutil`: Adaptation de l'interface à différentes tailles d'écran (déduit de `main.dart`).
    *   `table_calendar`: Affichage de calendriers.
    *   `flutter_colorpicker`: Sélection de couleurs.
    *   `reorderables`: Listes et grilles réorganisables.
    *   `qr_flutter`: Génération de codes QR.
    *   `printing`: Fonctionnalités d'impression.
    *   `share_plus`: Partage de contenu.
    *   `flutter_inappwebview`: Intégration de vues web.
    *   `device_preview`: Test de l'UI sur différents appareils (déduit de `main.dart`).
-   **Utilitaires & Système**:
    *   `path_provider`: Accès aux chemins du système de fichiers.
    *   `file_picker`: Sélection de fichiers.
    *   `encrypt` & `crypto`: Chiffrement de données.
    *   `archive`: Gestion d'archives (ex: ZIP).
    *   `permission_handler`: Gestion des permissions.
    *   `url_launcher`: Ouverture d'URLs.
    *   `package_info_plus` & `device_info_plus`: Informations sur l'application et l'appareil.
    *   `app_settings`: Ouverture des paramètres de l'application.
    *   `flutter_local_notifications`: Affichage de notifications locales.
-   **Internationalisation**: `intl` (et probablement `slang` basé sur tes usages précédents).
-   **Développement & Analyse**:
    *   `sentry_flutter`: Suivi des erreurs et crashs (déduit de `main.dart`).
    *   `flutter_lints`: Analyse statique du code.

**Architecture Générale**:
-   **Structure modulaire par fonctionnalités** (dossier `lib/features/`).
-   Utilisation de l'**injection de dépendances** (confirmé par la présence de `get_it` dans `main.dart`).
-   Séparation des préoccupations avec des dossiers comme `core`, `data`, `app`.

---

## 📂 Structure du Projet

Le code source principal se trouve dans `lib/` et est organisé comme suit :

*   `main.dart`: Point d'entrée de l'application.
*   `app/`: Configuration de l'application, routage (probablement avec `auto_route`), services globaux.
*   `core/`: Éléments transversaux (injection de dépendances, gestion de thèmes, utilitaires).
*   `data/`: Sources de données, modèles, repositories (utilisant Realm, Sqflite).
*   `features/`: Chaque sous-dossier représente une fonctionnalité principale (ex: `bible`, `settings`).
*   `i18n/`: Fichiers pour l'internationalisation.
*   `widgets/`: Widgets réutilisables.
*   `generated/`: Code généré automatiquement (par exemple, par `slang` ou des outils de routage).

---

## 🎯 Objectifs du projet

- ✅ Expérience utilisateur fluide
- ✅ Interface propre et moderne
- ✅ Outils utiles et pratiques pour les activités spirituelles
- ✅ Application libre, open-source et extensible

---

## 🚧 Prochaines améliorations

- 🧠 Suggestions d’étude contextuelles
- 📅 Intégration du calendrier de prédication
- 🔔 Notifications personnalisées
- 🌍 Mode en ligne plus avancé

---

## 🛠️ Installation et Lancement

1.  **Prérequis**:
    *   [Flutter SDK](https://flutter.dev/docs/get-started/install) installé.
    *   Un éditeur comme VS Code ou Android Studio.

2.  **Cloner le dépôt**:
    ```bash
    git clone https://github.com/Noamcreator/jwlife.git
    cd jwlife
    ```

3.  **Installer les dépendances**:
    ```bash
    flutter pub get
    ```

4.  **(Si nécessaire) Configurer les services externes**:
    *   Si Firebase est utilisé (par exemple pour Analytics, Remote Config, Sentry), assurez-vous que les fichiers `google-services.json` (Android) et `GoogleService-Info.plist` (iOS) sont correctement configurés.

5.  **Générer les fichiers de code** (si vous utilisez `build_runner` pour des packages comme `auto_route`, `freezed`, `slang`, etc.):
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
    *(Cette étape pourrait être nécessaire après avoir récupéré les dépendances ou après avoir modifié des fichiers qui déclenchent la génération de code.)*

6.  **Lancer l'application**:
    ```bash
    flutter run
    ```

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1.  Forkez le projet.
2.  Créez une branche pour votre fonctionnalité (`git checkout -b feature/NomDeLaFonctionnalite`).
3.  Commitez vos changements (`git commit -am 'Ajout de la fonctionnalité X'`).
4.  Pushez vers la branche (`git push origin feature/NomDeLaFonctionnalite`).
5.  Ouvrez une Pull Request.

Veuillez vous assurer que votre code respecte les conventions du projet et inclut les tests pertinents si applicable.

---

## 📄 Licence

(À PRÉCISER - Par exemple : Ce projet est sous licence MIT. Voir le fichier `LICENSE.md` pour plus de détails.)

