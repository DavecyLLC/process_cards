import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/models/project.dart';
import '../logic/projects_controller.dart';
import 'project_detail_screen.dart';

enum _SortMode { updatedDesc, titleAsc, createdAsc }

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final _search = TextEditingController();
  _SortMode _sortMode = _SortMode.updatedDesc;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsControllerProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Projects'),
          actions: [
            _SortButton(
              mode: _sortMode,
              onChanged: (m) => setState(() => _sortMode = m),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final title = await _promptText(context, 'New project', '');
            if (title == null) return;
            final p = await ref.read(projectsControllerProvider.notifier).createProject(title);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p)),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
        body: projectsAsync.when(
          data: (projects) {
            final filtered = _applySearchAndSort(projects);

            if (projects.isEmpty) {
              return const EmptyState(
                title: 'No projects yet',
                subtitle: 'Tap “New” to create your first process.',
                icon: Icons.view_agenda_outlined,
              );
            }

            return Column(
              children: [
                // Top summary / header
                _HeaderSummary(projects: projects),

                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search projects…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? const _NothingFound()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = filtered[i];
                            return _ProjectCard(
                              project: p,
                              onOpen: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p)),
                                );
                              },
                              onRename: () async {
                                final name = await _promptText(context, 'Rename project', p.title);
                                if (name == null) return;
                                await ref.read(projectsControllerProvider.notifier).renameProject(p, name);
                              },
                              onDelete: () async {
                                final ok = await showConfirmDialog(
                                  context,
                                  title: 'Delete project?',
                                  message: 'This removes the project and all steps (including photos).',
                                );
                                if (!ok) return;
                                await ref.read(projectsControllerProvider.notifier).deleteProject(p);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
          error: (e, _) => Center(child: Text('Error: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  List<Project> _applySearchAndSort(List<Project> projects) {
    final q = _search.text.trim().toLowerCase();

    final filtered = q.isEmpty
        ? List<Project>.from(projects)
        : projects.where((p) => p.title.toLowerCase().contains(q)).toList();

    switch (_sortMode) {
      case _SortMode.updatedDesc:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortMode.titleAsc:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortMode.createdAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return filtered;
  }

  Future<String?> _promptText(BuildContext context, String title, String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
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
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final List<Project> projects;

  const _HeaderSummary({required this.projects});

  @override
  Widget build(BuildContext context) {
    final total = projects.length;
    final latest = projects.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b).updatedAt;
    final latestStr = _formatUpdated(latest);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total ${total == 1 ? "Project" : "Projects"}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated: $latestStr',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: null, // reserved for “Import” later if you add it
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  static String _formatUpdated(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: () => _showActions(context),
        child: ListTile(
          leading: CircleAvatar(
            child: Text(_initials(project.title)),
          ),
          title: Text(
            project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('Updated: ${project.updatedAt.toLocal()}'),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String title) {
    final t = title.trim();
    if (t.isEmpty) return 'P';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final first = parts.first.characters.first.toUpperCase();
    final second = parts.length > 1 ? parts[1].characters.first.toUpperCase() : '';
    return (first + second).trim();
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 44, color: Theme.of(context).hintColor),
            const SizedBox(height: 10),
            Text('No matches', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Try a different search term.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final _SortMode mode;
  final ValueChanged<_SortMode> onChanged;

  const _SortButton({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      tooltip: 'Sort',
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _SortMode.updatedDesc, child: Text('Recently updated')),
        PopupMenuItem(value: _SortMode.titleAsc, child: Text('Title (A–Z)')),
        PopupMenuItem(value: _SortMode.createdAsc, child: Text('Oldest first')),
      ],
      icon: const Icon(Icons.sort),
    );
  }
}
