// lib/features/projects/ui/project_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/docx_export_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/models/project.dart';
import '../data/models/step_item.dart';
import '../logic/projects_controller.dart';
import '../logic/steps_controller.dart';
import 'step_editor_screen.dart';

final docxExportProvider = Provider<DocxExportService>((ref) => DocxExportService());
final pdfExportProvider = Provider<PdfExportService>((ref) => PdfExportService());

class ProjectDetailScreen extends ConsumerWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(stepsControllerProvider(project.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'export_docx') {
                await _exportDocx(context, ref, stepsAsync);
              } else if (v == 'export_pdf') {
                await _exportPdf(context, ref, stepsAsync);
              } else if (v == 'rename') {
                final name = await _promptText(context, 'Rename project', project.title);
                if (name != null) {
                  await ref.read(projectsControllerProvider.notifier).renameProject(project, name);
                }
              } else if (v == 'delete') {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Delete project?',
                  message: 'This removes the project and all steps (including photos).',
                );
                if (!ok) return;

                await ref.read(projectsControllerProvider.notifier).deleteProject(project);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export_docx', child: Text('Export DOCX & Share')),
              PopupMenuItem(value: 'export_pdf', child: Text('Export PDF & Share')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: stepsAsync.when(
        data: (steps) {
          if (steps.isEmpty) {
            return const EmptyState(
              title: 'No steps yet',
              subtitle: 'Tap + to add your first step card.',
              icon: Icons.note_add_outlined,
            );
          }

          // ✅ copy + sort (never mutate provider list)
          final items = List<StepItem>.from(steps)..sort((a, b) => a.order.compareTo(b.order));

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;

              final reordered = List<StepItem>.from(items);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);

              await ref.read(stepsControllerProvider(project.uid).notifier).reorder(
                    project: project,
                    newOrder: reordered,
                  );
            },
            itemBuilder: (context, i) {
              final s = items[i];
              return _StepCard(
                key: ValueKey(s.uid),
                step: s,
                dragIndex: i,
                onEdit: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StepEditorScreen(project: project, step: s)),
                  );
                },
                onDelete: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Delete step?',
                    message: 'This removes the step and its photo.',
                  );
                  if (!ok) return;

                  await ref.read(stepsControllerProvider(project.uid).notifier).deleteStep(
                        project: project,
                        step: s,
                      );
                },
              );
            },
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StepEditorScreen(project: project)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportDocx(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StepItem>> stepsAsync,
  ) async {
    // ✅ copy (protect against unmodifiable lists)
    final steps = List<StepItem>.from(stepsAsync.value ?? const []);

    try {
      final file = await ref.read(docxExportProvider).exportProjectToDocx(
            project: project,
            steps: steps,
          );

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Project export: ${project.title}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DOCX export failed: $e')),
      );
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StepItem>> stepsAsync,
  ) async {
    // ✅ copy (protect against unmodifiable lists)
    final steps = List<StepItem>.from(stepsAsync.value ?? const []);

    try {
      final file = await ref.read(pdfExportProvider).exportProjectToPdf(
            project: project,
            steps: steps,
          );

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Project export: ${project.title}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Future<String?> _promptText(BuildContext context, String title, String initial) async {
    final controller = TextEditingController(text: initial);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.pop(ctx, controller.text),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class _StepCard extends StatelessWidget {
  final StepItem step;
  final int dragIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepCard({
    super.key,
    required this.step,
    required this.dragIndex,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stepNo = (step.order + 1).toString().padLeft(2, '0');

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(Icons.drag_handle, color: cs.outline),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _StepImage(path: step.imagePath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Step $stepNo', style: TextStyle(color: cs.onPrimaryContainer)),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.title.trim().isEmpty ? 'Untitled Step' : step.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description.trim().isEmpty ? '(No description)' : step.description.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepImage extends StatelessWidget {
  final String? path;
  const _StepImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (path == null || path!.isEmpty) {
      return Container(
        width: 88,
        height: 88,
        color: bg,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined),
      );
    }

    return SizedBox(
      width: 88,
      height: 88,
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            color: bg,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      ),
    );
  }
}
