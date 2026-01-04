import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'localization_af.dart';
import 'localization_am.dart';
import 'localization_ar.dart';
import 'localization_as.dart';
import 'localization_ay.dart';
import 'localization_az.dart';
import 'localization_de.dart';
import 'localization_en.dart';
import 'localization_es.dart';
import 'localization_fa.dart';
import 'localization_fr.dart';
import 'localization_gl.dart';
import 'localization_hu.dart';
import 'localization_it.dart';
import 'localization_ja.dart';
import 'localization_ko.dart';
import 'localization_ne.dart';
import 'localization_nl.dart';
import 'localization_pt.dart';
import 'localization_ru.dart';
import 'localization_tr.dart';
import 'localization_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'i18n/localization.dart';
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
    Locale('af'),
    Locale('am'),
    Locale('ar'),
    Locale('as'),
    Locale('ay'),
    Locale('az'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('gl'),
    Locale('hu'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('ne'),
    Locale('nl'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
    Locale('zh', 'HK'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @search_hint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get search_hint;

  /// No description provided for @action_accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get action_accept;

  /// No description provided for @action_accept_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ACCEPTER'**
  String get action_accept_uppercase;

  /// No description provided for @action_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get action_add;

  /// No description provided for @action_add_a_note.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note'**
  String get action_add_a_note;

  /// No description provided for @action_add_a_tag.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie'**
  String get action_add_a_tag;

  /// No description provided for @action_add_from_camera.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis l\'appareil photo'**
  String get action_add_from_camera;

  /// No description provided for @action_add_from_files.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis les fichiers'**
  String get action_add_from_files;

  /// No description provided for @action_add_from_photos.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis la bibliothèque photos ou vidéos'**
  String get action_add_from_photos;

  /// No description provided for @action_add_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une liste de lecture'**
  String get action_add_playlist;

  /// No description provided for @action_add_to_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la liste de lecture'**
  String get action_add_to_playlist;

  /// No description provided for @action_add_to_playlist_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'AJOUTER À LA LISTE DE LECTURE'**
  String get action_add_to_playlist_uppercase;

  /// No description provided for @action_add_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'AJOUTER'**
  String get action_add_uppercase;

  /// No description provided for @action_allow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get action_allow;

  /// No description provided for @action_ask_me_again_later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get action_ask_me_again_later;

  /// No description provided for @action_ask_me_again_later_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PLUS TARD'**
  String get action_ask_me_again_later_uppercase;

  /// No description provided for @action_back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get action_back;

  /// No description provided for @action_backup_and_restore.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder et restaurer'**
  String get action_backup_and_restore;

  /// No description provided for @action_backup_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get action_backup_create;

  /// No description provided for @action_bookmark.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un marque-page'**
  String get action_bookmark;

  /// No description provided for @action_bookmark_replace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer le marque-page'**
  String get action_bookmark_replace;

  /// No description provided for @action_bookmark_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ENREGISTRER UN MARQUE-PAGE'**
  String get action_bookmark_uppercase;

  /// No description provided for @action_bookmarks.
  ///
  /// In fr, this message translates to:
  /// **'Marque-pages'**
  String get action_bookmarks;

  /// No description provided for @action_books.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get action_books;

  /// No description provided for @action_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get action_cancel;

  /// No description provided for @action_cancel_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ANNULER'**
  String get action_cancel_uppercase;

  /// No description provided for @action_change_color.
  ///
  /// In fr, this message translates to:
  /// **'Changer la couleur'**
  String get action_change_color;

  /// No description provided for @action_chapters.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres'**
  String get action_chapters;

  /// No description provided for @action_chapters_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CHAPITRES'**
  String get action_chapters_uppercase;

  /// No description provided for @action_check.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get action_check;

  /// No description provided for @action_clear.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get action_clear;

  /// No description provided for @action_clear_cache.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache'**
  String get action_clear_cache;

  /// No description provided for @action_clear_selection.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get action_clear_selection;

  /// No description provided for @action_close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get action_close;

  /// No description provided for @action_close_upper.
  ///
  /// In fr, this message translates to:
  /// **'FERMER'**
  String get action_close_upper;

  /// No description provided for @action_collapse.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get action_collapse;

  /// No description provided for @action_contents.
  ///
  /// In fr, this message translates to:
  /// **'Table des matières'**
  String get action_contents;

  /// No description provided for @action_continue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get action_continue;

  /// No description provided for @action_continue_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CONTINUER'**
  String get action_continue_uppercase;

  /// No description provided for @action_copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get action_copy;

  /// No description provided for @action_copy_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'COPIER'**
  String get action_copy_uppercase;

  /// No description provided for @action_copy_lyrics.
  ///
  /// In fr, this message translates to:
  /// **'Copier les paroles'**
  String get action_copy_lyrics;

  /// No description provided for @action_copy_subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Copier les sous-titres'**
  String get action_copy_subtitles;

  /// No description provided for @action_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get action_create;

  /// No description provided for @action_create_a_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Créer une liste de lecture'**
  String get action_create_a_playlist;

  /// No description provided for @action_create_a_playlist_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CRÉER UNE LISTE DE LECTURE'**
  String get action_create_a_playlist_uppercase;

  /// No description provided for @action_customize.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser'**
  String get action_customize;

  /// No description provided for @action_customize_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PERSONNALISER'**
  String get action_customize_uppercase;

  /// No description provided for @action_decline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get action_decline;

  /// No description provided for @action_decline_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'REFUSER'**
  String get action_decline_uppercase;

  /// No description provided for @action_define.
  ///
  /// In fr, this message translates to:
  /// **'Définition'**
  String get action_define;

  /// No description provided for @action_define_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'DÉFINITION'**
  String get action_define_uppercase;

  /// No description provided for @action_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get action_delete;

  /// No description provided for @action_delete_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get action_delete_all;

  /// No description provided for @action_delete_all_media.
  ///
  /// In fr, this message translates to:
  /// **'Tous les médias'**
  String get action_delete_all_media;

  /// No description provided for @action_delete_all_media_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TOUS LES MÉDIAS'**
  String get action_delete_all_media_uppercase;

  /// No description provided for @action_delete_audio.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le fichier audio'**
  String get action_delete_audio;

  /// No description provided for @action_delete_item.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} »'**
  String action_delete_item(Object name);

  /// No description provided for @action_delete_media_from_this_publication.
  ///
  /// In fr, this message translates to:
  /// **'Les médias de cette publication'**
  String get action_delete_media_from_this_publication;

  /// No description provided for @action_delete_media_from_this_publication_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'LES MÉDIAS DE CETTE PUBLICATION'**
  String get action_delete_media_from_this_publication_uppercase;

  /// No description provided for @action_delete_note.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la note'**
  String get action_delete_note;

  /// No description provided for @action_delete_publication.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la publication'**
  String get action_delete_publication;

  /// No description provided for @action_delete_publication_media.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la publication et les médias'**
  String get action_delete_publication_media;

  /// No description provided for @action_delete_publication_media_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER LA PUBLICATION ET LES MÉDIAS'**
  String get action_delete_publication_media_uppercase;

  /// No description provided for @action_delete_publication_only.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer uniquement la publication'**
  String get action_delete_publication_only;

  /// No description provided for @action_delete_publication_only_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER UNIQUEMENT LA PUBLICATION'**
  String get action_delete_publication_only_uppercase;

  /// No description provided for @action_delete_publications.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {count} éléments'**
  String action_delete_publications(Object count);

  /// No description provided for @action_delete_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get action_delete_uppercase;

  /// No description provided for @action_deselect_all.
  ///
  /// In fr, this message translates to:
  /// **'Déselectionner tout'**
  String get action_deselect_all;

  /// No description provided for @action_discard.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas sauvegarder'**
  String get action_discard;

  /// No description provided for @action_display_furigana.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les furigana'**
  String get action_display_furigana;

  /// No description provided for @action_display_pinyin.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le pinyin'**
  String get action_display_pinyin;

  /// No description provided for @action_display_menu.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le menu'**
  String get action_display_menu;

  /// No description provided for @action_display_yale.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la romanisation Yale'**
  String get action_display_yale;

  /// No description provided for @action_do_not_show_again.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus afficher'**
  String get action_do_not_show_again;

  /// No description provided for @action_done.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get action_done;

  /// No description provided for @action_done_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TERMINÉ'**
  String get action_done_uppercase;

  /// No description provided for @action_download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get action_download;

  /// No description provided for @action_download_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout télécharger'**
  String get action_download_all;

  /// No description provided for @action_download_all_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TOUT TÉLÉCHARGER'**
  String get action_download_all_uppercase;

  /// No description provided for @action_download_audio.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger l\'audio'**
  String get action_download_audio;

  /// No description provided for @action_download_audio_size.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger l\'audio ({size})'**
  String action_download_audio_size(Object size);

  /// No description provided for @action_download_bible.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger une Bible'**
  String get action_download_bible;

  /// No description provided for @action_download_media.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les médias'**
  String get action_download_media;

  /// No description provided for @action_download_publication.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger {title}'**
  String action_download_publication(Object title);

  /// No description provided for @action_download_supplemental_videos.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les vidéos supplémentaires'**
  String get action_download_supplemental_videos;

  /// No description provided for @action_download_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TÉLÉCHARGER'**
  String get action_download_uppercase;

  /// No description provided for @action_download_video.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger {option} ({size})'**
  String action_download_video(Object option, Object size);

  /// No description provided for @action_download_videos.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les vidéos'**
  String get action_download_videos;

  /// No description provided for @action_duplicate.
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer'**
  String get action_duplicate;

  /// No description provided for @action_edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get action_edit;

  /// No description provided for @action_edit_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'MODIFIER'**
  String get action_edit_uppercase;

  /// No description provided for @action_enter.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get action_enter;

  /// No description provided for @action_enter_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'VALIDER'**
  String get action_enter_uppercase;

  /// No description provided for @action_expand.
  ///
  /// In fr, this message translates to:
  /// **'Développer'**
  String get action_expand;

  /// No description provided for @action_export.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get action_export;

  /// No description provided for @action_favorites_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get action_favorites_add;

  /// No description provided for @action_favorites_remove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer des favoris'**
  String get action_favorites_remove;

  /// No description provided for @action_full_screen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get action_full_screen;

  /// No description provided for @action_full_screen_exit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le mode « plein écran »'**
  String get action_full_screen_exit;

  /// No description provided for @action_go_to_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Aller dans la liste de lecture'**
  String get action_go_to_playlist;

  /// No description provided for @action_go_to_publication.
  ///
  /// In fr, this message translates to:
  /// **'Consulter la publication'**
  String get action_go_to_publication;

  /// No description provided for @action_got_it.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get action_got_it;

  /// No description provided for @action_got_it_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'COMPRIS'**
  String get action_got_it_uppercase;

  /// No description provided for @action_hide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get action_hide;

  /// No description provided for @action_highlight.
  ///
  /// In fr, this message translates to:
  /// **'Surligner'**
  String get action_highlight;

  /// No description provided for @action_history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get action_history;

  /// No description provided for @action_import_anyway.
  ///
  /// In fr, this message translates to:
  /// **'Importer quand même'**
  String get action_import_anyway;

  /// No description provided for @action_import_file.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier'**
  String get action_import_file;

  /// No description provided for @action_import_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Importer une liste de lecture'**
  String get action_import_playlist;

  /// No description provided for @action_just_once.
  ///
  /// In fr, this message translates to:
  /// **'Juste cette fois'**
  String get action_just_once;

  /// No description provided for @action_just_once_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'JUSTE CETTE FOIS'**
  String get action_just_once_uppercase;

  /// No description provided for @action_keep_editing.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à la vidéo'**
  String get action_keep_editing;

  /// No description provided for @action_languages.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get action_languages;

  /// No description provided for @action_later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get action_later;

  /// No description provided for @action_learn_more.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus'**
  String get action_learn_more;

  /// No description provided for @action_make_available_offline.
  ///
  /// In fr, this message translates to:
  /// **'Accessible hors ligne'**
  String get action_make_available_offline;

  /// No description provided for @action_media_minimize.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la fenêtre'**
  String get action_media_minimize;

  /// No description provided for @action_media_restore.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au mode « plein écran »'**
  String get action_media_restore;

  /// No description provided for @action_more_songs.
  ///
  /// In fr, this message translates to:
  /// **'Autres cantiques'**
  String get action_more_songs;

  /// No description provided for @action_navigation_menu_close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le menu de navigation'**
  String get action_navigation_menu_close;

  /// No description provided for @action_navigation_menu_open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le menu de navigation'**
  String get action_navigation_menu_open;

  /// No description provided for @action_new_note_in_this_tag.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note'**
  String get action_new_note_in_this_tag;

  /// No description provided for @action_new_tag.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get action_new_tag;

  /// No description provided for @action_next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get action_next;

  /// No description provided for @action_no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get action_no;

  /// No description provided for @action_note_minimize.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la note'**
  String get action_note_minimize;

  /// No description provided for @action_note_restore.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir la note'**
  String get action_note_restore;

  /// No description provided for @action_ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get action_ok;

  /// No description provided for @action_open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get action_open;

  /// No description provided for @action_open_in.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans…'**
  String get action_open_in;

  /// No description provided for @action_open_in_jworg.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans JW.ORG'**
  String get action_open_in_jworg;

  /// No description provided for @action_open_in_online_library.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans la Bibliothèque en ligne'**
  String get action_open_in_online_library;

  /// No description provided for @action_open_in_share.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get action_open_in_share;

  /// No description provided for @action_open_in_share_file.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le fichier'**
  String get action_open_in_share_file;

  /// No description provided for @action_open_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'OUVRIR'**
  String get action_open_uppercase;

  /// No description provided for @action_outline_of_contents.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get action_outline_of_contents;

  /// No description provided for @action_outline_of_contents_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RÉSUMÉ'**
  String get action_outline_of_contents_uppercase;

  /// No description provided for @action_pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get action_pause;

  /// No description provided for @action_personal_data_backup.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get action_personal_data_backup;

  /// No description provided for @action_personal_data_backup_internal.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde de la dernière mise à jour'**
  String get action_personal_data_backup_internal;

  /// No description provided for @action_personal_data_backup_internal_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SAUVEGARDE DE LA DERNIÈRE MISE À JOUR'**
  String get action_personal_data_backup_internal_uppercase;

  /// No description provided for @action_personal_data_backup_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CRÉER UNE SAUVEGARDE'**
  String get action_personal_data_backup_uppercase;

  /// No description provided for @action_personal_data_backup_what_i_have_now.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des données actuelles'**
  String get action_personal_data_backup_what_i_have_now;

  /// No description provided for @action_personal_data_backup_what_i_have_now_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SAUVEGARDE DES DONNÉES ACTUELLES'**
  String get action_personal_data_backup_what_i_have_now_uppercase;

  /// No description provided for @action_personal_data_delete_backup.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde'**
  String get action_personal_data_delete_backup;

  /// No description provided for @action_personal_data_delete_backup_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER LA SAUVEGARDE'**
  String get action_personal_data_delete_backup_uppercase;

  /// No description provided for @action_personal_data_do_not_backup.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas créer de sauvegarde'**
  String get action_personal_data_do_not_backup;

  /// No description provided for @action_personal_data_do_not_backup_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'NE PAS CRÉER DE SAUVEGARDE'**
  String get action_personal_data_do_not_backup_uppercase;

  /// No description provided for @action_personal_data_keep_current.
  ///
  /// In fr, this message translates to:
  /// **'Conserver les données actuelles'**
  String get action_personal_data_keep_current;

  /// No description provided for @action_personal_data_keep_current_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CONSERVER LES DONNÉES ACTUELLES'**
  String get action_personal_data_keep_current_uppercase;

  /// No description provided for @action_personal_data_restore_internal_backup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer la sauvegarde'**
  String get action_personal_data_restore_internal_backup;

  /// No description provided for @action_personal_data_restore_internal_backup_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RESTAURER LA SAUVEGARDE'**
  String get action_personal_data_restore_internal_backup_uppercase;

  /// No description provided for @action_play.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get action_play;

  /// No description provided for @action_play_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout lire'**
  String get action_play_all;

  /// No description provided for @action_play_audio.
  ///
  /// In fr, this message translates to:
  /// **'Écouter l\'audio'**
  String get action_play_audio;

  /// No description provided for @action_play_downloaded.
  ///
  /// In fr, this message translates to:
  /// **'Lire les fichiers téléchargés'**
  String get action_play_downloaded;

  /// No description provided for @action_play_this_track_only.
  ///
  /// In fr, this message translates to:
  /// **'Lire cette piste uniquement'**
  String get action_play_this_track_only;

  /// No description provided for @action_playlist_end_continue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get action_playlist_end_continue;

  /// No description provided for @action_playlist_end_freeze.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get action_playlist_end_freeze;

  /// No description provided for @action_playlist_end_stop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get action_playlist_end_stop;

  /// No description provided for @action_previous.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get action_previous;

  /// No description provided for @action_reading_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode lecture'**
  String get action_reading_mode;

  /// No description provided for @action_refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get action_refresh;

  /// No description provided for @action_refresh_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ACTUALISER'**
  String get action_refresh_uppercase;

  /// No description provided for @action_remove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get action_remove;

  /// No description provided for @action_remove_audio_size.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le fichier audio ({size})'**
  String action_remove_audio_size(Object size);

  /// No description provided for @action_remove_from_device.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer de l\'appareil'**
  String get action_remove_from_device;

  /// No description provided for @action_remove_supplemental_videos.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les vidéos supplémentaires'**
  String get action_remove_supplemental_videos;

  /// No description provided for @action_remove_tag.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la catégorie'**
  String get action_remove_tag;

  /// No description provided for @action_remove_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get action_remove_uppercase;

  /// No description provided for @action_remove_video_size.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la vidéo ({size})'**
  String action_remove_video_size(Object size);

  /// No description provided for @action_remove_videos.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les vidéos'**
  String get action_remove_videos;

  /// No description provided for @action_rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get action_rename;

  /// No description provided for @action_rename_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RENOMMER'**
  String get action_rename_uppercase;

  /// No description provided for @action_reopen_second_window.
  ///
  /// In fr, this message translates to:
  /// **'Rouvrir'**
  String get action_reopen_second_window;

  /// No description provided for @action_replace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer'**
  String get action_replace;

  /// No description provided for @action_reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get action_reset;

  /// No description provided for @action_reset_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RÉINITIALISER'**
  String get action_reset_uppercase;

  /// No description provided for @action_reset_today_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RÉINITIALISER À AUJOURD\'HUI'**
  String get action_reset_today_uppercase;

  /// No description provided for @action_restore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get action_restore;

  /// No description provided for @action_restore_a_backup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer une sauvegarde'**
  String get action_restore_a_backup;

  /// No description provided for @action_restore_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RESTAURER'**
  String get action_restore_uppercase;

  /// No description provided for @action_retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get action_retry;

  /// No description provided for @action_retry_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RÉESSAYER'**
  String get action_retry_uppercase;

  /// No description provided for @action_save_image.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l\'image'**
  String get action_save_image;

  /// No description provided for @action_search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get action_search;

  /// No description provided for @action_search_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RECHERCHER'**
  String get action_search_uppercase;

  /// No description provided for @action_see_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get action_see_all;

  /// No description provided for @action_select.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get action_select;

  /// No description provided for @action_select_all.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner tout'**
  String get action_select_all;

  /// No description provided for @action_settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get action_settings;

  /// No description provided for @action_settings_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PARAMÈTRES'**
  String get action_settings_uppercase;

  /// No description provided for @action_share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get action_share;

  /// No description provided for @action_share_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PARTAGER'**
  String get action_share_uppercase;

  /// No description provided for @action_share_image.
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'image'**
  String get action_share_image;

  /// No description provided for @action_shuffle.
  ///
  /// In fr, this message translates to:
  /// **'Lecture aléatoire'**
  String get action_shuffle;

  /// No description provided for @action_show_lyrics.
  ///
  /// In fr, this message translates to:
  /// **'Voir les paroles'**
  String get action_show_lyrics;

  /// No description provided for @action_show_subtitles.
  ///
  /// In fr, this message translates to:
  /// **'Voir les sous-titres'**
  String get action_show_subtitles;

  /// No description provided for @action_sort_by.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get action_sort_by;

  /// No description provided for @action_stop_download.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter le téléchargement'**
  String get action_stop_download;

  /// No description provided for @action_stop_trying.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get action_stop_trying;

  /// No description provided for @action_stop_trying_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ANNULER'**
  String get action_stop_trying_uppercase;

  /// No description provided for @action_stream.
  ///
  /// In fr, this message translates to:
  /// **'Lire en streaming'**
  String get action_stream;

  /// No description provided for @action_text_settings.
  ///
  /// In fr, this message translates to:
  /// **'Taille de police'**
  String get action_text_settings;

  /// No description provided for @action_translations.
  ///
  /// In fr, this message translates to:
  /// **'Traductions'**
  String get action_translations;

  /// No description provided for @action_trim.
  ///
  /// In fr, this message translates to:
  /// **'Couper'**
  String get action_trim;

  /// No description provided for @action_try_again.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get action_try_again;

  /// No description provided for @action_try_again_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RÉESSAYER'**
  String get action_try_again_uppercase;

  /// No description provided for @action_ungroup.
  ///
  /// In fr, this message translates to:
  /// **'Dissocier'**
  String get action_ungroup;

  /// No description provided for @action_update.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get action_update;

  /// No description provided for @action_update_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout mettre à jour'**
  String get action_update_all;

  /// No description provided for @action_update_audio_size.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour l\'audio ({size})'**
  String action_update_audio_size(Object size);

  /// No description provided for @action_update_video_size.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour la vidéo ({size})'**
  String action_update_video_size(Object size);

  /// No description provided for @action_view_mode_image.
  ///
  /// In fr, this message translates to:
  /// **'Mode image'**
  String get action_view_mode_image;

  /// No description provided for @action_view_mode_text.
  ///
  /// In fr, this message translates to:
  /// **'Mode texte'**
  String get action_view_mode_text;

  /// No description provided for @action_view_picture.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'image'**
  String get action_view_picture;

  /// No description provided for @action_view_source.
  ///
  /// In fr, this message translates to:
  /// **'Voir la vidéo source'**
  String get action_view_source;

  /// No description provided for @action_view_text.
  ///
  /// In fr, this message translates to:
  /// **'Voir le texte'**
  String get action_view_text;

  /// No description provided for @action_volume_adjust.
  ///
  /// In fr, this message translates to:
  /// **'Régler le volume'**
  String get action_volume_adjust;

  /// No description provided for @action_volume_mute.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le son'**
  String get action_volume_mute;

  /// No description provided for @action_volume_unmute.
  ///
  /// In fr, this message translates to:
  /// **'Activer le son'**
  String get action_volume_unmute;

  /// No description provided for @action_yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get action_yes;

  /// No description provided for @label_additional_reading.
  ///
  /// In fr, this message translates to:
  /// **'À lire aussi'**
  String get label_additional_reading;

  /// No description provided for @label_all_notes.
  ///
  /// In fr, this message translates to:
  /// **'Mes {count} notes'**
  String label_all_notes(Object count);

  /// No description provided for @label_all_tags.
  ///
  /// In fr, this message translates to:
  /// **'Mes {count} catégories'**
  String label_all_tags(Object count);

  /// No description provided for @label_all_types.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les catégories'**
  String get label_all_types;

  /// No description provided for @label_audio_available.
  ///
  /// In fr, this message translates to:
  /// **'Fichier audio disponible'**
  String get label_audio_available;

  /// No description provided for @label_breaking_news.
  ///
  /// In fr, this message translates to:
  /// **'Alerte info'**
  String get label_breaking_news;

  /// No description provided for @label_breaking_news_count.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur {total}'**
  String label_breaking_news_count(Object count, Object total);

  /// No description provided for @label_color_blue.
  ///
  /// In fr, this message translates to:
  /// **'Bleu'**
  String get label_color_blue;

  /// No description provided for @label_color_green.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get label_color_green;

  /// No description provided for @label_color_orange.
  ///
  /// In fr, this message translates to:
  /// **'Orange'**
  String get label_color_orange;

  /// No description provided for @label_color_pink.
  ///
  /// In fr, this message translates to:
  /// **'Rose'**
  String get label_color_pink;

  /// No description provided for @label_color_purple.
  ///
  /// In fr, this message translates to:
  /// **'Violet'**
  String get label_color_purple;

  /// No description provided for @label_color_yellow.
  ///
  /// In fr, this message translates to:
  /// **'Jaune'**
  String get label_color_yellow;

  /// No description provided for @label_convention_day.
  ///
  /// In fr, this message translates to:
  /// **'Jour {number}'**
  String label_convention_day(Object number);

  /// No description provided for @label_convention_releases.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés (assemblée régionale)'**
  String get label_convention_releases;

  /// No description provided for @label_date_range_one_month.
  ///
  /// In fr, this message translates to:
  /// **'{day1}-{day2} {month}'**
  String label_date_range_one_month(Object day1, Object day2, Object month);

  /// No description provided for @label_date_range_two_months.
  ///
  /// In fr, this message translates to:
  /// **'{day1} {month1} - {day2} {month2}'**
  String label_date_range_two_months(
    Object day1,
    Object day2,
    Object month1,
    Object month2,
  );

  /// No description provided for @label_document_pub_title.
  ///
  /// In fr, this message translates to:
  /// **'{doc} ({pub})'**
  String label_document_pub_title(Object doc, Object pub);

  /// No description provided for @label_download_all_cloud_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUR LE CLOUD'**
  String get label_download_all_cloud_uppercase;

  /// No description provided for @label_download_all_device_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'SUR VOTRE APPAREIL'**
  String get label_download_all_device_uppercase;

  /// No description provided for @label_download_all_files.
  ///
  /// In fr, this message translates to:
  /// **'{count} fichiers'**
  String label_download_all_files(Object count);

  /// No description provided for @label_download_all_one_file.
  ///
  /// In fr, this message translates to:
  /// **'1 fichier'**
  String get label_download_all_one_file;

  /// No description provided for @label_download_all_up_to_date.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à jour'**
  String get label_download_all_up_to_date;

  /// No description provided for @label_download_video.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la vidéo'**
  String get label_download_video;

  /// No description provided for @label_downloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get label_downloaded;

  /// No description provided for @label_downloaded_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TÉLÉCHARGÉ'**
  String get label_downloaded_uppercase;

  /// No description provided for @label_duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée {time}'**
  String label_duration(Object time);

  /// No description provided for @label_entire_video.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo complète'**
  String get label_entire_video;

  /// No description provided for @label_home_frequently_used.
  ///
  /// In fr, this message translates to:
  /// **'Souvent consulté'**
  String get label_home_frequently_used;

  /// No description provided for @label_icon_bookmark.
  ///
  /// In fr, this message translates to:
  /// **'Marque-page'**
  String get label_icon_bookmark;

  /// No description provided for @label_icon_bookmark_actions.
  ///
  /// In fr, this message translates to:
  /// **'Fonctions'**
  String get label_icon_bookmark_actions;

  /// No description provided for @label_icon_bookmark_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le marque-page'**
  String get label_icon_bookmark_delete;

  /// No description provided for @label_icon_download_publication.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la publication'**
  String get label_icon_download_publication;

  /// No description provided for @label_icon_extracted_content.
  ///
  /// In fr, this message translates to:
  /// **'Extrait de publication'**
  String get label_icon_extracted_content;

  /// No description provided for @label_icon_footnotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get label_icon_footnotes;

  /// No description provided for @label_icon_marginal_references.
  ///
  /// In fr, this message translates to:
  /// **'Renvois'**
  String get label_icon_marginal_references;

  /// No description provided for @label_icon_parallel_translations.
  ///
  /// In fr, this message translates to:
  /// **'Différentes versions'**
  String get label_icon_parallel_translations;

  /// No description provided for @label_icon_scroll_down.
  ///
  /// In fr, this message translates to:
  /// **'Faire défiler vers le bas'**
  String get label_icon_scroll_down;

  /// No description provided for @label_icon_search_suggestion.
  ///
  /// In fr, this message translates to:
  /// **'Suggestion de recherche'**
  String get label_icon_search_suggestion;

  /// No description provided for @label_icon_supplementary_hide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le volet d\'étude'**
  String get label_icon_supplementary_hide;

  /// No description provided for @label_icon_supplementary_show.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le volet d\'étude'**
  String get label_icon_supplementary_show;

  /// No description provided for @label_import.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get label_import;

  /// No description provided for @label_import_jwpub.
  ///
  /// In fr, this message translates to:
  /// **'Importer JWPUB'**
  String get label_import_jwpub;

  /// No description provided for @label_import_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Importer des listes de lecture'**
  String get label_import_playlists;

  /// No description provided for @label_import_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'IMPORTER'**
  String get label_import_uppercase;

  /// No description provided for @label_languages_2.
  ///
  /// In fr, this message translates to:
  /// **'{language1} et {language2}'**
  String label_languages_2(Object language1, Object language2);

  /// No description provided for @label_languages_3_or_more.
  ///
  /// In fr, this message translates to:
  /// **'{language} et {count} autre(s) langue(s)'**
  String label_languages_3_or_more(Object count, Object language);

  /// No description provided for @label_languages_more.
  ///
  /// In fr, this message translates to:
  /// **'Autres langues'**
  String get label_languages_more;

  /// No description provided for @label_languages_more_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'AUTRES LANGUES'**
  String get label_languages_more_uppercase;

  /// No description provided for @label_languages_recommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé'**
  String get label_languages_recommended;

  /// No description provided for @label_languages_recommended_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'RECOMMANDÉ'**
  String get label_languages_recommended_uppercase;

  /// No description provided for @label_last_updated.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour : {datetime}'**
  String label_last_updated(Object datetime);

  /// No description provided for @label_marginal_general.
  ///
  /// In fr, this message translates to:
  /// **'Compléments d\'information'**
  String get label_marginal_general;

  /// No description provided for @label_marginal_parallel_account.
  ///
  /// In fr, this message translates to:
  /// **'Récits parallèles'**
  String get label_marginal_parallel_account;

  /// No description provided for @label_marginal_quotation.
  ///
  /// In fr, this message translates to:
  /// **'Citations'**
  String get label_marginal_quotation;

  /// No description provided for @label_markers.
  ///
  /// In fr, this message translates to:
  /// **'Marqueurs'**
  String get label_markers;

  /// No description provided for @label_media_gallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie multimédia'**
  String get label_media_gallery;

  /// No description provided for @label_more.
  ///
  /// In fr, this message translates to:
  /// **'Autres fonctions'**
  String get label_more;

  /// No description provided for @label_not_included.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get label_not_included;

  /// No description provided for @label_not_included_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'AUTRES'**
  String get label_not_included_uppercase;

  /// No description provided for @label_note.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get label_note;

  /// No description provided for @label_note_title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get label_note_title;

  /// No description provided for @label_notes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get label_notes;

  /// No description provided for @label_notes_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'NOTES'**
  String get label_notes_uppercase;

  /// No description provided for @label_off.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get label_off;

  /// No description provided for @label_on.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get label_on;

  /// No description provided for @label_other_articles.
  ///
  /// In fr, this message translates to:
  /// **'Autres articles dans ce numéro'**
  String get label_other_articles;

  /// No description provided for @label_other_meeting_publications.
  ///
  /// In fr, this message translates to:
  /// **'Autres publications pour les réunions'**
  String get label_other_meeting_publications;

  /// No description provided for @label_overview.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get label_overview;

  /// No description provided for @label_paused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get label_paused;

  /// No description provided for @label_pending_updates.
  ///
  /// In fr, this message translates to:
  /// **'Mises à jour en attente'**
  String get label_pending_updates;

  /// No description provided for @label_pending_updates_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'MISES À JOUR EN ATTENTE'**
  String get label_pending_updates_uppercase;

  /// No description provided for @label_picture.
  ///
  /// In fr, this message translates to:
  /// **'Image'**
  String get label_picture;

  /// No description provided for @label_pictures.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get label_pictures;

  /// No description provided for @label_pictures_videos_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'IMAGES ET VIDÉOS'**
  String get label_pictures_videos_uppercase;

  /// No description provided for @label_playback_position.
  ///
  /// In fr, this message translates to:
  /// **'Position de lecture'**
  String get label_playback_position;

  /// No description provided for @label_playback_speed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get label_playback_speed;

  /// No description provided for @label_playback_speed_colon.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture : {speed}'**
  String label_playback_speed_colon(Object speed);

  /// No description provided for @label_playback_speed_normal.
  ///
  /// In fr, this message translates to:
  /// **'{speed} · Normale'**
  String label_playback_speed_normal(Object speed);

  /// No description provided for @label_playing.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get label_playing;

  /// No description provided for @label_playing_pip.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en mode image dans l\'image'**
  String get label_playing_pip;

  /// No description provided for @label_playlist_duration.
  ///
  /// In fr, this message translates to:
  /// **'{number} minutes'**
  String label_playlist_duration(Object number);

  /// No description provided for @label_playlist_items.
  ///
  /// In fr, this message translates to:
  /// **'{count} éléments'**
  String label_playlist_items(Object count);

  /// No description provided for @label_playlist_midweek_meeting.
  ///
  /// In fr, this message translates to:
  /// **'Vie et ministère · {date}'**
  String label_playlist_midweek_meeting(Object date);

  /// No description provided for @label_playlist_name.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la liste de lecture'**
  String get label_playlist_name;

  /// No description provided for @label_playlist_watchtower_study.
  ///
  /// In fr, this message translates to:
  /// **'Tour de Garde d\'étude · {date}'**
  String label_playlist_watchtower_study(Object date);

  /// No description provided for @label_playlist_when_done.
  ///
  /// In fr, this message translates to:
  /// **'Une fois terminée...'**
  String get label_playlist_when_done;

  /// No description provided for @label_reference_works.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrages de référence'**
  String get label_reference_works;

  /// No description provided for @label_related_scriptures.
  ///
  /// In fr, this message translates to:
  /// **'Verset(s) concerné(s) :'**
  String get label_related_scriptures;

  /// No description provided for @label_repeat.
  ///
  /// In fr, this message translates to:
  /// **'Répéter'**
  String get label_repeat;

  /// No description provided for @label_repeat_all.
  ///
  /// In fr, this message translates to:
  /// **'Activer la répétition de toutes les pistes'**
  String get label_repeat_all;

  /// No description provided for @label_repeat_all_short.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les pistes'**
  String get label_repeat_all_short;

  /// No description provided for @label_repeat_off.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la répétition'**
  String get label_repeat_off;

  /// No description provided for @label_repeat_one.
  ///
  /// In fr, this message translates to:
  /// **'Activer la répétition de la piste'**
  String get label_repeat_one;

  /// No description provided for @label_repeat_one_short.
  ///
  /// In fr, this message translates to:
  /// **'La piste'**
  String get label_repeat_one_short;

  /// No description provided for @label_research_guide.
  ///
  /// In fr, this message translates to:
  /// **'Guide de recherche'**
  String get label_research_guide;

  /// No description provided for @label_search_jworg.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher sur JW.ORG'**
  String get label_search_jworg;

  /// No description provided for @label_search_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des listes de lecture'**
  String get label_search_playlists;

  /// No description provided for @label_seek_back_5.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 5 secondes'**
  String get label_seek_back_5;

  /// No description provided for @label_seek_forward_15.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 15 secondes'**
  String get label_seek_forward_15;

  /// No description provided for @label_select_a_week.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une semaine'**
  String get label_select_a_week;

  /// No description provided for @label_select_markers.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des marqueurs'**
  String get label_select_markers;

  /// No description provided for @label_settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get label_settings;

  /// No description provided for @label_settings_airplay.
  ///
  /// In fr, this message translates to:
  /// **'AirPlay'**
  String get label_settings_airplay;

  /// No description provided for @label_settings_airplay_disconnect.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver AirPlay'**
  String get label_settings_airplay_disconnect;

  /// No description provided for @label_settings_cast.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à un appareil'**
  String get label_settings_cast;

  /// No description provided for @label_settings_cast_disconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion d\'un appareil'**
  String get label_settings_cast_disconnect;

  /// No description provided for @label_share_start_at.
  ///
  /// In fr, this message translates to:
  /// **'Commencer à {marker}'**
  String label_share_start_at(Object marker);

  /// No description provided for @label_shuffle_off.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver la lecture aléatoire'**
  String get label_shuffle_off;

  /// No description provided for @label_shuffle_on.
  ///
  /// In fr, this message translates to:
  /// **'Activer la lecture aléatoire'**
  String get label_shuffle_on;

  /// No description provided for @label_sort_frequently_used.
  ///
  /// In fr, this message translates to:
  /// **'Souvent consulté'**
  String get label_sort_frequently_used;

  /// No description provided for @label_sort_largest_size.
  ///
  /// In fr, this message translates to:
  /// **'Taille décroissante'**
  String get label_sort_largest_size;

  /// No description provided for @label_sort_publication_symbol.
  ///
  /// In fr, this message translates to:
  /// **'Symbole de publication'**
  String get label_sort_publication_symbol;

  /// No description provided for @label_sort_rarely_used.
  ///
  /// In fr, this message translates to:
  /// **'Rarement consulté'**
  String get label_sort_rarely_used;

  /// No description provided for @label_sort_title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get label_sort_title;

  /// No description provided for @label_sort_year.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get label_sort_year;

  /// No description provided for @label_streaming_media.
  ///
  /// In fr, this message translates to:
  /// **'Lecture • {title}'**
  String label_streaming_media(Object title);

  /// No description provided for @label_study_bible_content_available.
  ///
  /// In fr, this message translates to:
  /// **'Des éléments de la Bible d\'étude sont disponibles'**
  String get label_study_bible_content_available;

  /// No description provided for @label_study_content.
  ///
  /// In fr, this message translates to:
  /// **'Contenus d\'étude'**
  String get label_study_content;

  /// No description provided for @label_supplemental_videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos supplémentaires'**
  String get label_supplemental_videos;

  /// No description provided for @label_support_code.
  ///
  /// In fr, this message translates to:
  /// **'Code'**
  String get label_support_code;

  /// No description provided for @label_support_code_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CODE'**
  String get label_support_code_uppercase;

  /// No description provided for @label_tags.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get label_tags;

  /// No description provided for @label_tags_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CATÉGORIES'**
  String get label_tags_uppercase;

  /// No description provided for @label_text_size_slider.
  ///
  /// In fr, this message translates to:
  /// **'Curseur pour changer la taille du texte'**
  String get label_text_size_slider;

  /// No description provided for @label_thumbnail_publication.
  ///
  /// In fr, this message translates to:
  /// **'Image miniature'**
  String get label_thumbnail_publication;

  /// No description provided for @label_topics_publications_media.
  ///
  /// In fr, this message translates to:
  /// **'Articles, publications et médias'**
  String get label_topics_publications_media;

  /// No description provided for @label_trim_current.
  ///
  /// In fr, this message translates to:
  /// **'En cours {timecode}'**
  String label_trim_current(Object timecode);

  /// No description provided for @label_trim_end.
  ///
  /// In fr, this message translates to:
  /// **'Fin {timecode}'**
  String label_trim_end(Object timecode);

  /// No description provided for @label_trim_start.
  ///
  /// In fr, this message translates to:
  /// **'Début {timecode}'**
  String label_trim_start(Object timecode);

  /// No description provided for @label_units_storage_bytes.
  ///
  /// In fr, this message translates to:
  /// **'{number} octets'**
  String label_units_storage_bytes(Object number);

  /// No description provided for @label_units_storage_gb.
  ///
  /// In fr, this message translates to:
  /// **'{number} Go'**
  String label_units_storage_gb(Object number);

  /// No description provided for @label_units_storage_kb.
  ///
  /// In fr, this message translates to:
  /// **'{number} Ko'**
  String label_units_storage_kb(Object number);

  /// No description provided for @label_units_storage_mb.
  ///
  /// In fr, this message translates to:
  /// **'{number} Mo'**
  String label_units_storage_mb(Object number);

  /// No description provided for @label_units_storage_tb.
  ///
  /// In fr, this message translates to:
  /// **'{number} To'**
  String label_units_storage_tb(Object number);

  /// No description provided for @label_untagged.
  ///
  /// In fr, this message translates to:
  /// **'Non classées'**
  String get label_untagged;

  /// No description provided for @label_unused_bookmark.
  ///
  /// In fr, this message translates to:
  /// **'Marque-page non utilisé'**
  String get label_unused_bookmark;

  /// No description provided for @label_update_available.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour disponible'**
  String get label_update_available;

  /// No description provided for @label_videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get label_videos;

  /// No description provided for @label_view_original.
  ///
  /// In fr, this message translates to:
  /// **'Voir la vidéo source'**
  String get label_view_original;

  /// No description provided for @label_volume_level.
  ///
  /// In fr, this message translates to:
  /// **'Volume'**
  String get label_volume_level;

  /// No description provided for @label_volume_percent.
  ///
  /// In fr, this message translates to:
  /// **'{value} %'**
  String label_volume_percent(Object value);

  /// No description provided for @label_weeks.
  ///
  /// In fr, this message translates to:
  /// **'Semaines'**
  String get label_weeks;

  /// No description provided for @label_whats_new_1_day_ago.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get label_whats_new_1_day_ago;

  /// No description provided for @label_whats_new_1_hour_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a 1 heure'**
  String get label_whats_new_1_hour_ago;

  /// No description provided for @label_whats_new_1_minute_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a 1 minute'**
  String get label_whats_new_1_minute_ago;

  /// No description provided for @label_whats_new_1_month_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a 1 mois'**
  String get label_whats_new_1_month_ago;

  /// No description provided for @label_whats_new_1_year_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a 1 an'**
  String get label_whats_new_1_year_ago;

  /// No description provided for @label_whats_new_earlier.
  ///
  /// In fr, this message translates to:
  /// **'PRÉCÉDEMMENT'**
  String get label_whats_new_earlier;

  /// No description provided for @label_whats_new_last_month.
  ///
  /// In fr, this message translates to:
  /// **'LE MOIS DERNIER'**
  String get label_whats_new_last_month;

  /// No description provided for @label_whats_new_multiple_days_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} jours'**
  String label_whats_new_multiple_days_ago(Object count);

  /// No description provided for @label_whats_new_multiple_hours_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} heures'**
  String label_whats_new_multiple_hours_ago(Object count);

  /// No description provided for @label_whats_new_multiple_minutes_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} minutes'**
  String label_whats_new_multiple_minutes_ago(Object count);

  /// No description provided for @label_whats_new_multiple_months_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} mois'**
  String label_whats_new_multiple_months_ago(Object count);

  /// No description provided for @label_whats_new_multiple_year_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} ans'**
  String label_whats_new_multiple_year_ago(Object count);

  /// No description provided for @label_whats_new_multiple_seconds_ago.
  ///
  /// In fr, this message translates to:
  /// **'Il y a quelques secondes'**
  String get label_whats_new_multiple_seconds_ago;

  /// No description provided for @label_whats_new_this_month.
  ///
  /// In fr, this message translates to:
  /// **'CE MOIS-CI'**
  String get label_whats_new_this_month;

  /// No description provided for @label_whats_new_this_week.
  ///
  /// In fr, this message translates to:
  /// **'CETTE SEMAINE'**
  String get label_whats_new_this_week;

  /// No description provided for @label_whats_new_today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get label_whats_new_today;

  /// No description provided for @label_yeartext_currently.
  ///
  /// In fr, this message translates to:
  /// **'Actuellement : {language}'**
  String label_yeartext_currently(Object language);

  /// No description provided for @label_yeartext_language.
  ///
  /// In fr, this message translates to:
  /// **'Langue d\'affichage du texte de l\'année'**
  String get label_yeartext_language;

  /// No description provided for @label_yeartext_meetings_tab.
  ///
  /// In fr, this message translates to:
  /// **'Même langue que la rubrique « Réunions »'**
  String get label_yeartext_meetings_tab;

  /// No description provided for @label_yeartext_off.
  ///
  /// In fr, this message translates to:
  /// **'Le texte de l\'année ne sera pas affiché'**
  String get label_yeartext_off;

  /// No description provided for @labels_media_player_elapsed_time.
  ///
  /// In fr, this message translates to:
  /// **'{time_elapsed} écoulé de {total_duration}'**
  String labels_media_player_elapsed_time(
    Object time_elapsed,
    Object total_duration,
  );

  /// No description provided for @labels_pip_exit.
  ///
  /// In fr, this message translates to:
  /// **'Sortir du mode « image dans l\'image »'**
  String get labels_pip_exit;

  /// No description provided for @labels_pip_play.
  ///
  /// In fr, this message translates to:
  /// **'Image dans l\'image'**
  String get labels_pip_play;

  /// No description provided for @labels_this_week.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get labels_this_week;

  /// No description provided for @message_access_file_permission_rationale_description.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez importer des publications, des médias et des sauvegardes dans l\'application. Touchez « Autoriser » au prochain message.'**
  String get message_access_file_permission_rationale_description;

  /// No description provided for @message_access_file_permission_rationale_title.
  ///
  /// In fr, this message translates to:
  /// **'JW Library souhaite accéder à vos fichiers'**
  String get message_access_file_permission_rationale_title;

  /// No description provided for @message_accessibility_narrator_enabled.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'est pas possible de surligner quand Narrateur est activé.'**
  String get message_accessibility_narrator_enabled;

  /// No description provided for @message_accessibility_talkback_enabled.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'est pas possible de surligner quand TalkBack est activé.'**
  String get message_accessibility_talkback_enabled;

  /// No description provided for @message_accessibility_voiceover_enabled.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'est pas possible de surligner quand VoiceOver est activé.'**
  String get message_accessibility_voiceover_enabled;

  /// No description provided for @message_added_to_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à la liste de lecture'**
  String get message_added_to_playlist;

  /// No description provided for @message_added_to_playlist_name.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à la liste de lecture « \'{playlistItem} »'**
  String message_added_to_playlist_name(Object playlistItem);

  /// No description provided for @message_auto_update_pubs.
  ///
  /// In fr, this message translates to:
  /// **'À l’avenir, souhaitez-vous mettre à jour les publications automatiquement ?'**
  String get message_auto_update_pubs;

  /// No description provided for @message_backup_create_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer vos notes, catégories, éléments surlignés, favoris et marque-pages dans un fichier de sauvegarde'**
  String get message_backup_create_explanation;

  /// No description provided for @message_clear_cache.
  ///
  /// In fr, this message translates to:
  /// **'Suppression du cache en cours...'**
  String get message_clear_cache;

  /// No description provided for @message_catalog_downloading.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de nouvelles publications...'**
  String get message_catalog_downloading;

  /// No description provided for @message_catalog_fail.
  ///
  /// In fr, this message translates to:
  /// **'Échec de la mise à jour'**
  String get message_catalog_fail;

  /// No description provided for @message_catalog_new.
  ///
  /// In fr, this message translates to:
  /// **'De nouvelles publications sont disponibles'**
  String get message_catalog_new;

  /// No description provided for @message_catalog_success.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour terminée'**
  String get message_catalog_success;

  /// No description provided for @message_catalog_up_to_date.
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle publication n\'est disponible'**
  String get message_catalog_up_to_date;

  /// No description provided for @message_checking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en cours...'**
  String get message_checking;

  /// No description provided for @message_choose_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une liste de lecture'**
  String get message_choose_playlist;

  /// No description provided for @message_coaching_change_speed.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la vitesse'**
  String get message_coaching_change_speed;

  /// No description provided for @message_coaching_change_speed_description.
  ///
  /// In fr, this message translates to:
  /// **'Glissez vers le haut ou le bas'**
  String get message_coaching_change_speed_description;

  /// No description provided for @message_coaching_more_button.
  ///
  /// In fr, this message translates to:
  /// **'Autres fonctions'**
  String get message_coaching_more_button;

  /// No description provided for @message_coaching_more_button_description.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour voir d\'autres options, comme « Supprimer »'**
  String get message_coaching_more_button_description;

  /// No description provided for @message_coaching_next_prev_marker.
  ///
  /// In fr, this message translates to:
  /// **'Précédent/Suivant'**
  String get message_coaching_next_prev_marker;

  /// No description provided for @message_coaching_next_prev_marker_description.
  ///
  /// In fr, this message translates to:
  /// **'Glissez vers la gauche ou la droite.'**
  String get message_coaching_next_prev_marker_description;

  /// No description provided for @message_coaching_play_pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause/Lecture'**
  String get message_coaching_play_pause;

  /// No description provided for @message_coaching_play_pause_description.
  ///
  /// In fr, this message translates to:
  /// **'Touchez avec deux doigts'**
  String get message_coaching_play_pause_description;

  /// No description provided for @message_coaching_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Créez des listes de lecture de fichiers vidéos et audio et d\'images. Utilisez-les ou modifiez-les depuis l\'onglet « Étude individuelle ».'**
  String get message_coaching_playlists;

  /// No description provided for @message_coaching_publications_download.
  ///
  /// In fr, this message translates to:
  /// **'Pour voir les vidéos, téléchargez d\'abord chaque publication.'**
  String get message_coaching_publications_download;

  /// No description provided for @message_confirm_delete.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ?'**
  String get message_confirm_delete;

  /// No description provided for @message_confirm_stop_download.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous arrêter le téléchargement ?'**
  String get message_confirm_stop_download;

  /// No description provided for @message_content_not_available.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n’est pas disponible.'**
  String get message_content_not_available;

  /// No description provided for @message_content_not_available_in_selected_language.
  ///
  /// In fr, this message translates to:
  /// **'Certains contenus ne sont pas disponibles dans cette langue.'**
  String get message_content_not_available_in_selected_language;

  /// No description provided for @message_delete_failure_title.
  ///
  /// In fr, this message translates to:
  /// **'La suppression a échoué'**
  String get message_delete_failure_title;

  /// No description provided for @message_delete_publication_media.
  ///
  /// In fr, this message translates to:
  /// **'Cette publication contient un fichier de la rubrique « Multimédia ». Que souhaitez-vous supprimer ?'**
  String get message_delete_publication_media;

  /// No description provided for @message_delete_publication_media_multiple.
  ///
  /// In fr, this message translates to:
  /// **'Cette publication contient {count} fichiers de la rubrique « Multimédia ». Que souhaitez-vous supprimer ?'**
  String message_delete_publication_media_multiple(Object count);

  /// No description provided for @message_delete_publication_videos.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos de cette publication seront aussi supprimées.'**
  String get message_delete_publication_videos;

  /// No description provided for @message_discard_changes.
  ///
  /// In fr, this message translates to:
  /// **'Vos modifications ne sont pas sauvegardées.'**
  String get message_discard_changes;

  /// No description provided for @message_discard_changes_title.
  ///
  /// In fr, this message translates to:
  /// **'Annuler les modifications ?'**
  String get message_discard_changes_title;

  /// No description provided for @message_do_not_close_app.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas fermer l\'application.'**
  String get message_do_not_close_app;

  /// No description provided for @message_download_complete.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement terminé'**
  String get message_download_complete;

  /// No description provided for @message_download_from_jworg.
  ///
  /// In fr, this message translates to:
  /// **'Allez sur la page correspondante de jw.org pour télécharger les fichiers.'**
  String get message_download_from_jworg;

  /// No description provided for @message_download_from_jworg_title.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les fichiers depuis jw.org'**
  String get message_download_from_jworg_title;

  /// No description provided for @message_download_publications_for_meeting.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les publications ci-dessus.'**
  String get message_download_publications_for_meeting;

  /// No description provided for @message_download_research_guide.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez la dernière version du Guide de recherche pour accéder aux références.'**
  String get message_download_research_guide;

  /// No description provided for @message_download_will_close_item.
  ///
  /// In fr, this message translates to:
  /// **'Le téléchargement fermera cette fenêtre.'**
  String get message_download_will_close_item;

  /// No description provided for @message_empty_audio.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier audio.'**
  String get message_empty_audio;

  /// No description provided for @message_empty_pictures_videos.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'image ni de vidéo.'**
  String get message_empty_pictures_videos;

  /// No description provided for @message_file_cannot_open.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'est pas possible d\'ouvrir ce fichier avec JW Library.'**
  String get message_file_cannot_open;

  /// No description provided for @message_file_corrupted.
  ///
  /// In fr, this message translates to:
  /// **'« {filename} » ne peut pas être importé car il y a un problème avec le fichier. Téléchargez-le à nouveau.'**
  String message_file_corrupted(Object filename);

  /// No description provided for @message_file_corrupted_title.
  ///
  /// In fr, this message translates to:
  /// **'Fichier endommagé'**
  String get message_file_corrupted_title;

  /// No description provided for @message_file_fail_multiple.
  ///
  /// In fr, this message translates to:
  /// **'{number} fichiers n\'ont pas été importés'**
  String message_file_fail_multiple(Object number);

  /// No description provided for @message_file_failed.
  ///
  /// In fr, this message translates to:
  /// **'1 fichier n\'a pas été importé'**
  String get message_file_failed;

  /// No description provided for @message_file_found.
  ///
  /// In fr, this message translates to:
  /// **'Cet emplacement contient un autre fichier qui peut être importé dans JW Library. Souhaitez-vous l\'importer maintenant ?'**
  String get message_file_found;

  /// No description provided for @message_file_found_multiple.
  ///
  /// In fr, this message translates to:
  /// **'Cet emplacement contient {number} autres fichiers qui peuvent être importés dans JW Library. Souhaitez-vous les importer maintenant ?'**
  String message_file_found_multiple(Object number);

  /// No description provided for @message_file_found_title.
  ///
  /// In fr, this message translates to:
  /// **'Autres fichiers détectés'**
  String get message_file_found_title;

  /// No description provided for @message_file_import_complete.
  ///
  /// In fr, this message translates to:
  /// **'Importation terminée'**
  String get message_file_import_complete;

  /// No description provided for @message_file_import_fail.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier ne peut pas être importé'**
  String get message_file_import_fail;

  /// No description provided for @message_file_importing.
  ///
  /// In fr, this message translates to:
  /// **'1 fichier restant'**
  String get message_file_importing;

  /// No description provided for @message_file_importing_multiple.
  ///
  /// In fr, this message translates to:
  /// **'{number} fichiers restants'**
  String message_file_importing_multiple(Object number);

  /// No description provided for @message_file_importing_title.
  ///
  /// In fr, this message translates to:
  /// **'Importation des fichiers'**
  String get message_file_importing_title;

  /// No description provided for @message_file_importing_name.
  ///
  /// In fr, this message translates to:
  /// **'Importation du fichier {fileName} en cours…'**
  String message_file_importing_name(Object fileName);

  /// No description provided for @message_file_missing_pub.
  ///
  /// In fr, this message translates to:
  /// **'La publication correspondante est introuvable. Installez la publication « {symbol} » et réessayez. Si une autre publication fait référence à ce fichier, utilisez la fonction « Importer » pour sélectionner directement le fichier.'**
  String message_file_missing_pub(Object symbol);

  /// No description provided for @message_file_missing_pub_title.
  ///
  /// In fr, this message translates to:
  /// **'Publication manquante'**
  String get message_file_missing_pub_title;

  /// No description provided for @message_file_not_recognized.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier ne correspond à aucun contenu de JW Library. Essayez d\'abord de télécharger une publication correspondante ou sélectionnez un autre fichier.'**
  String get message_file_not_recognized;

  /// No description provided for @message_file_not_recognized_title.
  ///
  /// In fr, this message translates to:
  /// **'Fichier non reconnu'**
  String get message_file_not_recognized_title;

  /// No description provided for @message_file_not_supported_title.
  ///
  /// In fr, this message translates to:
  /// **'Fichier non supporté'**
  String get message_file_not_supported_title;

  /// No description provided for @message_file_success.
  ///
  /// In fr, this message translates to:
  /// **'1 fichier a été vérifié et importé dans JW Library'**
  String get message_file_success;

  /// No description provided for @message_file_success_multiple.
  ///
  /// In fr, this message translates to:
  /// **'{number} fichiers ont été vérifiés et importés dans JW Library'**
  String message_file_success_multiple(Object number);

  /// No description provided for @message_file_unknown_type.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'a pas pu être ouvert.'**
  String get message_file_unknown_type;

  /// No description provided for @message_file_wrong.
  ///
  /// In fr, this message translates to:
  /// **'Il y a un problème avec le nom du fichier'**
  String get message_file_wrong;

  /// No description provided for @message_file_wrong_title.
  ///
  /// In fr, this message translates to:
  /// **'Fichier erroné'**
  String get message_file_wrong_title;

  /// No description provided for @message_full_screen_left_swipe.
  ///
  /// In fr, this message translates to:
  /// **'Pour naviguer, glisser vers la droite.'**
  String get message_full_screen_left_swipe;

  /// No description provided for @message_full_screen_title.
  ///
  /// In fr, this message translates to:
  /// **'Mode « plein écran »'**
  String get message_full_screen_title;

  /// No description provided for @message_full_screen_top_swipe.
  ///
  /// In fr, this message translates to:
  /// **'Pour quitter le mode « plein écran », glisser vers le bas.'**
  String get message_full_screen_top_swipe;

  /// No description provided for @message_help_us_improve.
  ///
  /// In fr, this message translates to:
  /// **'JW Library a rencontré un problème récemment. Souhaitez-vous nous envoyer des données de diagnostic ? Ces informations nous aident à maintenir les performances de l\'application.'**
  String get message_help_us_improve;

  /// No description provided for @message_help_us_improve_title.
  ///
  /// In fr, this message translates to:
  /// **'Aidez-nous à améliorer l\'application'**
  String get message_help_us_improve_title;

  /// No description provided for @message_import_jwlsl_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Cette sauvegarde contient des listes de lecture créées dans l\'application JW Library Sign Language. Importer ces listes de lecture ?'**
  String get message_import_jwlsl_playlist;

  /// No description provided for @message_install_failure.
  ///
  /// In fr, this message translates to:
  /// **'L’installation n’a pas pu se terminer.'**
  String get message_install_failure;

  /// No description provided for @message_install_failure_description.
  ///
  /// In fr, this message translates to:
  /// **'JW Library ne peut pas installer cette publication. Merci de réessayer le téléchargement puis l\'installation.'**
  String get message_install_failure_description;

  /// No description provided for @message_install_failure_title.
  ///
  /// In fr, this message translates to:
  /// **'Le téléchargement a échoué'**
  String get message_install_failure_title;

  /// No description provided for @message_install_latest.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour l\'application JW Library pour installer cette publication.'**
  String get message_install_latest;

  /// No description provided for @message_install_media_extensions.
  ///
  /// In fr, this message translates to:
  /// **'Installez l\'extension d\'image HEIF et l\'extension de vidéo HEVC depuis le Microsoft Store.'**
  String get message_install_media_extensions;

  /// No description provided for @message_install_study_edition.
  ///
  /// In fr, this message translates to:
  /// **'Les marque-pages, les surlignages et les notes que vous avez dans la Traduction du monde nouveau seront déplacés dans l\'édition d\'étude.'**
  String get message_install_study_edition;

  /// No description provided for @message_install_study_edition_title.
  ///
  /// In fr, this message translates to:
  /// **'Installer l\'édition d\'étude'**
  String get message_install_study_edition_title;

  /// No description provided for @message_install_success_study_edition.
  ///
  /// In fr, this message translates to:
  /// **'Les notes et les surlignages que vous aviez dans la Traduction du monde nouveau ont été déplacés dans l\'édition d\'étude.'**
  String get message_install_success_study_edition;

  /// No description provided for @message_install_success_title.
  ///
  /// In fr, this message translates to:
  /// **'Installation réussie'**
  String get message_install_success_title;

  /// No description provided for @message_installing.
  ///
  /// In fr, this message translates to:
  /// **'Installation...'**
  String get message_installing;

  /// No description provided for @message_item_unavailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas disponible pour l\'instant. Essayez plus tard ou importez le fichier si vous l\'avez sur votre appareil.'**
  String get message_item_unavailable;

  /// No description provided for @message_item_unavailable_title.
  ///
  /// In fr, this message translates to:
  /// **'Élément non disponible'**
  String get message_item_unavailable_title;

  /// No description provided for @message_large_file_warning.
  ///
  /// In fr, this message translates to:
  /// **'La taille de ce fichier est de {size}. Il occupera beaucoup d\'espace de stockage sur votre appareil. Voulez-vous importer ce fichier ?'**
  String message_large_file_warning(Object size);

  /// No description provided for @message_large_file_warning_title.
  ///
  /// In fr, this message translates to:
  /// **'Fichier volumineux'**
  String get message_large_file_warning_title;

  /// No description provided for @message_media_starting_may_2016.
  ///
  /// In fr, this message translates to:
  /// **'Les contenus multimédias seront disponibles à partir de mai 2016.'**
  String get message_media_starting_may_2016;

  /// No description provided for @message_media_up_next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant: {title}'**
  String message_media_up_next(Object title);

  /// No description provided for @message_migration_failure_study_edition.
  ///
  /// In fr, this message translates to:
  /// **'Les notes et les surlignages que vous aviez dans la Traduction du monde nouveau n\'ont pas été déplacés dans l\'édition d\'étude. Pour réessayer, supprimez l\'édition d\'étude et téléchargez-la de nouveau.'**
  String get message_migration_failure_study_edition;

  /// No description provided for @message_migration_failure_title.
  ///
  /// In fr, this message translates to:
  /// **'La migration a échoué'**
  String get message_migration_failure_title;

  /// No description provided for @message_migration_study_edition.
  ///
  /// In fr, this message translates to:
  /// **'Merci de patienter pendant le transfert de vos notes et de vos surlignages vers l\'édition d\'étude. Cela peut prendre du temps.'**
  String get message_migration_study_edition;

  /// No description provided for @message_missing_download_location.
  ///
  /// In fr, this message translates to:
  /// **'Dans les Paramètres, sélectionnez un emplacement de téléchargement.'**
  String get message_missing_download_location;

  /// No description provided for @message_missing_download_location_title.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement impossible'**
  String get message_missing_download_location_title;

  /// No description provided for @message_missing_download_location_windows_n.
  ///
  /// In fr, this message translates to:
  /// **'Aucun emplacement de téléchargement disponible.'**
  String get message_missing_download_location_windows_n;

  /// No description provided for @message_name_taken.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom existe déjà.'**
  String get message_name_taken;

  /// No description provided for @message_no_audio_programs.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a aucun contenu audio dans cette langue.'**
  String get message_no_audio_programs;

  /// No description provided for @message_no_content.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu disponible'**
  String get message_no_content;

  /// No description provided for @message_no_footnotes.
  ///
  /// In fr, this message translates to:
  /// **'Aucune note.'**
  String get message_no_footnotes;

  /// No description provided for @message_no_internet_audio.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour vérifier si du contenu audio est disponible.'**
  String get message_no_internet_audio;

  /// No description provided for @message_no_internet_audio_programs.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir les contenus audio disponibles.'**
  String get message_no_internet_audio_programs;

  /// No description provided for @message_no_internet_connection.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet.'**
  String get message_no_internet_connection;

  /// No description provided for @message_no_internet_connection_title.
  ///
  /// In fr, this message translates to:
  /// **'Aucune connexion Internet'**
  String get message_no_internet_connection_title;

  /// No description provided for @message_no_internet_language.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir toutes les langues disponibles.'**
  String get message_no_internet_language;

  /// No description provided for @message_no_internet_media.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir les médias disponibles.'**
  String get message_no_internet_media;

  /// No description provided for @message_no_internet_meeting.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir les programmes de réunions disponibles.'**
  String get message_no_internet_meeting;

  /// No description provided for @message_no_internet_publications.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir les publications disponibles.'**
  String get message_no_internet_publications;

  /// No description provided for @message_no_internet_videos_media.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à Internet pour voir les vidéos disponibles.'**
  String get message_no_internet_videos_media;

  /// No description provided for @message_no_items_audios.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a pas d\'audios disponibles dans cette langue.'**
  String get message_no_items_audios;

  /// No description provided for @message_no_items_publications.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a pas de publications disponibles dans cette langue.'**
  String get message_no_items_publications;

  /// No description provided for @message_no_items_videos.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a pas de vidéos disponibles dans cette langue.'**
  String get message_no_items_videos;

  /// No description provided for @message_no_marginal_references.
  ///
  /// In fr, this message translates to:
  /// **'Aucune référence marginale.'**
  String get message_no_marginal_references;

  /// No description provided for @message_no_media.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez des publications audio ou vidéo.'**
  String get message_no_media;

  /// No description provided for @message_no_media_items.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a pas de nouveau média dans cette langue.'**
  String get message_no_media_items;

  /// No description provided for @message_no_media_title.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média'**
  String get message_no_media_title;

  /// No description provided for @message_no_midweek_meeting_content.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu pour la réunion de semaine pour cette date.'**
  String get message_no_midweek_meeting_content;

  /// No description provided for @message_no_weekend_meeting_content.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu pour pour la réunions du weekend pour cette date.'**
  String get message_no_weekend_meeting_content;

  /// No description provided for @message_no_ministry_publications.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a aucune publication pour la prédication dans cette langue.'**
  String get message_no_ministry_publications;

  /// No description provided for @message_no_notes.
  ///
  /// In fr, this message translates to:
  /// **'Vos notes apparaîtront ici.'**
  String get message_no_notes;

  /// No description provided for @message_no_other_bibles.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre Bible ne contient de texte à afficher pour ce chapitre.'**
  String get message_no_other_bibles;

  /// No description provided for @message_no_playlist_items.
  ///
  /// In fr, this message translates to:
  /// **'Aucun élément dans cette liste de lecture.'**
  String get message_no_playlist_items;

  /// No description provided for @message_no_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Aucune liste de lecture.'**
  String get message_no_playlists;

  /// No description provided for @message_no_study_content.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu d\'étude'**
  String get message_no_study_content;

  /// No description provided for @message_no_tags.
  ///
  /// In fr, this message translates to:
  /// **'Les éléments classés dans la catégorie « {name} » apparaîtront ici.'**
  String message_no_tags(Object name);

  /// No description provided for @message_no_topics_found.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get message_no_topics_found;

  /// No description provided for @message_no_verses_available.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo n\'est disponible pour ce livre de la Bible.'**
  String get message_no_verses_available;

  /// No description provided for @message_no_videos.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a aucune vidéo dans cette langue.'**
  String get message_no_videos;

  /// No description provided for @message_no_wifi_connection.
  ///
  /// In fr, this message translates to:
  /// **'Cela peut entraîner des frais. Pour autoriser systématiquement le téléchargement en utilisant les données cellulaires allez dans les Paramètres. Souhaitez-vous quand même continuer ?'**
  String get message_no_wifi_connection;

  /// No description provided for @message_no_wifi_connection_missing_items.
  ///
  /// In fr, this message translates to:
  /// **'Certains éléments de la liste ne sont pas téléchargés et doivent être consultés en streaming. Cela peut entraîner des frais liés à la consommation de données cellulaires. Souhaitez-vous continuer ?'**
  String get message_no_wifi_connection_missing_items;

  /// No description provided for @message_not_enough_storage.
  ///
  /// In fr, this message translates to:
  /// **'La capacité de stockage est insuffisante pour télécharger la publication. Vous pouvez gérer le stockage dans les Paramètres.'**
  String get message_not_enough_storage;

  /// No description provided for @message_not_enough_storage_title.
  ///
  /// In fr, this message translates to:
  /// **'Capacité de stockage insuffisante'**
  String get message_not_enough_storage_title;

  /// No description provided for @message_offline_mode.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à Internet est désactivé sur JW Library. Souhaitez-vous quand même continuer ?'**
  String get message_offline_mode;

  /// No description provided for @message_offline_mode_multiple_items.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à Internet est désactivé sur JW Library. Certains médias ne sont pas téléchargés et devront être lus en ligne. Souhaitez-vous quand même continuer ?'**
  String get message_offline_mode_multiple_items;

  /// No description provided for @message_offline_terms.
  ///
  /// In fr, this message translates to:
  /// **'JW Library n\'a pas pu charger ce document. Veuillez lire les conditions d\'utilisation à l\'adresse {url} sur un appareil disposant d\'une connexion Internet avant d\'accepter les conditions d\'utilisation.'**
  String message_offline_terms(Object url);

  /// No description provided for @message_permission_files.
  ///
  /// In fr, this message translates to:
  /// **'Pour ouvrir des fichiers à partir d\'autres applications, nous devons accéder à des répertoires de votre appareil.'**
  String get message_permission_files;

  /// No description provided for @message_permission_photos.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez ainsi sauvegarder des images contenues dans les publications.'**
  String get message_permission_photos;

  /// No description provided for @message_permission_title.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'autorisation'**
  String get message_permission_title;

  /// No description provided for @message_personal_data_backup_confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr ? Nous vous recommandons de créer une sauvegarde pour pouvoir récupérer vos notes et surlignages plus tard.'**
  String get message_personal_data_backup_confirmation;

  /// No description provided for @message_personal_data_backup_found_description.
  ///
  /// In fr, this message translates to:
  /// **'Une sauvegarde de vos notes et surlignages perdus lors d\'une récente mise à jour a été conservée dans JW Library. Que souhaitez-vous sauvegarder ?'**
  String get message_personal_data_backup_found_description;

  /// No description provided for @message_personal_data_backup_found_title.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde existante'**
  String get message_personal_data_backup_found_title;

  /// No description provided for @message_personal_data_delete_backup.
  ///
  /// In fr, this message translates to:
  /// **'Si vous avez tout ce dont vous avez besoin, vous pouvez supprimer la sauvegarde des notes et surlignages que vous aviez perdus. Vous ne pourrez plus les récupérer. Souhaitez-vous supprimer la sauvegarder ?'**
  String get message_personal_data_delete_backup;

  /// No description provided for @message_personal_data_not_enough_storage.
  ///
  /// In fr, this message translates to:
  /// **'Un problème est survenu et JW Library ne peut pas s\'ouvrir. Il est possible que la capacité de stockage soit insuffisante.'**
  String get message_personal_data_not_enough_storage;

  /// No description provided for @message_personal_data_restore_internal_backup_description.
  ///
  /// In fr, this message translates to:
  /// **'Une sauvegarde de vos notes et surlignages perdus lors d\'une récente mise à jour a été conservée dans JW Library. Souhaitez-vous restaurer cette sauvergarde ?'**
  String get message_personal_data_restore_internal_backup_description;

  /// No description provided for @message_personal_data_update_fail_description.
  ///
  /// In fr, this message translates to:
  /// **'Vos notes et surlignages ont été perdus au cours de la mise à jour de l\'application. Veuillez créer une sauvegarde pour que ces notes et surlignages soient conservés. Une future mise à jour de JW Library devrait permettre de restaurer cette sauvegarde.'**
  String get message_personal_data_update_fail_description;

  /// No description provided for @message_personal_data_update_fail_title.
  ///
  /// In fr, this message translates to:
  /// **'Un problème est survenu...'**
  String get message_personal_data_update_fail_title;

  /// No description provided for @message_playing_pip.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en mode image dans l\'image'**
  String get message_playing_pip;

  /// No description provided for @message_please_select_a_bible.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez une Bible pour commencer'**
  String get message_please_select_a_bible;

  /// No description provided for @message_privacy_settings.
  ///
  /// In fr, this message translates to:
  /// **'Afin que l\'application fonctionne sur votre appareil, certaines données essentielles doivent vous être transférées. De plus, pour vous offrir la meilleure expérience possible, nous recueillons des données sur l\'utilisation de cette application. Vous pouvez accepter ou refuser que nous recueillions ces données supplémentaires de diagnostic et d\'utilisation. En cliquant sur \"Accepter\", vous acceptez que nous utilisions ces données pour améliorer votre expérience et assurer le bon fonctionnement de l\'application. Aucune de ces données ne sera jamais vendue ou utilisée à des fins commerciales. Vous pouvez lire plus de détails sur notre utilisation des données et personnaliser vos paramètres à tout moment en cliquant sur \"Personnaliser\" ci-dessous ou en vous rendant sur la page des paramètres de cette application.'**
  String get message_privacy_settings;

  /// No description provided for @message_privacy_settings_title.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de confidentialité'**
  String get message_privacy_settings_title;

  /// No description provided for @message_publication_no_videos.
  ///
  /// In fr, this message translates to:
  /// **'Cette publication ne contient pas de vidéos. Elle peut être utilisée pour prendre en charge d\'autres fonctionnalités de l\'application.'**
  String get message_publication_no_videos;

  /// No description provided for @message_publication_unavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cette publication n’est pas disponible actuellement. Merci de réessayer plus tard.'**
  String get message_publication_unavailable;

  /// No description provided for @message_publication_unavailable_title.
  ///
  /// In fr, this message translates to:
  /// **'Publication non disponible'**
  String get message_publication_unavailable_title;

  /// No description provided for @message_remove_tag.
  ///
  /// In fr, this message translates to:
  /// **'Cette action supprimera la catégorie « {name} » mais les notes ne seront pas supprimées.'**
  String message_remove_tag(Object name);

  /// No description provided for @message_request_timed_out_title.
  ///
  /// In fr, this message translates to:
  /// **'Le délai d’attente est dépassé'**
  String get message_request_timed_out_title;

  /// No description provided for @message_restore_a_backup_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Les données de votre étude individuelle sur cet appareil seront écrasées'**
  String get message_restore_a_backup_explanation;

  /// No description provided for @message_restore_confirm_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Les notes, catégories, éléments surlignés, favoris, marque-pages et listes de lecture sur cet appareil seront écrasés.'**
  String get message_restore_confirm_explanation;

  /// No description provided for @message_restore_confirm_explanation_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Les listes de lecture sur cet appareil seront écrasées.'**
  String get message_restore_confirm_explanation_playlists;

  /// No description provided for @message_restore_confirm_explanation_updated.
  ///
  /// In fr, this message translates to:
  /// **'Les notes, catégories, éléments surlignés, favoris, marque-pages et listes de lecture sur cet appareil seront remplacés par la sauvegarde suivante :'**
  String get message_restore_confirm_explanation_updated;

  /// No description provided for @message_restore_failed.
  ///
  /// In fr, this message translates to:
  /// **'La restauration a échoué'**
  String get message_restore_failed;

  /// No description provided for @message_restore_failed_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Il y a un problème avec le fichier de sauvegarde.'**
  String get message_restore_failed_explanation;

  /// No description provided for @message_restore_in_progress.
  ///
  /// In fr, this message translates to:
  /// **'Restauration en cours...'**
  String get message_restore_in_progress;

  /// No description provided for @message_restore_successful.
  ///
  /// In fr, this message translates to:
  /// **'Restauration réussie'**
  String get message_restore_successful;

  /// No description provided for @message_ruby_coaching_tip.
  ///
  /// In fr, this message translates to:
  /// **'Affichez les guides de prononciation pinyin et furigana du chinois et du japonais quand ils sont disponibles.'**
  String get message_ruby_coaching_tip;

  /// No description provided for @message_search_topics_publications.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des sujets ou des publications'**
  String get message_search_topics_publications;

  /// No description provided for @message_second_window_closed.
  ///
  /// In fr, this message translates to:
  /// **'La fenêtre du deuxième écran a été fermée.'**
  String get message_second_window_closed;

  /// No description provided for @message_select_a_bible.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une Bible'**
  String get message_select_a_bible;

  /// No description provided for @message_select_video_size_title.
  ///
  /// In fr, this message translates to:
  /// **'Résolution'**
  String get message_select_video_size_title;

  /// No description provided for @message_selection_count.
  ///
  /// In fr, this message translates to:
  /// **'{count} publication(s) sélectionnée(s)'**
  String message_selection_count(Object count);

  /// No description provided for @message_setting_up.
  ///
  /// In fr, this message translates to:
  /// **'Des tâches sont en cours d\'exécution...'**
  String get message_setting_up;

  /// No description provided for @message_sideload_older_than_current.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier est plus ancien que la version actuellement téléchargée.'**
  String get message_sideload_older_than_current;

  /// No description provided for @message_sideload_overwrite.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier a mis à jour une version plus ancienne de « {title} ».'**
  String message_sideload_overwrite(Object title);

  /// No description provided for @message_sideload_unsupported_version.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas compatible avec cette version de JW Library.'**
  String get message_sideload_unsupported_version;

  /// No description provided for @message_still_watching.
  ///
  /// In fr, this message translates to:
  /// **'Nous n’aimons pas diffuser une vidéo pour rien.'**
  String get message_still_watching;

  /// No description provided for @message_still_watching_title.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous toujours là ?'**
  String get message_still_watching_title;

  /// No description provided for @message_support_code_invalid.
  ///
  /// In fr, this message translates to:
  /// **'Merci de vérifier votre code puis de réessayer.'**
  String get message_support_code_invalid;

  /// No description provided for @message_support_code_invalid_title.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get message_support_code_invalid_title;

  /// No description provided for @message_support_enter_code.
  ///
  /// In fr, this message translates to:
  /// **'Si vous avez un code de support, merci de l\'entrer pour bénéficier de l\'aide.'**
  String get message_support_enter_code;

  /// No description provided for @message_support_read_help.
  ///
  /// In fr, this message translates to:
  /// **'Trouver sur jw.org des réponses aux questions fréquentes concernant JW Library.'**
  String get message_support_read_help;

  /// No description provided for @message_support_reset_confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir désactiver la fonctionnalité d\'aide ?'**
  String get message_support_reset_confirmation;

  /// No description provided for @message_support_reset_confirmation_title.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité d\'aide'**
  String get message_support_reset_confirmation_title;

  /// No description provided for @message_tap_link.
  ///
  /// In fr, this message translates to:
  /// **'Touchez un lien.'**
  String get message_tap_link;

  /// No description provided for @message_tap_verse_number.
  ///
  /// In fr, this message translates to:
  /// **'Touchez un verset.'**
  String get message_tap_verse_number;

  /// No description provided for @message_terms_accept.
  ///
  /// In fr, this message translates to:
  /// **'En cliquant sur \"Accepter\", vous acceptez nos conditions d\'utilisation. Vous pouvez consulter nos conditions d\'utilisation et notre politique de confidentialité à tout moment sur la page Paramètres de cette application.'**
  String get message_terms_accept;

  /// No description provided for @message_terms_of_use.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez consulter nos conditions d\'utilisation. Vous devez les lire jusqu\'au bout avant de les accepter :'**
  String get message_terms_of_use;

  /// No description provided for @message_this_cannot_be_undone.
  ///
  /// In fr, this message translates to:
  /// **'La suppression sera définitive.'**
  String get message_this_cannot_be_undone;

  /// No description provided for @message_try_again_later.
  ///
  /// In fr, this message translates to:
  /// **'Merci de réessayer plus tard.'**
  String get message_try_again_later;

  /// No description provided for @message_unavailable_playlist_media.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez {title} et réessayez.'**
  String message_unavailable_playlist_media(Object title);

  /// No description provided for @message_uninstall_deletes_media.
  ///
  /// In fr, this message translates to:
  /// **'Si vous désinstallez l\'application, les fichiers téléchargés seront supprimés.'**
  String get message_uninstall_deletes_media;

  /// No description provided for @message_unrecognized_language_title.
  ///
  /// In fr, this message translates to:
  /// **'Langue non reconnue ({languageid})'**
  String message_unrecognized_language_title(Object languageid);

  /// No description provided for @message_update_android_webview.
  ///
  /// In fr, this message translates to:
  /// **'Pour que le contenu s\'affiche correctement, installer la dernière version d\'« Android System WebView » ou de « Google Chrome » depuis Google Play.'**
  String get message_update_android_webview;

  /// No description provided for @message_update_app.
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour de JW Library est nécessaire pour recevoir de nouvelles publications.'**
  String get message_update_app;

  /// No description provided for @message_update_in_progress_title.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour en cours'**
  String get message_update_in_progress_title;

  /// No description provided for @message_update_os.
  ///
  /// In fr, this message translates to:
  /// **'La mise à jour de JW Library requiert au minimum {version}.'**
  String message_update_os(Object version);

  /// No description provided for @message_update_os_description.
  ///
  /// In fr, this message translates to:
  /// **'Afin de préserver la sécurité et la fiabilité de JW Library, une configuration minimale est requise pour exécuter l\'application. Si possible, mettez à jour votre appareil avec la dernière version du système d\'exploitation. Si votre appareil ne peut pas être mis à jour, vous pourrez utiliser l\'application encore un certain temps. Cependant, vous ne pourrez plus installer les dernières mises à jour de l\'application.'**
  String get message_update_os_description;

  /// No description provided for @message_update_os_title.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour système requise'**
  String get message_update_os_title;

  /// No description provided for @message_updated_item.
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour de cet élément est disponible.'**
  String get message_updated_item;

  /// No description provided for @message_updated_publication.
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour de cette publication est disponible.'**
  String get message_updated_publication;

  /// No description provided for @message_updated_video.
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour de cette vidéo est disponible.'**
  String get message_updated_video;

  /// No description provided for @message_updated_video_trim.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez peut-être couper de nouveau cette vidéo.'**
  String get message_updated_video_trim;

  /// No description provided for @message_updated_video_trim_title.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo mise à jour'**
  String get message_updated_video_trim_title;

  /// No description provided for @message_verse_not_present.
  ///
  /// In fr, this message translates to:
  /// **'Le verset sélectionné n’existe pas dans cette Bible.'**
  String get message_verse_not_present;

  /// No description provided for @message_verses_not_present.
  ///
  /// In fr, this message translates to:
  /// **'Les versets sélectionnés n’existent pas dans cette Bible.'**
  String get message_verses_not_present;

  /// No description provided for @message_video_import_incomplete.
  ///
  /// In fr, this message translates to:
  /// **'Vos vidéos téléchargées n\'ont pas toutes été transférées.'**
  String get message_video_import_incomplete;

  /// No description provided for @message_video_import_incomplete_titel.
  ///
  /// In fr, this message translates to:
  /// **'Importation vidéo incomplète'**
  String get message_video_import_incomplete_titel;

  /// No description provided for @message_video_playback_failed.
  ///
  /// In fr, this message translates to:
  /// **'Ce format de vidéo n’est pas compatible avec votre appareil.'**
  String get message_video_playback_failed;

  /// No description provided for @message_video_playback_failed_title.
  ///
  /// In fr, this message translates to:
  /// **'La lecture de cette vidéo a échoué'**
  String get message_video_playback_failed_title;

  /// No description provided for @message_welcome_to_jw_life.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur JW Life'**
  String get message_welcome_to_jw_life;

  /// No description provided for @message_app_for_jehovah_witnesses.
  ///
  /// In fr, this message translates to:
  /// **'Une application pour la vie d\'un Témoin de Jéhovah'**
  String get message_app_for_jehovah_witnesses;

  /// No description provided for @message_download_daily_text.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger le Texte du jour de l\'année {year}'**
  String message_download_daily_text(Object year);

  /// No description provided for @message_whatsnew_add_favorites.
  ///
  /// In fr, this message translates to:
  /// **'Touchez le bouton « Autres fonctions » pour ajouter aux favoris'**
  String get message_whatsnew_add_favorites;

  /// No description provided for @message_whatsnew_audio_recordings.
  ///
  /// In fr, this message translates to:
  /// **'Écouter les enregistrements audio de la Bible ou d\'autres publications'**
  String get message_whatsnew_audio_recordings;

  /// No description provided for @message_whatsnew_bible_gem.
  ///
  /// In fr, this message translates to:
  /// **'Dans la Bible, utiliser l\'icône diamant dans le menu contextuel pour afficher tous les contenus d\'étude en lien avec un verset, dont les références du Guide de recherche.'**
  String get message_whatsnew_bible_gem;

  /// No description provided for @message_whatsnew_bookmarks.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez un marque-page sur une sélection de texte.'**
  String get message_whatsnew_bookmarks;

  /// No description provided for @message_whatsnew_create_tags.
  ///
  /// In fr, this message translates to:
  /// **'Créez des catégories pour classer vos publications et vos notes.'**
  String get message_whatsnew_create_tags;

  /// No description provided for @message_whatsnew_download_media.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez des fichiers audio et vidéo associés à une publication.'**
  String get message_whatsnew_download_media;

  /// No description provided for @message_whatsnew_download_sorting.
  ///
  /// In fr, this message translates to:
  /// **'Triez les publications téléchargées de différentes manières'**
  String get message_whatsnew_download_sorting;

  /// No description provided for @message_whatsnew_highlight.
  ///
  /// In fr, this message translates to:
  /// **'Pour surligner : toucher l\'écran et glisser le doigt sur le texte.'**
  String get message_whatsnew_highlight;

  /// No description provided for @message_whatsnew_highlight_textselection.
  ///
  /// In fr, this message translates to:
  /// **'Surlignez du texte.'**
  String get message_whatsnew_highlight_textselection;

  /// No description provided for @message_whatsnew_home.
  ///
  /// In fr, this message translates to:
  /// **'La section Accueil affiche les publications que vous utilisez le plus souvent'**
  String get message_whatsnew_home;

  /// No description provided for @message_whatsnew_many_sign_languages.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez maintenant télécharger des vidéos dans de nombreuses langues des signes !'**
  String get message_whatsnew_many_sign_languages;

  /// No description provided for @message_whatsnew_media.
  ///
  /// In fr, this message translates to:
  /// **'La section Multimédia permet d\'explorer les contenus audio et vidéo'**
  String get message_whatsnew_media;

  /// No description provided for @message_whatsnew_meetings.
  ///
  /// In fr, this message translates to:
  /// **'Voir les publications utilisées pendant les réunions'**
  String get message_whatsnew_meetings;

  /// No description provided for @message_whatsnew_noversion_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés de JW Library'**
  String get message_whatsnew_noversion_title;

  /// No description provided for @message_whatsnew_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Créez des listes de lecture contenant vos vidéos préférées.'**
  String get message_whatsnew_playlists;

  /// No description provided for @message_whatsnew_research_guide.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez le Guide de recherche pour voir apparaître des références utiles dans le volet d\'étude de la Bible.'**
  String get message_whatsnew_research_guide;

  /// No description provided for @message_whatsnew_sign_language.
  ///
  /// In fr, this message translates to:
  /// **'Des publications en langues des signes sont disponibles.'**
  String get message_whatsnew_sign_language;

  /// No description provided for @message_whatsnew_sign_language_migration.
  ///
  /// In fr, this message translates to:
  /// **'Attendez, s\'il vous plaît. Vos vidéos sont en train d\'être transférées sur la nouvelle version. Cela peut prendre du temps.'**
  String get message_whatsnew_sign_language_migration;

  /// No description provided for @message_whatsnew_stream.
  ///
  /// In fr, this message translates to:
  /// **'Possibilité de regarder en streaming ou de télécharger les vidéos ou les chansons.'**
  String get message_whatsnew_stream;

  /// No description provided for @message_whatsnew_stream_video.
  ///
  /// In fr, this message translates to:
  /// **'Regarder en streaming ou télécharger les vidéos.'**
  String get message_whatsnew_stream_video;

  /// No description provided for @message_whatsnew_study_edition.
  ///
  /// In fr, this message translates to:
  /// **'L\'édition d\'étude de la Traduction du monde nouveau est maintenant disponible !'**
  String get message_whatsnew_study_edition;

  /// No description provided for @message_whatsnew_take_notes.
  ///
  /// In fr, this message translates to:
  /// **'Créez des notes quand vous étudiez'**
  String get message_whatsnew_take_notes;

  /// No description provided for @message_whatsnew_tap_longpress.
  ///
  /// In fr, this message translates to:
  /// **'Pour regarder en streaming : touchez. Pour télécharger : appuyez longtemps ou faites un clic droit.'**
  String get message_whatsnew_tap_longpress;

  /// No description provided for @message_whatsnew_title.
  ///
  /// In fr, this message translates to:
  /// **'Quoi de neuf sur JW Library {version} ?'**
  String message_whatsnew_title(Object version);

  /// No description provided for @messages_coaching_appearance_setting_description.
  ///
  /// In fr, this message translates to:
  /// **'L\'apparence claire ou sombre peut être selectionnée dans les Paramètres.'**
  String get messages_coaching_appearance_setting_description;

  /// No description provided for @messages_coaching_library_tab_description.
  ///
  /// In fr, this message translates to:
  /// **'Les onglets « Publications » et « Multimédia » ont été fusionnés en un nouvel onglet « Bibliothèque ».'**
  String get messages_coaching_library_tab_description;

  /// No description provided for @messages_convention_releases_prompt.
  ///
  /// In fr, this message translates to:
  /// **'Avez-vous déjà assisté à l\'assemblée régionale de cette année ?'**
  String get messages_convention_releases_prompt;

  /// No description provided for @messages_convention_releases_prompt_watched.
  ///
  /// In fr, this message translates to:
  /// **'As-tu déjà regardé l\'assemblée régionale de cette année?'**
  String get messages_convention_releases_prompt_watched;

  /// No description provided for @messages_convention_theme_2015.
  ///
  /// In fr, this message translates to:
  /// **'Imitons Jésus !'**
  String get messages_convention_theme_2015;

  /// No description provided for @messages_convention_theme_2016.
  ///
  /// In fr, this message translates to:
  /// **'Restons fidèles à Jéhovah !'**
  String get messages_convention_theme_2016;

  /// No description provided for @messages_convention_theme_2017.
  ///
  /// In fr, this message translates to:
  /// **'Ne renoncez pas !'**
  String get messages_convention_theme_2017;

  /// No description provided for @messages_convention_theme_2018.
  ///
  /// In fr, this message translates to:
  /// **'« Soyez courageux ! »'**
  String get messages_convention_theme_2018;

  /// No description provided for @messages_empty_downloads.
  ///
  /// In fr, this message translates to:
  /// **'Les publications que vous téléchargez s’afficheront ici.'**
  String get messages_empty_downloads;

  /// No description provided for @messages_empty_favorites.
  ///
  /// In fr, this message translates to:
  /// **'Vos favoris apparaîtront ici.'**
  String get messages_empty_favorites;

  /// No description provided for @messages_help_download_bibles.
  ///
  /// In fr, this message translates to:
  /// **'Pour télécharger d’autres traductions, allez dans la section Bible et touchez le bouton « Langues ».'**
  String get messages_help_download_bibles;

  /// No description provided for @messages_internal_publication.
  ///
  /// In fr, this message translates to:
  /// **'Il s’agit d’une publication à l’usage exclusif des assemblées des Témoins de Jéhovah, et non diffusée auprès du public.'**
  String get messages_internal_publication;

  /// No description provided for @messages_internal_publication_title.
  ///
  /// In fr, this message translates to:
  /// **'Continuer le téléchargement ?'**
  String get messages_internal_publication_title;

  /// No description provided for @messages_locked_sd_card.
  ///
  /// In fr, this message translates to:
  /// **'Votre appareil n\'autorise pas JW Library à enregistrer des fichiers sur votre carte SD.'**
  String get messages_locked_sd_card;

  /// No description provided for @messages_no_new_publications.
  ///
  /// In fr, this message translates to:
  /// **'Il n’y a pas de nouvelles publications dans cette langue.'**
  String get messages_no_new_publications;

  /// No description provided for @messages_no_pending_updates.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les publications téléchargées sont à jour.'**
  String get messages_no_pending_updates;

  /// No description provided for @messages_tap_publication_type.
  ///
  /// In fr, this message translates to:
  /// **'Touchez une catégorie.'**
  String get messages_tap_publication_type;

  /// No description provided for @messages_turn_on_pip.
  ///
  /// In fr, this message translates to:
  /// **'Pour lire cette vidéo en mode « image dans l\'image », activer l\'option pour cette application.'**
  String get messages_turn_on_pip;

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

  /// No description provided for @navigation_favorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get navigation_favorites;

  /// No description provided for @navigation_frequently_used.
  ///
  /// In fr, this message translates to:
  /// **'Souvent Utilisé'**
  String get navigation_frequently_used;

  /// No description provided for @navigation_ministry.
  ///
  /// In fr, this message translates to:
  /// **'Panoplie d’enseignant'**
  String get navigation_ministry;

  /// No description provided for @navigation_whats_new.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get navigation_whats_new;

  /// No description provided for @navigation_online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get navigation_online;

  /// No description provided for @navigation_official_website.
  ///
  /// In fr, this message translates to:
  /// **'Site Web Officiel'**
  String get navigation_official_website;

  /// No description provided for @navigation_online_broadcasting.
  ///
  /// In fr, this message translates to:
  /// **'JW Télédiffusion'**
  String get navigation_online_broadcasting;

  /// No description provided for @navigation_online_library.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque en ligne'**
  String get navigation_online_library;

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

  /// No description provided for @navigation_bible_reading.
  ///
  /// In fr, this message translates to:
  /// **'Ma lecture de la Bible'**
  String get navigation_bible_reading;

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

  /// No description provided for @navigation_workship_meetings.
  ///
  /// In fr, this message translates to:
  /// **'RÉUNIONS'**
  String get navigation_workship_meetings;

  /// No description provided for @navigation_workship_conventions.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉES'**
  String get navigation_workship_conventions;

  /// No description provided for @navigation_drawer_content_description.
  ///
  /// In fr, this message translates to:
  /// **'Panneau de navigation'**
  String get navigation_drawer_content_description;

  /// No description provided for @navigation_meetings_assembly.
  ///
  /// In fr, this message translates to:
  /// **'Assemblée de circonscription'**
  String get navigation_meetings_assembly;

  /// No description provided for @navigation_meetings_assembly_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE DE CIRCONSCRIPTION'**
  String get navigation_meetings_assembly_uppercase;

  /// No description provided for @navigation_meetings_convention.
  ///
  /// In fr, this message translates to:
  /// **'Assemblée régionale'**
  String get navigation_meetings_convention;

  /// No description provided for @navigation_meetings_convention_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ASSEMBLÉE RÉGIONALE'**
  String get navigation_meetings_convention_uppercase;

  /// No description provided for @navigation_meetings_life_and_ministry.
  ///
  /// In fr, this message translates to:
  /// **'Vie et ministère'**
  String get navigation_meetings_life_and_ministry;

  /// No description provided for @navigation_meetings_life_and_ministry_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'VIE ET MINISTÈRE'**
  String get navigation_meetings_life_and_ministry_uppercase;

  /// No description provided for @navigation_meetings_show_media.
  ///
  /// In fr, this message translates to:
  /// **'Voir les médias'**
  String get navigation_meetings_show_media;

  /// No description provided for @navigation_meetings_watchtower_study.
  ///
  /// In fr, this message translates to:
  /// **'Étude de La Tour de Garde'**
  String get navigation_meetings_watchtower_study;

  /// No description provided for @navigation_meetings_watchtower_study_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'ÉTUDE DE LA TOUR DE GARDE'**
  String get navigation_meetings_watchtower_study_uppercase;

  /// No description provided for @navigation_menu.
  ///
  /// In fr, this message translates to:
  /// **'Menu de navigation'**
  String get navigation_menu;

  /// No description provided for @navigation_notes_and_tag.
  ///
  /// In fr, this message translates to:
  /// **'Notes et Catégories'**
  String get navigation_notes_and_tag;

  /// No description provided for @navigation_personal_study.
  ///
  /// In fr, this message translates to:
  /// **'Étude individuelle'**
  String get navigation_personal_study;

  /// No description provided for @navigation_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Listes de lecture'**
  String get navigation_playlists;

  /// No description provided for @navigation_publications.
  ///
  /// In fr, this message translates to:
  /// **'Publications'**
  String get navigation_publications;

  /// No description provided for @navigation_publications_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PUBLICATIONS'**
  String get navigation_publications_uppercase;

  /// No description provided for @navigation_pubs_by_type.
  ///
  /// In fr, this message translates to:
  /// **'Par catégorie'**
  String get navigation_pubs_by_type;

  /// No description provided for @navigation_pubs_by_type_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'PAR CATÉGORIE'**
  String get navigation_pubs_by_type_uppercase;

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
  /// **'Audios'**
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

  /// No description provided for @pub_type_bibles.
  ///
  /// In fr, this message translates to:
  /// **'Bibles'**
  String get pub_type_bibles;

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
  /// **'Dossiers d’information'**
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

  /// No description provided for @pub_type_videos_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'VIDÉOS'**
  String get pub_type_videos_uppercase;

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

  /// No description provided for @search_all_results.
  ///
  /// In fr, this message translates to:
  /// **'Tous les résultats'**
  String get search_all_results;

  /// No description provided for @search_bar_search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search_bar_search;

  /// No description provided for @search_commonly_used.
  ///
  /// In fr, this message translates to:
  /// **'Souvent cités'**
  String get search_commonly_used;

  /// No description provided for @search_match_exact_phrase.
  ///
  /// In fr, this message translates to:
  /// **'Expression exacte'**
  String get search_match_exact_phrase;

  /// No description provided for @search_menu_title.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search_menu_title;

  /// No description provided for @search_prompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisir une expression ou un numéro de page'**
  String get search_prompt;

  /// No description provided for @search_prompt_languages.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une langue ({count})'**
  String search_prompt_languages(Object count);

  /// No description provided for @search_prompt_playlists.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une liste de lecture ({count})'**
  String search_prompt_playlists(Object count);

  /// No description provided for @search_results_articles.
  ///
  /// In fr, this message translates to:
  /// **'Articles'**
  String get search_results_articles;

  /// No description provided for @search_results_none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get search_results_none;

  /// No description provided for @search_results_occurence.
  ///
  /// In fr, this message translates to:
  /// **'1 résultat'**
  String get search_results_occurence;

  /// No description provided for @search_results_occurences.
  ///
  /// In fr, this message translates to:
  /// **'{count} résultats'**
  String search_results_occurences(Object count);

  /// No description provided for @search_results_title.
  ///
  /// In fr, this message translates to:
  /// **'Résultats de la recherche'**
  String get search_results_title;

  /// No description provided for @search_results_title_with_query.
  ///
  /// In fr, this message translates to:
  /// **'Résultats pour « {query} »'**
  String search_results_title_with_query(Object query);

  /// No description provided for @search_suggestion_page_number_title.
  ///
  /// In fr, this message translates to:
  /// **'Page {number}, {title}'**
  String search_suggestion_page_number_title(Object number, Object title);

  /// No description provided for @search_suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions'**
  String get search_suggestions;

  /// No description provided for @search_suggestions_page_number.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de page'**
  String get search_suggestions_page_number;

  /// No description provided for @search_results_per_chronological.
  ///
  /// In fr, this message translates to:
  /// **'CHRONOLOGIQUE'**
  String get search_results_per_chronological;

  /// No description provided for @search_results_per_top_verses.
  ///
  /// In fr, this message translates to:
  /// **'LES PLUS CITÉS'**
  String get search_results_per_top_verses;

  /// No description provided for @search_results_per_occurences.
  ///
  /// In fr, this message translates to:
  /// **'OCCURENCES'**
  String get search_results_per_occurences;

  /// No description provided for @search_show_less.
  ///
  /// In fr, this message translates to:
  /// **'VOIR MOINS'**
  String get search_show_less;

  /// No description provided for @search_show_more.
  ///
  /// In fr, this message translates to:
  /// **'VOIR PLUS'**
  String get search_show_more;

  /// No description provided for @search_suggestions_recent.
  ///
  /// In fr, this message translates to:
  /// **'Récent'**
  String get search_suggestions_recent;

  /// No description provided for @search_suggestions_topics.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrages de référence'**
  String get search_suggestions_topics;

  /// No description provided for @search_suggestions_topics_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'OUVRAGES DE RÉFÉRENCE'**
  String get search_suggestions_topics_uppercase;

  /// No description provided for @searchview_clear_text_content_description.
  ///
  /// In fr, this message translates to:
  /// **'Effacer le texte'**
  String get searchview_clear_text_content_description;

  /// No description provided for @searchview_navigation_content_description.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get searchview_navigation_content_description;

  /// No description provided for @selected.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionné'**
  String get selected;

  /// No description provided for @settings_about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settings_about;

  /// No description provided for @settings_about_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'À PROPOS'**
  String get settings_about_uppercase;

  /// No description provided for @settings_acknowledgements.
  ///
  /// In fr, this message translates to:
  /// **'Remerciements'**
  String get settings_acknowledgements;

  /// No description provided for @settings_always.
  ///
  /// In fr, this message translates to:
  /// **'Toujours'**
  String get settings_always;

  /// No description provided for @settings_always_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TOUJOURS'**
  String get settings_always_uppercase;

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

  /// No description provided for @settings_appearance_display_upper.
  ///
  /// In fr, this message translates to:
  /// **'AFFICHAGE'**
  String get settings_appearance_display_upper;

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

  /// No description provided for @settings_application_version.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settings_application_version;

  /// No description provided for @settings_ask_every_time.
  ///
  /// In fr, this message translates to:
  /// **'Toujours demander'**
  String get settings_ask_every_time;

  /// No description provided for @settings_ask_every_time_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'TOUJOURS DEMANDER'**
  String get settings_ask_every_time_uppercase;

  /// No description provided for @settings_audio_player_controls.
  ///
  /// In fr, this message translates to:
  /// **'Commandes du lecteur audio'**
  String get settings_audio_player_controls;

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

  /// No description provided for @settings_bad_windows_music_library.
  ///
  /// In fr, this message translates to:
  /// **'La Bibliothèque Musique n\'a pas de lieu d\'enregistrement défini. Dans l\'Explorateur, ouvrez les Propriétés de Bibliothèques\\Musique et définissez un lieu d\'enregistrement.'**
  String get settings_bad_windows_music_library;

  /// No description provided for @settings_bad_windows_video_library.
  ///
  /// In fr, this message translates to:
  /// **'La Bibliothèque Vidéos n\'a pas de lieu d\'enregistrement défini. Dans l\'Explorateur, ouvrez les Propriétés de Bibliothèques\\Vidéos et définissez un lieu d\'enregistrement.'**
  String get settings_bad_windows_video_library;

  /// No description provided for @settings_cache.
  ///
  /// In fr, this message translates to:
  /// **'Cache'**
  String get settings_cache;

  /// No description provided for @settings_cache_upper.
  ///
  /// In fr, this message translates to:
  /// **'CACHE'**
  String get settings_cache_upper;

  /// No description provided for @settings_catalog_date.
  ///
  /// In fr, this message translates to:
  /// **'Date du catalogue'**
  String get settings_catalog_date;

  /// No description provided for @settings_library_date.
  ///
  /// In fr, this message translates to:
  /// **'Date de la bibliothèque'**
  String get settings_library_date;

  /// No description provided for @settings_category_app_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'APPLICATION'**
  String get settings_category_app_uppercase;

  /// No description provided for @settings_category_download.
  ///
  /// In fr, this message translates to:
  /// **'Lecture et téléchargement'**
  String get settings_category_download;

  /// No description provided for @settings_category_download_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'LECTURE ET TÉLÉCHARGEMENT'**
  String get settings_category_download_uppercase;

  /// No description provided for @settings_category_legal.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get settings_category_legal;

  /// No description provided for @settings_category_legal_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'MENTIONS LÉGALES'**
  String get settings_category_legal_uppercase;

  /// No description provided for @settings_category_playlists_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'LISTES DE LECTURE'**
  String get settings_category_playlists_uppercase;

  /// No description provided for @settings_category_privacy_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Afin que l\'application fonctionne sur votre appareil, certaines données essentielles doivent vous être transférées. Aucune de ces données ne sera jamais vendue ou utilisée à des fins commerciales. Pour plus d\'informations, veuillez lire {settings_how_jwl_uses_your_data}.'**
  String settings_category_privacy_subtitle(
    Object settings_how_jwl_uses_your_data,
  );

  /// No description provided for @settings_default_end_action.
  ///
  /// In fr, this message translates to:
  /// **'Action de fin de lecture par défaut'**
  String get settings_default_end_action;

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

  /// No description provided for @settings_how_jwl_uses_your_data.
  ///
  /// In fr, this message translates to:
  /// **'Comment JW Library utilise vos données'**
  String get settings_how_jwl_uses_your_data;

  /// No description provided for @settings_languages.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settings_languages;

  /// No description provided for @settings_languages_upper.
  ///
  /// In fr, this message translates to:
  /// **'LANGUES'**
  String get settings_languages_upper;

  /// No description provided for @settings_language_app.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'Application'**
  String get settings_language_app;

  /// No description provided for @settings_language_library.
  ///
  /// In fr, this message translates to:
  /// **'Langue de la Bibliothèque'**
  String get settings_language_library;

  /// No description provided for @settings_license.
  ///
  /// In fr, this message translates to:
  /// **'Contrat de licence'**
  String get settings_license;

  /// No description provided for @settings_license_agreement.
  ///
  /// In fr, this message translates to:
  /// **'Contrat de licence'**
  String get settings_license_agreement;

  /// No description provided for @settings_main_color.
  ///
  /// In fr, this message translates to:
  /// **'Couleur principale'**
  String get settings_main_color;

  /// No description provided for @settings_main_books_color.
  ///
  /// In fr, this message translates to:
  /// **'Couleur des livres de la Bible'**
  String get settings_main_books_color;

  /// No description provided for @settings_never.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get settings_never;

  /// No description provided for @settings_never_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'JAMAIS'**
  String get settings_never_uppercase;

  /// No description provided for @settings_notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications et rappels'**
  String get settings_notifications;

  /// No description provided for @settings_notifications_upper.
  ///
  /// In fr, this message translates to:
  /// **'NOTIFICATIONS & RAPPELS'**
  String get settings_notifications_upper;

  /// No description provided for @settings_notifications_daily_text.
  ///
  /// In fr, this message translates to:
  /// **'Rappel du text du jour'**
  String get settings_notifications_daily_text;

  /// No description provided for @settings_notifications_hour.
  ///
  /// In fr, this message translates to:
  /// **'Heure du rappel: {hour}'**
  String settings_notifications_hour(Object hour);

  /// No description provided for @settings_notifications_bible_reading.
  ///
  /// In fr, this message translates to:
  /// **'Rappel de la lecture de la bible'**
  String get settings_notifications_bible_reading;

  /// No description provided for @settings_notifications_download_file.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de fichiers téléchargés'**
  String get settings_notifications_download_file;

  /// No description provided for @settings_notifications_download_file_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Une notification est envoyée chaque fois qu’un fichier est téléchargé.'**
  String get settings_notifications_download_file_subtitle;

  /// No description provided for @settings_offline_mode.
  ///
  /// In fr, this message translates to:
  /// **'Mode « hors ligne »'**
  String get settings_offline_mode;

  /// No description provided for @settings_offline_mode_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Économise des données en désactivant l\'accès à Internet sur JW Library.'**
  String get settings_offline_mode_subtitle;

  /// No description provided for @settings_open_source_licenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences Open Source'**
  String get settings_open_source_licenses;

  /// No description provided for @settings_play_video_second_display.
  ///
  /// In fr, this message translates to:
  /// **'Lire la vidéo sur le deuxième écran'**
  String get settings_play_video_second_display;

  /// No description provided for @settings_privacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settings_privacy;

  /// No description provided for @settings_privacy_policy.
  ///
  /// In fr, this message translates to:
  /// **'Règles de confidentialité'**
  String get settings_privacy_policy;

  /// No description provided for @settings_privacy_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'CONFIDENTIALITÉ'**
  String get settings_privacy_uppercase;

  /// No description provided for @settings_send_diagnostic_data.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer des données de diagnostic'**
  String get settings_send_diagnostic_data;

  /// No description provided for @settings_send_diagnostic_data_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous aimerions recueillir des informations lorsque l\'application se bloque ou présente une erreur. Nous n\'utilisons ces données que pour assurer le bon fonctionnement de l\'application.'**
  String get settings_send_diagnostic_data_subtitle;

  /// No description provided for @settings_send_usage_data.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer les données d\'utilisation'**
  String get settings_send_usage_data;

  /// No description provided for @settings_send_usage_data_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous souhaitons recueillir des informations sur la façon dont vous utilisez et interagissez avec l\'application. Nous utilisons ces données uniquement pour améliorer l\'application, notamment sa conception, ses performances et sa stabilité.'**
  String get settings_send_usage_data_subtitle;

  /// No description provided for @settings_start_action.
  ///
  /// In fr, this message translates to:
  /// **'Action à l\'ouverture'**
  String get settings_start_action;

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

  /// No description provided for @settings_subtitles_not_available.
  ///
  /// In fr, this message translates to:
  /// **'Non disponibles'**
  String get settings_subtitles_not_available;

  /// No description provided for @settings_suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions & Bugs'**
  String get settings_suggestions;

  /// No description provided for @settings_suggestions_upper.
  ///
  /// In fr, this message translates to:
  /// **'SUGGESTIONS & BUGS'**
  String get settings_suggestions_upper;

  /// No description provided for @settings_suggestions_send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une suggestion'**
  String get settings_suggestions_send;

  /// No description provided for @settings_suggestions_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre suggestion dans un champ qui sera automatiquement envoyé au développeur.'**
  String get settings_suggestions_subtitle;

  /// No description provided for @settings_bugs_send.
  ///
  /// In fr, this message translates to:
  /// **'Décrire un bug rencontré'**
  String get settings_bugs_send;

  /// No description provided for @settings_bugs_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre bug dans un champ qui sera automatiquement envoyé au développeur.'**
  String get settings_bugs_subtitle;

  /// No description provided for @settings_support.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get settings_support;

  /// No description provided for @settings_terms_of_use.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d’utilisation'**
  String get settings_terms_of_use;

  /// No description provided for @settings_userdata.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde'**
  String get settings_userdata;

  /// No description provided for @settings_userdata_upper.
  ///
  /// In fr, this message translates to:
  /// **'SAUVEGARDE'**
  String get settings_userdata_upper;

  /// No description provided for @settings_userdata_import.
  ///
  /// In fr, this message translates to:
  /// **'Importer une sauvegarde'**
  String get settings_userdata_import;

  /// No description provided for @settings_userdata_export.
  ///
  /// In fr, this message translates to:
  /// **'Exporter la sauvegarde'**
  String get settings_userdata_export;

  /// No description provided for @settings_userdata_reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser cette sauvegarde'**
  String get settings_userdata_reset;

  /// No description provided for @settings_userdata_export_jwlibrary.
  ///
  /// In fr, this message translates to:
  /// **'Exporter les données utilisateur vers JW Library'**
  String get settings_userdata_export_jwlibrary;

  /// No description provided for @settings_video_display.
  ///
  /// In fr, this message translates to:
  /// **'Deuxième écran'**
  String get settings_video_display;

  /// No description provided for @settings_video_display_uppercase.
  ///
  /// In fr, this message translates to:
  /// **'DEUXIÈME ÉCRAN'**
  String get settings_video_display_uppercase;

  /// No description provided for @message_download_publication.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous télécharger « {publicationTitle} » ?'**
  String message_download_publication(Object publicationTitle);

  /// No description provided for @message_import_data.
  ///
  /// In fr, this message translates to:
  /// **'Importation des données de l\'app en cours…'**
  String get message_import_data;

  /// No description provided for @label_sort_title_asc.
  ///
  /// In fr, this message translates to:
  /// **'Titre (A-Z)'**
  String get label_sort_title_asc;

  /// No description provided for @label_sort_title_desc.
  ///
  /// In fr, this message translates to:
  /// **'Titre (Z-A)'**
  String get label_sort_title_desc;

  /// No description provided for @label_sort_year_asc.
  ///
  /// In fr, this message translates to:
  /// **'Année (Plus ancien)'**
  String get label_sort_year_asc;

  /// No description provided for @label_sort_year_desc.
  ///
  /// In fr, this message translates to:
  /// **'Année (Plus récent)'**
  String get label_sort_year_desc;

  /// No description provided for @label_sort_symbol_asc.
  ///
  /// In fr, this message translates to:
  /// **'Symbole (A-Z)'**
  String get label_sort_symbol_asc;

  /// No description provided for @label_sort_symbol_desc.
  ///
  /// In fr, this message translates to:
  /// **'Symbole (Z-A)'**
  String get label_sort_symbol_desc;

  /// No description provided for @message_delete_publication.
  ///
  /// In fr, this message translates to:
  /// **'Publication supprimée'**
  String get message_delete_publication;

  /// No description provided for @message_update_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Mis à jour annulée'**
  String get message_update_cancel;

  /// No description provided for @message_download_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement annulé'**
  String get message_download_cancel;

  /// No description provided for @message_item_download_title.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » n\'est pas téléchargé'**
  String message_item_download_title(Object title);

  /// No description provided for @message_item_download.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous télécharger « {title} » ?'**
  String message_item_download(Object title);

  /// No description provided for @message_item_downloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de « {title} »'**
  String message_item_downloading(Object title);

  /// No description provided for @message_confirm_userdata_reset_title.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la réinitialisation'**
  String get message_confirm_userdata_reset_title;

  /// No description provided for @message_confirm_userdata_reset.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment réinitialiser cette sauvegarde ? Vous perdrez toutes vos données de votre étude individuelle. Cette action est irréversible.'**
  String get message_confirm_userdata_reset;

  /// No description provided for @message_exporting_userdata.
  ///
  /// In fr, this message translates to:
  /// **'Exportation des données en cours...'**
  String get message_exporting_userdata;

  /// No description provided for @message_delete_userdata_title.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde supprimée'**
  String get message_delete_userdata_title;

  /// No description provided for @message_delete_userdata.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde a bien été supprimée.'**
  String get message_delete_userdata;

  /// No description provided for @message_file_not_supported_1_extension.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier doit avoir une extension {extention}.'**
  String message_file_not_supported_1_extension(Object extention);

  /// No description provided for @message_file_not_supported_2_extensions.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier doit avoir une extension {exention1} ou {extention2}.'**
  String message_file_not_supported_2_extensions(
    Object exention1,
    Object extention2,
  );

  /// No description provided for @message_file_not_supported_multiple_extensions.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier doit avoir l\'une des extensions suivantes : {extensions}.'**
  String message_file_not_supported_multiple_extensions(Object extensions);

  /// No description provided for @message_file_error_title.
  ///
  /// In fr, this message translates to:
  /// **'Erreur avec le fichier'**
  String get message_file_error_title;

  /// No description provided for @message_file_error.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier {extension} sélectionné est corrompu ou invalide. Veuillez vérifier le fichier et réessayer.'**
  String message_file_error(Object extension);

  /// No description provided for @message_publication_invalid_title.
  ///
  /// In fr, this message translates to:
  /// **'Mauvaise publication'**
  String get message_publication_invalid_title;

  /// No description provided for @message_publication_invalid.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier .jwpub sélectionné ne correspond pas à la publication requise. Veuillez choisir une publication avec pour symbol « {symbol} ».'**
  String message_publication_invalid(Object symbol);

  /// No description provided for @message_import_playlist_successful.
  ///
  /// In fr, this message translates to:
  /// **'Importation de la liste de lecture réussi.'**
  String get message_import_playlist_successful;

  /// No description provided for @message_userdata_reseting.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisation de la sauvegarde en cours…'**
  String get message_userdata_reseting;

  /// No description provided for @message_download_in_progress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en cours...'**
  String get message_download_in_progress;

  /// No description provided for @label_tag_notes.
  ///
  /// In fr, this message translates to:
  /// **'{count} notes'**
  String label_tag_notes(Object count);

  /// No description provided for @label_tags_and_notes.
  ///
  /// In fr, this message translates to:
  /// **'{count1} catégories et {count2} notes'**
  String label_tags_and_notes(Object count1, Object count2);

  /// No description provided for @message_delete_playlist_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la liste de lecture'**
  String get message_delete_playlist_title;

  /// No description provided for @message_delete_playlist.
  ///
  /// In fr, this message translates to:
  /// **'Cette action supprimera définitivement la liste de lecture « {name} ».'**
  String message_delete_playlist(Object name);

  /// No description provided for @message_delete_item.
  ///
  /// In fr, this message translates to:
  /// **'« {item} » a été supprimé'**
  String message_delete_item(Object item);

  /// No description provided for @message_app_up_to_date.
  ///
  /// In fr, this message translates to:
  /// **' Aucune mise à jour disponible (version actuelle: {currentVersion})'**
  String message_app_up_to_date(Object currentVersion);

  /// No description provided for @message_app_update_available.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle version disponible'**
  String get message_app_update_available;

  /// No description provided for @label_next_meeting.
  ///
  /// In fr, this message translates to:
  /// **'PROCHAINE RÉUNION'**
  String get label_next_meeting;

  /// No description provided for @label_date_next_meeting.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {hour}:{minute}'**
  String label_date_next_meeting(Object date, Object hour, Object minute);

  /// No description provided for @label_workship_public_talk_choosing.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le numéro de discours ici...'**
  String get label_workship_public_talk_choosing;

  /// No description provided for @action_public_talk_replace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer le discours'**
  String get action_public_talk_replace;

  /// No description provided for @action_public_talk_choose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un discours'**
  String get action_public_talk_choose;

  /// No description provided for @action_public_talk_remove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le discours'**
  String get action_public_talk_remove;

  /// No description provided for @action_congregations.
  ///
  /// In fr, this message translates to:
  /// **'Assemblées Locales'**
  String get action_congregations;

  /// No description provided for @action_meeting_management.
  ///
  /// In fr, this message translates to:
  /// **'Planning des Réunions'**
  String get action_meeting_management;

  /// No description provided for @action_brothers_and_sisters.
  ///
  /// In fr, this message translates to:
  /// **'Frères et Sœurs'**
  String get action_brothers_and_sisters;

  /// No description provided for @action_blocking_horizontally_mode.
  ///
  /// In fr, this message translates to:
  /// **'Blocage Horizontal'**
  String get action_blocking_horizontally_mode;

  /// No description provided for @action_qr_code.
  ///
  /// In fr, this message translates to:
  /// **'Générer un code QR'**
  String get action_qr_code;

  /// No description provided for @action_scan_qr_code.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un Code QR'**
  String get action_scan_qr_code;

  /// No description provided for @settings_page_transition.
  ///
  /// In fr, this message translates to:
  /// **'Transition des pages'**
  String get settings_page_transition;

  /// No description provided for @settings_page_transition_bottom.
  ///
  /// In fr, this message translates to:
  /// **'Transition par le bas'**
  String get settings_page_transition_bottom;

  /// No description provided for @settings_page_transition_right.
  ///
  /// In fr, this message translates to:
  /// **'Transition par la droite'**
  String get settings_page_transition_right;

  /// No description provided for @label_research_all.
  ///
  /// In fr, this message translates to:
  /// **'TOUT'**
  String get label_research_all;

  /// No description provided for @label_research_wol.
  ///
  /// In fr, this message translates to:
  /// **'WOL'**
  String get label_research_wol;

  /// No description provided for @label_research_bible.
  ///
  /// In fr, this message translates to:
  /// **'BIBLE'**
  String get label_research_bible;

  /// No description provided for @label_research_verses.
  ///
  /// In fr, this message translates to:
  /// **'VERSETS'**
  String get label_research_verses;

  /// No description provided for @label_research_images.
  ///
  /// In fr, this message translates to:
  /// **'IMAGES'**
  String get label_research_images;

  /// No description provided for @label_research_notes.
  ///
  /// In fr, this message translates to:
  /// **'NOTES'**
  String get label_research_notes;

  /// No description provided for @label_research_inputs_fields.
  ///
  /// In fr, this message translates to:
  /// **'CHAMPS'**
  String get label_research_inputs_fields;

  /// No description provided for @label_research_wikipedia.
  ///
  /// In fr, this message translates to:
  /// **'WIKIPÉDIA'**
  String get label_research_wikipedia;

  /// No description provided for @meps_language.
  ///
  /// In fr, this message translates to:
  /// **'F'**
  String get meps_language;

  /// No description provided for @label_icon_commentary.
  ///
  /// In fr, this message translates to:
  /// **'Note d\'étude'**
  String get label_icon_commentary;

  /// No description provided for @label_verses_side_by_side.
  ///
  /// In fr, this message translates to:
  /// **'Versets côte à côte'**
  String get label_verses_side_by_side;

  /// No description provided for @message_verses_side_by_side.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les deux premières traductions côte à côte'**
  String get message_verses_side_by_side;

  /// No description provided for @settings_menu_display_upper.
  ///
  /// In fr, this message translates to:
  /// **'MENU'**
  String get settings_menu_display_upper;

  /// No description provided for @settings_show_publication_description.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la description des publications'**
  String get settings_show_publication_description;

  /// No description provided for @settings_show_publication_description_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la description qui a sur le site internet en dessous du titre.'**
  String get settings_show_publication_description_subtitle;

  /// No description provided for @settings_show_document_description.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la description pour les documents'**
  String get settings_show_document_description;

  /// No description provided for @settings_show_document_description_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la description qui a sur le site internet en dessous des documents'**
  String get settings_show_document_description_subtitle;

  /// No description provided for @settings_menu_auto_open_single_document.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir directement le document'**
  String get settings_menu_auto_open_single_document;

  /// No description provided for @settings_menu_auto_open_single_document_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Si un seul document est présent, l\'ouvrir sans afficher le menu.'**
  String get settings_menu_auto_open_single_document_subtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'am',
    'ar',
    'as',
    'ay',
    'az',
    'de',
    'en',
    'es',
    'fa',
    'fr',
    'gl',
    'hu',
    'it',
    'ja',
    'ko',
    'ne',
    'nl',
    'pt',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'HK':
            return AppLocalizationsZhHk();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'am':
      return AppLocalizationsAm();
    case 'ar':
      return AppLocalizationsAr();
    case 'as':
      return AppLocalizationsAs();
    case 'ay':
      return AppLocalizationsAy();
    case 'az':
      return AppLocalizationsAz();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'gl':
      return AppLocalizationsGl();
    case 'hu':
      return AppLocalizationsHu();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ne':
      return AppLocalizationsNe();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
