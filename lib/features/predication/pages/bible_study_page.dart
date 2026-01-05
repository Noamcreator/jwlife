import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwlife/core/icons.dart';
import 'package:jwlife/core/utils/widgets_utils.dart';
import 'package:jwlife/widgets/responsive_appbar_actions.dart';
import '../../../app/app_page.dart';
import '../../../app/jwlife_app_bar.dart';
import '../../../data/models/userdata/bible_study.dart';
import '../../../data/models/userdata/person.dart';

class BibleStudyPage extends StatefulWidget {
  const BibleStudyPage({super.key});

  @override
  BibleStudyPageState createState() => BibleStudyPageState();
}

class BibleStudyPageState extends State<BibleStudyPage> {
  // Simulation de données (à remplacer par vos appels DB)
  final List<Map<String, dynamic>> studiesData = [
    {
      'student': Person(personId: 1, firstName: 'Jean', lastName: 'Pierre', me: false),
      'lastStudy': BibleStudy(bibleStudyId: 101, studentId: 1, teacherId: 0, durationTicks: 36000000000, date: '2025-12-20'),
      'progress': 'Chapitre 5',
    },
    {
      'student': Person(personId: 2, firstName: 'Marc', lastName: 'Lévy', me: false),
      'lastStudy': BibleStudy(bibleStudyId: 102, studentId: 2, teacherId: 0, durationTicks: 27000000000, date: '2025-12-18'),
      'progress': 'Livre "Vivez pour toujours"',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPage(
      appBar: JwLifeAppBar(
        title: 'Cours bibliques', // Ou i18n().bible_studies
        actions: [
          IconTextButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: (context) {
              // Action pour ajouter un nouvel étudiant
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {

        },
        child: const Icon(JwIcons.plus),
      ),
      body: SafeArea(
        child: studiesData.isEmpty
            ? emptyStateWidget('Aucun cours biblique', JwIcons.persons_bible_study)
            : ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: studiesData.length,
          separatorBuilder: (context, index) => const Divider(indent: 72, height: 1),
          itemBuilder: (context, index) {
            final data = studiesData[index];
            final Person student = data['student'];
            final BibleStudy lastStudy = data['lastStudy'];

            return _buildStudentTile(context, student, lastStudy, data['progress']);
          },
        ),
      ),
    );
  }

  Widget _buildStudentTile(BuildContext context, Person student, BibleStudy lastStudy, String progress) {
    final theme = Theme.of(context);

    // Formatage de la date
    DateTime studyDate = DateTime.parse(lastStudy.date);
    String formattedDate = DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(studyDate);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Text(
          student.firstName[0],
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        '${student.firstName} ${student.lastName}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(progress, style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
          Text('Dernier cours : $formattedDate', style: theme.textTheme.bodySmall),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        // Naviguer vers le détail de l'étudiant et l'historique de ses études
      },
    );
  }
}