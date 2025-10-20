import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'i18n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @action_no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get action_no;

  /// No description provided for @action_yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get action_yes;

  /// No description provided for @action_ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get action_ok;

  /// No description provided for @action_off.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get action_off;

  /// No description provided for @action_on.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get action_on;

  /// No description provided for @action_accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get action_accept;

  /// No description provided for @action_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get action_add;

  /// No description provided for @action_back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get action_back;

  /// No description provided for @action_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get action_cancel;

  /// No description provided for @action_close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get action_close;

  /// No description provided for @action_save.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get action_save;

  /// No description provided for @action_download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get action_download;

  /// No description provided for @action_next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get action_next;

  /// No description provided for @action_sign_out.
  ///
  /// In fr, this message translates to:
  /// **'Deconnexion'**
  String get action_sign_out;

  /// No description provided for @action_sign_in.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get action_sign_in;

  /// No description provided for @action_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get action_delete;

  /// No description provided for @search_hint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get search_hint;

  /// No description provided for @import_jwpub.
  ///
  /// In fr, this message translates to:
  /// **'Importer JWPUB'**
  String get import_jwpub;

  /// No description provided for @login_title.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à JW Life'**
  String get login_title;

  /// No description provided for @login_create_account_title.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get login_create_account_title;

  /// No description provided for @login_name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get login_name;

  /// No description provided for @login_email.
  ///
  /// In fr, this message translates to:
  /// **'Adresse mail'**
  String get login_email;

  /// No description provided for @login_password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get login_password;

  /// No description provided for @login_phone.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get login_phone;

  /// No description provided for @login_sign_in.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get login_sign_in;

  /// No description provided for @login_dont_have_account.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de compte ?'**
  String get login_dont_have_account;

  /// No description provided for @login_create_account.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get login_create_account;

  /// No description provided for @login_forgot_password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get login_forgot_password;

  /// No description provided for @login_password_reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get login_password_reset;

  /// No description provided for @login_password_message_reset_email.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre adresse mail pour les instructions de réinitialisation du mot de passe'**
  String get login_password_message_reset_email;

  /// No description provided for @login_email_verification.
  ///
  /// In fr, this message translates to:
  /// **'Vérification de l\'adresse mail'**
  String get login_email_verification;

  /// No description provided for @login_email_message_verification.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez verifier votre adresse mail pour pouvoir vous connecter'**
  String get login_email_message_verification;

  /// No description provided for @login_error_title.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get login_error_title;

  /// No description provided for @login_error_message_email_password_required.
  ///
  /// In fr, this message translates to:
  /// **'Entrer une adresse mail et un mot de passe'**
  String get login_error_message_email_password_required;

  /// No description provided for @login_error_message_email_required.
  ///
  /// In fr, this message translates to:
  /// **'Entrer une adresse mail'**
  String get login_error_message_email_required;

  /// No description provided for @login_error_message_password_required.
  ///
  /// In fr, this message translates to:
  /// **'Entrer un mot de passe'**
  String get login_error_message_password_required;

  /// No description provided for @login_error_message.
  ///
  /// In fr, this message translates to:
  /// **'Adresse mail ou mot de passe incorrect'**
  String get login_error_message;

  /// No description provided for @navigation_home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navigation_home;

  /// No description provided for @navigation_bible.
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get navigation_bible;

  /// No description provided for @navigation_library.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get navigation_library;

  /// No description provided for @navigation_workship.
  ///
  /// In fr, this message translates to:
  /// **'Culte'**
  String get navigation_workship;

  /// No description provided for @navigation_predication.
  ///
  /// In fr, this message translates to:
  /// **'Prédication'**
  String get navigation_predication;

  /// No description provided for @navigation_congregations.
  ///
  /// In fr, this message translates to:
  /// **'Assemblées locales'**
  String get navigation_congregations;

  /// No description provided for @navigation_personal.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get navigation_personal;

  /// No description provided for @navigation_settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navigation_settings;

  /// No description provided for @navigation_daily_text.
  ///
  /// In fr, this message translates to:
  /// **'Texte du jour'**
  String get navigation_daily_text;

  /// No description provided for @navigation_favorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get navigation_favorites;

  /// No description provided for @navigation_workship_assembly_br.
  ///
  /// In fr, this message translates to:
  /// **'Assemblées de circonscription avec un représentant de la filiale'**
  String get navigation_workship_assembly_br;

  /// No description provided for @navigation_workship_assembly_co.
  ///
  /// In fr, this message translates to:
  /// **'Assemblées de circonscription avec le responsable de circonscription'**
  String get navigation_workship_assembly_co;

  /// No description provided for @navigation_workship_convention.
  ///
  /// In fr, this message translates to:
  /// **'Assemblée régionale'**
  String get navigation_workship_convention;

  /// No description provided for @navigation_workship_life_and_ministry.
  ///
  /// In fr, this message translates to:
  /// **'Réunion de semaine'**
  String get navigation_workship_life_and_ministry;

  /// No description provided for @navigation_workship_watchtower_study.
  ///
  /// In fr, this message translates to:
  /// **'Réunion du weekend'**
  String get navigation_workship_watchtower_study;

  /// No description provided for @navigation_predication_letters.
  ///
  /// In fr, this message translates to:
  /// **'Courriers'**
  String get navigation_predication_letters;

  /// No description provided for @navigation_predication_visits.
  ///
  /// In fr, this message translates to:
  /// **'Visites'**
  String get navigation_predication_visits;

  /// No description provided for @navigation_predication_bible_studies.
  ///
  /// In fr, this message translates to:
  /// **'Cours Bibliques'**
  String get navigation_predication_bible_studies;

  /// No description provided for @navigation_predication_report.
  ///
  /// In fr, this message translates to:
  /// **'Rapport de prédication'**
  String get navigation_predication_report;

  /// No description provided for @navigation_congregation_brothers_and_sisters.
  ///
  /// In fr, this message translates to:
  /// **'Frères et Soeurs'**
  String get navigation_congregation_brothers_and_sisters;

  /// No description provided for @navigation_congregation_events.
  ///
  /// In fr, this message translates to:
  /// **'Événements de l’Assemblée Locale'**
  String get navigation_congregation_events;

  /// No description provided for @navigation_personal_bible_reading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture de la Bible'**
  String get navigation_personal_bible_reading;

  /// No description provided for @navigation_personal_study.
  ///
  /// In fr, this message translates to:
  /// **'Étude individuelle'**
  String get navigation_personal_study;

  /// No description provided for @navigation_personal_predication_meetings.
  ///
  /// In fr, this message translates to:
  /// **'Réunions pour la prédication'**
  String get navigation_personal_predication_meetings;

  /// No description provided for @navigation_personal_prayers.
  ///
  /// In fr, this message translates to:
  /// **'Prières'**
  String get navigation_personal_prayers;

  /// No description provided for @navigation_personal_talks.
  ///
  /// In fr, this message translates to:
  /// **'Sujets'**
  String get navigation_personal_talks;

  /// No description provided for @navigation_personal_about_me.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get navigation_personal_about_me;

  /// No description provided for @navigation_ministry.
  ///
  /// In fr, this message translates to:
  /// **'Panoplie d’enseignant'**
  String get navigation_ministry;

  /// No description provided for @navigation_notes_and_tag.
  ///
  /// In fr, this message translates to:
  /// **'Notes et Catégories'**
  String get navigation_notes_and_tag;

  /// No description provided for @navigation_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Listes de lecture'**
  String get navigation_playlists;

  /// No description provided for @navigation_official_website.
  ///
  /// In fr, this message translates to:
  /// **'Site Web officiel'**
  String get navigation_official_website;

  /// No description provided for @navigation_online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get navigation_online;

  /// No description provided for @navigation_online_broadcasting.
  ///
  /// In fr, this message translates to:
  /// **'JW Télédiffusion'**
  String get navigation_online_broadcasting;

  /// No description provided for @navigation_online_donation.
  ///
  /// In fr, this message translates to:
  /// **'Dons'**
  String get navigation_online_donation;

  /// No description provided for @navigation_online_gitub.
  ///
  /// In fr, this message translates to:
  /// **'GitHub de JW Life'**
  String get navigation_online_gitub;

  /// No description provided for @navigation_online_library.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque en ligne'**
  String get navigation_online_library;

  /// No description provided for @navigation_publications.
  ///
  /// In fr, this message translates to:
  /// **'Publications'**
  String get navigation_publications;

  /// No description provided for @navigation_videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get navigation_videos;

  /// No description provided for @navigation_audios.
  ///
  /// In fr, this message translates to:
  /// **'Audios'**
  String get navigation_audios;

  /// No description provided for @navigation_download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get navigation_download;

  /// No description provided for @navigation_pending_updates.
  ///
  /// In fr, this message translates to:
  /// **'Mises à jour en attente'**
  String get navigation_pending_updates;

  /// No description provided for @navigation_pubs_by_type.
  ///
  /// In fr, this message translates to:
  /// **'Par catégorie'**
  String get navigation_pubs_by_type;

  /// No description provided for @navigation_whats_new.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get navigation_whats_new;

  /// No description provided for @pub_attributes_archive.
  ///
  /// In fr, this message translates to:
  /// **'PUBLICATIONS PLUS ANCIENNES'**
  String get pub_attributes_archive;

  /// No description provided for @pub_attributes_assembly_convention.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE RÉGIONALE ET DE CIRCONSCRIPTION'**
  String get pub_attributes_assembly_convention;

  /// No description provided for @pub_attributes_bethel.
  ///
  /// In fr, this message translates to:
  /// **'BÉTHEL'**
  String get pub_attributes_bethel;

  /// No description provided for @pub_attributes_circuit_assembly.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE DE CIRCONSCRIPTION'**
  String get pub_attributes_circuit_assembly;

  /// No description provided for @pub_attributes_circuit_overseer.
  ///
  /// In fr, this message translates to:
  /// **'RESPONSABLE DE CIRCONSCRIPTION'**
  String get pub_attributes_circuit_overseer;

  /// No description provided for @pub_attributes_congregation.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE LOCALE'**
  String get pub_attributes_congregation;

  /// No description provided for @pub_attributes_congregation_circuit_overseer.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE LOCALE ET RESPONSABLE DE CIRCONSCRIPTION'**
  String get pub_attributes_congregation_circuit_overseer;

  /// No description provided for @pub_attributes_convention.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE RÉGIONALE'**
  String get pub_attributes_convention;

  /// No description provided for @pub_attributes_convention_invitation.
  ///
  /// In fr, this message translates to:
  /// **'INVITATIONS À L\'ASSEMBLÉE RÉGIONALE'**
  String get pub_attributes_convention_invitation;

  /// No description provided for @pub_attributes_design_construction.
  ///
  /// In fr, this message translates to:
  /// **'DÉVELOPPEMENT-CONSTRUCTION'**
  String get pub_attributes_design_construction;

  /// No description provided for @pub_attributes_drama.
  ///
  /// In fr, this message translates to:
  /// **'REPRÉSENTATIONS THÉÂTRALES'**
  String get pub_attributes_drama;

  /// No description provided for @pub_attributes_dramatic_bible_reading.
  ///
  /// In fr, this message translates to:
  /// **'LECTURES BIBLIQUES THÉÂTRALES'**
  String get pub_attributes_dramatic_bible_reading;

  /// No description provided for @pub_attributes_examining_the_scriptures.
  ///
  /// In fr, this message translates to:
  /// **'EXAMINONS LES ÉCRITURES'**
  String get pub_attributes_examining_the_scriptures;

  /// No description provided for @pub_attributes_financial.
  ///
  /// In fr, this message translates to:
  /// **'COMPTABILITÉ'**
  String get pub_attributes_financial;

  /// No description provided for @pub_attributes_invitation.
  ///
  /// In fr, this message translates to:
  /// **'INVITATIONS'**
  String get pub_attributes_invitation;

  /// No description provided for @pub_attributes_kingdom_news.
  ///
  /// In fr, this message translates to:
  /// **'NOUVELLES DU ROYAUME'**
  String get pub_attributes_kingdom_news;

  /// No description provided for @pub_attributes_medical.
  ///
  /// In fr, this message translates to:
  /// **'MÉDICAL'**
  String get pub_attributes_medical;

  /// No description provided for @pub_attributes_meetings.
  ///
  /// In fr, this message translates to:
  /// **'RÉUNIONS'**
  String get pub_attributes_meetings;

  /// No description provided for @pub_attributes_ministry.
  ///
  /// In fr, this message translates to:
  /// **'MINISTÈRE'**
  String get pub_attributes_ministry;

  /// No description provided for @pub_attributes_music.
  ///
  /// In fr, this message translates to:
  /// **'MUSIQUE'**
  String get pub_attributes_music;

  /// No description provided for @pub_attributes_public.
  ///
  /// In fr, this message translates to:
  /// **'ÉDITION PUBLIQUE'**
  String get pub_attributes_public;

  /// No description provided for @pub_attributes_purchasing.
  ///
  /// In fr, this message translates to:
  /// **'ACHATS'**
  String get pub_attributes_purchasing;

  /// No description provided for @pub_attributes_safety.
  ///
  /// In fr, this message translates to:
  /// **'SÉCURITÉ'**
  String get pub_attributes_safety;

  /// No description provided for @pub_attributes_schools.
  ///
  /// In fr, this message translates to:
  /// **'ÉCOLES'**
  String get pub_attributes_schools;

  /// No description provided for @pub_attributes_simplified.
  ///
  /// In fr, this message translates to:
  /// **'VERSION FACILE'**
  String get pub_attributes_simplified;

  /// No description provided for @pub_attributes_study.
  ///
  /// In fr, this message translates to:
  /// **'ÉDITION D’ÉTUDE'**
  String get pub_attributes_study;

  /// No description provided for @pub_attributes_study_questions.
  ///
  /// In fr, this message translates to:
  /// **'QUESTIONS D\'ÉTUDE'**
  String get pub_attributes_study_questions;

  /// No description provided for @pub_attributes_study_simplified.
  ///
  /// In fr, this message translates to:
  /// **'ÉDITION D’ÉTUDE (FACILE)'**
  String get pub_attributes_study_simplified;

  /// No description provided for @pub_attributes_vocal_rendition.
  ///
  /// In fr, this message translates to:
  /// **'VERSION CHANTÉE'**
  String get pub_attributes_vocal_rendition;

  /// No description provided for @pub_attributes_writing_translation.
  ///
  /// In fr, this message translates to:
  /// **'RÉDACTION / TRADUCTION'**
  String get pub_attributes_writing_translation;

  /// No description provided for @pub_attributes_yearbook.
  ///
  /// In fr, this message translates to:
  /// **'ANNUAIRES ET RAPPORTS DES ANNÉES DE SERVICE'**
  String get pub_attributes_yearbook;

  /// No description provided for @pub_type_audio_programs.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrements audio'**
  String get pub_type_audio_programs;

  /// No description provided for @pub_type_audio_programs_sign_language.
  ///
  /// In fr, this message translates to:
  /// **'Cantiques et films'**
  String get pub_type_audio_programs_sign_language;

  /// No description provided for @pub_type_audio_programs_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'AUDIOS'**
  String get pub_type_audio_programs_uppercase;

  /// No description provided for @pub_type_audio_programs_uppercase_sign_language.
  ///
  /// In fr, this message translates to:
  /// **'CANTIQUES ET FILMS'**
  String get pub_type_audio_programs_uppercase_sign_language;

  /// No description provided for @pub_type_awake.
  ///
  /// In fr, this message translates to:
  /// **'Réveillez-vous !'**
  String get pub_type_awake;

  /// No description provided for @pub_type_books.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get pub_type_books;

  /// No description provided for @pub_type_broadcast_programs.
  ///
  /// In fr, this message translates to:
  /// **'Programmes de télédiffusion'**
  String get pub_type_broadcast_programs;

  /// No description provided for @pub_type_brochures_booklets.
  ///
  /// In fr, this message translates to:
  /// **'Brochures'**
  String get pub_type_brochures_booklets;

  /// No description provided for @pub_type_calendars.
  ///
  /// In fr, this message translates to:
  /// **'Calendriers'**
  String get pub_type_calendars;

  /// No description provided for @pub_type_curriculums.
  ///
  /// In fr, this message translates to:
  /// **'Écoles bibliques'**
  String get pub_type_curriculums;

  /// No description provided for @pub_type_forms.
  ///
  /// In fr, this message translates to:
  /// **'Formulaires'**
  String get pub_type_forms;

  /// No description provided for @pub_type_index.
  ///
  /// In fr, this message translates to:
  /// **'Index'**
  String get pub_type_index;

  /// No description provided for @pub_type_information_packets.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers d\'information'**
  String get pub_type_information_packets;

  /// No description provided for @pub_type_kingdom_ministry.
  ///
  /// In fr, this message translates to:
  /// **'Ministère du Royaume'**
  String get pub_type_kingdom_ministry;

  /// No description provided for @pub_type_letters.
  ///
  /// In fr, this message translates to:
  /// **'Courrier'**
  String get pub_type_letters;

  /// No description provided for @pub_type_manuals_guidelines.
  ///
  /// In fr, this message translates to:
  /// **'Instructions'**
  String get pub_type_manuals_guidelines;

  /// No description provided for @pub_type_meeting_workbook.
  ///
  /// In fr, this message translates to:
  /// **'Cahiers Vie et ministère'**
  String get pub_type_meeting_workbook;

  /// No description provided for @pub_type_other.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get pub_type_other;

  /// No description provided for @pub_type_programs.
  ///
  /// In fr, this message translates to:
  /// **'Programmes'**
  String get pub_type_programs;

  /// No description provided for @pub_type_talks.
  ///
  /// In fr, this message translates to:
  /// **'Plans de discours'**
  String get pub_type_talks;

  /// No description provided for @pub_type_tour_items.
  ///
  /// In fr, this message translates to:
  /// **'Visite du Béthel'**
  String get pub_type_tour_items;

  /// No description provided for @pub_type_tracts.
  ///
  /// In fr, this message translates to:
  /// **'Tracts et invitations'**
  String get pub_type_tracts;

  /// No description provided for @pub_type_videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get pub_type_videos;

  /// No description provided for @pub_type_watchtower.
  ///
  /// In fr, this message translates to:
  /// **'Tour de Garde'**
  String get pub_type_watchtower;

  /// No description provided for @pub_type_web.
  ///
  /// In fr, this message translates to:
  /// **'Rubriques'**
  String get pub_type_web;

  /// No description provided for @settings_about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settings_about;

  /// No description provided for @settings_account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settings_account;

  /// No description provided for @settings_appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settings_appearance;

  /// No description provided for @settings_appearance_dark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get settings_appearance_dark;

  /// No description provided for @settings_appearance_display.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get settings_appearance_display;

  /// No description provided for @settings_appearance_light.
  ///
  /// In fr, this message translates to:
  /// **'Claire'**
  String get settings_appearance_light;

  /// No description provided for @settings_appearance_system.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut'**
  String get settings_appearance_system;

  /// No description provided for @settings_languages.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get settings_languages;

  /// No description provided for @settings_language_app.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get settings_language_app;

  /// No description provided for @settings_language_library.
  ///
  /// In fr, this message translates to:
  /// **'Langue de la bibliothèque'**
  String get settings_language_library;

  /// No description provided for @settings_userdata.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get settings_userdata;

  /// No description provided for @settings_userdata_import.
  ///
  /// In fr, this message translates to:
  /// **'Importer une sauvegarde'**
  String get settings_userdata_import;

  /// No description provided for @settings_userdata_export.
  ///
  /// In fr, this message translates to:
  /// **'Exporter une sauvegarde'**
  String get settings_userdata_export;

  /// No description provided for @settings_application_version.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settings_application_version;

  /// No description provided for @settings_user_name.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get settings_user_name;

  /// No description provided for @settings_user_email.
  ///
  /// In fr, this message translates to:
  /// **'Adresse mail'**
  String get settings_user_email;

  /// No description provided for @settings_user_email_verified.
  ///
  /// In fr, this message translates to:
  /// **'Adresse mail verifiée'**
  String get settings_user_email_verified;

  /// No description provided for @settings_auto_update_pubs.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour les publications automatiquement'**
  String get settings_auto_update_pubs;

  /// No description provided for @settings_auto_update_pubs_wifi_only.
  ///
  /// In fr, this message translates to:
  /// **'Via le wifi uniquement'**
  String get settings_auto_update_pubs_wifi_only;

  /// No description provided for @settings_catalog_date.
  ///
  /// In fr, this message translates to:
  /// **'Date du catalogue'**
  String get settings_catalog_date;

  /// No description provided for @settings_category_download.
  ///
  /// In fr, this message translates to:
  /// **'Lecture et téléchargement'**
  String get settings_category_download;

  /// No description provided for @settings_download_over_cellular.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger en utilisant les données cellulaires'**
  String get settings_download_over_cellular;

  /// No description provided for @settings_download_over_cellular_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Cela peut entraîner des frais.'**
  String get settings_download_over_cellular_subtitle;

  /// No description provided for @settings_offline_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode « hors ligne »'**
  String get settings_offline_mode;

  /// No description provided for @settings_stop_all_downloads.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter tous les téléchargements'**
  String get settings_stop_all_downloads;

  /// No description provided for @settings_storage_device.
  ///
  /// In fr, this message translates to:
  /// **'Mémoire interne'**
  String get settings_storage_device;

  /// No description provided for @settings_storage_external.
  ///
  /// In fr, this message translates to:
  /// **'Carte SD'**
  String get settings_storage_external;

  /// No description provided for @settings_storage_folder_title_audio_programs.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les fichiers audio dans'**
  String get settings_storage_folder_title_audio_programs;

  /// No description provided for @settings_storage_folder_title_media.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les fichiers sur'**
  String get settings_storage_folder_title_media;

  /// No description provided for @settings_storage_folder_title_videos.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les fichiers vidéo dans'**
  String get settings_storage_folder_title_videos;

  /// No description provided for @settings_storage_free_space.
  ///
  /// In fr, this message translates to:
  /// **'{free} disponibles sur {total}'**
  String settings_storage_free_space(Object free, Object total);

  /// No description provided for @settings_stream_over_cellular.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en utilisant les données cellulaires'**
  String get settings_stream_over_cellular;

  /// No description provided for @settings_subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get settings_subtitles;

  /// No description provided for @settings_subtitles_off.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get settings_subtitles_off;

  /// No description provided for @settings_subtitles_on.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get settings_subtitles_on;

  /// No description provided for @settings_subtitles_select.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la langue des sous-titres'**
  String get settings_subtitles_select;

  /// No description provided for @settings_subtitles_size.
  ///
  /// In fr, this message translates to:
  /// **'Taille des sous-titres'**
  String get settings_subtitles_size;

  /// No description provided for @settings_subtitles_size_small.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get settings_subtitles_size_small;

  /// No description provided for @settings_subtitles_size_medium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get settings_subtitles_size_medium;

  /// No description provided for @settings_subtitles_size_large.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get settings_subtitles_size_large;

  /// No description provided for @settings_use_subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser les sous-titres'**
  String get settings_use_subtitles;

  /// No description provided for @settings_video_quality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité vidéo'**
  String get settings_video_quality;

  /// No description provided for @settings_video_quality_high.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get settings_video_quality_high;

  /// No description provided for @settings_video_quality_medium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get settings_video_quality_medium;

  /// No description provided for @settings_video_quality_low.
  ///
  /// In fr, this message translates to:
  /// **'Basse'**
  String get settings_video_quality_low;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
