import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jwlife/app/services/settings_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../../core/jworg_uri.dart';
import '../../i18n/i18n.dart';
import 'global_key_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('Notification tapée depuis le fond - Action: ${notificationResponse.actionId}, Payload: ${notificationResponse.payload}');

  if (notificationResponse.actionId == 'id_dismiss') {
    print('Bouton "Plus tard" pressé');
    return;
  }

  try {
    final uri = JwOrgUri.parse(notificationResponse.payload!);
    JwOrgUri.startUri = uri;
  }
  catch (e) {
    print('ERREUR: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    // Initialiser les fuseaux horaires
    tz.initializeTimeZones();

    tz.setLocalLocation(tz.getLocation('Europe/Paris'));

    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // Gérer les actions des notifications (bouton "Ouvrir")
    await notificationPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground
    );
  }

  // Callback quand une notification ou action est tapée
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapée - Action: ${response.actionId}, Payload: ${response.payload}');

    if (response.actionId == 'id_dismiss') {
      print('Bouton "Plus tard" pressé');
      return;
    }

    try {
      final uri = JwOrgUri.parse(response.payload!);
      GlobalKeyService.jwLifeAppKey.currentState!.handleUri(uri);
    }
    catch (e) {
      print('ERREUR: $e');
    }
  }

  // Annuler une notification
  Future<void> cancelNotification(int id) async {
    await notificationPlugin.cancel(id);
  }

  NotificationDetails notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
          'jwlife_channel_id',
          'JW Life Notifications',
          channelDescription: 'JW Life Channel',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          playSound: true,
          actions: [
            AndroidNotificationAction(
              'id_open',
              i18n().action_open,
            ),
          ]
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // Notification simple (votre méthode originale)
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    try {
      // Vérifier les permissions avant d'afficher
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        print('Permission de notification refusée');
        return;
      }

      print('Tentative d\'affichage de notification: $title - $body');
      await notificationPlugin.show(
          id,
          title,
          body,
          notificationDetails()
      );
      print('Notification envoyée avec succès');
    } catch (e) {
      print('Erreur lors de l\'affichage de la notification: $e');
    }
  }

  // Notification de progression (pour le téléchargement)
  Future<void> showProgressNotification({
    int id = 1,
    String? title,
    String? body,
    int progress = 0,
    int maxProgress = 100,
  }) async {
    try {
      if (progress == 0) {
        final hasPermission = await _checkNotificationPermission();
        if (!hasPermission) return;
      }

      final androidDetails = AndroidNotificationDetails(
        'download_channel_id',
        'Téléchargements',
        channelDescription: 'Notifications de téléchargement avec progression',
        importance: Importance.low, // Low pour éviter les sons répétés
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        ongoing: progress < maxProgress, // Reste affichée tant que pas terminée
        autoCancel: false, // Ne disparaît pas au tap
        playSound: false, // Pas de son pour chaque update
      );

      await notificationPlugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      print('Erreur notification de progression: $e');
    }
  }

  // Notification de fin avec bouton "Ouvrir"
  Future<void> showCompletionNotification({
    int id = 1,
    String? title,
    String? body,
    String? payload,
  }) async {
    try {
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) return;

      final androidDetails = AndroidNotificationDetails(
        'completion_channel_id',
        'Téléchargements terminés',
        channelDescription: 'Notifications de fin de téléchargement',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        ongoing: false,
        autoCancel: true,
        actions: [
          AndroidNotificationAction(
            'id_open',
            i18n().action_open,
            showsUserInterface: true,
          ),
        ],
      );

      await notificationPlugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      print('Erreur notification de fin: $e');
    }
  }

  // Notification quotidienne pour le texte du jour
  Future<void> scheduleDailyTextReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    try {
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) return;

      // Demander permission pour les alarmes exactes (Android 12+)
      await _requestExactAlarmPermission();

      const androidDetails = AndroidNotificationDetails(
        'daily_text_channel_id',
        'Texte du jour',
        channelDescription: 'Rappel quotidien pour lire le texte du jour',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        actions: [
          AndroidNotificationAction(
            'id_read_text',
            'Lire le texte',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'id_dismiss',
            'Plus tard',
          ),
        ],
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Calculer la prochaine occurrence à 8h
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      // Si l'heure est déjà passée aujourd'hui, programmer pour demain
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await notificationPlugin.zonedSchedule(
        100, // ID fixe pour pouvoir l'annuler/modifier
        'Texte du jour',
        'Cliquez ici pour lire le texte du jour',
        scheduledDate,
        notificationDetails,
        matchDateTimeComponents: DateTimeComponents.time, // Répète chaque jour à la même heure
        payload: JwOrgUri.dailyText(
          wtlocale: JwLifeSettings().currentLanguage.symbol,
          date: 'today'
        ).toString(),
        androidScheduleMode: AndroidScheduleMode.exact,
      );

      print('Notification quotidienne programmée pour ${hour}h${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      print('Erreur lors de la programmation du rappel quotidien: $e');
    }
  }

  Future<void> scheduleBibleReadingReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    try {
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) return;

      // Demander permission pour les alarmes exactes (Android 12+)
      await _requestExactAlarmPermission();

      const androidDetails = AndroidNotificationDetails(
        'bible_reading_channel_id',
        'Lecture de la Bible',
        channelDescription: 'Rappel quotidien pour lire la Bible',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        actions: [
          AndroidNotificationAction(
            'id_read_bible',
            'Lire la Bible',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'id_dismiss',
            'Plus tard',
          ),
        ],
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Calculer la prochaine occurrence à 8h
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      // Si l'heure est déjà passée aujourd'hui, programmer pour demain
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await notificationPlugin.zonedSchedule(
        101, // ID fixe pour pouvoir l'annuler/modifier
        'Lecture de la Bible',
        'Cliquez ici pour ouvrir la Bible',
        scheduledDate,
        notificationDetails,
        matchDateTimeComponents: DateTimeComponents.time, // Répète chaque jour à la même heure
        payload: JwOrgUri.bibleBook(
            wtlocale: JwLifeSettings().currentLanguage.symbol,
            pub: 'nwtsty',
            book: 1,
        ).toString(),
        androidScheduleMode: AndroidScheduleMode.exact,
      );

      print('Notification quotidienne programmée pour ${hour}h${minute.toString().padLeft(2, '0')}');
    }
    catch (e) {
      print('Erreur lors de la programmation du rappel quotidien: $e');
    }
  }

  // Demander permission pour les alarmes exactes (Android 12+)
  Future<void> _requestExactAlarmPermission() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  // Annuler le rappel quotidien
  Future<void> cancelDailyTextReminder() async {
    await notificationPlugin.cancel(100);
    print('Rappel quotidien annulé');
  }

  Future<void> cancelBibleReadingReminder() async {
    await notificationPlugin.cancel(101);
    print('Rappel quotidien annulé');
  }

  // Vérifier si le rappel est programmé
  Future<bool> isDailyTextReminderActive() async {
    final pendingNotifications = await notificationPlugin.pendingNotificationRequests();
    return pendingNotifications.any((notification) => notification.id == 100);
  }

  Future<bool> isBibleReadingReminderActive() async {
    final pendingNotifications = await notificationPlugin.pendingNotificationRequests();
    return pendingNotifications.any((notification) => notification.id == 101);
  }

  Future<bool> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    print('Status actuel des notifications: $status');

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    return false;
  }
}