import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/project.dart';
import '../data/models/step_item.dart';
import '../data/project_repository.dart';
import '../data/providers.dart';


final stepsControllerProvider =
    AsyncNotifierProviderFamily<StepsController, List<StepItem>, String>(StepsController.new);

class StepsController extends FamilyAsyncNotifier<List<StepItem>, String> {
  late final ProjectRepository _repo = ref.read(projectRepositoryProvider);

  @override
  Future<List<StepItem>> build(String projectUid) async {
    return _repo.getSteps(projectUid: projectUid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.getSteps(projectUid: arg));
  }

  Future<void> addStep({
    required Project project,
    required String title,
    required String description,
    File? pickedImage,
  }) async {
    await _repo.addStep(
      project: project,
      title: title,
      description: description,
      pickedImage: pickedImage,
    );
    await refresh();
  }

  Future<void> updateStep({
    required Project project,
    required StepItem step,
    required String title,
    required String description,
    File? newPickedImage,
    bool removeImage = false,
  }) async {
    await _repo.updateStep(
      project: project,
      step: step,
      title: title,
      description: description,
      newPickedImage: newPickedImage,
      removeImage: removeImage,
    );
    await refresh();
  }

  Future<void> deleteStep({
    required Project project,
    required StepItem step,
  }) async {
    await _repo.deleteStep(project: project, step: step);
    await refresh();
  }

  Future<void> reorder({
    required Project project,
    required List<StepItem> newOrder,
  }) async {
    await _repo.reorderSteps(project: project, stepsInNewOrder: newOrder);
    await refresh();
  }
}
