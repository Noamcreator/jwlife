import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';

class ActivityReportPage extends StatefulWidget {
  const ActivityReportPage({super.key});

  @override
  ActivityReportPageState createState() => ActivityReportPageState();
}

class ActivityReportPageState extends State<ActivityReportPage> {
  // Valeurs du rapport
  int hours = 0;
  int minutes = 0;
  int publications = 0;
  int videos = 0;
  int returnVisits = 0;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String locale = Localizations.localeOf(context).toString();
    String formattedDate = DateFormat.yMMMMd(locale).format(selectedDate);

    return AppPage(
      appBar: JwLifeAppBar(
        title: "Nouvelle activité",
        actions: [
          IconTextButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: (buildContext) {
              // Logique de sauvegarde ici
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// SÉLECTEUR DE DATE
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text("Date de l'activité"),
              subtitle: Text(formattedDate),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
            ),
            const Divider(height: 1),

            /// SECTION TEMPS (HEURES & MINUTES)
            _buildSectionHeader("TEMPS DANS LE MINISTÈRE"),
            _buildCounterTile(
              label: "Heures",
              value: hours,
              icon: Icons.access_time_rounded,
              onChanged: (val) => setState(() => hours = val),
            ),
            _buildCounterTile(
              label: "Minutes",
              value: minutes,
              icon: Icons.more_time_rounded,
              step: 15, // Souvent on compte par quart d'heure
              onChanged: (val) => setState(() => minutes = val),
            ),

            const SizedBox(height: 20),

            /// SECTION PLACEMENTS
            _buildSectionHeader("ACTIVITÉ"),
            _buildCounterTile(
              label: "Publications",
              value: publications,
              icon: JwIcons.publications_pile, // Utilisation de tes icônes
              onChanged: (val) => setState(() => publications = val),
            ),
            _buildCounterTile(
              label: "Vidéos montrées",
              value: videos,
              icon: Icons.play_circle_outline,
              onChanged: (val) => setState(() => videos = val),
            ),
            _buildCounterTile(
              label: "Nouvelles visites",
              value: returnVisits,
              icon: JwIcons.persons_doorstep,
              onChanged: (val) => setState(() => returnVisits = val),
            ),

            const SizedBox(height: 32),

            /// NOTES / COMMENTAIRES
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: "Commentaires ou notes de prédication",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Header de section gris discret
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)
      ),
    );
  }

  // Widget de compteur épuré
  Widget _buildCounterTile({
    required String label,
    required int value,
    required IconData icon,
    required Function(int) onChanged,
    int step = 1
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),

          // Contrôles - / +
          Row(
            children: [
              _circleButton(Icons.remove, () {
                if (value >= step) onChanged(value - step);
              }),
              SizedBox(
                width: 50,
                child: Text(value.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              _circleButton(Icons.add, () => onChanged(value + step)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
        ),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
    );
  }
}