import 'dart:io';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/isar_db.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../core/services/photo_gallery_service.dart';
import 'models/project.dart';
import 'models/step_item.dart';

class ProjectRepository {
  static const _uuid = Uuid();

  final ImageStorageService _imageStorage;
  final PhotoGalleryService _gallery;

  ProjectRepository(this._imageStorage, this._gallery);

  Future<Isar> _db() => IsarDb.instance();

  // ---------- Projects ----------
  Future<List<Project>> getAllProjects() async {
    final isar = await _db();
    return isar.projects.where().sortByUpdatedAtDesc().findAll();
  }

  Future<Project> createProject({required String title}) async {
    final isar = await _db();
    final now = DateTime.now();

    final p = Project()
      ..uid = _uuid.v4()
      ..title = _safeTitle(title)
      ..createdAt = now
      ..updatedAt = now;

    await isar.writeTxn(() async => isar.projects.put(p));
    return p;
  }

  Future<void> renameProject(Project project, String newTitle) async {
    final isar = await _db();
    project
      ..title = _safeTitle(newTitle)
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async => isar.projects.put(project));
  }

  Future<void> deleteProject(Project project) async {
    final isar = await _db();

    // Delete steps + images + gallery assets
    final steps = await getSteps(projectUid: project.uid);
    for (final s in steps) {
      await _imageStorage.deleteImageIfExists(s.imagePath);

      final gid = s.galleryAssetId;
      if (gid != null && gid.isNotEmpty) {
        await _gallery.deleteFromGallery(gid);
      }
    }

    await isar.writeTxn(() async {
      await isar.stepItems.filter().projectUidEqualTo(project.uid).deleteAll();
      await isar.projects.delete(project.id);
    });
  }

  // ---------- Steps ----------
  Future<List<StepItem>> getSteps({required String projectUid}) async {
    final isar = await _db();

    final list = await isar.stepItems
        .filter()
        .projectUidEqualTo(projectUid)
        .sortByOrder()
        .findAll();

    // Restore missing local images from Photos if we have galleryAssetId
    var changed = false;

    for (final s in list) {
      final path = s.imagePath;
      final hasLocal = path != null && path.isNotEmpty && await _imageStorage.exists(path);

      if (hasLocal) continue;

      final gid = s.galleryAssetId;
      if (gid != null && gid.isNotEmpty) {
        final galleryFile = await _gallery.getFileFromAssetId(gid);
        if (galleryFile != null) {
          final restoredPath = await _imageStorage.saveStepImage(
            pickedImage: galleryFile,
            projectUid: s.projectUid,
            stepUid: s.uid,
          );
          s.imagePath = restoredPath;
          changed = true;
        } else {
          // Gallery asset missing too
          s
            ..imagePath = null
            ..galleryAssetId = null;
          changed = true;
        }
      } else {
        // No gallery id, nothing to restore
        if (path != null && path.isNotEmpty) {
          s.imagePath = null;
          changed = true;
        }
      }
    }

    if (changed) {
      await isar.writeTxn(() async => isar.stepItems.putAll(list));
    }

    return list;
  }

  Future<StepItem> addStep({
    required Project project,
    required String title,
    required String description,
    File? pickedImage,
  }) async {
    final isar = await _db();
    final now = DateTime.now();

    // Determine next order
    final last = await isar.stepItems
        .filter()
        .projectUidEqualTo(project.uid)
        .sortByOrderDesc()
        .findFirst();

    final nextOrder = last == null ? 0 : (last.order + 1);
    final stepUid = _uuid.v4();

    String? storedPath;
    String? galleryId;

    if (pickedImage != null) {
      // 1) Save to Photos (persists across reinstalls)
      galleryId = await _gallery.saveImageToGallery(
        pickedImage,
        filename: 'process_cards_${project.uid}_$stepUid.jpg',
      );

      // 2) Copy into app storage (fast access + exports)
      storedPath = await _imageStorage.saveStepImage(
        pickedImage: pickedImage,
        projectUid: project.uid,
        stepUid: stepUid,
      );
    }

    final s = StepItem()
      ..uid = stepUid
      ..projectUid = project.uid
      ..order = nextOrder
      ..title = _safeStepTitle(title)
      ..description = description.trim()
      ..imagePath = storedPath
      ..galleryAssetId = galleryId
      ..createdAt = now
      ..updatedAt = now;

    project.updatedAt = now;

    await isar.writeTxn(() async {
      await isar.stepItems.put(s);
      await isar.projects.put(project);
    });

    return s;
  }

  Future<void> updateStep({
    required Project project,
    required StepItem step,
    required String title,
    required String description,
    File? newPickedImage,
    bool removeImage = false,
  }) async {
    final isar = await _db();
    final now = DateTime.now();

    step
      ..title = _safeStepTitle(title)
      ..description = description.trim()
      ..updatedAt = now;

    if (removeImage) {
      await _imageStorage.deleteImageIfExists(step.imagePath);
      step.imagePath = null;

      final gid = step.galleryAssetId;
      if (gid != null && gid.isNotEmpty) {
        await _gallery.deleteFromGallery(gid);
      }
      step.galleryAssetId = null;
    }

    if (newPickedImage != null) {
      // Delete old local
      await _imageStorage.deleteImageIfExists(step.imagePath);

      // Delete old gallery (if any)
      final oldGid = step.galleryAssetId;
      if (oldGid != null && oldGid.isNotEmpty) {
        await _gallery.deleteFromGallery(oldGid);
      }

      // Save new to gallery
      final newGid = await _gallery.saveImageToGallery(
        newPickedImage,
        filename: 'process_cards_${project.uid}_${step.uid}.jpg',
      );

      // Copy to app storage
      final storedPath = await _imageStorage.saveStepImage(
        pickedImage: newPickedImage,
        projectUid: project.uid,
        stepUid: step.uid,
      );

      step
        ..galleryAssetId = newGid
        ..imagePath = storedPath;
    }

    project.updatedAt = now;

    await isar.writeTxn(() async {
      await isar.stepItems.put(step);
      await isar.projects.put(project);
    });
  }

  Future<void> deleteStep({
    required Project project,
    required StepItem step,
  }) async {
    final isar = await _db();

    await _imageStorage.deleteImageIfExists(step.imagePath);

    final gid = step.galleryAssetId;
    if (gid != null && gid.isNotEmpty) {
      await _gallery.deleteFromGallery(gid);
    }

    await isar.writeTxn(() async {
      await isar.stepItems.delete(step.id);
      await _reindexOrdersInTxn(isar, project.uid);

      project.updatedAt = DateTime.now();
      await isar.projects.put(project);
    });
  }

  Future<void> reorderSteps({
    required Project project,
    required List<StepItem> stepsInNewOrder,
  }) async {
    final isar = await _db();
    final now = DateTime.now();

    for (var i = 0; i < stepsInNewOrder.length; i++) {
      stepsInNewOrder[i]
        ..order = i
        ..updatedAt = now;
    }

    project.updatedAt = now;

    await isar.writeTxn(() async {
      await isar.stepItems.putAll(stepsInNewOrder);
      await isar.projects.put(project);
    });
  }

  Future<void> _reindexOrdersInTxn(Isar isar, String projectUid) async {
    final steps = await isar.stepItems
        .filter()
        .projectUidEqualTo(projectUid)
        .sortByOrder()
        .findAll();

    final now = DateTime.now();
    for (var i = 0; i < steps.length; i++) {
      steps[i]
        ..order = i
        ..updatedAt = now;
    }

    await isar.stepItems.putAll(steps);
  }

  String _safeTitle(String input) {
    final t = input.trim();
    return t.isEmpty ? 'Untitled Project' : t;
  }

  String _safeStepTitle(String input) {
    final t = input.trim();
    return t.isEmpty ? 'Untitled Step' : t;
  }
}
