import 'package:flutter/material.dart';

class BetaIdeasSettingsScreen extends StatelessWidget {
  const BetaIdeasSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ideas & beta')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A creative work in progress',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Quexdc is an early prototype, not a finished MVP. This page '
                  'keeps future ideas in Settings so they do not interrupt the '
                  'main experience. The ideas below are not promises or active '
                  'services.',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        _BetaIdeaCard(
          icon: Icons.lightbulb_outline,
          title: 'Inventors, innovators & collaboration',
          status: 'Future concept',
          details:
              'Spaces and smaller subspaces could bring together inventors, '
              'creative teams, and organizations to discuss real-world '
              'problems and speculative ideas. A future design could offer '
              'public brainstorming and invite-only collaboration. This beta '
              'does not provide confidential rooms, end-to-end encryption, '
              'NDAs, or guaranteed access controls.',
        ),
        _BetaIdeaCard(
          icon: Icons.science_outlined,
          title: 'Idea notes, patents & funding',
          status: 'Local prototype',
          details:
              'The Inventor Workspace can keep idea notes and self-reported '
              'progress on this device. Notes are not encrypted or proof of '
              'ownership. Patent filing, crowdfunding, company introductions, '
              'donations, loans, and payments are not connected.',
        ),
        _BetaIdeaCard(
          icon: Icons.palette_outlined,
          title: 'Creative themes, fonts & memos',
          status: 'Small local prototype',
          details:
              'Starter Frutiger Aero, Weirdcore, Mysticule, and seasonal or '
              'regional-inspired palettes and memo styling are available. '
              'More creator-made assets and revenue sharing are ideas only; '
              'creator sales and payments are not active.',
        ),
        _BetaIdeaCard(
          icon: Icons.handshake_outlined,
          title: 'Community care & second chances',
          status: 'Future concept',
          details:
              'Brainstormed ideas include escalating second-chance notices, '
              'a playful Ban Hammer screen, possible profile titles or '
              'self-reflection quizzes, and human review for serious cases. '
              'None of these run here: this beta does not moderate accounts, '
              'ban anyone, administer psychological tests, or publish scores '
              'or titles. Any future quiz would need clear consent and must '
              'not be presented as a clinical assessment.',
        ),
        _BetaIdeaCard(
          icon: Icons.explore_outlined,
          title: 'Quexdc direction',
          status: 'Creative social platform',
          details:
              'The focus here is creative expression and a welcoming place '
              'for curious minds to share and collaborate. Political-platform '
              'features are outside the scope of this Quexdc beta.',
        ),
        SizedBox(height: 8),
        Text(
          'Current prototypes may store data only on this device and may not '
          'include privacy, moderation, or service guarantees. Check each '
          'feature’s in-app notice before using it.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _BetaIdeaCard extends StatelessWidget {
  const _BetaIdeaCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String status;
  final String details;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(details),
          ],
        ),
      ),
    ),
  );
}
