import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/utils/common_ui.dart';
import 'package:jwlife/core/utils/utils.dart';
import 'package:jwlife/data/databases/history.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';

import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../app/services/global_key_service.dart';
import '../../../core/icons.dart';
import '../../../i18n/i18n.dart';
import 'activity_report_page.dart';
import 'bible_study_page.dart';

class PredicationPage extends StatefulWidget {
  const PredicationPage({super.key});

  @override
  PredicationPageState createState() => PredicationPageState();
}

class PredicationPageState extends State<PredicationPage> {
  // Simulation d'un état de chronomètre
  bool isTimerRunning = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionHeaderStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 22,
    );

    String locale = Localizations.localeOf(context).toString();
    String formattedDate = DateFormat('MMMM yyyy', locale).format(DateTime.now()).toUpperCase();

    return AppPage(
      appBar: JwLifeAppBar(
        title: i18n().navigation_predication,
        actions: [
          IconTextButton(
            icon: const Icon(JwIcons.calendar),
            onPressed: (BuildContext context) {},
          ),
          IconTextButton(
            icon: const Icon(JwIcons.arrow_circular_left_clock),
            onPressed: (BuildContext context) => History.showHistoryDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 1. RÉSUMÉ DU MOIS & CHRONO
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: InkWell(
                  onTap: () {
                    showPage(ActivityReportPage());
                  },
                  child: Row(
                    children: [
                      Icon(JwIcons.calendar, color: theme.primaryColor, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formattedDate, style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
                            Text('8h 15min', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      _buildCircularProgress(0.7), // Objectif 30h / 50h
                    ],
                  ),
                ),
              ),

              const Divider(height: 32, thickness: 0.5, indent: 16, endIndent: 16),

              /// 2. GESTION DES ACTIVITÉS (Les tuiles principales)
              _buildSimpleTile(
                context,
                title: 'Nouvelles Visites',
                subtitle: '12 personnes à revoir',
                icon: JwIcons.persons_doorstep,
                onTap: () {

                },
              ),
              _buildSimpleTile(
                context,
                title: 'Cours bibliques',
                subtitle: '3 études actives',
                icon: JwIcons.persons_bible_study,
                onTap: () {
                  showPage(BibleStudyPage());
                },
              ),
              _buildSimpleTile(
                context,
                title: 'Territoires',
                subtitle: 'Vérifier les cartes de groupe',
                icon: JwIcons.home,
                onTap: () {},
              ),
              _buildSimpleTile(
                context,
                title: 'Courriers & QR',
                subtitle: 'Prédication par lettre et liens JW.ORG',
                icon: JwIcons.envelope,
                onTap: () {},
              ),

              const SizedBox(height: 32),

              /// 4. ACTIVITÉ RÉCENTE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Activité récente', style: sectionHeaderStyle),
              ),
              const SizedBox(height: 8),
              _buildRecentActivity(
                context,
                title: 'Territoire 15A',
                subtitle: 'Aujourd\'hui • 1h 30min',
                trailing: '3 NV • 1 vidéo',
              ),
              _buildRecentActivity(
                context,
                title: 'Marie Dupont',
                subtitle: 'Hier • Nouveau cours biblique',
                trailing: 'Chap. 01',
              ),

              const SizedBox(height: 100), // Espace pour le FAB
            ],
          ),
        ),
      ),
    );
  }

  /// Petit widget pour l'objectif d'heures (Cercle de progression)
  Widget _buildCircularProgress(double percent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: percent,
          strokeWidth: 6,
          backgroundColor: Colors.grey.withOpacity(0.2),
        ),
        Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSimpleTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, size: 28),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  Widget _buildRecentActivity(BuildContext context, {required String title, required String subtitle, required String trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Container(
        width: 4,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Text(trailing, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }
}