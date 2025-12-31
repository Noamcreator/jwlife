import 'package:jwlife/core/app_data/app_data_service.dart';
import 'package:jwlife/data/models/meps_language.dart';

import '../api/api.dart';
import '../utils/utils.dart';

Future<void> fetchAlertsList(String mepsLanguageSymbol) async {
  printTime("fetchAlertInfo");

  if(Api.currentJwToken.isEmpty) {
    await Api.fetchCurrentJwToken();
  }

  // Préparer les paramètres de requête pour l'URL
  final queryParams = {
    'type': 'news',
    'lang': mepsLanguageSymbol,
    'context': 'homePage',
  };

  // Construire l'URI avec les paramètres
  final url = Uri.https('b.jw-cdn.org', '/apis/alerts/list', queryParams);

  try {
    // Préparer les headers pour la requête avec l'autorisation
    Map<String, String> headers = {
      'Authorization': 'Bearer ${Api.currentJwToken}',
    };

    // Faire la requête HTTP pour récupérer les alertes
    final response = await Api.httpGetWithHeadersUri(url, headers: headers);

    if (response.statusCode == 200) {
      AppDataService.instance.alerts.value = response.data['alerts'];
    }
    else {
      // Gérer une erreur de statut HTTP
      printTime('Erreur de requête HTTP: ${response.statusCode}');
    }
  }
  catch (e) {
    // Gérer les erreurs lors des requêtes
    printTime('Erreur lors de la récupération des données de l\'API: $e');
  }

  printTime("fetchAlertInfo end");
}