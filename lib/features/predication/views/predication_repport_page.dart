import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/app/jwlife_app.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/services/settings_service.dart';

class PredicationReportPage extends StatefulWidget {
  const PredicationReportPage({super.key});

  @override
  _PredicationReportPageState createState() => _PredicationReportPageState();
}

class _PredicationReportPageState extends State<PredicationReportPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _placementsController = TextEditingController();
  final TextEditingController _creditsController = TextEditingController();

  final Map<DateTime, Map<String, dynamic>> _dailyReports = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _placementsController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  // Charger les données depuis Firestore
  Future<void> _loadReports() async {
    /*
    // Charger les rapports depuis Firestore
    // Enregistrer ou mettre à jour le rapport dans Firestore
    DocumentReference userDoc = await getUserCollection();

    final snapshot = await userDoc.collection('preaching_reports').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = DateTime.parse(data['date']);
      setState(() {
        _dailyReports[date] = {
          'hours': data['hours'],
          'placements': data['placements'],
          'credits': data['credits'],
        };
      });
    }

     */
  }

  // Enregistrer les données dans Firestore
  Future<void> _updateReport() async {
    /*
    if (_selectedDay != null) {
      final dateString = _selectedDay!.toIso8601String();

      // Enregistrer ou mettre à jour le rapport dans Firestore
      DocumentReference userDoc = await getUserCollection();

      userDoc.collection('preaching_reports').doc(dateString).set({
        'date': dateString,
        'hours': _hoursController.text,
        'placements': _placementsController.text,
        'credits': _creditsController.text,
      });

      setState(() {
        _dailyReports[_selectedDay!] = {
          'hours': _hoursController.text,
          'placements': _placementsController.text,
          'credits': _creditsController.text,
        };
      });
    }

     */
  }

  void _incrementController(TextEditingController controller, int value) {
    final currentValue = int.tryParse(controller.text) ?? 0;
    controller.text = (currentValue + value).clamp(0, 999).toString();
    _updateReport(); // Enregistrer automatiquement lors de l'incrémentation
  }

  @override
  Widget build(BuildContext context) {
    // Calculer le résumé du mois
    int totalHours = 0, totalPlacements = 0, totalCredits = 0;
    for (var report in _dailyReports.values) {
      totalHours += int.tryParse(report['hours'] ?? '0') ?? 0;
      totalPlacements += int.tryParse(report['placements'] ?? '0') ?? 0;
      totalCredits += int.tryParse(report['credits'] ?? '0') ?? 0;
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Affichage du résumé du mois
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Résumé du mois",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Heures: $totalHours"),
                      Text("Cours Bibliques: $totalPlacements"),
                      Text("Crédits d'Heures: $totalCredits"),
                    ],
                  ),
                ],
              ),
            ),
            TableCalendar(
              locale: JwLifeSettings().locale.languageCode,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;

                  // Charger les données du jour sélectionné dans les TextField
                  if (_dailyReports.containsKey(selectedDay)) {
                    final report = _dailyReports[selectedDay]!;

                    _hoursController.text = report['hours'] ?? '';
                    _placementsController.text = report['placements'] ?? '';
                    _creditsController.text = report['credits'] ?? '';
                  } else {
                    _hoursController.clear();
                    _placementsController.clear();
                    _creditsController.clear();
                  }
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              eventLoader: (day) {
                return _dailyReports.containsKey(day) ? [true] : [];
              },
            ),
            const SizedBox(height: 20),
            if (_selectedDay != null) ...[
              Text(
                DateFormat("EEEE d MMMM", JwLifeSettings().locale.languageCode).format(_selectedDay!),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Heures",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _updateReport(), // Enregistrer lors du changement
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.add_circle_outline),
                              onPressed: () => _incrementController(_hoursController, 1),
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline),
                              onPressed: () => _incrementController(_hoursController, -1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _placementsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Cours Bibliques",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _updateReport(), // Enregistrer lors du changement
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _creditsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Crédit (Béthel, écoles, LDC)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _updateReport(), // Enregistrer lors du changement
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.add_circle_outline),
                              onPressed: () => _incrementController(_creditsController, 1),
                            ),
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline),
                              onPressed: () => _incrementController(_creditsController, -1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]
            else
              Text(
                "Veuillez sélectionner une date pour ajouter des données.",
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
