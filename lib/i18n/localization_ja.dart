// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'localization.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get search_hint => '検索...';

  @override
  String get action_accept => '受け入れる';

  @override
  String get action_accept_uppercase => '受け入れる';

  @override
  String get action_add => '追加';

  @override
  String get action_add_a_note => 'メモを追加';

  @override
  String get action_add_a_tag => 'タグを追加';

  @override
  String get action_add_from_camera => '写真や動画を撮影して追加';

  @override
  String get action_add_from_files => 'ファイルを追加';

  @override
  String get action_add_from_photos => '撮影済みの写真や動画を追加';

  @override
  String get action_add_playlist => 'プレイリストを追加';

  @override
  String get action_add_to_playlist => 'プレイリストに追加';

  @override
  String get action_add_to_playlist_uppercase => 'プレイリストに追加';

  @override
  String get action_add_uppercase => '追加';

  @override
  String get action_allow => '許可';

  @override
  String get action_ask_me_again_later => '後で確認する';

  @override
  String get action_ask_me_again_later_uppercase => '後で確認する';

  @override
  String get action_back => '戻る';

  @override
  String get action_backup_and_restore => 'バックアップと復元';

  @override
  String get action_backup_create => 'バックアップを作成';

  @override
  String get action_bookmark => 'ブックマーク';

  @override
  String get action_bookmark_replace => 'ブックマークを移動';

  @override
  String get action_bookmark_uppercase => 'ブックマーク';

  @override
  String get action_bookmarks => 'ブックマーク';

  @override
  String get action_books => '聖書の各書';

  @override
  String get action_cancel => 'キャンセル';

  @override
  String get action_cancel_uppercase => 'キャンセル';

  @override
  String get action_change_color => '色を変更';

  @override
  String get action_chapters => '章';

  @override
  String get action_chapters_uppercase => '章';

  @override
  String get action_check => '確認';

  @override
  String get action_clear => 'クリア';

  @override
  String get action_clear_cache => 'キャッシュをクリア';

  @override
  String get action_clear_selection => '全て選択を解除';

  @override
  String get action_close => '閉じる';

  @override
  String get action_close_upper => '閉じる';

  @override
  String get action_collapse => '折り畳む';

  @override
  String get action_contents => '目次';

  @override
  String get action_continue => '続ける';

  @override
  String get action_continue_uppercase => '続ける';

  @override
  String get action_copy => 'コピー';

  @override
  String get action_copy_uppercase => 'コピー';

  @override
  String get action_copy_lyrics => '歌詞をコピー';

  @override
  String get action_copy_subtitles => '字幕をコピー';

  @override
  String get action_create => '作成';

  @override
  String get action_create_a_playlist => 'プレイリストを作成';

  @override
  String get action_create_a_playlist_uppercase => 'プレイリストを作成';

  @override
  String get action_customize => 'カスタマイズ';

  @override
  String get action_customize_uppercase => 'カスタマイズ';

  @override
  String get action_decline => '受け入れない';

  @override
  String get action_decline_uppercase => '受け入れない';

  @override
  String get action_define => '辞書';

  @override
  String get action_define_uppercase => '辞書';

  @override
  String get action_delete => '削除';

  @override
  String get action_delete_all => '全て削除';

  @override
  String get action_delete_all_media => '全てのメディア';

  @override
  String get action_delete_all_media_uppercase => '全てのメディア';

  @override
  String get action_delete_audio => '朗読版を削除';

  @override
  String action_delete_item(Object name) {
    return '$nameを削除する';
  }

  @override
  String get action_delete_media_from_this_publication => 'この出版物のメディア';

  @override
  String get action_delete_media_from_this_publication_uppercase =>
      'この出版物のメディア';

  @override
  String get action_delete_note => 'メモを削除する';

  @override
  String get action_delete_publication => '削除する';

  @override
  String get action_delete_publication_media => '出版物とメディアを削除';

  @override
  String get action_delete_publication_media_uppercase => '出版物とメディアを削除';

  @override
  String get action_delete_publication_only => '出版物のみ削除';

  @override
  String get action_delete_publication_only_uppercase => '出版物のみ削除';

  @override
  String action_delete_publications(Object count) {
    return '$count個を削除する';
  }

  @override
  String get action_delete_uppercase => '削除';

  @override
  String get action_deselect_all => '全ての選択を解除';

  @override
  String get action_discard => '破棄';

  @override
  String get action_display_furigana => 'ふりがなを表示';

  @override
  String get action_display_pinyin => 'ピンインを表示';

  @override
  String get action_display_menu => 'メニューを表示';

  @override
  String get action_display_yale => 'エール式ローマ字を表示';

  @override
  String get action_do_not_show_again => '次回からは表示しない';

  @override
  String get action_done => '完了';

  @override
  String get action_done_uppercase => '完了';

  @override
  String get action_download => 'ダウンロード';

  @override
  String get action_download_all => '全てダウンロード';

  @override
  String get action_download_all_uppercase => '全てダウンロード';

  @override
  String get action_download_audio => '朗読版をダウンロード';

  @override
  String action_download_audio_size(Object size) {
    return '朗読版（$size）をダウンロード';
  }

  @override
  String get action_download_bible => '聖書をダウンロード';

  @override
  String get action_download_media => 'メディアをダウンロード';

  @override
  String action_download_publication(Object title) {
    return '「$title」をダウンロードする';
  }

  @override
  String get action_download_supplemental_videos => '補足動画をダウンロード';

  @override
  String get action_download_uppercase => 'ダウンロード';

  @override
  String action_download_video(Object option, Object size) {
    return '$option ($size)をダウンロード';
  }

  @override
  String get action_download_videos => '動画をダウンロード';

  @override
  String get action_duplicate => 'コピー';

  @override
  String get action_edit => '編集';

  @override
  String get action_edit_uppercase => '編集';

  @override
  String get action_enter => '決定';

  @override
  String get action_enter_uppercase => '決定';

  @override
  String get action_expand => '展開する';

  @override
  String get action_export => 'エクスポート';

  @override
  String get action_favorites_add => 'お気に入りに追加';

  @override
  String get action_favorites_remove => 'お気に入りから削除';

  @override
  String get action_full_screen => '全画面';

  @override
  String get action_full_screen_exit => '全画面を終了する';

  @override
  String get action_go_to_playlist => 'プレイリストへ移動する';

  @override
  String get action_go_to_publication => '出版物を見る';

  @override
  String get action_got_it => '了解';

  @override
  String get action_got_it_uppercase => '了解';

  @override
  String get action_hide => '隠す';

  @override
  String get action_highlight => 'ハイライト';

  @override
  String get action_history => '履歴';

  @override
  String get action_import_anyway => 'OK';

  @override
  String get action_import_file => 'ファイルをインポート';

  @override
  String get action_import_playlist => 'プレイリストをインポート';

  @override
  String get action_just_once => '今回のみ';

  @override
  String get action_just_once_uppercase => '今回のみ';

  @override
  String get action_keep_editing => '編集を続ける';

  @override
  String get action_languages => '言語';

  @override
  String get action_later => '後で';

  @override
  String get action_learn_more => 'もっと詳しく';

  @override
  String get action_make_available_offline => 'デバイスに保存';

  @override
  String get action_media_minimize => '最小化する';

  @override
  String get action_media_restore => '再表示する';

  @override
  String get action_more_songs => '他の曲';

  @override
  String get action_navigation_menu_close => 'ナビゲーション・メニューを閉じる';

  @override
  String get action_navigation_menu_open => 'ナビゲーション・メニューを開く';

  @override
  String get action_new_note_in_this_tag => 'このタグで新しいメモを作成';

  @override
  String get action_new_tag => '新規タグ';

  @override
  String get action_next => '次へ';

  @override
  String get action_no => 'いいえ';

  @override
  String get action_note_minimize => 'メモを最小化';

  @override
  String get action_note_restore => 'メモを再表示';

  @override
  String get action_ok => 'OK';

  @override
  String get action_open => '開く';

  @override
  String get action_open_in => '開く';

  @override
  String get action_open_in_jworg => 'JW.ORGで開く';

  @override
  String get action_open_in_online_library => 'オンライン・ライブラリーで開く';

  @override
  String get action_open_in_share => 'リンクをシェア';

  @override
  String get action_open_in_share_file => 'ファイルをシェア';

  @override
  String get action_open_uppercase => '開く';

  @override
  String get action_outline_of_contents => '概要';

  @override
  String get action_outline_of_contents_uppercase => '概要';

  @override
  String get action_pause => '一時停止';

  @override
  String get action_personal_data_backup => 'バックアップを作成';

  @override
  String get action_personal_data_backup_internal => '更新前のデータもバックアップ';

  @override
  String get action_personal_data_backup_internal_uppercase => '更新前のデータもバックアップ';

  @override
  String get action_personal_data_backup_uppercase => 'バックアップを作成';

  @override
  String get action_personal_data_backup_what_i_have_now =>
      '端末に今あるデータだけをバックアップ';

  @override
  String get action_personal_data_backup_what_i_have_now_uppercase =>
      '端末に今あるデータだけをバックアップ';

  @override
  String get action_personal_data_delete_backup => 'バックアップを削除';

  @override
  String get action_personal_data_delete_backup_uppercase => 'バックアップを削除';

  @override
  String get action_personal_data_do_not_backup => 'バックアップを作成しない';

  @override
  String get action_personal_data_do_not_backup_uppercase => 'バックアップを作成しない';

  @override
  String get action_personal_data_keep_current => '端末に今あるデータだけで続行';

  @override
  String get action_personal_data_keep_current_uppercase => '端末に今あるデータだけで続行';

  @override
  String get action_personal_data_restore_internal_backup => 'バックアップを復元';

  @override
  String get action_personal_data_restore_internal_backup_uppercase =>
      'バックアップを復元';

  @override
  String get action_play => '再生';

  @override
  String get action_play_all => '全て再生';

  @override
  String get action_play_audio => '朗読版を再生';

  @override
  String get action_play_downloaded => 'ダウンロード済みのものだけを再生する';

  @override
  String get action_play_this_track_only => '1曲のみ再生';

  @override
  String get action_playlist_end_continue => '次を再生';

  @override
  String get action_playlist_end_freeze => '一時停止';

  @override
  String get action_playlist_end_stop => '停止';

  @override
  String get action_previous => '戻る';

  @override
  String get action_reading_mode => '閲覧モード';

  @override
  String get action_refresh => '更新';

  @override
  String get action_refresh_uppercase => '更新';

  @override
  String get action_remove => '削除';

  @override
  String action_remove_audio_size(Object size) {
    return '朗読版（$size）を削除';
  }

  @override
  String get action_remove_from_device => 'デバイスから削除';

  @override
  String get action_remove_supplemental_videos => '補足動画を削除';

  @override
  String get action_remove_tag => 'タグを削除する';

  @override
  String get action_remove_uppercase => '削除';

  @override
  String action_remove_video_size(Object size) {
    return '動画（$size）を削除';
  }

  @override
  String get action_remove_videos => '動画を削除';

  @override
  String get action_rename => '名前の変更';

  @override
  String get action_rename_uppercase => '名前の変更';

  @override
  String get action_reopen_second_window => 'もう一度開く';

  @override
  String get action_replace => '移動';

  @override
  String get action_reset => 'リセット';

  @override
  String get action_reset_uppercase => 'リセット';

  @override
  String get action_reset_today_uppercase => '今日にリセット';

  @override
  String get action_restore => '復元';

  @override
  String get action_restore_a_backup => 'バックアップを復元';

  @override
  String get action_restore_uppercase => '復元';

  @override
  String get action_retry => '再試行';

  @override
  String get action_retry_uppercase => '再試行';

  @override
  String get action_save_image => '画像を保存';

  @override
  String get action_search => '検索';

  @override
  String get action_search_uppercase => '検索';

  @override
  String get action_see_all => '全て見る';

  @override
  String get action_select => '選択';

  @override
  String get action_select_all => '全て選択';

  @override
  String get action_settings => '設定';

  @override
  String get action_settings_uppercase => '設定';

  @override
  String get action_share => '共有';

  @override
  String get action_share_uppercase => '共有';

  @override
  String get action_share_image => '画像を共有';

  @override
  String get action_shuffle => 'シャッフル';

  @override
  String get action_show_lyrics => '歌詞を表示';

  @override
  String get action_show_subtitles => '字幕を表示';

  @override
  String get action_sort_by => '並べ替える';

  @override
  String get action_stop_download => 'ダウンロードの中止';

  @override
  String get action_stop_trying => '中止';

  @override
  String get action_stop_trying_uppercase => '中止';

  @override
  String get action_stream => 'ストリーミング';

  @override
  String get action_text_settings => '文字サイズ';

  @override
  String get action_translations => '他の翻訳';

  @override
  String get action_trim => 'トリミング';

  @override
  String get action_try_again => '再試行';

  @override
  String get action_try_again_uppercase => '再試行';

  @override
  String get action_ungroup => '分割';

  @override
  String get action_update => '更新';

  @override
  String get action_update_all => '全て更新';

  @override
  String action_update_audio_size(Object size) {
    return '朗読版（$size）を更新';
  }

  @override
  String action_update_video_size(Object size) {
    return '動画（$size）を更新';
  }

  @override
  String get action_view_mode_image => '印刷版を表示';

  @override
  String get action_view_mode_text => 'テキストを表示';

  @override
  String get action_view_picture => '画像を見る';

  @override
  String get action_view_source => '元のビデオに戻る';

  @override
  String get action_view_text => '文章を表示';

  @override
  String get action_volume_adjust => '音量調整';

  @override
  String get action_volume_mute => 'ミュート';

  @override
  String get action_volume_unmute => 'ミュート解除';

  @override
  String get action_yes => 'はい';

  @override
  String get label_additional_reading => 'さらに読む';

  @override
  String label_all_notes(Object count) {
    return '$count個のメモ';
  }

  @override
  String label_all_tags(Object count) {
    return '$count個のタグ';
  }

  @override
  String get label_all_types => '全種類';

  @override
  String get label_audio_available => '朗読版が利用可能';

  @override
  String get label_breaking_news => 'ニュース速報';

  @override
  String label_breaking_news_count(Object count, Object total) {
    return '$count / $total';
  }

  @override
  String get label_color_blue => 'ブルー';

  @override
  String get label_color_green => 'グリーン';

  @override
  String get label_color_orange => 'オレンジ';

  @override
  String get label_color_pink => 'ピンク';

  @override
  String get label_color_purple => 'パープル';

  @override
  String get label_color_yellow => 'イエロー';

  @override
  String label_convention_day(Object number) {
    return '$number日目';
  }

  @override
  String get label_convention_releases => '大会の発表物';

  @override
  String label_date_range_one_month(Object day1, Object day2, Object month) {
    return '$month$day1-$day2日';
  }

  @override
  String label_date_range_two_months(
    Object day1,
    Object day2,
    Object month1,
    Object month2,
  ) {
    return '$month1$day1日-$month2$day2日';
  }

  @override
  String label_document_pub_title(Object doc, Object pub) {
    return '$doc - $pub';
  }

  @override
  String get label_download_all_cloud_uppercase => '未ダウンロード';

  @override
  String get label_download_all_device_uppercase => 'ダウンロード済み';

  @override
  String label_download_all_files(Object count) {
    return '$countファイル';
  }

  @override
  String get label_download_all_one_file => '1個のファイル';

  @override
  String get label_download_all_up_to_date => '全てダウンロード済み';

  @override
  String get label_download_video => '動画をダウンロード';

  @override
  String get label_downloaded => 'ダウンロード済み';

  @override
  String get label_downloaded_uppercase => 'ダウンロード済み';

  @override
  String label_duration(Object time) {
    return '長さ $time';
  }

  @override
  String get label_entire_video => '動画全体';

  @override
  String get label_home_frequently_used => 'よく使うもの';

  @override
  String get label_icon_bookmark => 'ブックマーク';

  @override
  String get label_icon_bookmark_actions => 'ブックマークの編集';

  @override
  String get label_icon_bookmark_delete => 'ブックマークの削除';

  @override
  String get label_icon_download_publication => 'ダウンロードする';

  @override
  String get label_icon_extracted_content => '抽出した情報';

  @override
  String get label_icon_footnotes => '脚注';

  @override
  String get label_icon_marginal_references => '欄外参照';

  @override
  String get label_icon_parallel_translations => '他の翻訳';

  @override
  String get label_icon_scroll_down => '下にスクロール';

  @override
  String get label_icon_search_suggestion => '検索候補';

  @override
  String get label_icon_supplementary_hide => 'スタディー・ペインを隠す';

  @override
  String get label_icon_supplementary_show => 'スタディー・ペインを表示';

  @override
  String get label_import => 'インポート';

  @override
  String get label_import_jwpub => 'JWPUBをインポート';

  @override
  String get label_import_playlists => 'プレイリストをインポート';

  @override
  String get label_import_uppercase => 'インポート';

  @override
  String label_languages_2(Object language1, Object language2) {
    return '$language1と$language2';
  }

  @override
  String label_languages_3_or_more(Object count, Object language) {
    return '$languageと他の$count言語';
  }

  @override
  String get label_languages_more => '利用可能な言語';

  @override
  String get label_languages_more_uppercase => '利用可能な言語';

  @override
  String get label_languages_recommended => 'おすすめ';

  @override
  String get label_languages_recommended_uppercase => 'おすすめ';

  @override
  String label_last_updated(Object datetime) {
    return '前回のアップデート $datetime';
  }

  @override
  String get label_marginal_general => '全般';

  @override
  String get label_marginal_parallel_account => '並行記述';

  @override
  String get label_marginal_quotation => '引用元';

  @override
  String get label_markers => 'マーカー';

  @override
  String get label_media_gallery => 'メディア・ギャラリー';

  @override
  String get label_more => 'その他';

  @override
  String get label_not_included => '非表示アイテム';

  @override
  String get label_not_included_uppercase => '非表示アイテム';

  @override
  String get label_note => 'メモ';

  @override
  String get label_note_title => 'タイトル';

  @override
  String get label_notes => 'メモ';

  @override
  String get label_notes_uppercase => 'メモ';

  @override
  String get label_off => 'オフ';

  @override
  String get label_on => 'オン';

  @override
  String get label_other_articles => 'この号のほかの記事';

  @override
  String get label_other_meeting_publications => '他の資料';

  @override
  String get label_overview => '概略';

  @override
  String get label_paused => '一時停止中';

  @override
  String get label_pending_updates => '更新待ち';

  @override
  String get label_pending_updates_uppercase => '更新待ち';

  @override
  String get label_picture => '画像';

  @override
  String get label_pictures => '画像';

  @override
  String get label_pictures_videos_uppercase => '画像と動画';

  @override
  String get label_playback_position => '再生位置';

  @override
  String get label_playback_speed => '再生スピード';

  @override
  String label_playback_speed_colon(Object speed) {
    return '再生スピード: $speed';
  }

  @override
  String label_playback_speed_normal(Object speed) {
    return '$speed · 標準';
  }

  @override
  String get label_playing => '再生中';

  @override
  String get label_playing_pip => 'ピクチャー・イン・ピクチャーで再生中';

  @override
  String label_playlist_duration(Object number) {
    return '​$number分';
  }

  @override
  String label_playlist_items(Object count) {
    return '​$count項目';
  }

  @override
  String label_playlist_midweek_meeting(Object date) {
    return '生活と奉仕（$date ）';
  }

  @override
  String get label_playlist_name => 'プレイリストの名称';

  @override
  String label_playlist_watchtower_study(Object date) {
    return '「ものみの塔」研究（$date）';
  }

  @override
  String get label_playlist_when_done => '再生が終わったら...';

  @override
  String get label_reference_works => '参照資料';

  @override
  String get label_related_scriptures => '関連聖句';

  @override
  String get label_repeat => 'リピート';

  @override
  String get label_repeat_all => '全曲リピート再生';

  @override
  String get label_repeat_all_short => '全て';

  @override
  String get label_repeat_off => 'リピート再生オフ';

  @override
  String get label_repeat_one => '1曲リピート再生';

  @override
  String get label_repeat_one_short => '1つ';

  @override
  String get label_research_guide => 'リサーチガイド';

  @override
  String get label_search_jworg => 'JW.ORGで検索';

  @override
  String get label_search_playlists => 'プレイリストを検索';

  @override
  String get label_seek_back_5 => '5秒戻す';

  @override
  String get label_seek_forward_15 => '15秒進める';

  @override
  String get label_select_a_week => '週を選択';

  @override
  String get label_select_markers => 'マーカーを選択';

  @override
  String get label_settings => '設定';

  @override
  String get label_settings_airplay => 'AirPlayに接続';

  @override
  String get label_settings_airplay_disconnect => 'AirPlayを解除';

  @override
  String get label_settings_cast => 'キャスト';

  @override
  String get label_settings_cast_disconnect => 'キャストを解除';

  @override
  String label_share_start_at(Object marker) {
    return '$markerから再生';
  }

  @override
  String get label_shuffle_off => 'シャッフル再生オフ';

  @override
  String get label_shuffle_on => 'シャッフル再生オン';

  @override
  String get label_sort_frequently_used => 'よく使うもの';

  @override
  String get label_sort_largest_size => 'データの大きいもの';

  @override
  String get label_sort_publication_symbol => '出版物の略号';

  @override
  String get label_sort_rarely_used => 'あまり使わないもの';

  @override
  String get label_sort_title => 'タイトル';

  @override
  String get label_sort_year => '年';

  @override
  String label_streaming_media(Object title) {
    return 'ストリーミング ・ $title';
  }

  @override
  String get label_study_bible_content_available => 'スタディー版聖書のコンテンツが利用可能';

  @override
  String get label_study_content => '研究用コンテンツ';

  @override
  String get label_supplemental_videos => '補足動画';

  @override
  String get label_support_code => 'コード';

  @override
  String get label_support_code_uppercase => 'コード';

  @override
  String get label_tags => 'タグ';

  @override
  String get label_tags_uppercase => 'タグ';

  @override
  String get label_text_size_slider => '文字サイズの調節バー';

  @override
  String get label_thumbnail_publication => '出版物のサムネイル';

  @override
  String get label_topics_publications_media => 'トピック，出版物，メディアなど';

  @override
  String label_trim_current(Object timecode) {
    return '現在の位置 $timecode';
  }

  @override
  String label_trim_end(Object timecode) {
    return '終点の位置 $timecode';
  }

  @override
  String label_trim_start(Object timecode) {
    return '始点の位置 $timecode';
  }

  @override
  String label_units_storage_bytes(Object number) {
    return '$numberバイト';
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
  String get label_untagged => 'タグなし';

  @override
  String get label_unused_bookmark => '未使用のブックマーク';

  @override
  String get label_update_available => 'アップデートがあります。';

  @override
  String get label_videos => '動画';

  @override
  String get label_view_original => '元のビデオを見る';

  @override
  String get label_volume_level => '音量';

  @override
  String label_volume_percent(Object value) {
    return '$valueパーセント';
  }

  @override
  String get label_weeks => '週';

  @override
  String get label_whats_new_1_day_ago => '1日前';

  @override
  String get label_whats_new_1_hour_ago => '1時間前';

  @override
  String get label_whats_new_1_minute_ago => '1分前';

  @override
  String get label_whats_new_1_month_ago => '1か月前';

  @override
  String get label_whats_new_1_year_ago => '1年前';

  @override
  String get label_whats_new_earlier => '2カ月前以前';

  @override
  String get label_whats_new_last_month => '先月';

  @override
  String label_whats_new_multiple_days_ago(Object count) {
    return '$count日前';
  }

  @override
  String label_whats_new_multiple_hours_ago(Object count) {
    return '$count時間前';
  }

  @override
  String label_whats_new_multiple_minutes_ago(Object count) {
    return '$count分前';
  }

  @override
  String label_whats_new_multiple_months_ago(Object count) {
    return '$countか月前';
  }

  @override
  String label_whats_new_multiple_year_ago(Object count) {
    return '$count年前';
  }

  @override
  String get label_whats_new_multiple_seconds_ago => '数秒前';

  @override
  String get label_whats_new_this_month => '今月';

  @override
  String get label_whats_new_this_week => '今週';

  @override
  String get label_whats_new_today => '今日';

  @override
  String label_yeartext_currently(Object language) {
    return '現在の設定: $language';
  }

  @override
  String get label_yeartext_language => '年句の言語';

  @override
  String get label_yeartext_meetings_tab => '集会タブと同じ言語';

  @override
  String get label_yeartext_off => '年句は表示されません。';

  @override
  String labels_media_player_elapsed_time(
    Object time_elapsed,
    Object total_duration,
  ) {
    return '$total_duration中$time_elapsed';
  }

  @override
  String get labels_pip_exit => 'ピクチャー・イン・ピクチャーを終了';

  @override
  String get labels_pip_play => 'ピクチャー・イン・ピクチャーを開始';

  @override
  String get labels_this_week => '今週';

  @override
  String get message_access_file_permission_rationale_description =>
      '出版物，メディア，バックアップデータをインポートするためのアクセスです。次の画面で「許可」をタップすると，アクセスが許可されます。';

  @override
  String get message_access_file_permission_rationale_title =>
      'JW Libraryがこの端末のファイルにアクセスしようとしています';

  @override
  String get message_accessibility_narrator_enabled =>
      'ナレーター機能が有効になっていると，ハイライト機能は使えません。';

  @override
  String get message_accessibility_talkback_enabled =>
      'TalkBack（音声読み上げ機能）が有効になっていると，ハイライト機能は使えません。';

  @override
  String get message_accessibility_voiceover_enabled =>
      'VoiceOver（画面読み上げ機能）が有効になっていると，ハイライト機能は使えません。';

  @override
  String get message_added_to_playlist => 'プレイリストに追加されました';

  @override
  String message_added_to_playlist_name(Object playlistItem) {
    return 'プレイリスト「$playlistItem」に追加されました';
  }

  @override
  String get message_auto_update_pubs => '今後，コンテンツを自動的に更新しますか？';

  @override
  String get message_backup_create_explanation =>
      'メモ，タグ，ハイライト，お気に入り，ブックマークをバックアップファイルに保存します。';

  @override
  String get message_clear_cache => 'キャッシュをクリアしています...';

  @override
  String get message_catalog_downloading => '新しいコンテンツを確認中…';

  @override
  String get message_catalog_fail => '確認に失敗しました';

  @override
  String get message_catalog_new => '新しいコンテンツがあります';

  @override
  String get message_catalog_success => '確認が完了しました';

  @override
  String get message_catalog_up_to_date => '新しいコンテンツはありません';

  @override
  String get message_checking => '確認中・・・・・・';

  @override
  String get message_choose_playlist => 'プレイリストを選択';

  @override
  String get message_coaching_change_speed => '再生スピードの調整';

  @override
  String get message_coaching_change_speed_description => '上か下にスワイプ';

  @override
  String get message_coaching_more_button => 'その他ボタン';

  @override
  String get message_coaching_more_button_description =>
      '「削除」などのオプションを見たい時にタップします。';

  @override
  String get message_coaching_next_prev_marker => '前後のマーカーに移動';

  @override
  String get message_coaching_next_prev_marker_description => '右か左にスワイプ';

  @override
  String get message_coaching_play_pause => '一時停止/再生';

  @override
  String get message_coaching_play_pause_description => '2本指でタップ';

  @override
  String get message_coaching_playlists =>
      '動画，オーディオファイル，画像をプレイリストに追加できます。作成したプレイリストは「個人研究」タブで確認・編集できます。';

  @override
  String get message_coaching_publications_download =>
      'ビデオを入手するには，まずそれぞれの出版物をダウンロードしてください。';

  @override
  String get message_confirm_delete => '削除してもよろしいですか？';

  @override
  String get message_confirm_stop_download => 'ダウンロードを中止しますか？';

  @override
  String get message_content_not_available => 'このコンテンツは利用できません。';

  @override
  String get message_content_not_available_in_selected_language =>
      '選択されている言語では利用できないコンテンツがあります。';

  @override
  String get message_delete_failure_title => '削除失敗';

  @override
  String get message_delete_publication_media =>
      'この出版物には，メディアのコンテンツが1個含まれています。削除しますか。';

  @override
  String message_delete_publication_media_multiple(Object count) {
    return 'この出版物には，メディアのコンテンツが$count個含まれています。削除しますか。';
  }

  @override
  String get message_delete_publication_videos => 'この出版物のビデオも削除されます。';

  @override
  String get message_discard_changes => '変更は保存されていません。';

  @override
  String get message_discard_changes_title => '変更を破棄しますか？';

  @override
  String get message_do_not_close_app => 'アプリを閉じないでください。';

  @override
  String get message_download_complete => 'ダウンロード完了';

  @override
  String get message_download_from_jworg => 'jw.orgへ移動してファイルをダウンロードします。';

  @override
  String get message_download_from_jworg_title => 'JW.ORGからファイルをダウンロード';

  @override
  String get message_download_publications_for_meeting =>
      '集会で使用する出版物をダウンロードしてください。';

  @override
  String get message_download_research_guide =>
      '最新のリサーチガイドをダウンロードすると，役立つ資料を見ることができます。';

  @override
  String get message_download_will_close_item => 'ダウンロードを始めると，このコンテンツは終了します。';

  @override
  String get message_empty_audio => '朗読版はありません。';

  @override
  String get message_empty_pictures_videos => '画像と動画はありません。';

  @override
  String get message_file_cannot_open => 'このファイルはJW Libraryでは開けません。';

  @override
  String message_file_corrupted(Object filename) {
    return 'ファイルに不具合があるため，\"$filename\"はJW Libraryにインポートされませんでした。ファイルをダウンロードし直してください。';
  }

  @override
  String get message_file_corrupted_title => 'ファイルの不具合';

  @override
  String message_file_fail_multiple(Object number) {
    return 'インポートされなかったファイル: $number';
  }

  @override
  String get message_file_failed => 'インポートされなかったファイル: 1';

  @override
  String get message_file_found =>
      'この場所には，JW Libraryにインポートできるファイルが他にも1個あります。今すぐインポートしますか？';

  @override
  String message_file_found_multiple(Object number) {
    return 'この場所には，JW Libraryにインポートできるファイルが他にも$number個あります。今すぐインポートしますか？';
  }

  @override
  String get message_file_found_title => 'インポート可能なファイル';

  @override
  String get message_file_import_complete => 'インポート完了';

  @override
  String get message_file_import_fail => 'このファイルはインポートできません。';

  @override
  String get message_file_importing => '残り1ファイル';

  @override
  String message_file_importing_multiple(Object number) {
    return '残り$numberファイル';
  }

  @override
  String get message_file_importing_title => 'インポート中…';

  @override
  String message_file_importing_name(Object fileName) {
    return 'ファイル $fileName をインポートしています...';
  }

  @override
  String message_file_missing_pub(Object symbol) {
    return 'このファイルに対応する出版物が見つかりません。\"$symbol”に対応する出版物をインストールしてから，もう一度お試しください。ほかの出版物でこのファイルを参照しようとしているなら，その出版物の画面に移動し，インポート機能を使ってこのファイルを直接選択してください。';
  }

  @override
  String get message_file_missing_pub_title => '出版物がインストールされていません';

  @override
  String get message_file_not_recognized =>
      'このファイルはJW Libraryのコンテンツに対応していません。該当する出版物を先にダウンロードするか，別のファイルを選択してください。';

  @override
  String get message_file_not_recognized_title => '対応していないファイル';

  @override
  String get message_file_not_supported_title => '対応していないファイル';

  @override
  String get message_file_success => 'インポートされたファイル: 1';

  @override
  String message_file_success_multiple(Object number) {
    return 'インポートされたファイル: $number';
  }

  @override
  String get message_file_unknown_type => 'このファイルを開くことができませんでした。';

  @override
  String get message_file_wrong => 'ファイル名が間違っています。';

  @override
  String get message_file_wrong_title => '間違ったファイル';

  @override
  String get message_full_screen_left_swipe => 'ナビゲーションウィンドウを表示するには，右にスワイプします。';

  @override
  String get message_full_screen_title => '全画面表示になっています';

  @override
  String get message_full_screen_top_swipe => '全画面表示を終了するには，下にスワイプします。';

  @override
  String get message_help_us_improve =>
      '前回JW Libraryが予期せずに終了しました。原因の診断に役立つ情報を開発者に提供しますか。この情報はアプリ性能の向上に役立ちます。';

  @override
  String get message_help_us_improve_title => '診断データを提供';

  @override
  String get message_import_jwlsl_playlist =>
      'このバックアップファイルには，手話用JW Libraryで作成されたプレイリストが含まれています。インポートしますか？';

  @override
  String get message_install_failure => 'インストールを完了できませんでした。';

  @override
  String get message_install_failure_description =>
      'この出版物をJW Libraryに読み込むことができませんでした。ダウンロードと読み込みをもう一度やり直してください。';

  @override
  String get message_install_failure_title => 'インストールに失敗しました';

  @override
  String get message_install_latest =>
      'この出版物をインストールするには，JW Libraryアプリを最新版に更新してください。';

  @override
  String get message_install_media_extensions =>
      'このファイルを使用するには，Microsoft Storeから「HEIF 画像拡張機能」と「HEVC ビデオ拡張機能」をインストールしてください。';

  @override
  String get message_install_study_edition =>
      '「新世界訳聖書」のブックマーク，ハイライト，メモの全てが，スタディー版でも見れるようにコピーされます。';

  @override
  String get message_install_study_edition_title => 'スタディー版をインストールする';

  @override
  String get message_install_success_study_edition =>
      '「新世界訳聖書」のハイライトとメモをスタディー版にコピーしました。';

  @override
  String get message_install_success_title => 'インストール完了';

  @override
  String get message_installing => '読み込み中…';

  @override
  String get message_item_unavailable =>
      '現在，このファイルは利用できません。後でもう一度お試しください。または，このファイルが端末に保存されているなら，インポートしてください。';

  @override
  String get message_item_unavailable_title => '利用できないファイル';

  @override
  String message_large_file_warning(Object size) {
    return 'このファイルは$sizeあり，デバイスの容量を消費します。このファイルをインポートしますか。';
  }

  @override
  String get message_large_file_warning_title => '容量の大きなファイル';

  @override
  String get message_media_starting_may_2016 =>
      '集会で用いる出版物にメディアが含まれるようになるのは，2016年5月以降です。';

  @override
  String message_media_up_next(Object title) {
    return '次の曲: $title';
  }

  @override
  String get message_migration_failure_study_edition =>
      '「新世界訳聖書」のハイライトとメモをスタディー版にコピーできませんでした。再試行するにはスタディー版を削除し，もう一度ダウンロードしてください。';

  @override
  String get message_migration_failure_title => 'コピー失敗';

  @override
  String get message_migration_study_edition =>
      'メモとハイライトをスタディー版にコピーしています。しばらくお待ちください。これには多少時間がかかります。';

  @override
  String get message_missing_download_location => '「設定」でダウンロードする場所を選択してください。';

  @override
  String get message_missing_download_location_title => 'ダウンロードできません';

  @override
  String get message_missing_download_location_windows_n => 'ダウンロードする場所がありません。';

  @override
  String get message_name_taken => 'この名前はすでに使われています。';

  @override
  String get message_no_audio_programs => 'この言語のオーディオ・プログラムはありません。';

  @override
  String get message_no_content => 'コンテンツはありません。';

  @override
  String get message_no_footnotes => '脚注はありません。';

  @override
  String get message_no_internet_audio => '朗読版があるかを確認するにはインターネットに接続してください。';

  @override
  String get message_no_internet_audio_programs =>
      'オーディオ・プログラムを聞くには，インターネットに接続してください。';

  @override
  String get message_no_internet_connection => 'インターネットに接続してください。';

  @override
  String get message_no_internet_connection_title => 'インターネット接続なし';

  @override
  String get message_no_internet_language => '全ての言語を確認するには，インターネットに接続してください。';

  @override
  String get message_no_internet_media => 'メディアを確認するには，インターネットに接続してください。';

  @override
  String get message_no_internet_meeting => '集会の予定を確認するには，インターネットに接続してください。';

  @override
  String get message_no_internet_publications => '出版物を確認するには，インターネットに接続してください。';

  @override
  String get message_no_internet_videos_media => 'ビデオを見るには，インターネットに接続してください。';

  @override
  String get message_no_items_audios => 'この言語では音声は利用できません。';

  @override
  String get message_no_items_publications => 'この言語では出版物は利用できません。';

  @override
  String get message_no_items_videos => 'この言語では動画は利用できません。';

  @override
  String get message_no_marginal_references => '欄外参照はありません。';

  @override
  String get message_no_media => 'オーディオ・プログラムかビデオをダウンロードしてください。';

  @override
  String get message_no_media_items => 'この言語の新しいメディアはありません。';

  @override
  String get message_no_media_title => 'メディアがありません';

  @override
  String get message_no_midweek_meeting_content => 'この日付の週半ばの集会のコンテンツはありません。';

  @override
  String get message_no_weekend_meeting_content => 'この日付の週末の集会のコンテンツはありません。';

  @override
  String get message_no_ministry_publications => 'この言語では，「宣教」に該当するコンテンツがありません。';

  @override
  String get message_no_notes => 'メモを作成するとここに表示されます。';

  @override
  String get message_no_other_bibles => 'この章を含む他の翻訳はありません。';

  @override
  String get message_no_playlist_items => 'プレイリストにアイテムを追加してください。';

  @override
  String get message_no_playlists => 'ビデオ，オーディオ，画像をプレイリストに追加できます。';

  @override
  String get message_no_study_content => '研究用コンテンツはありません。';

  @override
  String message_no_tags(Object name) {
    return '\"$name\"というタグが付いたものがここに表示されます。';
  }

  @override
  String get message_no_topics_found => 'トピックはありません。';

  @override
  String get message_no_verses_available => 'この書で利用できる節はありません。';

  @override
  String get message_no_videos => 'この言語のビデオはありません。';

  @override
  String get message_no_wifi_connection =>
      'データ通信料が発生する可能性があります。「設定」から，モバイルデータ通信の使用を常に有効にできます。再生しますか。';

  @override
  String get message_no_wifi_connection_missing_items =>
      '全てを再生するには，幾つかのアイテムをストリーミングで再生する必要があります。データ通信料が発生する可能性があります。続行しますか。';

  @override
  String get message_not_enough_storage =>
      'ストレージに十分な空き容量がありません。「設定」からストレージの管理を行ってください。';

  @override
  String get message_not_enough_storage_title => '空き容量不足';

  @override
  String get message_offline_mode =>
      'JW Lifeでのインターネット接続が無効になっています。インターネット接続を許可しますか。';

  @override
  String get message_offline_mode_multiple_items =>
      'JW Lifeでのインターネット接続が無効になっています。全てを再生するには，インターネット経由のストリーミングが必要です。';

  @override
  String message_offline_terms(Object url) {
    return 'JW Libraryはこの文書を読み込めませんでした。インターネットにつながっている端末で，$urlにアクセスし，利用規約をご覧ください。その後に「受け入れる」をタップしてください。';
  }

  @override
  String get message_permission_files => '他のアプリにあるファイルを開くには，アクセスを許可する必要があります。';

  @override
  String get message_permission_photos => '出版物の画像を保存することを許可します。';

  @override
  String get message_permission_title => 'アクセスの許可';

  @override
  String get message_personal_data_backup_confirmation =>
      'バックアップを作成しないとメモやハイライトを復元できなくなります。バックアップを作成することをお勧めします。';

  @override
  String get message_personal_data_backup_found_description =>
      'アプリの更新の際に失われたメモとハイライトのデータを復元できます。どちらのデータをバックアップしますか。';

  @override
  String get message_personal_data_backup_found_title => 'バックアップファイルがあります';

  @override
  String get message_personal_data_delete_backup =>
      '失われたメモやハイライトのデータは復元できなくなります。削除しますか。';

  @override
  String get message_personal_data_not_enough_storage =>
      'JW Libraryをうまく起動できません。ストレージに十分な空き容量がない可能性があります。';

  @override
  String get message_personal_data_restore_internal_backup_description =>
      'アプリの更新の際に失われたメモとハイライトが自動的にバックアップされています。バックアップを復元しますか。';

  @override
  String get message_personal_data_update_fail_description =>
      'アプリの更新の時にメモやハイライトの一部が失われました。メモとハイライトのバックアップを作成しておけば，次のアプリの更新の時に復元できるかもしれません。';

  @override
  String get message_personal_data_update_fail_title => '申し訳ありません…';

  @override
  String get message_playing_pip => 'ピクチャー・イン・ピクチャーで再生中';

  @override
  String get message_please_select_a_bible => 'まず聖書をダウンロードしましょう';

  @override
  String get message_privacy_settings =>
      'アプリがきちんと動作するために必須のデータが，お使いのデバイスと開発者の間でやり取りされます。さらに，アプリをさらに使いやすいものにするために，アプリの使用に関するデータも収集されます。診断に役立つデータやアプリの使用に関するデータは，「受け入れる」か「受け入れない」かを選ぶことができます。「受け入れる」をクリックすると，アプリの性能や使いやすさを向上させるために開発者がこのデータを使用することに同意したことになります。このデータが販売されたり商業目的で利用されたりすることは決してありません。データの使用に関してさらに知りたい場合や，細かな設定をしたい場合には，下にある「カスタマイズ」をクリックするか，アプリの「設定」ページをご覧ください。';

  @override
  String get message_privacy_settings_title => 'プライバシー設定';

  @override
  String get message_publication_no_videos =>
      'この出版物にはビデオがありません。この出版物は，このアプリの他の機能をサポートするために使われている可能性があります。';

  @override
  String get message_publication_unavailable =>
      '現在このコンテンツを利用できません。後でもう一度お試しください。';

  @override
  String get message_publication_unavailable_title => 'このコンテンツはご利用いただけません';

  @override
  String message_remove_tag(Object name) {
    return '\"$name\"というタグが全てのアイテムから削除されます。メモは削除されません。';
  }

  @override
  String get message_request_timed_out_title => '接続要求がタイムアウトしました';

  @override
  String get message_restore_a_backup_explanation => 'この端末の個人研究データを上書きします。';

  @override
  String get message_restore_confirm_explanation =>
      'この端末のメモ，タグ，ハイライト，お気に入り，ブックマーク，プレイリストを上書きします。';

  @override
  String get message_restore_confirm_explanation_playlists =>
      'この端末のプレイリストを上書きします。';

  @override
  String get message_restore_confirm_explanation_updated =>
      'この端末のメモ，タグ，ハイライト，お気に入り，ブックマーク，プレイリストを以下のデータで上書きします。';

  @override
  String get message_restore_failed => '復元に失敗しました';

  @override
  String get message_restore_failed_explanation => 'バックアップファイルに問題があります。';

  @override
  String get message_restore_in_progress => '復元中...';

  @override
  String get message_restore_successful => '復元完了';

  @override
  String get message_ruby_coaching_tip => '中国語のピンインや日本語のふりがなを表示できるようになりました。';

  @override
  String get message_search_topics_publications => 'トピックまたは出版物の検索';

  @override
  String get message_second_window_closed => 'セカンドディスプレーが閉じられました。';

  @override
  String get message_select_a_bible => '聖書を選択';

  @override
  String get message_select_video_size_title => '動画の画質';

  @override
  String message_selection_count(Object count) {
    return '$count個を選択中';
  }

  @override
  String get message_setting_up => '設定中...';

  @override
  String get message_sideload_older_than_current =>
      'ファイルはインストールされませんでした。お使いの端末には，この出版物の同じバージョンかもっと新しいバージョンがすでにインストールされています。';

  @override
  String message_sideload_overwrite(Object title) {
    return '「$title」が最新のデータに更新されました。';
  }

  @override
  String get message_sideload_unsupported_version =>
      'このファイルはこのバージョンのJW Libraryではサポートされていません。';

  @override
  String get message_still_watching => '視聴していない場合は終了してください。';

  @override
  String get message_still_watching_title => '再生を続けますか？';

  @override
  String get message_support_code_invalid => 'コードを確認して，もう一度やり直してください。';

  @override
  String get message_support_code_invalid_title => '無効なコード';

  @override
  String get message_support_enter_code =>
      'サポートコードがあるなら，以下の欄に入力し，サポートモードを有効にしてください。';

  @override
  String get message_support_read_help =>
      'JW Libraryに関するよくある質問はjw.orgに載せられています。';

  @override
  String get message_support_reset_confirmation => 'サポートモードを終了します。よろしいですか。';

  @override
  String get message_support_reset_confirmation_title => 'サポートモード';

  @override
  String get message_tap_link => 'リンクをタップしてください。';

  @override
  String get message_tap_verse_number => '節番号をタップしてください。';

  @override
  String get message_terms_accept =>
      '「受け入れる」を選択すると，この利用規約に同意したことになります。利用規約と「プライバシーに関する方針」は，このアプリの「設定」ページからいつでも確認できます。';

  @override
  String get message_terms_of_use => '利用規約をご確認ください。受け入れる前に，規約を全てお読みください。';

  @override
  String get message_this_cannot_be_undone => 'この操作は取り消すことができません。';

  @override
  String get message_try_again_later => '後でもう一度お試しください。';

  @override
  String message_unavailable_playlist_media(Object title) {
    return '“$title”をダウンロードしてからやり直してください。';
  }

  @override
  String get message_uninstall_deletes_media => 'アプリをアンインストールすると，メディアも削除されます。';

  @override
  String message_unrecognized_language_title(Object languageid) {
    return '対応していない言語 ($languageid)';
  }

  @override
  String get message_update_android_webview =>
      'コンテンツをきちんと表示するには，Playストアから「AndroidシステムのWebView」か「Google Chrome」の最新版をインストールしてください。';

  @override
  String get message_update_app => '新しいコンテンツを入手するには、JW Libraryのバージョンアップが必要です。';

  @override
  String get message_update_in_progress_title => 'アップデート中...';

  @override
  String message_update_os(Object version) {
    return '次回のアプリの更新を行うには，$version以降のOSが必要です。';
  }

  @override
  String get message_update_os_description =>
      'JW Libraryを安全で信頼できる状態に保つために，アプリの最小要件が時折引き上げられます。可能なら，お使いの端末のOSを最新のバージョンに更新してください。端末のOSが最小要件を満たさない場合も，しばらくの間はアプリを使用できるかもしれません。ただし，アプリを更新することはできなくなります。';

  @override
  String get message_update_os_title => 'システムアップデートが必要です';

  @override
  String get message_updated_item => 'このアイテムを更新することができます。';

  @override
  String get message_updated_publication => 'この出版物を更新することができます。';

  @override
  String get message_updated_video => 'このビデオを更新することができます。';

  @override
  String get message_updated_video_trim => '動画をトリミングし直す必要があるかもしれません。';

  @override
  String get message_updated_video_trim_title => '動画が更新されました';

  @override
  String get message_verse_not_present => '選択した節は，この聖書にありません。';

  @override
  String get message_verses_not_present => '選択した節は，この聖書にありません。';

  @override
  String get message_video_import_incomplete => 'ダウンロード未完了のビデオがあります。';

  @override
  String get message_video_import_incomplete_titel => 'ビデオのインポート未完了';

  @override
  String get message_video_playback_failed => 'デバイスがこのファイル形式に対応していません。';

  @override
  String get message_video_playback_failed_title => 'ビデオの再生に失敗しました';

  @override
  String get message_welcome_to_jw_life => 'JW Lifeへようこそ';

  @override
  String get message_app_for_jehovah_witnesses => 'エホバの証人の生活のためのアプリ';

  @override
  String message_download_daily_text(Object year) {
    return '年 $year の日々の聖句をダウンロード';
  }

  @override
  String get message_whatsnew_add_favorites => 'お気に入りに追加するには，その他ボタンをタップします';

  @override
  String get message_whatsnew_audio_recordings => '聖書や出版物のオーディオ版を再生する';

  @override
  String get message_whatsnew_bible_gem =>
      '聖句を開いて，コンテキストメニューの「宝石」アイコンをタップすると，その節に関連のあるすべての研究用コンテンツ（リサーチガイドにある資料を含む）が表示されます。';

  @override
  String get message_whatsnew_bookmarks => '選択したテキストにブックマークを付けられます。';

  @override
  String get message_whatsnew_create_tags => 'タグを作成するとメモを整理できます。';

  @override
  String get message_whatsnew_download_media => '出版物の朗読版やビデオをダウンロードできます。';

  @override
  String get message_whatsnew_download_sorting => 'ダウンロードした出版物を何通りかに並べ替えられます';

  @override
  String get message_whatsnew_highlight => '長押ししてドラッグするとハイライトを付けられます。';

  @override
  String get message_whatsnew_highlight_textselection =>
      '個人研究をしながらハイライトを付けられます。';

  @override
  String get message_whatsnew_home => 'ホームセクションには，あなたが一番よく使うものが表示されます。';

  @override
  String get message_whatsnew_many_sign_languages =>
      'いろいろな手話言語のビデオをダウンロードできるようになりました。';

  @override
  String get message_whatsnew_media => 'メディアセクションで，ビデオやオーディオ・プログラムを視聴できます';

  @override
  String get message_whatsnew_meetings => '集会で使用する出版物を見ることができます';

  @override
  String get message_whatsnew_noversion_title => 'JW Libraryの新機能';

  @override
  String get message_whatsnew_playlists => 'プレイリストを作成して，お気に入りのビデオを登録できます。';

  @override
  String get message_whatsnew_research_guide =>
      'リサーチガイドをダウンロードすると，聖書のスタディー・ペインで参照資料を見ることができます。';

  @override
  String get message_whatsnew_sign_language => '手話の出版物も見られるようになりました。';

  @override
  String get message_whatsnew_sign_language_migration =>
      '以前のバージョンからダウンロード済みのビデオを移行中です。しばらくお待ちください。これには多少時間がかかります。';

  @override
  String get message_whatsnew_stream =>
      '全てのビデオや歌で，ストリーミング再生するかダウンロードするかを選択できます。';

  @override
  String get message_whatsnew_stream_video => 'ビデオのストリーミング再生とダウンロードが可能です。';

  @override
  String get message_whatsnew_study_edition => '「新世界訳聖書」スタディー版が利用できるようになりました。';

  @override
  String get message_whatsnew_take_notes => '個人研究をしながらメモを作成できます';

  @override
  String get message_whatsnew_tap_longpress =>
      'タップするとストリーミング再生できます。長押しまたは右クリックでダウンロードできます。';

  @override
  String message_whatsnew_title(Object version) {
    return 'JW Library $versionの新機能';
  }

  @override
  String get messages_coaching_appearance_setting_description =>
      '「設定」で画面表示をライトかダークにできます。';

  @override
  String get messages_coaching_library_tab_description =>
      '「出版物」タブと「メディア」タブは，「ライブラリー」という新しいタブに統合されました。';

  @override
  String get messages_convention_releases_prompt => '今年の地区大会にもう出席しましたか？';

  @override
  String get messages_convention_releases_prompt_watched =>
      '今年の地区大会をすでに視聴しましたか？';

  @override
  String get messages_convention_theme_2015 => '「イエスに倣いましょう！」';

  @override
  String get messages_convention_theme_2016 => '「エホバへの忠節を保ちましょう！」';

  @override
  String get messages_convention_theme_2017 => '「あきらめてはいけない！」';

  @override
  String get messages_convention_theme_2018 => '勇気を出しなさい！';

  @override
  String get messages_empty_downloads => 'ダウンロードしたアイテムがここに表示されます。';

  @override
  String get messages_empty_favorites => 'お気に入りに追加したアイテムがここに表示されます。';

  @override
  String get messages_help_download_bibles =>
      '他の翻訳をダウンロードするには，聖書の画面から言語ボタンをタップしてください。';

  @override
  String get messages_internal_publication =>
      'この出版物はエホバの証人の会衆内でのみ使用されるもので，一般向けに配布するものではありません。';

  @override
  String get messages_internal_publication_title => 'ダウンロードを続けますか？';

  @override
  String get messages_locked_sd_card => 'この端末では，JW LibraryからSDカードへの書き込みができません。';

  @override
  String get messages_no_new_publications => '選択中の言語で新しい出版物はありません。';

  @override
  String get messages_no_pending_updates => 'ダウンロード済みの出版物は全て最新です。';

  @override
  String get messages_tap_publication_type => '出版物の種類を選択してください。';

  @override
  String get messages_turn_on_pip => 'この動画をピクチャー・イン・ピクチャーで再生するには，設定を変更してください。';

  @override
  String get navigation_home => 'ホーム';

  @override
  String get navigation_bible => '聖書';

  @override
  String get navigation_library => 'ライブラリ－';

  @override
  String get navigation_workship => '崇拝';

  @override
  String get navigation_predication => '宣べ伝える活動';

  @override
  String get navigation_personal => '個人';

  @override
  String get navigation_settings => '設定';

  @override
  String get navigation_favorites => 'お気に入り';

  @override
  String get navigation_frequently_used => '頻繁に使用';

  @override
  String get navigation_ministry => '宣教ツールボックス';

  @override
  String get navigation_whats_new => '新着情報';

  @override
  String get navigation_online => 'オンライン';

  @override
  String get navigation_official_website => '公式ウェブサイト';

  @override
  String get navigation_online_broadcasting => 'Broadcasting';

  @override
  String get navigation_online_library => 'オンライン・ライブラリー';

  @override
  String get navigation_online_donation => '寄付をする';

  @override
  String get navigation_online_gitub => 'JW Life GitHub';

  @override
  String get navigation_bible_reading => '私の聖書通読';

  @override
  String get navigation_workship_assembly_br => '支部代表者との巡回大会';

  @override
  String get navigation_workship_assembly_co => '巡回監督との巡回大会';

  @override
  String get navigation_workship_convention => '地域大会';

  @override
  String get navigation_workship_life_and_ministry => '週半ばの集会';

  @override
  String get navigation_workship_watchtower_study => '週末の集会';

  @override
  String get navigation_workship_meetings => '集会';

  @override
  String get navigation_workship_conventions => '大会';

  @override
  String get navigation_drawer_content_description => 'ナビゲーション ドロワー';

  @override
  String get navigation_meetings_assembly => '巡回大会';

  @override
  String get navigation_meetings_assembly_uppercase => '巡回大会';

  @override
  String get navigation_meetings_convention => '地区大会';

  @override
  String get navigation_meetings_convention_uppercase => '地区大会';

  @override
  String get navigation_meetings_life_and_ministry => '生活と奉仕の集会';

  @override
  String get navigation_meetings_life_and_ministry_uppercase => '生活と奉仕の集会';

  @override
  String get navigation_meetings_show_media => 'メディアを視聴';

  @override
  String get navigation_meetings_watchtower_study => '「ものみの塔」研究';

  @override
  String get navigation_meetings_watchtower_study_uppercase => '「ものみの塔」研究';

  @override
  String get navigation_menu => 'ナビゲーションメニュー';

  @override
  String get navigation_notes_and_tag => 'メモとタグ';

  @override
  String get navigation_personal_study => '個人研究';

  @override
  String get navigation_playlists => 'プレイリスト';

  @override
  String get navigation_publications => '出版物';

  @override
  String get navigation_publications_uppercase => '出版物';

  @override
  String get navigation_pubs_by_type => '種類別';

  @override
  String get navigation_pubs_by_type_uppercase => '種類別';

  @override
  String get pub_attributes_archive => '過去の出版物';

  @override
  String get pub_attributes_assembly_convention => '大会';

  @override
  String get pub_attributes_bethel => 'ベテル';

  @override
  String get pub_attributes_circuit_assembly => '巡回大会';

  @override
  String get pub_attributes_circuit_overseer => '巡回監督';

  @override
  String get pub_attributes_congregation => '会衆';

  @override
  String get pub_attributes_congregation_circuit_overseer => '会衆／巡回監督';

  @override
  String get pub_attributes_convention => '地区大会';

  @override
  String get pub_attributes_convention_invitation => '地区大会の招待状';

  @override
  String get pub_attributes_design_construction => '設計／建設';

  @override
  String get pub_attributes_drama => '劇';

  @override
  String get pub_attributes_dramatic_bible_reading => '劇形式の聖書朗読';

  @override
  String get pub_attributes_examining_the_scriptures => '聖書を調べる';

  @override
  String get pub_attributes_financial => '会計';

  @override
  String get pub_attributes_invitation => '招待状';

  @override
  String get pub_attributes_kingdom_news => '王国ニュース';

  @override
  String get pub_attributes_medical => '医療';

  @override
  String get pub_attributes_meetings => '集会';

  @override
  String get pub_attributes_ministry => '宣教';

  @override
  String get pub_attributes_music => '音楽';

  @override
  String get pub_attributes_public => '一般用';

  @override
  String get pub_attributes_purchasing => '購買';

  @override
  String get pub_attributes_safety => '安全';

  @override
  String get pub_attributes_schools => '学校';

  @override
  String get pub_attributes_simplified => '簡易版';

  @override
  String get pub_attributes_study => '研究用';

  @override
  String get pub_attributes_study_questions => '研究用の質問';

  @override
  String get pub_attributes_study_simplified => '研究用（簡易版）';

  @override
  String get pub_attributes_vocal_rendition => 'コーラス版';

  @override
  String get pub_attributes_writing_translation => '執筆／翻訳';

  @override
  String get pub_attributes_yearbook => '年鑑と奉仕年度の報告';

  @override
  String get pub_type_audio_programs => 'オーディオ・プログラム';

  @override
  String get pub_type_audio_programs_sign_language => '歌と劇';

  @override
  String get pub_type_audio_programs_uppercase => 'オーディオ・プログラム';

  @override
  String get pub_type_audio_programs_uppercase_sign_language => '歌と劇';

  @override
  String get pub_type_awake => '目ざめよ！';

  @override
  String get pub_type_bibles => '聖書';

  @override
  String get pub_type_books => '書籍';

  @override
  String get pub_type_broadcast_programs => 'ブロードキャスティング・プログラム';

  @override
  String get pub_type_brochures_booklets => '冊子類';

  @override
  String get pub_type_calendars => 'カレンダー';

  @override
  String get pub_type_curriculums => 'カリキュラム';

  @override
  String get pub_type_forms => '用紙類';

  @override
  String get pub_type_index => '索引';

  @override
  String get pub_type_information_packets => '資料';

  @override
  String get pub_type_kingdom_ministry => '王国宣教';

  @override
  String get pub_type_letters => '手紙類';

  @override
  String get pub_type_manuals_guidelines => 'ガイドライン';

  @override
  String get pub_type_meeting_workbook => '集会ワークブック';

  @override
  String get pub_type_other => 'その他';

  @override
  String get pub_type_programs => 'プログラム';

  @override
  String get pub_type_talks => '筋書き';

  @override
  String get pub_type_tour_items => 'ベテル見学の情報';

  @override
  String get pub_type_tracts => 'パンフレット／招待状';

  @override
  String get pub_type_videos => 'ビデオ';

  @override
  String get pub_type_videos_uppercase => 'ビデオ';

  @override
  String get pub_type_watchtower => 'ものみの塔';

  @override
  String get pub_type_web => 'シリーズ記事';

  @override
  String get search_all_results => '全ての検索結果';

  @override
  String get search_bar_search => '検索';

  @override
  String get search_commonly_used => 'よく使う聖句';

  @override
  String get search_match_exact_phrase => '完全一致語句';

  @override
  String get search_menu_title => '検索';

  @override
  String get search_prompt => '単語かページ数を入力する';

  @override
  String search_prompt_languages(Object count) {
    return '言語を探す ($count)';
  }

  @override
  String search_prompt_playlists(Object count) {
    return 'プレイリストの検索 ($count)';
  }

  @override
  String get search_results_articles => '他の出例';

  @override
  String get search_results_none => '該当するものがありません';

  @override
  String get search_results_occurence => '1件';

  @override
  String search_results_occurences(Object count) {
    return '$count件';
  }

  @override
  String get search_results_title => '検索結果';

  @override
  String search_results_title_with_query(Object query) {
    return '”$query”の検索結果';
  }

  @override
  String search_suggestion_page_number_title(Object number, Object title) {
    return '$title, $numberページ';
  }

  @override
  String get search_suggestions => '予測候補';

  @override
  String get search_suggestions_page_number => 'ページ番号';

  @override
  String get search_results_per_chronological => '年代順';

  @override
  String get search_results_per_top_verses => '最も引用されたもの';

  @override
  String get search_results_per_occurences => '出現';

  @override
  String get search_show_less => '少なく表示';

  @override
  String get search_show_more => 'さらに表示';

  @override
  String get search_suggestions_recent => '検索履歴';

  @override
  String get search_suggestions_topics => '見出し';

  @override
  String get search_suggestions_topics_uppercase => '見出し';

  @override
  String get searchview_clear_text_content_description => 'テキストを消去';

  @override
  String get searchview_navigation_content_description => '戻る';

  @override
  String get selected => '選択済み';

  @override
  String get settings_about => '情報';

  @override
  String get settings_about_uppercase => '情報';

  @override
  String get settings_acknowledgements => '謝辞';

  @override
  String get settings_always => '常に許可';

  @override
  String get settings_always_uppercase => '常に許可';

  @override
  String get settings_appearance => '画面表示';

  @override
  String get settings_appearance_dark => 'ダーク';

  @override
  String get settings_appearance_display => 'ディスプレー';

  @override
  String get settings_appearance_display_upper => 'ディスプレー';

  @override
  String get settings_appearance_light => 'ライト';

  @override
  String get settings_appearance_system => 'システム';

  @override
  String get settings_application_version => 'バージョン';

  @override
  String get settings_ask_every_time => '毎回確認する';

  @override
  String get settings_ask_every_time_uppercase => '毎回確認する';

  @override
  String get settings_audio_player_controls => 'オーディオ・プレーヤー・コントロール';

  @override
  String get settings_auto_update_pubs => 'コンテンツを自動的に更新する';

  @override
  String get settings_auto_update_pubs_wifi_only => 'Wi-Fi接続のみ';

  @override
  String get settings_bad_windows_music_library =>
      'Windowsのミュージック・ライブラリで保管場所が設定されていません。ファイルエクスプローラで，ミュージック・ライブラリのプロパティを開き，保管場所を設定してください。';

  @override
  String get settings_bad_windows_video_library =>
      'Windowsのビデオ・ライブラリで保管場所が設定されていません。ファイルエクスプローラで，ビデオ・ライブラリのプロパティを開き，保管場所を設定してください。';

  @override
  String get settings_cache => 'キャッシュ';

  @override
  String get settings_cache_upper => 'キャッシュ';

  @override
  String get settings_catalog_date => 'コンテンツ更新日';

  @override
  String get settings_library_date => 'ライブラリの日付';

  @override
  String get settings_category_app_uppercase => 'アプリ';

  @override
  String get settings_category_download => 'ストリーミングとダウンロード';

  @override
  String get settings_category_download_uppercase => 'ストリーミングとダウンロード';

  @override
  String get settings_category_legal => 'リーガルポリシー';

  @override
  String get settings_category_legal_uppercase => 'リーガルポリシー';

  @override
  String get settings_category_playlists_uppercase => 'プレイリスト';

  @override
  String settings_category_privacy_subtitle(
    Object settings_how_jwl_uses_your_data,
  ) {
    return 'アプリがきちんと動作するために必須のデータが，お使いのデバイスと開発者の間でやり取りされます。このデータが販売されたり商業目的で利用されたりすることは決してありません。詳しくは$settings_how_jwl_uses_your_dataをご覧ください。';
  }

  @override
  String get settings_default_end_action => 'ビデオ終了時の設定';

  @override
  String get settings_download_over_cellular => 'モバイルデータ通信経由のダウンロード';

  @override
  String get settings_download_over_cellular_subtitle => 'データ通信料が発生する可能性があります。';

  @override
  String get settings_how_jwl_uses_your_data => 'データの使用方法';

  @override
  String get settings_languages => '言語';

  @override
  String get settings_languages_upper => '言語';

  @override
  String get settings_language_app => 'アプリケーションの言語';

  @override
  String get settings_language_library => 'ライブラリの言語';

  @override
  String get settings_license => 'ライセンス契約';

  @override
  String get settings_license_agreement => '使用許諾契約';

  @override
  String get settings_main_color => 'メインカラー';

  @override
  String get settings_main_books_color => '聖書の本の色';

  @override
  String get settings_never => '許可しない';

  @override
  String get settings_never_uppercase => '許可しない';

  @override
  String get settings_notifications => '通知とリマインダー';

  @override
  String get settings_notifications_upper => '通知とリマインダー';

  @override
  String get settings_notifications_daily_text => '日々の聖句のリマインダー';

  @override
  String settings_notifications_hour(Object hour) {
    return 'リマインダー時間: $hour';
  }

  @override
  String get settings_notifications_bible_reading => '聖書通読のリマインダー';

  @override
  String get settings_notifications_download_file => 'ダウンロードされたファイルの通知';

  @override
  String get settings_notifications_download_file_subtitle =>
      'ファイルがダウンロードされるたびに通知が送信されます。';

  @override
  String get settings_offline_mode => 'オフラインモード';

  @override
  String get settings_offline_mode_subtitle =>
      'JW Lifeでのインターネット接続を無効にして，データ通信を節約します。';

  @override
  String get settings_open_source_licenses => 'オープンソースライセンス';

  @override
  String get settings_play_video_second_display => 'ビデオをセカンドディスプレーで再生する';

  @override
  String get settings_privacy => 'プライバシー';

  @override
  String get settings_privacy_policy => 'プライバシーに関する方針';

  @override
  String get settings_privacy_uppercase => 'プライバシー';

  @override
  String get settings_send_diagnostic_data => '診断データを提供';

  @override
  String get settings_send_diagnostic_data_subtitle =>
      'アプリが突然終了した時やエラーが起きた時のデータが開発者に送信されます。このデータはアプリの性能を向上させるためだけに使用されます。';

  @override
  String get settings_send_usage_data => 'アプリの使用に関するデータを提供';

  @override
  String get settings_send_usage_data_subtitle =>
      'どのようにアプリを使っているかに関するデータが開発者に送信されます。このデータは，アプリのデザイン，性能，安定性などを向上させるためだけに使用されます。';

  @override
  String get settings_start_action => '開いた時の設定';

  @override
  String get settings_stop_all_downloads => '全てのダウンロードを中止する';

  @override
  String get settings_storage_device => '端末本体';

  @override
  String get settings_storage_external => 'SDカード';

  @override
  String get settings_storage_folder_title_audio_programs =>
      'ダウンロードしたオーディオ・プログラムの保存先';

  @override
  String get settings_storage_folder_title_media => 'ダウンロードしたメディアの保存先';

  @override
  String get settings_storage_folder_title_videos => 'ダウンロードしたビデオの保存先';

  @override
  String settings_storage_free_space(Object free, Object total) {
    return '空き領域 $free/$total';
  }

  @override
  String get settings_stream_over_cellular => 'モバイルデータ通信経由のストリーミング';

  @override
  String get settings_subtitles => '字幕';

  @override
  String get settings_subtitles_not_available => '利用不可';

  @override
  String get settings_suggestions => '提案とバグ';

  @override
  String get settings_suggestions_upper => '提案とバグ';

  @override
  String get settings_suggestions_send => '提案を送信';

  @override
  String get settings_suggestions_subtitle => '開発者に自動的に送信されるフィールドに提案を書いてください。';

  @override
  String get settings_bugs_send => '発生したバグを説明';

  @override
  String get settings_bugs_subtitle => '開発者に自動的に送信されるフィールドにバグを説明してください。';

  @override
  String get settings_support => 'サポート';

  @override
  String get settings_terms_of_use => '利用規約';

  @override
  String get settings_userdata => 'バックアップ';

  @override
  String get settings_userdata_upper => 'バックアップ';

  @override
  String get settings_userdata_import => 'バックアップをインポート';

  @override
  String get settings_userdata_export => 'バックアップをエクスポート';

  @override
  String get settings_userdata_reset => 'このバックアップをリセット';

  @override
  String get settings_userdata_export_jwlibrary => 'ユーザーデータをJW Libraryにエクスポート';

  @override
  String get settings_video_display => 'ビデオの表示';

  @override
  String get settings_video_display_uppercase => 'ビデオの表示';

  @override
  String message_download_publication(Object publicationTitle) {
    return '「$publicationTitle」をダウンロードしますか？';
  }

  @override
  String get message_import_data => 'アプリデータをインポート中です…';

  @override
  String get label_sort_title_asc => 'タイトル (A-Z)';

  @override
  String get label_sort_title_desc => 'タイトル (Z-A)';

  @override
  String get label_sort_year_asc => '年 (古い順)';

  @override
  String get label_sort_year_desc => '年 (新しい順)';

  @override
  String get label_sort_symbol_asc => 'シンボル (A-Z)';

  @override
  String get label_sort_symbol_desc => 'シンボル (Z-A)';

  @override
  String get message_delete_publication => '出版物を削除しました';

  @override
  String get message_update_cancel => 'アップデートがキャンセルされました';

  @override
  String get message_download_cancel => 'ダウンロードがキャンセルされました';

  @override
  String message_item_download_title(Object title) {
    return '「 $title 」はダウンロードされていません';
  }

  @override
  String message_item_download(Object title) {
    return '「 $title 」をダウンロードしますか？';
  }

  @override
  String message_item_downloading(Object title) {
    return '「 $title 」をダウンロードしています';
  }

  @override
  String get message_confirm_userdata_reset_title => 'リセットを確認';

  @override
  String get message_confirm_userdata_reset =>
      'このバックアップをリセットしてもよろしいですか？個人的な学習のデータがすべて失われます。この操作は元に戻せません。';

  @override
  String get message_exporting_userdata => 'データをエクスポートしています...';

  @override
  String get message_delete_userdata_title => 'バックアップが削除されました';

  @override
  String get message_delete_userdata => 'バックアップは正常に削除されました。';

  @override
  String message_file_not_supported_1_extension(Object extention) {
    return 'ファイルは $extention 拡張子を持っている必要があります。';
  }

  @override
  String message_file_not_supported_2_extensions(
    Object exention1,
    Object extention2,
  ) {
    return 'ファイルは $exention1 または $extention2 拡張子を持っている必要があります。';
  }

  @override
  String message_file_not_supported_multiple_extensions(Object extensions) {
    return 'ファイルは次の拡張子のいずれかを持っている必要があります: $extensions。';
  }

  @override
  String get message_file_error_title => 'ファイルのエラー';

  @override
  String message_file_error(Object extension) {
    return '選択された $extension ファイルは破損しているか無効です。ファイルを確認して、もう一度お試しください。';
  }

  @override
  String get message_publication_invalid_title => '間違った出版物';

  @override
  String message_publication_invalid(Object symbol) {
    return '選択された.jwpubファイルは、必要な出版物と一致しません。シンボル「 $symbol 」の出版物を選択してください。';
  }

  @override
  String get message_import_playlist_successful => 'プレイリストのインポートに成功しました。';

  @override
  String get message_userdata_reseting => 'バックアップをリセットしています...';

  @override
  String get message_download_in_progress => 'ダウンロード中...';

  @override
  String label_tag_notes(Object count) {
    return '$count 件のメモ';
  }

  @override
  String label_tags_and_notes(Object count1, Object count2) {
    return '$count1 件のタグと $count2 件のメモ';
  }

  @override
  String get message_delete_playlist_title => 'プレイリストを削除';

  @override
  String message_delete_playlist(Object name) {
    return 'この操作を行うと、プレイリスト「$name」は完全に削除されます。';
  }

  @override
  String message_delete_item(Object item) {
    return '「$item」は削除されました';
  }

  @override
  String message_app_up_to_date(Object currentVersion) {
    return '利用可能なアップデートはありません (現在のバージョン: $currentVersion)';
  }

  @override
  String get message_app_update_available => '新しいバージョンが利用可能です';

  @override
  String get label_next_meeting => '次回の会議';

  @override
  String label_date_next_meeting(Object date, Object hour, Object minute) {
    return '$date $hour:$minute';
  }

  @override
  String get label_workship_public_talk_choosing => 'ここで話の番号を選択...';

  @override
  String get action_public_talk_replace => '話の差し替え';

  @override
  String get action_public_talk_choose => '話を選択';

  @override
  String get action_public_talk_remove => '話を削除';

  @override
  String get action_congregations => '地方集会';

  @override
  String get action_meeting_management => '集会の計画';

  @override
  String get action_brothers_and_sisters => '兄弟姉妹';

  @override
  String get action_blocking_horizontally_mode => '水平方向のブロック';

  @override
  String get action_qr_code => 'QRコードを生成';

  @override
  String get action_scan_qr_code => 'QRコードをスキャン';

  @override
  String get settings_page_transition => 'ページの切り替え';

  @override
  String get settings_page_transition_bottom => '下からの切り替え';

  @override
  String get settings_page_transition_right => '右からの切り替え';

  @override
  String get label_research_all => 'すべて';

  @override
  String get label_research_wol => 'WOL';

  @override
  String get label_research_bible => '聖書';

  @override
  String get label_research_verses => '節';

  @override
  String get label_research_images => '画像';

  @override
  String get label_research_notes => 'ノート';

  @override
  String get label_research_inputs_fields => 'フィールド';

  @override
  String get label_research_wikipedia => 'ウィキペディア';

  @override
  String get meps_language => 'J';

  @override
  String get label_icon_commentary => '学習ノート';

  @override
  String get label_verses_side_by_side => '節を並べて表示';

  @override
  String get message_verses_side_by_side => '最初の2つの翻訳を並べて表示する';

  @override
  String get settings_menu_display_upper => 'メニュー';

  @override
  String get settings_show_publication_description => '出版物の説明を表示する';

  @override
  String get settings_show_publication_description_subtitle =>
      'ウェブサイト上の説明をタイトルの下に表示します。';

  @override
  String get settings_show_document_description => 'ドキュメントの説明を表示する';

  @override
  String get settings_show_document_description_subtitle =>
      'ウェブサイト上の説明をドキュメントの下に表示します。';

  @override
  String get settings_menu_auto_open_single_document => 'ドキュメントを直接開く';

  @override
  String get settings_menu_auto_open_single_document_subtitle =>
      'ドキュメントが1つしかない場合は、メニューを表示せずに開きます。';

  @override
  String get settings_appearance_frequently_used => '頻繁に使用される出版物';

  @override
  String get settings_appearance_frequently_used_subtitle =>
      'ホームページの「お気に入り」セクションの下に、最も頻繁に使用される出版物を表示します';

  @override
  String get action_all_selection => 'すべて選択';

  @override
  String get action_translate => '翻訳する';

  @override
  String get action_open_in_jwlife => 'JW Lifeで開く';
}
