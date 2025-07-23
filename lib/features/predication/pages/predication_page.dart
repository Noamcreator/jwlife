import 'package:flutter/material.dart';

class PredicationPage extends StatefulWidget {
  const PredicationPage({super.key});

  @override
  PredicationPageState createState() => PredicationPageState();
}

class PredicationPageState extends State<PredicationPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(color: Colors.grey);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Prédication'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Résumé du mois
              _MonthSummaryCard(),

              const SizedBox(height: 32),

              /// Actions rapides
              Text('Actions rapides', style: titleStyle),
              const SizedBox(height: 16),
              _QuickActionsGrid(),

              const SizedBox(height: 32),

              /// Outils de prédication
              Text('Outils de prédication', style: titleStyle),
              const SizedBox(height: 16),
              _ToolCard(
                title: 'Revisites',
                icon: Icons.home_outlined,
                gradient: const LinearGradient(colors: [Color(0xFF56ab2f), Color(0xFFa8e063)]),
                onTap: () {
                  // Naviguer vers les revisites
                },
              ),
              const SizedBox(height: 16),
              _ToolCard(
                title: 'Études bibliques',
                icon: Icons.book_outlined,
                gradient: const LinearGradient(colors: [Color(0xFF614385), Color(0xFF516395)]),
                onTap: () {
                  // Naviguer vers les études
                },
              ),
              const SizedBox(height: 16),
              _ToolCard(
                title: 'Rapport du mois',
                icon: Icons.insert_chart_outlined,
                gradient: const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]),
                onTap: () {
                  // Voir rapport
                },
              ),

              const SizedBox(height: 32),

              /// Activité récente
              Text('Activité récente', style: titleStyle),
              const SizedBox(height: 16),
              _RecentActivityCard(
                title: 'Territoire 15A',
                subtitle: 'Visité aujourd\'hui',
                icon: Icons.location_on_outlined,
                color: Colors.green,
                trailing: '3 maisons',
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(
                title: 'Marie Dupont',
                subtitle: 'Étude demain',
                icon: Icons.person_outline,
                color: Colors.blue,
                trailing: '1ère visite',
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(
                title: 'Rapport juillet',
                subtitle: 'En cours',
                icon: Icons.edit_note,
                color: Colors.orange,
                trailing: '8h, 12 pubs',
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 40),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Juillet 2025', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('8h • 12 publications • 3 revisites', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData('Nouveau rapport', Icons.add, Colors.green, () {}),
      _QuickActionData('Lettres / QR', Icons.qr_code, Colors.blue, () {}),
      _QuickActionData('Mes territoires', Icons.map, Colors.purple, () {}),
      _QuickActionData('Historique', Icons.history, Colors.orange, () {}),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: actions.map((a) => _QuickActionCard(data: a)).toList(),
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _QuickActionData(this.label, this.icon, this.color, this.onTap);
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData data;
  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 48) / 2;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: data.onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, color: data.color, size: 32),
                const SizedBox(height: 10),
                Text(data.label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String trailing;

  const _RecentActivityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
