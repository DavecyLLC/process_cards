import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/models/project.dart';

final projectsControllerProvider =
    AsyncNotifierProvider<ProjectsController, List<Project>>(ProjectsController.new);

class ProjectsController extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repo = ref.read(projectRepositoryProvider);
    return repo.getAllProjects();
  }

  Future<Project> createProject(String title) async {
    final repo = ref.read(projectRepositoryProvider);
    final p = await repo.createProject(title: title);
    state = AsyncData(await repo.getAllProjects());
    return p;
  }

  Future<void> renameProject(Project p, String newTitle) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.renameProject(p, newTitle);
    state = AsyncData(await repo.getAllProjects());
  }

  Future<void> deleteProject(Project p) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.deleteProject(p);
    state = AsyncData(await repo.getAllProjects());
  }
}
