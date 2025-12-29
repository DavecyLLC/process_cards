import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'how_to_use_screen.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  // 🔁 Replace with YOUR real privacy policy URL
  final Uri _privacyPolicyUrl =
      Uri.parse('https://davecyllc.github.io/process_cards/privacy.html');

  Future<void> _openUrl(BuildContext context, Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: 'Help & Usage',
            children: [
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('How to use this app'),
                subtitle: const Text('Tips for the best workflow'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HowToUseScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Legal',
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('View the policy in your browser'),
                onTap: () => _openUrl(context, _privacyPolicyUrl),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Section(
            title: 'About',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Process Cards'),
                subtitle: Text('Your projects are stored on-device'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
