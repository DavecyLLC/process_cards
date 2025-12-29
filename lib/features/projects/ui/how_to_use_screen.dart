import 'package:flutter/material.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to use')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Tip(
            icon: Icons.add_circle_outline,
            title: 'Create a project',
            text: 'Tap “New” to create a blank project.',
          ),
          _Tip(
            icon: Icons.file_upload_outlined,
            title: 'Import photos',
            text: 'Use Import to create one step per photo. Then rename steps and add descriptions.',
          ),
          _Tip(
            icon: Icons.edit_outlined,
            title: 'Edit steps',
            text: 'Open a step to edit title, description, and image. Tap image for full-screen view.',
          ),
          _Tip(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export',
            text: 'Export to PDF or DOCX to share your full process with images.',
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Tip({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
