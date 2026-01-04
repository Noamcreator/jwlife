// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'localization.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get search_hint => 'Buscar...';

  @override
  String get action_accept => 'Aceptar';

  @override
  String get action_accept_uppercase => 'ACEPTAR';

  @override
  String get action_add => 'Añadir';

  @override
  String get action_add_a_note => 'Añadir nota';

  @override
  String get action_add_a_tag => 'Añadir etiqueta';

  @override
  String get action_add_from_camera => 'Añadir desde cámara';

  @override
  String get action_add_from_files => 'Añadir desde archivos';

  @override
  String get action_add_from_photos => 'Añadir desde fotos';

  @override
  String get action_add_playlist => 'Añadir lista de reproducción';

  @override
  String get action_add_to_playlist => 'Añadir a la lista de reproducción';

  @override
  String get action_add_to_playlist_uppercase =>
      'AÑADIR A LA LISTA DE REPRODUCCIÓN';

  @override
  String get action_add_uppercase => 'AÑADIR';

  @override
  String get action_allow => 'Permitir';

  @override
  String get action_ask_me_again_later => 'Preguntarme más tarde';

  @override
  String get action_ask_me_again_later_uppercase => 'PREGUNTARME MÁS TARDE';

  @override
  String get action_back => 'Volver';

  @override
  String get action_backup_and_restore =>
      'Hacer y restaurar copia de seguridad';

  @override
  String get action_backup_create => 'Hacer copia de seguridad';

  @override
  String get action_bookmark => 'Marcador';

  @override
  String get action_bookmark_replace =>
      'Mover el marcador a la posición actual';

  @override
  String get action_bookmark_uppercase => 'MARCADOR';

  @override
  String get action_bookmarks => 'Marcadores';

  @override
  String get action_books => 'Libros';

  @override
  String get action_cancel => 'Cancelar';

  @override
  String get action_cancel_uppercase => 'CANCELAR';

  @override
  String get action_change_color => 'Cambiar color';

  @override
  String get action_chapters => 'Capítulos';

  @override
  String get action_chapters_uppercase => 'CAPÍTULOS';

  @override
  String get action_check => 'REVISAR';

  @override
  String get action_clear => 'Borrar';

  @override
  String get action_clear_cache => 'Borrar caché';

  @override
  String get action_clear_selection => 'Quitar selección';

  @override
  String get action_close => 'Cerrar';

  @override
  String get action_close_upper => 'CERRAR';

  @override
  String get action_collapse => 'Ocultar';

  @override
  String get action_contents => 'Índice';

  @override
  String get action_continue => 'Continuar';

  @override
  String get action_continue_uppercase => 'CONTINUAR';

  @override
  String get action_copy => 'Copiar';

  @override
  String get action_copy_uppercase => 'COPIAR';

  @override
  String get action_copy_lyrics => 'Copiar letra';

  @override
  String get action_copy_subtitles => 'Copiar subtítulos';

  @override
  String get action_create => 'Crear';

  @override
  String get action_create_a_playlist => 'Crear lista de reproducción';

  @override
  String get action_create_a_playlist_uppercase =>
      'CREAR LISTA DE REPRODUCCIÓN';

  @override
  String get action_customize => 'Personalizar';

  @override
  String get action_customize_uppercase => 'PERSONALIZAR';

  @override
  String get action_decline => 'Rechazar';

  @override
  String get action_decline_uppercase => 'RECHAZAR';

  @override
  String get action_define => 'Definir';

  @override
  String get action_define_uppercase => 'DEFINIR';

  @override
  String get action_delete => 'Borrar';

  @override
  String get action_delete_all => 'Borrar todo';

  @override
  String get action_delete_all_media => 'Todos los archivos multimedia';

  @override
  String get action_delete_all_media_uppercase =>
      'TODOS LOS ARCHIVOS MULTIMEDIA';

  @override
  String get action_delete_audio => 'Eliminar la grabación';

  @override
  String action_delete_item(Object name) {
    return 'Borrar $name';
  }

  @override
  String get action_delete_media_from_this_publication =>
      'Archivos multimedia de esta publicación';

  @override
  String get action_delete_media_from_this_publication_uppercase =>
      'ARCHIVOS MULTIMEDIA DE ESTA PUBLICACIÓN';

  @override
  String get action_delete_note => 'Borrar nota';

  @override
  String get action_delete_publication => 'Borrar publicación';

  @override
  String get action_delete_publication_media =>
      'Borrar la publicación y los archivos multimedia';

  @override
  String get action_delete_publication_media_uppercase =>
      'BORRAR LA PUBLICACIÓN Y LOS ARCHIVOS MULTIMEDIA';

  @override
  String get action_delete_publication_only => 'Borrar solo la publicación';

  @override
  String get action_delete_publication_only_uppercase =>
      'BORRAR SOLO LA PUBLICACIÓN';

  @override
  String action_delete_publications(Object count) {
    return 'Borrar $count elementos';
  }

  @override
  String get action_delete_uppercase => 'BORRAR';

  @override
  String get action_deselect_all => 'Deseleccionar todo';

  @override
  String get action_discard => 'Rechazar';

  @override
  String get action_display_furigana => 'Ver furigana';

  @override
  String get action_display_pinyin => 'Ver pinyin';

  @override
  String get action_display_menu => 'Mostrar menú';

  @override
  String get action_display_yale => 'Ver romanización Yale';

  @override
  String get action_do_not_show_again => 'No volver a mostrar';

  @override
  String get action_done => 'OK';

  @override
  String get action_done_uppercase => 'HECHO';

  @override
  String get action_download => 'Descargar';

  @override
  String get action_download_all => 'Descargar todo';

  @override
  String get action_download_all_uppercase => 'DESCARGAR TODO';

  @override
  String get action_download_audio => 'Descargar la grabación';

  @override
  String action_download_audio_size(Object size) {
    return 'Descargar la grabación ($size)';
  }

  @override
  String get action_download_bible => 'Descargar una Biblia';

  @override
  String get action_download_media => 'Descargar los archivos multimedia';

  @override
  String action_download_publication(Object title) {
    return 'Descargar $title';
  }

  @override
  String get action_download_supplemental_videos =>
      'Descargar videos adicionales';

  @override
  String get action_download_uppercase => 'DESCARGAR';

  @override
  String action_download_video(Object option, Object size) {
    return 'Descargar $option ($size)';
  }

  @override
  String get action_download_videos => 'Descargar videos';

  @override
  String get action_duplicate => 'Duplicar';

  @override
  String get action_edit => 'Editar';

  @override
  String get action_edit_uppercase => 'EDITAR';

  @override
  String get action_enter => 'Aceptar';

  @override
  String get action_enter_uppercase => 'ACEPTAR';

  @override
  String get action_expand => 'Desplegar';

  @override
  String get action_export => 'Exportar';

  @override
  String get action_favorites_add => 'Añadir a favoritos';

  @override
  String get action_favorites_remove => 'Quitar de favoritos';

  @override
  String get action_full_screen => 'Pantalla completa';

  @override
  String get action_full_screen_exit => 'Salir de pantalla completa';

  @override
  String get action_go_to_playlist => 'Ir a la lista de reproducción';

  @override
  String get action_go_to_publication => 'Ir a la publicación';

  @override
  String get action_got_it => 'Ok';

  @override
  String get action_got_it_uppercase => 'OK';

  @override
  String get action_hide => 'Ocultar';

  @override
  String get action_highlight => 'Resaltar';

  @override
  String get action_history => 'Historial';

  @override
  String get action_import_anyway => 'Importar';

  @override
  String get action_import_file => 'Importar archivo';

  @override
  String get action_import_playlist => 'Importar lista de reproducción';

  @override
  String get action_just_once => 'Solo esta vez';

  @override
  String get action_just_once_uppercase => 'SOLO ESTA VEZ';

  @override
  String get action_keep_editing => 'Seguir editando';

  @override
  String get action_languages => 'Idiomas';

  @override
  String get action_later => 'Más tarde';

  @override
  String get action_learn_more => 'Aprenda más';

  @override
  String get action_make_available_offline => 'Hacer disponible sin Internet';

  @override
  String get action_media_minimize => 'Minimizar';

  @override
  String get action_media_restore => 'Expandir';

  @override
  String get action_more_songs => 'Más canciones';

  @override
  String get action_navigation_menu_close => 'Cerrar el menú de navegación';

  @override
  String get action_navigation_menu_open => 'Abrir el menú de navegación';

  @override
  String get action_new_note_in_this_tag => 'Nueva nota con esta etiqueta';

  @override
  String get action_new_tag => 'Nueva etiqueta';

  @override
  String get action_next => 'Siguiente';

  @override
  String get action_no => 'No';

  @override
  String get action_note_minimize => 'Minimizar la nota';

  @override
  String get action_note_restore => 'Restaurar la nota';

  @override
  String get action_ok => 'OK';

  @override
  String get action_open => 'Abrir';

  @override
  String get action_open_in => 'Abrir en...';

  @override
  String get action_open_in_jworg => 'Abrir en jw.org';

  @override
  String get action_open_in_online_library => 'Abrir en BIBLIOTECA EN LÍNEA';

  @override
  String get action_open_in_share => 'Compartir enlace';

  @override
  String get action_open_in_share_file => 'Compartir archivo';

  @override
  String get action_open_uppercase => 'ABRIR';

  @override
  String get action_outline_of_contents => 'Contenido';

  @override
  String get action_outline_of_contents_uppercase => 'CONTENIDO';

  @override
  String get action_pause => 'Pausar';

  @override
  String get action_personal_data_backup => 'Hacer copia de seguridad';

  @override
  String get action_personal_data_backup_internal =>
      'Copia de actualización reciente';

  @override
  String get action_personal_data_backup_internal_uppercase =>
      'COPIA DE ACTUALIZACIÓN RECIENTE';

  @override
  String get action_personal_data_backup_uppercase =>
      'HACER COPIA DE SEGURIDAD';

  @override
  String get action_personal_data_backup_what_i_have_now =>
      'Copia de lo que tengo ahora';

  @override
  String get action_personal_data_backup_what_i_have_now_uppercase =>
      'COPIA DE LO QUE TENGO AHORA';

  @override
  String get action_personal_data_delete_backup => 'Borrar copia de seguridad';

  @override
  String get action_personal_data_delete_backup_uppercase =>
      'BORRAR COPIA DE SEGURIDAD';

  @override
  String get action_personal_data_do_not_backup =>
      'No hacer copia de seguridad';

  @override
  String get action_personal_data_do_not_backup_uppercase =>
      'NO HACER COPIA DE SEGURIDAD';

  @override
  String get action_personal_data_keep_current => 'Mantener lo que tengo ahora';

  @override
  String get action_personal_data_keep_current_uppercase =>
      'MANTENER LO QUE TENGO AHORA';

  @override
  String get action_personal_data_restore_internal_backup =>
      'Restaurar copia de seguridad';

  @override
  String get action_personal_data_restore_internal_backup_uppercase =>
      'RESTAURAR COPIA DE SEGURIDAD';

  @override
  String get action_play => 'Reproducir';

  @override
  String get action_play_all => 'Reproducir todo';

  @override
  String get action_play_audio => 'Reproducir la grabación';

  @override
  String get action_play_downloaded => 'Reproducir los archivos descargados';

  @override
  String get action_play_this_track_only => 'Reproducir una pista';

  @override
  String get action_playlist_end_continue => 'Continuar';

  @override
  String get action_playlist_end_freeze => 'Pausa';

  @override
  String get action_playlist_end_stop => 'Stop';

  @override
  String get action_previous => 'Anterior';

  @override
  String get action_reading_mode => 'Modo lectura';

  @override
  String get action_refresh => 'Actualizar';

  @override
  String get action_refresh_uppercase => 'ACTUALIZAR';

  @override
  String get action_remove => 'Eliminar';

  @override
  String action_remove_audio_size(Object size) {
    return 'Eliminar la grabación ($size)';
  }

  @override
  String get action_remove_from_device => 'Borrar del dispositivo';

  @override
  String get action_remove_supplemental_videos => 'Eliminar videos adicionales';

  @override
  String get action_remove_tag => 'Quitar etiqueta';

  @override
  String get action_remove_uppercase => 'QUITAR';

  @override
  String action_remove_video_size(Object size) {
    return 'Eliminar el video ($size)';
  }

  @override
  String get action_remove_videos => 'Eliminar videos';

  @override
  String get action_rename => 'Cambiar nombre';

  @override
  String get action_rename_uppercase => 'CAMBIAR NOMBRE';

  @override
  String get action_reopen_second_window => 'Reabrir';

  @override
  String get action_replace => 'Reemplazar';

  @override
  String get action_reset => 'Restablecer';

  @override
  String get action_reset_uppercase => 'RESTABLECER';

  @override
  String get action_reset_today_uppercase => 'REINICIAR A HOY';

  @override
  String get action_restore => 'Restaurar';

  @override
  String get action_restore_a_backup => 'Restaurar copia de seguridad';

  @override
  String get action_restore_uppercase => 'RESTAURAR';

  @override
  String get action_retry => 'Reintentar';

  @override
  String get action_retry_uppercase => 'REINTENTAR';

  @override
  String get action_save_image => 'Guardar imagen';

  @override
  String get action_search => 'Buscar';

  @override
  String get action_search_uppercase => 'BUSCAR';

  @override
  String get action_see_all => 'Ver todo';

  @override
  String get action_select => 'Seleccionar';

  @override
  String get action_select_all => 'Seleccionar todo';

  @override
  String get action_settings => 'Configuración';

  @override
  String get action_settings_uppercase => 'CONFIGURACIÓN';

  @override
  String get action_share => 'Compartir';

  @override
  String get action_share_uppercase => 'COMPARTIR';

  @override
  String get action_share_image => 'Compartir imagen';

  @override
  String get action_shuffle => 'Aleatorio';

  @override
  String get action_show_lyrics => 'Ver letra';

  @override
  String get action_show_subtitles => 'Ver subtítulos';

  @override
  String get action_sort_by => 'Ordenar por';

  @override
  String get action_stop_download => 'Detener la descarga';

  @override
  String get action_stop_trying => 'Dejar de intentar';

  @override
  String get action_stop_trying_uppercase => 'DEJAR DE INTENTAR';

  @override
  String get action_stream => 'Streaming';

  @override
  String get action_text_settings => 'Formato de la letra';

  @override
  String get action_translations => 'Versiones de la Biblia';

  @override
  String get action_trim => 'Recortar';

  @override
  String get action_try_again => 'Volver a intentar';

  @override
  String get action_try_again_uppercase => 'VOLVER A INTENTAR';

  @override
  String get action_ungroup => 'Dividir';

  @override
  String get action_update => 'Actualizar';

  @override
  String get action_update_all => 'Actualizar todo';

  @override
  String action_update_audio_size(Object size) {
    return 'Actualizar la grabación ($size)';
  }

  @override
  String action_update_video_size(Object size) {
    return 'Actualizar el video ($size)';
  }

  @override
  String get action_view_mode_image => 'Edición impresa';

  @override
  String get action_view_mode_text => 'Edición digital';

  @override
  String get action_view_picture => 'Ver imagen';

  @override
  String get action_view_source => 'Ver video original';

  @override
  String get action_view_text => 'Ver texto';

  @override
  String get action_volume_adjust => 'Ajustar el volumen';

  @override
  String get action_volume_mute => 'Silenciar';

  @override
  String get action_volume_unmute => 'Activar sonido';

  @override
  String get action_yes => 'Sí';

  @override
  String get label_additional_reading => 'Otros artículos';

  @override
  String label_all_notes(Object count) {
    return 'Todas las notas ($count)';
  }

  @override
  String label_all_tags(Object count) {
    return 'Todas las etiquetas ($count)';
  }

  @override
  String get label_all_types => 'Todas las categorías';

  @override
  String get label_audio_available => 'Grabación en audio está disponible';

  @override
  String get label_breaking_news => 'Noticia de última hora';

  @override
  String label_breaking_news_count(Object count, Object total) {
    return '$count de $total';
  }

  @override
  String get label_color_blue => 'Azul';

  @override
  String get label_color_green => 'Verde';

  @override
  String get label_color_orange => 'Naranja';

  @override
  String get label_color_pink => 'Rosa';

  @override
  String get label_color_purple => 'Morado';

  @override
  String get label_color_yellow => 'Amarillo';

  @override
  String label_convention_day(Object number) {
    return 'Día $number';
  }

  @override
  String get label_convention_releases => 'Nuevas publicaciones';

  @override
  String label_date_range_one_month(Object day1, Object day2, Object month) {
    return '$day1-$day2 de $month';
  }

  @override
  String label_date_range_two_months(
    Object day1,
    Object day2,
    Object month1,
    Object month2,
  ) {
    return '$day1 de $month1 - $day2 $month2';
  }

  @override
  String label_document_pub_title(Object doc, Object pub) {
    return '$doc - $pub';
  }

  @override
  String get label_download_all_cloud_uppercase => 'EN LA NUBE';

  @override
  String get label_download_all_device_uppercase => 'EN EL DISPOSITIVO';

  @override
  String label_download_all_files(Object count) {
    return '$count archivos';
  }

  @override
  String get label_download_all_one_file => '1 archivo';

  @override
  String get label_download_all_up_to_date => 'Ya tiene todo descargado';

  @override
  String get label_download_video => 'Descargar el video';

  @override
  String get label_downloaded => 'Descargado';

  @override
  String get label_downloaded_uppercase => 'DESCARGADO';

  @override
  String label_duration(Object time) {
    return 'Duración $time';
  }

  @override
  String get label_entire_video => 'Video completo';

  @override
  String get label_home_frequently_used => 'Lo más usado';

  @override
  String get label_icon_bookmark => 'Marcador';

  @override
  String get label_icon_bookmark_actions => 'Mostrar opciones del marcador';

  @override
  String get label_icon_bookmark_delete => 'Borrar marcador';

  @override
  String get label_icon_download_publication => 'Descargar publicación';

  @override
  String get label_icon_extracted_content => 'Otras referencias';

  @override
  String get label_icon_footnotes => 'Notas';

  @override
  String get label_icon_marginal_references => 'Referencias marginales';

  @override
  String get label_icon_parallel_translations => 'Otras traducciones';

  @override
  String get label_icon_scroll_down => 'Desplazarse hacia abajo';

  @override
  String get label_icon_search_suggestion => 'Sugerencias para la búsqueda';

  @override
  String get label_icon_supplementary_hide => 'Ocultar panel suplementario';

  @override
  String get label_icon_supplementary_show => 'Mostrar panel suplementario';

  @override
  String get label_import => 'Importar';

  @override
  String get label_import_jwpub => 'Importar JWPUB';

  @override
  String get label_import_playlists => 'Importar listas de reproducción';

  @override
  String get label_import_uppercase => 'IMPORTAR';

  @override
  String label_languages_2(Object language1, Object language2) {
    return '$language1 y $language2';
  }

  @override
  String label_languages_3_or_more(Object count, Object language) {
    return '$language y $count más';
  }

  @override
  String get label_languages_more => 'Más idiomas';

  @override
  String get label_languages_more_uppercase => 'MÁS IDIOMAS';

  @override
  String get label_languages_recommended => 'Recomendados';

  @override
  String get label_languages_recommended_uppercase => 'RECOMENDADOS';

  @override
  String label_last_updated(Object datetime) {
    return 'Última actualización $datetime';
  }

  @override
  String get label_marginal_general => 'General';

  @override
  String get label_marginal_parallel_account => 'Relato paralelo';

  @override
  String get label_marginal_quotation => 'Cita';

  @override
  String get label_markers => 'Marcadores';

  @override
  String get label_media_gallery => 'Galería multimedia';

  @override
  String get label_more => 'Más';

  @override
  String get label_not_included => 'No incluidas';

  @override
  String get label_not_included_uppercase => 'NO INCLUIDAS';

  @override
  String get label_note => 'Nota';

  @override
  String get label_note_title => 'Título';

  @override
  String get label_notes => 'Notas';

  @override
  String get label_notes_uppercase => 'NOTAS';

  @override
  String get label_off => 'Desactivar';

  @override
  String get label_on => 'Activar';

  @override
  String get label_other_articles => 'Contenido de este número';

  @override
  String get label_other_meeting_publications => 'Otras publicaciones';

  @override
  String get label_overview => 'Esquema';

  @override
  String get label_paused => 'Pausa';

  @override
  String get label_pending_updates => 'Actualizaciones pendientes';

  @override
  String get label_pending_updates_uppercase => 'ACTUALIZACIONES PENDIENTES';

  @override
  String get label_picture => 'Imagen';

  @override
  String get label_pictures => 'Imágenes';

  @override
  String get label_pictures_videos_uppercase => 'IMÁGENES Y VIDEOS';

  @override
  String get label_playback_position => 'Posición de la reproducción';

  @override
  String get label_playback_speed => 'Velocidad';

  @override
  String label_playback_speed_colon(Object speed) {
    return 'Velocidad: $speed';
  }

  @override
  String label_playback_speed_normal(Object speed) {
    return '$speed · Normal';
  }

  @override
  String get label_playing => 'Reproducir';

  @override
  String get label_playing_pip => 'Reproducción Imagen en imagen';

  @override
  String label_playlist_duration(Object number) {
    return '$number minutos';
  }

  @override
  String label_playlist_items(Object count) {
    return '$count elementos';
  }

  @override
  String label_playlist_midweek_meeting(Object date) {
    return 'Vida y Ministerio · $date';
  }

  @override
  String get label_playlist_name => 'Nombre de la lista de reproducción';

  @override
  String label_playlist_watchtower_study(Object date) {
    return 'Estudio de La Atalaya · $date';
  }

  @override
  String get label_playlist_when_done => 'Una vez reproducido...';

  @override
  String get label_reference_works => 'Obras de consulta';

  @override
  String get label_related_scriptures => 'Versículo(s) relacionado(s):';

  @override
  String get label_repeat => 'Repetir';

  @override
  String get label_repeat_all => 'Reproducir otra vez todo';

  @override
  String get label_repeat_all_short => 'Todo';

  @override
  String get label_repeat_off => 'Desactivar Reproducir otra vez';

  @override
  String get label_repeat_one => 'Reproducir otra vez una pista';

  @override
  String get label_repeat_one_short => 'Una';

  @override
  String get label_research_guide => 'Guía de estudio';

  @override
  String get label_search_jworg => 'Buscar en JW.ORG';

  @override
  String get label_search_playlists => 'Búsqueda en las listas de reproducción';

  @override
  String get label_seek_back_5 => 'Retroceder 5 segundos';

  @override
  String get label_seek_forward_15 => 'Adelantar 15 segundos';

  @override
  String get label_select_a_week => 'Seleccione la semana';

  @override
  String get label_select_markers => 'Seleccione marcadores';

  @override
  String get label_settings => 'Configuración';

  @override
  String get label_settings_airplay => 'AirPlay';

  @override
  String get label_settings_airplay_disconnect => 'Desconectar AirPlay';

  @override
  String get label_settings_cast => 'Cast';

  @override
  String get label_settings_cast_disconnect => 'Desconectar Cast';

  @override
  String label_share_start_at(Object marker) {
    return 'Comenzar en $marker';
  }

  @override
  String get label_shuffle_off => 'Desactivar Aleatorio';

  @override
  String get label_shuffle_on => 'Activar Aleatorio';

  @override
  String get label_sort_frequently_used => 'Lo más usado';

  @override
  String get label_sort_largest_size => 'Tamaño';

  @override
  String get label_sort_publication_symbol => 'Símbolo de la publicación';

  @override
  String get label_sort_rarely_used => 'Lo que menos usa';

  @override
  String get label_sort_title => 'Título';

  @override
  String get label_sort_year => 'Año';

  @override
  String label_streaming_media(Object title) {
    return 'Streaming · $title';
  }

  @override
  String get label_study_bible_content_available =>
      'Contenido de la Biblia de estudio disponible';

  @override
  String get label_study_content => 'Material de estudio';

  @override
  String get label_supplemental_videos => 'Videos adicionales';

  @override
  String get label_support_code => 'Código';

  @override
  String get label_support_code_uppercase => 'CÓDIGO';

  @override
  String get label_tags => 'Etiquetas';

  @override
  String get label_tags_uppercase => 'ETIQUETAS';

  @override
  String get label_text_size_slider => 'Controlador del tamaño de la letra';

  @override
  String get label_thumbnail_publication => 'Imagen de la publicación';

  @override
  String get label_topics_publications_media =>
      'Temas, publicaciones y archivos multimedia';

  @override
  String label_trim_current(Object timecode) {
    return 'Tiempo actual: $timecode';
  }

  @override
  String label_trim_end(Object timecode) {
    return 'Final: $timecode';
  }

  @override
  String label_trim_start(Object timecode) {
    return 'Comienzo: $timecode';
  }

  @override
  String label_units_storage_bytes(Object number) {
    return '$number bytes';
  }

  @override
  String label_units_storage_gb(Object number) {
    return '$number GB';
  }

  @override
  String label_units_storage_kb(Object number) {
    return '$number KB';
  }

  @override
  String label_units_storage_mb(Object number) {
    return '$number MB';
  }

  @override
  String label_units_storage_tb(Object number) {
    return '$number TB';
  }

  @override
  String get label_untagged => 'Sin etiqueta';

  @override
  String get label_unused_bookmark => 'Marcador no utilizado';

  @override
  String get label_update_available => 'Actualización disponible';

  @override
  String get label_videos => 'Videos';

  @override
  String get label_view_original => 'Ver original';

  @override
  String get label_volume_level => 'Volumen';

  @override
  String label_volume_percent(Object value) {
    return '$value %';
  }

  @override
  String get label_weeks => 'Semanas';

  @override
  String get label_whats_new_1_day_ago => 'Hace 1 día';

  @override
  String get label_whats_new_1_hour_ago => 'Hace 1 hora';

  @override
  String get label_whats_new_1_minute_ago => 'Hace 1 minuto';

  @override
  String get label_whats_new_1_month_ago => 'Hace 1 mes';

  @override
  String get label_whats_new_1_year_ago => 'Hace 1 año';

  @override
  String get label_whats_new_earlier => 'MESES ANTERIORES';

  @override
  String get label_whats_new_last_month => 'MES PASADO';

  @override
  String label_whats_new_multiple_days_ago(Object count) {
    return 'Hace $count días';
  }

  @override
  String label_whats_new_multiple_hours_ago(Object count) {
    return 'Hace $count horas';
  }

  @override
  String label_whats_new_multiple_minutes_ago(Object count) {
    return 'Hace $count minutos';
  }

  @override
  String label_whats_new_multiple_months_ago(Object count) {
    return 'Hace $count meses';
  }

  @override
  String label_whats_new_multiple_year_ago(Object count) {
    return 'Hace $count años';
  }

  @override
  String get label_whats_new_multiple_seconds_ago => 'Hace unos segundos';

  @override
  String get label_whats_new_this_month => 'ESTE MES';

  @override
  String get label_whats_new_this_week => 'ESTA SEMANA';

  @override
  String get label_whats_new_today => 'Hoy';

  @override
  String label_yeartext_currently(Object language) {
    return 'Idioma seleccionado: $language';
  }

  @override
  String get label_yeartext_language => 'Idioma del texto del año';

  @override
  String get label_yeartext_meetings_tab =>
      'El mismo que el de la sección Reuniones';

  @override
  String get label_yeartext_off =>
      'El texto del año no se mostrará en pantalla';

  @override
  String labels_media_player_elapsed_time(
    Object time_elapsed,
    Object total_duration,
  ) {
    return '$time_elapsed de un total de $total_duration';
  }

  @override
  String get labels_pip_exit => 'Cerrar Imagen en imagen';

  @override
  String get labels_pip_play => 'Imagen en imagen';

  @override
  String get labels_this_week => 'Esta semana';

  @override
  String get message_access_file_permission_rationale_description =>
      'Para poder importar publicaciones, contenido multimedia y copias de seguridad, pulse \"Permitir\" en el siguiente mensaje.';

  @override
  String get message_access_file_permission_rationale_title =>
      'JW Library quiere acceder a sus archivos';

  @override
  String get message_accessibility_narrator_enabled =>
      'No es posible resaltar si tiene activada la función Narrador.';

  @override
  String get message_accessibility_talkback_enabled =>
      'No es posible resaltar si tiene activada la función TalkBack.';

  @override
  String get message_accessibility_voiceover_enabled =>
      'No es posible resaltar si tiene activada la función VoiceOver.';

  @override
  String get message_added_to_playlist => 'Añadido a la lista de reproducción';

  @override
  String message_added_to_playlist_name(Object playlistItem) {
    return 'Añadido a la lista de reproducción «$playlistItem»';
  }

  @override
  String get message_auto_update_pubs =>
      '¿Desea que las publicaciones se actualicen automáticamente en el futuro?';

  @override
  String get message_backup_create_explanation =>
      'Esta función guarda sus notas, etiquetas, resaltados, favoritos y marcadores en un archivo de copia de seguridad.';

  @override
  String get message_clear_cache => 'Borrando caché...';

  @override
  String get message_catalog_downloading => 'Actualizando contenido...';

  @override
  String get message_catalog_fail => 'No se pudo actualizar';

  @override
  String get message_catalog_new => 'Nuevas publicaciones disponibles';

  @override
  String get message_catalog_success => 'Actualización completada';

  @override
  String get message_catalog_up_to_date => 'No hay contenido nuevo';

  @override
  String get message_checking => 'Verificando...';

  @override
  String get message_choose_playlist => 'Seleccione lista de reproducción';

  @override
  String get message_coaching_change_speed => 'Cambiar velocidad';

  @override
  String get message_coaching_change_speed_description =>
      'Deslice el dedo sobre la pantalla hacia arriba o hacia abajo';

  @override
  String get message_coaching_more_button => 'Más';

  @override
  String get message_coaching_more_button_description =>
      'Pulse para ver más opciones, como la de \"Borrar\"';

  @override
  String get message_coaching_next_prev_marker =>
      'Ir al marcador siguiente/anterior';

  @override
  String get message_coaching_next_prev_marker_description =>
      'Deslice el dedo sobre la pantalla hacia la izquierda o hacia la derecha';

  @override
  String get message_coaching_play_pause => 'Pausar/Reproducir';

  @override
  String get message_coaching_play_pause_description => 'Pulse con dos dedos';

  @override
  String get message_coaching_playlists =>
      'Cree listas de videos, grabaciones de audio e imágenes. Podrá acceder a ellas o editarlas en la sección Estudio personal.';

  @override
  String get message_coaching_publications_download =>
      'Para ver los videos de una publicación, antes tiene que descargarla.';

  @override
  String get message_confirm_delete => '¿Está seguro de que lo quiere borrar?';

  @override
  String get message_confirm_stop_download => '¿Desea detener la descarga?';

  @override
  String get message_content_not_available => 'Publicación no disponible';

  @override
  String get message_content_not_available_in_selected_language =>
      'Algunos artículos no están disponibles en el idioma seleccionado.';

  @override
  String get message_delete_failure_title => 'No se pudo borrar';

  @override
  String get message_delete_publication_media =>
      'Esta publicación incluye un archivo multimedia. ¿Qué desea borrar?';

  @override
  String message_delete_publication_media_multiple(Object count) {
    return 'Esta publicación incluye $count archivos multimedia. ¿Qué desea borrar?';
  }

  @override
  String get message_delete_publication_videos =>
      'Esta acción borrará también los videos de esta publicación.';

  @override
  String get message_discard_changes => 'Los cambios no se han guardado';

  @override
  String get message_discard_changes_title => '¿Rechazar los cambios?';

  @override
  String get message_do_not_close_app => 'Por favor, no cierre la aplicación.';

  @override
  String get message_download_complete => 'Descarga completada';

  @override
  String get message_download_from_jworg =>
      'Vaya a esta página de jw.org para descargar los archivos';

  @override
  String get message_download_from_jworg_title => 'Descargar de JW.ORG';

  @override
  String get message_download_publications_for_meeting =>
      'Descargar las publicaciones para la reunión que aparecen arriba.';

  @override
  String get message_download_research_guide =>
      'Descargue la Guía de estudio con las referencias más recientes.';

  @override
  String get message_download_will_close_item =>
      'El archivo se cerrará al descargarlo.';

  @override
  String get message_empty_audio =>
      'No hay ninguna grabación de audio disponible';

  @override
  String get message_empty_pictures_videos =>
      'No hay imágenes o videos disponibles';

  @override
  String get message_file_cannot_open =>
      'Ese archivo no se puede abrir en JW Library.';

  @override
  String message_file_corrupted(Object filename) {
    return '\"$filename\" no se puede importar a JW Library porque el archivo tiene algún problema. Intente descargarlo otra vez.';
  }

  @override
  String get message_file_corrupted_title => 'El archivo está dañado';

  @override
  String message_file_fail_multiple(Object number) {
    return 'No se importaron $number archivos';
  }

  @override
  String get message_file_failed => 'No se importó 1 archivo';

  @override
  String get message_file_found =>
      'En esta ubicación hay otro archivo que se puede importar a JW Library. ¿Desea importarlo ahora?';

  @override
  String message_file_found_multiple(Object number) {
    return 'En esta ubicación hay otros $number archivos que se pueden importar a JW Library. ¿Desea importarlos ahora?';
  }

  @override
  String get message_file_found_title => 'Se han encontrado más archivos';

  @override
  String get message_file_import_complete => 'Se ha completado la importación';

  @override
  String get message_file_import_fail => 'Este archivo no se puede importar.';

  @override
  String get message_file_importing => 'Queda 1 archivo';

  @override
  String message_file_importing_multiple(Object number) {
    return 'Quedan $number archivos';
  }

  @override
  String get message_file_importing_title => 'Importando archivos';

  @override
  String message_file_importing_name(Object fileName) {
    return 'Importando archivo $fileName...';
  }

  @override
  String message_file_missing_pub(Object symbol) {
    return 'No se encuentra esta publicación. Instale la publicación \"$symbol\" y vuelva a intentarlo. O, si se hace referencia a este archivo en otra publicación, use la función Importar para seleccionarlo directamente.';
  }

  @override
  String get message_file_missing_pub_title =>
      'La publicación no está descargada';

  @override
  String get message_file_not_recognized =>
      'Este archivo no corresponde a ningún contenido de JW Library. Intente descargar primero la publicación correspondiente o seleccione otro archivo.';

  @override
  String get message_file_not_recognized_title => 'No se reconoce este archivo';

  @override
  String get message_file_not_supported_title => 'Archivo no compatible';

  @override
  String get message_file_success =>
      'Se ha verificado e importado 1 archivo a JW Library';

  @override
  String message_file_success_multiple(Object number) {
    return 'Se han verificado e importado $number archivos a JW Library';
  }

  @override
  String get message_file_unknown_type => 'Este archivo no se pudo abrir';

  @override
  String get message_file_wrong => 'El nombre del archivo no es correcto.';

  @override
  String get message_file_wrong_title => 'Archivo erróneo';

  @override
  String get message_full_screen_left_swipe =>
      'Para ver otra sección o capítulo, deslice el dedo sobre la pantalla de un lado a otro.';

  @override
  String get message_full_screen_title => 'Está en modo pantalla completa';

  @override
  String get message_full_screen_top_swipe =>
      'Para salir de pantalla completa, deslice el dedo desde el extremo superior de la pantalla hacia abajo.';

  @override
  String get message_help_us_improve =>
      'Se produjo un fallo en JW Library la última vez que se usó. ¿Desea enviarnos los datos de diagnóstico? Eso nos permitirá mejorar el funcionamiento de la aplicación.';

  @override
  String get message_help_us_improve_title => 'Ayúdenos a mejorar';

  @override
  String get message_import_jwlsl_playlist =>
      'Esta copia de seguridad contiene listas de reproducción creadas en la aplicación JW Library Sign Language. ¿Desea importarlas?';

  @override
  String get message_install_failure =>
      'No se pudo completar la instalación. Asegúrese de que tiene suficiente espacio de almacenamiento.';

  @override
  String get message_install_failure_description =>
      'JW Library no pudo instalar esta publicación. Intente descargarla e instalarla de nuevo.';

  @override
  String get message_install_failure_title =>
      'No se pudo completar la instalación';

  @override
  String get message_install_latest =>
      'Actualice JW Library con su última versión para instalar esta publicación.';

  @override
  String get message_install_media_extensions =>
      'Este archivo requiere que instale las extensiones de imagen HEIF y de video HEVC desde Microsoft Store.';

  @override
  String get message_install_study_edition =>
      'Esta acción transferirá los marcadores, los resaltados y las notas de la Traducción del Nuevo Mundo a la edición de estudio.';

  @override
  String get message_install_study_edition_title =>
      'Instalar la edición de estudio';

  @override
  String get message_install_success_study_edition =>
      'Las notas y los resaltados de la Traducción del Nuevo Mundo se han transferido a la edición de estudio';

  @override
  String get message_install_success_title => 'Se ha instalado correctamente';

  @override
  String get message_installing => 'Instalando...';

  @override
  String get message_item_unavailable =>
      'En este momento este archivo no está disponible. Inténtelo más tarde o importe el archivo si lo tiene en su dispositivo.';

  @override
  String get message_item_unavailable_title => 'Archivo no disponible';

  @override
  String message_large_file_warning(Object size) {
    return 'Este archivo pesa $size y ocupará mucho espacio en su dispositivo. ¿Desea importarlo?';
  }

  @override
  String get message_large_file_warning_title => 'Archivo grande';

  @override
  String get message_media_starting_may_2016 =>
      'La sección Reuniones incluirá videos o grabaciones a partir de mayo de 2016 o más tarde.';

  @override
  String message_media_up_next(Object title) {
    return 'A continuación: $title';
  }

  @override
  String get message_migration_failure_study_edition =>
      'Las notas y los resaltados de la Traducción del Nuevo Mundo no se pudieron transferir a la edición de estudio. Para intentarlo de nuevo, borre la edición de estudio y descárguela otra vez.';

  @override
  String get message_migration_failure_title =>
      'La migración no se ha podido realizar';

  @override
  String get message_migration_study_edition =>
      'Por favor, espere a que se transfieran a la edición de estudio las notas y los resaltados. Este proceso puede tomar unos minutos.';

  @override
  String get message_missing_download_location =>
      'Vaya a Configuración y elija dónde descargar el archivo.';

  @override
  String get message_missing_download_location_title => 'No se puede descargar';

  @override
  String get message_missing_download_location_windows_n =>
      'No hay ninguna ubicación disponible para esta descarga.';

  @override
  String get message_name_taken =>
      'Ya existe otra lista de reproducción con este nombre.';

  @override
  String get message_no_audio_programs =>
      'No hay grabaciones de audio en este idioma.';

  @override
  String get message_no_content => 'No hay contenido disponible';

  @override
  String get message_no_footnotes => 'No hay notas.';

  @override
  String get message_no_internet_audio =>
      'Conéctese a Internet para comprobar si hay alguna grabación de audio disponible';

  @override
  String get message_no_internet_audio_programs =>
      'Conéctese a Internet para ver los audios disponibles.';

  @override
  String get message_no_internet_connection => 'Conéctese a Internet.';

  @override
  String get message_no_internet_connection_title => 'Sin conexión a Internet';

  @override
  String get message_no_internet_language =>
      'Conéctese a Internet para ver todos los idiomas disponibles.';

  @override
  String get message_no_internet_media =>
      'Conéctese a Internet para ver los archivos multimedia disponibles.';

  @override
  String get message_no_internet_meeting =>
      'Conéctese a Internet para ver los programas de reuniones disponibles.';

  @override
  String get message_no_internet_publications =>
      'Conéctese a Internet para ver las publicaciones disponibles.';

  @override
  String get message_no_internet_videos_media =>
      'Conéctese a Internet para ver los videos disponibles.';

  @override
  String get message_no_items_audios =>
      'No hay audios disponibles en este idioma.';

  @override
  String get message_no_items_publications =>
      'No hay publicaciones disponibles en este idioma.';

  @override
  String get message_no_items_videos =>
      'No hay videos disponibles en este idioma.';

  @override
  String get message_no_marginal_references => 'No hay referencias marginales.';

  @override
  String get message_no_media => 'Descargue grabaciones de audio o videos.';

  @override
  String get message_no_media_items =>
      'No hay nuevos archivos multimedia en este idioma.';

  @override
  String get message_no_media_title => 'No tiene archivos multimedia';

  @override
  String get message_no_midweek_meeting_content =>
      'No hay contenido para la reunión de entre semana para esta fecha.';

  @override
  String get message_no_weekend_meeting_content =>
      'No hay contenido para la reunión de fin de semana para esta fecha.';

  @override
  String get message_no_ministry_publications =>
      'No hay publicaciones para la predicación en este idioma.';

  @override
  String get message_no_notes => 'Cree notas para su estudio personal';

  @override
  String get message_no_other_bibles =>
      'No hay otras Biblias disponibles que contengan este capítulo.';

  @override
  String get message_no_playlist_items => 'Añada elementos para escuchar o ver';

  @override
  String get message_no_playlists =>
      'Cree listas de reproducción con videos, audios e imágenes.';

  @override
  String get message_no_study_content => 'No hay material de estudio';

  @override
  String message_no_tags(Object name) {
    return 'Las cosas a las que le ponga la etiqueta \"$name\" aparecerán aquí.';
  }

  @override
  String get message_no_topics_found => 'No se han encontrado temas.';

  @override
  String get message_no_verses_available =>
      'No hay versículos disponibles de este libro de la Biblia.';

  @override
  String get message_no_videos => 'No hay videos en este idioma.';

  @override
  String get message_no_wifi_connection =>
      'Puede que su compañía le cobre por el consumo de datos. Puede activar el uso automático de datos móviles en Configuración. ¿Desea continuar?';

  @override
  String get message_no_wifi_connection_missing_items =>
      'Para reproducir todos los archivos, algunos tendrán que reproducirse en streaming y puede que le cobren por el consumo de datos. ¿Desea continuar?';

  @override
  String get message_not_enough_storage =>
      'No hay suficiente espacio para descargar esta publicación. Puede ir a Configuración para liberar espacio.';

  @override
  String get message_not_enough_storage_title => 'No hay suficiente espacio';

  @override
  String get message_offline_mode =>
      'Tiene desactivado el acceso a Internet en JW Library. ¿Desea continuar?';

  @override
  String get message_offline_mode_multiple_items =>
      'Tiene desactivado el acceso a Internet en JW Library. Si quiere reproducir todos los archivos, algunos se reproducirán en streaming. ¿Desea continuar?';

  @override
  String message_offline_terms(Object url) {
    return 'JW Library no pudo cargar el documento. Lea las Condiciones de uso en $url en un dispositivo con conexión a internet antes de pulsar \"Aceptar\".';
  }

  @override
  String get message_permission_files =>
      'Para abrir archivos de otras aplicaciones, necesitamos acceso a carpetas de su dispositivo.';

  @override
  String get message_permission_photos =>
      'Pulsar OK le permite guardar imágenes de las publicaciones';

  @override
  String get message_permission_title => 'Se necesita su autorización';

  @override
  String get message_personal_data_backup_confirmation =>
      '¿Está seguro? Le recomendamos hacer una copia de seguridad para poder restaurar sus notas y resaltados más adelante.';

  @override
  String get message_personal_data_backup_found_description =>
      'JW Library aún tiene una copia de seguridad de las notas y resaltados que se perdieron en una actualización reciente. ¿Qué copia desea guardar?';

  @override
  String get message_personal_data_backup_found_title =>
      'Copia de seguridad encontrada';

  @override
  String get message_personal_data_delete_backup =>
      'Si ya tiene lo que necesita, puede borrar la copia de seguridad de las notas y resaltados que se perdieron. No podrá restaurar esas notas y resaltados más adelante. ¿Desea borrar la copia?';

  @override
  String get message_personal_data_not_enough_storage =>
      'Algo salió mal y JW Library no puede abrirse. Quizás no haya suficiente espacio de almacenamiento.';

  @override
  String get message_personal_data_restore_internal_backup_description =>
      'JW Library aún tiene una copia de seguridad de las notas y resaltados que se perdieron en una actualización reciente. ¿Desea restaurar esa copia?';

  @override
  String get message_personal_data_update_fail_description =>
      'Sus notas y resaltados se perdieron en la actualización. Haga una copia de seguridad para guardar sus notas y resaltados. JW Library quizás pueda restaurar esa copia de seguridad en una actualización futura.';

  @override
  String get message_personal_data_update_fail_title => 'Algo salió mal...';

  @override
  String get message_playing_pip => 'Reproducción Imagen en imagen';

  @override
  String get message_please_select_a_bible =>
      'Descargue una Biblia para poder empezar.';

  @override
  String get message_privacy_settings =>
      'Para hacer que la aplicación funcione bien y mejorar su experiencia con ella, necesitamos transferir desde su dispositivo ciertos datos de diagnóstico y de uso. Puede aceptar o rechazar esta recopilación de datos adicionales. Si pulsa \"Aceptar\", estará autorizándonos a usar estos datos para mejorar el funcionamiento de la aplicación y su experiencia con ella. No los venderemos ni los usaremos con fines de marketing. Puede leer más detalles sobre cómo usamos estos datos y personalizar su configuración en cualquier momento. Solo tiene que pulsar \"Personalizar\" o ir a Configuración de la aplicación.';

  @override
  String get message_privacy_settings_title => 'Configuración de privacidad';

  @override
  String get message_publication_no_videos =>
      'Esta publicación no contiene videos. Se usa para otras funciones de la aplicación.';

  @override
  String get message_publication_unavailable =>
      'Esta publicación no está disponible en este momento. Por favor, inténtelo más adelante.';

  @override
  String get message_publication_unavailable_title =>
      'Publicación no disponible';

  @override
  String message_remove_tag(Object name) {
    return 'Esta acción quitará la etiqueta \"$name\" de todas las notas, aunque estas no se borrarán.';
  }

  @override
  String get message_request_timed_out_title =>
      'El tiempo de espera para esta solicitud se ha agotado';

  @override
  String get message_restore_a_backup_explanation =>
      'Esta acción reemplazará la información de estudio personal que ahora hay en este dispositivo por la que contiene la copia de seguridad.';

  @override
  String get message_restore_confirm_explanation =>
      'Esta acción reemplazará las notas, etiquetas, resaltados, favoritos, marcadores y listas de reproducción de este dispositivo por las de la copia de seguridad.';

  @override
  String get message_restore_confirm_explanation_playlists =>
      'Las listas de reproducción de este dispositivo serán reemplazadas.';

  @override
  String get message_restore_confirm_explanation_updated =>
      'Esta acción reemplazará las notas, etiquetas, resaltados, favoritos, marcadores y listas de reproducción de este dispositivo por las de esta copia de seguridad:';

  @override
  String get message_restore_failed =>
      'La restauración no se ha podido realizar';

  @override
  String get message_restore_failed_explanation =>
      'El archivo de copia de seguridad tiene algún problema.';

  @override
  String get message_restore_in_progress => 'Realizando la restauración...';

  @override
  String get message_restore_successful => 'Se ha restaurado correctamente';

  @override
  String get message_ruby_coaching_tip =>
      'Vea las guías de pronunciación para el chino (pinyin) y el japonés (furigana), si están disponibles.';

  @override
  String get message_search_topics_publications =>
      'Búsqueda por temas o publicaciones';

  @override
  String get message_second_window_closed =>
      'La segunda pantalla se ha apagado.';

  @override
  String get message_select_a_bible => 'Seleccione una Biblia';

  @override
  String get message_select_video_size_title => 'Calidad';

  @override
  String message_selection_count(Object count) {
    return 'Ha seleccionado $count';
  }

  @override
  String get message_setting_up =>
      'La aplicación está realizando algunas tareas...';

  @override
  String get message_sideload_older_than_current =>
      'Archivo no instalado. Ya tiene instalada la misma versión o una anterior de esta publicación.';

  @override
  String message_sideload_overwrite(Object title) {
    return 'Este archivo ha actualizado una versión más antigua de \"$title\".';
  }

  @override
  String get message_sideload_unsupported_version =>
      'Esta versión de JW Library no puede abrir este archivo.';

  @override
  String get message_still_watching =>
      'No tiene sentido mostrarle videos al aire.';

  @override
  String get message_still_watching_title => '¿Sigue ahí?';

  @override
  String get message_support_code_invalid =>
      'Revise su código y vuelva a intentarlo.';

  @override
  String get message_support_code_invalid_title => 'Código incorrecto';

  @override
  String get message_support_enter_code =>
      'Si tiene un código para función de asistencia, escríbalo para activarla.';

  @override
  String get message_support_read_help =>
      'Vea en jw.org respuestas a preguntas comunes sobre JW Library.';

  @override
  String get message_support_reset_confirmation =>
      '¿Está seguro de que quiere desactivar la función de asistencia?';

  @override
  String get message_support_reset_confirmation_title =>
      'Función de asistencia';

  @override
  String get message_tap_link => 'Pulse un vínculo.';

  @override
  String get message_tap_verse_number => 'Pulse el número de un versículo.';

  @override
  String get message_terms_accept =>
      'Si acepta nuestras Condiciones de uso, pulse \"Aceptar\". Puede leer estas condiciones y nuestra Política de privacidad en cualquier momento en Configuración de la aplicación.';

  @override
  String get message_terms_of_use =>
      'Antes de pulsar \"Aceptar\", lea detenidamente nuestras Condiciones de uso hasta el final:';

  @override
  String get message_this_cannot_be_undone =>
      'Esta acción no se puede deshacer.';

  @override
  String get message_try_again_later => 'Vuelva a intentarlo más tarde.';

  @override
  String message_unavailable_playlist_media(Object title) {
    return 'Por favor, descargue \"$title\" e inténtelo de nuevo.';
  }

  @override
  String get message_uninstall_deletes_media =>
      'Los archivos multimedia se borrarán si desinstala esta aplicación.';

  @override
  String message_unrecognized_language_title(Object languageid) {
    return 'Idioma no reconocido ($languageid)';
  }

  @override
  String get message_update_android_webview =>
      'Para visualizar correctamente el contenido, descargue de Google Play la última versión de \"Android System WebView\" o \"Google Chrome\" e instálela.';

  @override
  String get message_update_app =>
      'Se requiere una versión de JW Library más reciente para descargar nuevas publicaciones.';

  @override
  String get message_update_in_progress_title => 'Actualizando';

  @override
  String message_update_os(Object version) {
    return 'La siguiente actualización de JW Library requerirá $version o posterior.';
  }

  @override
  String get message_update_os_description =>
      'Para que JW Library funcione de forma segura y confiable, a veces hay que aumentar los requisitos mínimos de la aplicación. Si es posible, actualice el sistema operativo de su dispositivo con la versión más reciente. Si la actualización no cumple los requisitos mínimos, podrá seguir usando la aplicación durante un tiempo. Pero no volverá a recibir actualizaciones de la aplicación.';

  @override
  String get message_update_os_title => 'Es necesario actualizar el sistema';

  @override
  String get message_updated_item =>
      'Existe una versión actualizada de este artículo.';

  @override
  String get message_updated_publication =>
      'Existe una versión actualizada de esta publicación.';

  @override
  String get message_updated_video =>
      'Existe una versión actualizada de este video.';

  @override
  String get message_updated_video_trim =>
      'Puede que necesite volver a recortar el video.';

  @override
  String get message_updated_video_trim_title => 'Video actualizado';

  @override
  String get message_verse_not_present =>
      'Esta Biblia no contiene el versículo seleccionado.';

  @override
  String get message_verses_not_present =>
      'Esta Biblia no contiene los versículos seleccionados.';

  @override
  String get message_video_import_incomplete =>
      'No se han podido transferir todos los videos descargados.';

  @override
  String get message_video_import_incomplete_titel =>
      'La importación de videos no ha sido completa';

  @override
  String get message_video_playback_failed =>
      'Este formato no es compatible con su dispositivo.';

  @override
  String get message_video_playback_failed_title =>
      'No se pudo reproducir el video';

  @override
  String get message_welcome_to_jw_life => 'Bienvenido a JW Life';

  @override
  String get message_app_for_jehovah_witnesses =>
      'Una aplicación para la vida de un Testigo de Jehová';

  @override
  String message_download_daily_text(Object year) {
    return 'Descargar el Texto diario para el año $year';
  }

  @override
  String get message_whatsnew_add_favorites =>
      'Pulse el botón Más para añadir a favoritos';

  @override
  String get message_whatsnew_audio_recordings =>
      'Escuche grabaciones de audio de la Biblia y otras publicaciones';

  @override
  String get message_whatsnew_bible_gem =>
      'En la Biblia, use el símbolo del diamante que aparece en el menú contextual para ver todo el material de estudio de un versículo, incluidas las referencias a la Guía de estudio.';

  @override
  String get message_whatsnew_bookmarks => 'Marcador para un texto específico.';

  @override
  String get message_whatsnew_create_tags =>
      'Cree etiquetas para organizar sus notas';

  @override
  String get message_whatsnew_download_media =>
      'Descargar archivos de audio y video de una publicación.';

  @override
  String get message_whatsnew_download_sorting =>
      'Posibilidad de ordenar de distintas maneras las publicaciones que ha descargado';

  @override
  String get message_whatsnew_highlight =>
      'Mantenga pulsada la pantalla y deslice el dedo para resaltar.';

  @override
  String get message_whatsnew_highlight_textselection =>
      'Ya es posible resaltar texto.';

  @override
  String get message_whatsnew_home =>
      'La sección Inicio, que muestra los contenidos que usted usa más a menudo';

  @override
  String get message_whatsnew_many_sign_languages =>
      'Ahora puede descargar videos en muchas lenguas de señas.';

  @override
  String get message_whatsnew_media =>
      'La sección Multimedia, en la que se encuentran videos o grabaciones';

  @override
  String get message_whatsnew_meetings =>
      'Posibilidad de ver las publicaciones que necesitará para las reuniones';

  @override
  String get message_whatsnew_noversion_title => 'Lo nuevo en JW Library';

  @override
  String get message_whatsnew_playlists =>
      'Haga listas de reproducción con sus videos favoritos.';

  @override
  String get message_whatsnew_research_guide =>
      'Descargue la Guía de estudio para ver referencias útiles en el panel suplementario de la Biblia';

  @override
  String get message_whatsnew_sign_language =>
      'Se han añadido publicaciones en lenguas de señas.';

  @override
  String get message_whatsnew_sign_language_migration =>
      'Por favor, espere a que se transfieran los videos que tenía descargados en la versión anterior. Este proceso puede tomar unos minutos.';

  @override
  String get message_whatsnew_stream =>
      'Reproducir en streaming o descargar cualquier video o canción.';

  @override
  String get message_whatsnew_stream_video =>
      'Reproducir en streaming o descargar cualquier video.';

  @override
  String get message_whatsnew_study_edition =>
      'Ya está disponible la edición de estudio de la Traducción del Nuevo Mundo.';

  @override
  String get message_whatsnew_take_notes => 'Tome notas durante su estudio.';

  @override
  String get message_whatsnew_tap_longpress =>
      'Pulse para reproducir en streaming. Pulse más tiempo o haga clic con el botón derecho para descargar.';

  @override
  String message_whatsnew_title(Object version) {
    return 'Qué novedades hay en JW Library $version';
  }

  @override
  String get messages_coaching_appearance_setting_description =>
      'Elija entre el modo claro y el modo oscuro en Configuración.';

  @override
  String get messages_coaching_library_tab_description =>
      'Las secciones Publicaciones y Multimedia se han combinado en la nueva sección Biblioteca.';

  @override
  String get messages_convention_releases_prompt =>
      '¿Ha asistido ya a la asamblea regional de este año?';

  @override
  String get messages_convention_releases_prompt_watched =>
      '¿Ya vio la asamblea regional de este año?';

  @override
  String get messages_convention_theme_2015 => 'Imitemos a Cristo';

  @override
  String get messages_convention_theme_2016 => 'Seamos leales a Jehová';

  @override
  String get messages_convention_theme_2017 => '¡No se rinda!';

  @override
  String get messages_convention_theme_2018 => '¡Sea valiente!';

  @override
  String get messages_empty_downloads =>
      'Las publicaciones que descargue aparecerán aquí.';

  @override
  String get messages_empty_favorites =>
      'Añada aquí sus publicaciones, videos y grabaciones favoritas';

  @override
  String get messages_help_download_bibles =>
      'Para descargar más versiones, vaya a la sección Biblia y pulse el botón Idiomas.';

  @override
  String get messages_internal_publication =>
      'Esta es una publicación interna para uso exclusivo de las congregaciones de los testigos de Jehová. No va dirigida al público en general.';

  @override
  String get messages_internal_publication_title =>
      '¿Desea continuar con la descarga?';

  @override
  String get messages_locked_sd_card =>
      'Su dispositivo no permite que JW Library guarde archivos en la tarjeta SD.';

  @override
  String get messages_no_new_publications =>
      'No hay nuevas publicaciones en este idioma.';

  @override
  String get messages_no_pending_updates =>
      'Todas las publicaciones descargadas están actualizadas.';

  @override
  String get messages_tap_publication_type =>
      'Pulse alguna de las categorías para ver las publicaciones que contiene.';

  @override
  String get messages_turn_on_pip =>
      'Para reproducir el video en modo Imagen en imagen, actívelo para esta aplicación en la configuración.';

  @override
  String get navigation_home => 'Inicio';

  @override
  String get navigation_bible => 'Biblia';

  @override
  String get navigation_library => 'Biblioteca';

  @override
  String get navigation_workship => 'Adoración';

  @override
  String get navigation_predication => 'Predicación';

  @override
  String get navigation_personal => 'Personal';

  @override
  String get navigation_settings => 'Ajustes';

  @override
  String get navigation_favorites => 'Favoritos';

  @override
  String get navigation_frequently_used => 'Frecuentemente Usado';

  @override
  String get navigation_ministry => 'Kit de enseñanza';

  @override
  String get navigation_whats_new => 'Lo nuevo';

  @override
  String get navigation_online => 'Internet';

  @override
  String get navigation_official_website => 'Sitio oficial';

  @override
  String get navigation_online_broadcasting => 'Broadcasting';

  @override
  String get navigation_online_library => 'Biblioteca en línea';

  @override
  String get navigation_online_donation => 'Donaciones';

  @override
  String get navigation_online_gitub => 'GitHub de JW Life';

  @override
  String get navigation_bible_reading => 'Mi lectura de la Biblia';

  @override
  String get navigation_workship_assembly_br =>
      'Asambleas de circuito con un representante de la sucursal';

  @override
  String get navigation_workship_assembly_co =>
      'Asambleas de circuito con el superintendente de circuito';

  @override
  String get navigation_workship_convention => 'Asamblea Regional';

  @override
  String get navigation_workship_life_and_ministry => 'Reunión de entre semana';

  @override
  String get navigation_workship_watchtower_study => 'Reunión de fin de semana';

  @override
  String get navigation_workship_meetings => 'REUNIONES';

  @override
  String get navigation_workship_conventions => 'ASAMBLEAS';

  @override
  String get navigation_drawer_content_description => 'Panel de navegación';

  @override
  String get navigation_meetings_assembly => 'Asamblea de circuito';

  @override
  String get navigation_meetings_assembly_uppercase => 'ASAMBLEA DE CIRCUITO';

  @override
  String get navigation_meetings_convention => 'Asamblea regional';

  @override
  String get navigation_meetings_convention_uppercase => 'ASAMBLEA REGIONAL';

  @override
  String get navigation_meetings_life_and_ministry => 'Vida y Ministerio';

  @override
  String get navigation_meetings_life_and_ministry_uppercase =>
      'VIDA Y MINISTERIO';

  @override
  String get navigation_meetings_show_media => 'Multimedia';

  @override
  String get navigation_meetings_watchtower_study => 'Estudio de La Atalaya';

  @override
  String get navigation_meetings_watchtower_study_uppercase =>
      'ESTUDIO DE LA ATALAYA';

  @override
  String get navigation_menu => 'Menú de navegación';

  @override
  String get navigation_notes_and_tag => 'Notas y etiquetas';

  @override
  String get navigation_personal_study => 'Estudio personal';

  @override
  String get navigation_playlists => 'Listas de reproducción';

  @override
  String get navigation_publications => 'Publicaciones';

  @override
  String get navigation_publications_uppercase => 'PUBLICACIONES';

  @override
  String get navigation_pubs_by_type => 'Por categorías';

  @override
  String get navigation_pubs_by_type_uppercase => 'POR CATEGORÍAS';

  @override
  String get pub_attributes_archive => 'PUBLICACIONES MÁS ANTIGUAS';

  @override
  String get pub_attributes_assembly_convention => 'ASAMBLEAS';

  @override
  String get pub_attributes_bethel => 'BETEL';

  @override
  String get pub_attributes_circuit_assembly => 'ASAMBLEA DE CIRCUITO';

  @override
  String get pub_attributes_circuit_overseer => 'SUPERINTENDENTE DE CIRCUITO';

  @override
  String get pub_attributes_congregation => 'CONGREGACIÓN';

  @override
  String get pub_attributes_congregation_circuit_overseer =>
      'CONGREGACIÓN Y SUPERINTENDENTE DE CIRCUITO';

  @override
  String get pub_attributes_convention => 'ASAMBLEA REGIONAL';

  @override
  String get pub_attributes_convention_invitation =>
      'INVITACIONES A ASAMBLEAS REGIONALES';

  @override
  String get pub_attributes_design_construction => 'DISEÑO Y CONSTRUCCIÓN';

  @override
  String get pub_attributes_drama => 'OBRAS TEATRALES';

  @override
  String get pub_attributes_dramatic_bible_reading =>
      'LECTURAS DRAMATIZADAS DE LA BIBLIA';

  @override
  String get pub_attributes_examining_the_scriptures => 'EXAMINEMOS';

  @override
  String get pub_attributes_financial => 'ASUNTOS FINANCIEROS';

  @override
  String get pub_attributes_invitation => 'INVITACIONES';

  @override
  String get pub_attributes_kingdom_news => 'NOTICIAS DEL REINO';

  @override
  String get pub_attributes_medical => 'ASUNTOS MÉDICOS';

  @override
  String get pub_attributes_meetings => 'REUNIONES';

  @override
  String get pub_attributes_ministry => 'MINISTERIO';

  @override
  String get pub_attributes_music => 'MÚSICA';

  @override
  String get pub_attributes_public => 'EDICIÓN PARA EL PÚBLICO';

  @override
  String get pub_attributes_purchasing => 'COMPRAS';

  @override
  String get pub_attributes_safety => 'SEGURIDAD';

  @override
  String get pub_attributes_schools => 'ESCUELAS';

  @override
  String get pub_attributes_simplified => 'EDICIÓN EN LENGUAJE SENCILLO';

  @override
  String get pub_attributes_study => 'EDICIÓN DE ESTUDIO';

  @override
  String get pub_attributes_study_questions => 'PREGUNTAS DE ESTUDIO';

  @override
  String get pub_attributes_study_simplified =>
      'EDICIÓN DE ESTUDIO (LENGUAJE SENCILLO)';

  @override
  String get pub_attributes_vocal_rendition => 'CORO Y ORQUESTA';

  @override
  String get pub_attributes_writing_translation => 'REDACCIÓN Y TRADUCCIÓN';

  @override
  String get pub_attributes_yearbook =>
      'ANUARIOS E INFORMES DEL AÑO DE SERVICIO';

  @override
  String get pub_type_audio_programs => 'Grabaciones de audio';

  @override
  String get pub_type_audio_programs_sign_language =>
      'Canciones y obras teatrales';

  @override
  String get pub_type_audio_programs_uppercase => 'GRABACIONES DE AUDIO';

  @override
  String get pub_type_audio_programs_uppercase_sign_language =>
      'CANCIONES Y OBRAS TEATRALES';

  @override
  String get pub_type_awake => '¡Despertad!';

  @override
  String get pub_type_bibles => 'Biblias';

  @override
  String get pub_type_books => 'Libros';

  @override
  String get pub_type_broadcast_programs => 'Videos de JW Broadcasting';

  @override
  String get pub_type_brochures_booklets => 'Folletos';

  @override
  String get pub_type_calendars => 'Calendarios';

  @override
  String get pub_type_curriculums => 'Plan de estudios';

  @override
  String get pub_type_forms => 'Formularios';

  @override
  String get pub_type_index => 'Índices';

  @override
  String get pub_type_information_packets => 'Documentación';

  @override
  String get pub_type_kingdom_ministry => 'Ministerio del Reino';

  @override
  String get pub_type_letters => 'Correspondencia';

  @override
  String get pub_type_manuals_guidelines => 'Pautas';

  @override
  String get pub_type_meeting_workbook => 'Guía de actividades';

  @override
  String get pub_type_other => 'Otras';

  @override
  String get pub_type_programs => 'Programas';

  @override
  String get pub_type_talks => 'Bosquejos';

  @override
  String get pub_type_tour_items => 'Visitas a Betel';

  @override
  String get pub_type_tracts => 'Tratados e invitaciones';

  @override
  String get pub_type_videos => 'Videos';

  @override
  String get pub_type_videos_uppercase => 'VIDEOS';

  @override
  String get pub_type_watchtower => 'La Atalaya';

  @override
  String get pub_type_web => 'Catálogo de artículos';

  @override
  String get search_all_results => 'Todos los resultados';

  @override
  String get search_bar_search => 'Buscar';

  @override
  String get search_commonly_used => 'Resultados más relevantes';

  @override
  String get search_match_exact_phrase => 'Frase exacta';

  @override
  String get search_menu_title => 'Buscar';

  @override
  String get search_prompt => 'Introduzca palabras o el número de página';

  @override
  String search_prompt_languages(Object count) {
    return 'Búsqueda de idiomas ($count)';
  }

  @override
  String search_prompt_playlists(Object count) {
    return 'Búsqueda de listas de reproducción ($count)';
  }

  @override
  String get search_results_articles => 'Artículos';

  @override
  String get search_results_none => 'No se han obtenido resultados';

  @override
  String get search_results_occurence => '1 resultado';

  @override
  String search_results_occurences(Object count) {
    return '$count resultados';
  }

  @override
  String get search_results_title => 'Resultados de la búsqueda';

  @override
  String search_results_title_with_query(Object query) {
    return 'Resultados para \"$query\"';
  }

  @override
  String search_suggestion_page_number_title(Object number, Object title) {
    return 'Página $number, $title';
  }

  @override
  String get search_suggestions => 'Sugerencias';

  @override
  String get search_suggestions_page_number => 'Número de página';

  @override
  String get search_results_per_chronological => 'CRONOLÓGICO';

  @override
  String get search_results_per_top_verses => 'LOS MÁS CITADOS';

  @override
  String get search_results_per_occurences => 'OCURRENCIAS';

  @override
  String get search_show_less => 'VER MENOS';

  @override
  String get search_show_more => 'VER MÁS';

  @override
  String get search_suggestions_recent => 'Recientes';

  @override
  String get search_suggestions_topics => 'Temas';

  @override
  String get search_suggestions_topics_uppercase => 'TEMAS';

  @override
  String get searchview_clear_text_content_description => 'Borrar texto';

  @override
  String get searchview_navigation_content_description => 'Atrás';

  @override
  String get selected => 'Seleccionado';

  @override
  String get settings_about => 'Sobre';

  @override
  String get settings_about_uppercase => 'SOBRE';

  @override
  String get settings_acknowledgements => 'Reconocimientos';

  @override
  String get settings_always => 'Siempre';

  @override
  String get settings_always_uppercase => 'SIEMPRE';

  @override
  String get settings_appearance => 'Apariencia';

  @override
  String get settings_appearance_dark => 'Modo oscuro';

  @override
  String get settings_appearance_display => 'Pantalla';

  @override
  String get settings_appearance_display_upper => 'PANTALLA';

  @override
  String get settings_appearance_light => 'Modo claro';

  @override
  String get settings_appearance_system => 'Modo predeterminado';

  @override
  String get settings_application_version => 'Versión';

  @override
  String get settings_ask_every_time => 'Preguntar siempre';

  @override
  String get settings_ask_every_time_uppercase => 'PREGUNTAR SIEMPRE';

  @override
  String get settings_audio_player_controls =>
      'Controles del reproductor de audio';

  @override
  String get settings_auto_update_pubs =>
      'Actualizar las publicaciones automáticamente';

  @override
  String get settings_auto_update_pubs_wifi_only => 'Solo con conexión a wifi';

  @override
  String get settings_bad_windows_music_library =>
      'La biblioteca de música de Windows no tiene establecida ninguna ubicación. En el Explorador de Windows, vaya a Propiedades de Bibliotecas/Música y establezca una ubicación para guardar.';

  @override
  String get settings_bad_windows_video_library =>
      'La biblioteca de videos de Windows no tiene establecida ninguna ubicación. En el Explorador de Windows, vaya a Propiedades de Bibliotecas/Vídeos y establezca una ubicación para guardar.';

  @override
  String get settings_cache => 'Caché';

  @override
  String get settings_cache_upper => 'CACHÉ';

  @override
  String get settings_catalog_date => 'Fecha del catálogo';

  @override
  String get settings_library_date => 'Fecha de la biblioteca';

  @override
  String get settings_category_app_uppercase => 'APLICACIÓN';

  @override
  String get settings_category_download => 'Streaming y descargas';

  @override
  String get settings_category_download_uppercase => 'STREAMING Y DESCARGAS';

  @override
  String get settings_category_legal => 'Información legal';

  @override
  String get settings_category_legal_uppercase => 'INFORMACIÓN LEGAL';

  @override
  String get settings_category_playlists_uppercase => 'LISTAS DE REPRODUCCIÓN';

  @override
  String settings_category_privacy_subtitle(
    Object settings_how_jwl_uses_your_data,
  ) {
    return 'Para hacer que la aplicación funcione bien, necesitamos transferir desde su dispositivo ciertos datos de diagnóstico. No los venderemos ni los usaremos con fines de marketing. Para obtener más información, vaya a $settings_how_jwl_uses_your_data.';
  }

  @override
  String get settings_default_end_action => 'Acción final predeterminada';

  @override
  String get settings_download_over_cellular =>
      'Permitir descargas usando datos móviles';

  @override
  String get settings_download_over_cellular_subtitle =>
      'Puede que su compañía le cobre por el consumo de datos.';

  @override
  String get settings_how_jwl_uses_your_data => 'Cómo usa sus datos JW Library';

  @override
  String get settings_languages => 'Idioma';

  @override
  String get settings_languages_upper => 'IDIOMAS';

  @override
  String get settings_language_app => 'Idioma de la aplicación';

  @override
  String get settings_language_library => 'Idioma de la biblioteca';

  @override
  String get settings_license => 'Acuerdo de licencia';

  @override
  String get settings_license_agreement => 'Contrato de licencia';

  @override
  String get settings_main_color => 'Color principal';

  @override
  String get settings_main_books_color => 'Color de los libros de la Biblia';

  @override
  String get settings_never => 'Nunca';

  @override
  String get settings_never_uppercase => 'NUNCA';

  @override
  String get settings_notifications => 'Notificaciones y recordatorios';

  @override
  String get settings_notifications_upper => 'NOTIFICACIONES Y RECORDATORIOS';

  @override
  String get settings_notifications_daily_text =>
      'Recordatorio del texto diario';

  @override
  String settings_notifications_hour(Object hour) {
    return 'Hora del recordatorio: $hour';
  }

  @override
  String get settings_notifications_bible_reading =>
      'Recordatorio de lectura de la Biblia';

  @override
  String get settings_notifications_download_file =>
      'Notificaciones de archivos descargados';

  @override
  String get settings_notifications_download_file_subtitle =>
      'Se envía una notificación cada vez que se descarga un archivo.';

  @override
  String get settings_offline_mode => 'Modo sin internet';

  @override
  String get settings_offline_mode_subtitle =>
      'Desactive el acceso a Internet en JW Library para guardar los datos.';

  @override
  String get settings_open_source_licenses => 'Licencias de código abierto';

  @override
  String get settings_play_video_second_display =>
      'Reproducir el video en otra pantalla';

  @override
  String get settings_privacy => 'Privacidad';

  @override
  String get settings_privacy_policy => 'Política de privacidad';

  @override
  String get settings_privacy_uppercase => 'PRIVACIDAD';

  @override
  String get settings_send_diagnostic_data => 'Enviar datos de diagnóstico';

  @override
  String get settings_send_diagnostic_data_subtitle =>
      'Nos gustaría recopilar datos si se produce algún fallo en la aplicación. Solo los usaremos para hacer que siga funcionando bien.';

  @override
  String get settings_send_usage_data => 'Enviar datos de uso';

  @override
  String get settings_send_usage_data_subtitle =>
      'Nos gustaría recopilar datos de cómo usa la aplicación e interactúa con ella. Solo los usaremos para mejorar la aplicación, incluidos su diseño, funcionamiento y estabilidad.';

  @override
  String get settings_start_action => 'Acción de inicio';

  @override
  String get settings_stop_all_downloads => 'Detener todas las descargas';

  @override
  String get settings_storage_device => 'Dispositivo';

  @override
  String get settings_storage_external => 'Tarjeta SD';

  @override
  String get settings_storage_folder_title_audio_programs =>
      'Guardar las grabaciones en';

  @override
  String get settings_storage_folder_title_media =>
      'Guardar los archivos multimedia en';

  @override
  String get settings_storage_folder_title_videos => 'Guardar los videos en';

  @override
  String settings_storage_free_space(Object free, Object total) {
    return '$free disponibles de $total';
  }

  @override
  String get settings_stream_over_cellular =>
      'Permitir streaming usando datos móviles';

  @override
  String get settings_subtitles => 'Subtítulos';

  @override
  String get settings_subtitles_not_available => 'No disponibles';

  @override
  String get settings_suggestions => 'Sugerencias y errores';

  @override
  String get settings_suggestions_upper => 'SUGERENCIAS Y ERRORES';

  @override
  String get settings_suggestions_send => 'Enviar una sugerencia';

  @override
  String get settings_suggestions_subtitle =>
      'Escriba su sugerencia en un campo que se enviará automáticamente al desarrollador.';

  @override
  String get settings_bugs_send => 'Describir un error encontrado';

  @override
  String get settings_bugs_subtitle =>
      'Describa su error en un campo que se enviará automáticamente al desarrollador.';

  @override
  String get settings_support => 'Asistencia';

  @override
  String get settings_terms_of_use => 'Condiciones de uso';

  @override
  String get settings_userdata => 'Copia de seguridad';

  @override
  String get settings_userdata_upper => 'COPIA DE SEGURIDAD';

  @override
  String get settings_userdata_import => 'Importar copia de seguridad';

  @override
  String get settings_userdata_export => 'Exportar copia de seguridad';

  @override
  String get settings_userdata_reset => 'Restablecer esta copia de seguridad';

  @override
  String get settings_userdata_export_jwlibrary =>
      'Exportar datos de usuario a JW Library';

  @override
  String get settings_video_display => 'Reproducción del video';

  @override
  String get settings_video_display_uppercase => 'REPRODUCCIÓN DEL VIDEO';

  @override
  String message_download_publication(Object publicationTitle) {
    return '¿Deseas descargar «$publicationTitle»?';
  }

  @override
  String get message_import_data =>
      'Importando datos de la aplicación en curso...';

  @override
  String get label_sort_title_asc => 'Título (A-Z)';

  @override
  String get label_sort_title_desc => 'Título (Z-A)';

  @override
  String get label_sort_year_asc => 'Año (Más antiguo)';

  @override
  String get label_sort_year_desc => 'Año (Más reciente)';

  @override
  String get label_sort_symbol_asc => 'Símbolo (A-Z)';

  @override
  String get label_sort_symbol_desc => 'Símbolo (Z-A)';

  @override
  String get message_delete_publication => 'Publicación eliminada';

  @override
  String get message_update_cancel => 'Actualización cancelada';

  @override
  String get message_download_cancel => 'Descarga cancelada';

  @override
  String message_item_download_title(Object title) {
    return '« $title » no está descargado';
  }

  @override
  String message_item_download(Object title) {
    return '¿Le gustaría descargar « $title »?';
  }

  @override
  String message_item_downloading(Object title) {
    return 'Descargando « $title »';
  }

  @override
  String get message_confirm_userdata_reset_title =>
      'Confirmar restablecimiento';

  @override
  String get message_confirm_userdata_reset =>
      '¿Está seguro de que desea restablecer esta copia de seguridad? Perderá todos sus datos de su estudio individual. Esta acción es irreversible.';

  @override
  String get message_exporting_userdata => 'Exportando datos...';

  @override
  String get message_delete_userdata_title => 'Copia de seguridad eliminada';

  @override
  String get message_delete_userdata =>
      'La copia de seguridad se eliminó con éxito.';

  @override
  String message_file_not_supported_1_extension(Object extention) {
    return 'El archivo debe tener una extensión $extention.';
  }

  @override
  String message_file_not_supported_2_extensions(
    Object exention1,
    Object extention2,
  ) {
    return 'El archivo debe tener una extensión $exention1 o $extention2.';
  }

  @override
  String message_file_not_supported_multiple_extensions(Object extensions) {
    return 'El archivo debe tener una de las siguientes extensiones: $extensions.';
  }

  @override
  String get message_file_error_title => 'Error con el archivo';

  @override
  String message_file_error(Object extension) {
    return 'El archivo $extension seleccionado está dañado o no es válido. Por favor, compruebe el archivo e inténtelo de nuevo.';
  }

  @override
  String get message_publication_invalid_title => 'Publicación incorrecta';

  @override
  String message_publication_invalid(Object symbol) {
    return 'El archivo .jwpub seleccionado no coincide con la publicación requerida. Por favor, elija una publicación con el símbolo « $symbol ».';
  }

  @override
  String get message_import_playlist_successful =>
      'Importación de lista de reproducción exitosa.';

  @override
  String get message_userdata_reseting =>
      'Restableciendo copia de seguridad...';

  @override
  String get message_download_in_progress => 'Descarga en curso...';

  @override
  String label_tag_notes(Object count) {
    return '$count notas';
  }

  @override
  String label_tags_and_notes(Object count1, Object count2) {
    return '$count1 categorías y $count2 notas';
  }

  @override
  String get message_delete_playlist_title => 'Eliminar lista de reproducción';

  @override
  String message_delete_playlist(Object name) {
    return 'Esta acción eliminará permanentemente la lista de reproducción « $name ».';
  }

  @override
  String message_delete_item(Object item) {
    return '« $item » ha sido eliminado';
  }

  @override
  String message_app_up_to_date(Object currentVersion) {
    return 'No hay actualización disponible (versión actual: $currentVersion)';
  }

  @override
  String get message_app_update_available => 'Nueva versión disponible';

  @override
  String get label_next_meeting => 'PRÓXIMA REUNIÓN';

  @override
  String label_date_next_meeting(Object date, Object hour, Object minute) {
    return '$date a las $hour:$minute';
  }

  @override
  String get label_workship_public_talk_choosing =>
      'Elegir el número de discurso aquí...';

  @override
  String get action_public_talk_replace => 'Reemplazar discurso';

  @override
  String get action_public_talk_choose => 'Elegir un discurso';

  @override
  String get action_public_talk_remove => 'Eliminar discurso';

  @override
  String get action_congregations => 'Asambleas Locales';

  @override
  String get action_meeting_management => 'Planificación de Reuniones';

  @override
  String get action_brothers_and_sisters => 'Hermanos y Hermanas';

  @override
  String get action_blocking_horizontally_mode => 'Bloqueo Horizontal';

  @override
  String get action_qr_code => 'Generar un código QR';

  @override
  String get action_scan_qr_code => 'Escanear un Código QR';

  @override
  String get settings_page_transition => 'Transición de página';

  @override
  String get settings_page_transition_bottom => 'Transición desde abajo';

  @override
  String get settings_page_transition_right => 'Transición desde la derecha';

  @override
  String get label_research_all => 'TODO';

  @override
  String get label_research_wol => 'WOL';

  @override
  String get label_research_bible => 'BIBLIA';

  @override
  String get label_research_verses => 'VERSÍCULOS';

  @override
  String get label_research_images => 'IMÁGENES';

  @override
  String get label_research_notes => 'NOTAS';

  @override
  String get label_research_inputs_fields => 'CAMPOS';

  @override
  String get label_research_wikipedia => 'WIKIPEDIA';

  @override
  String get meps_language => 'S';

  @override
  String get label_icon_commentary => 'Nota de estudio';

  @override
  String get label_verses_side_by_side => 'Versículos lado a lado';

  @override
  String get message_verses_side_by_side =>
      'Mostrar las dos primeras traducciones lado a lado';

  @override
  String get settings_menu_display_upper => 'MENÚ';

  @override
  String get settings_show_publication_description =>
      'Mostrar descripción de las publicaciones';

  @override
  String get settings_show_publication_description_subtitle =>
      'Mostrar la descripción del sitio web debajo del título.';

  @override
  String get settings_show_document_description =>
      'Mostrar descripción de los documentos';

  @override
  String get settings_show_document_description_subtitle =>
      'Mostrar la descripción del sitio web debajo de los documentos.';

  @override
  String get settings_menu_auto_open_single_document =>
      'Abrir el documento directamente';

  @override
  String get settings_menu_auto_open_single_document_subtitle =>
      'Si solo hay un documento presente, abrirlo sin mostrar el menú.';
}
