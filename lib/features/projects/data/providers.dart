import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/image_storage_service.dart';
import '../../../core/services/photo_gallery_service.dart';
import '../data/project_repository.dart';

final imageStorageProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});

final photoGalleryProvider = Provider<PhotoGalleryService>((ref) {
  return PhotoGalleryService();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    ref.read(imageStorageProvider),
    ref.read(photoGalleryProvider),
  );
});
