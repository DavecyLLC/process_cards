import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

class PhotoGalleryService {
  Future<bool> ensurePermission() async {
    final perm = await PhotoManager.requestPermissionExtend();
    return perm.isAuth || perm.hasAccess;
  }

  /// Save to iOS Photos. Returns localIdentifier (asset id).
  Future<String?> saveImageToGallery(File imageFile, {required String filename}) async {
    if (!await ensurePermission()) return null;

    final bytes = await imageFile.readAsBytes();

    // photo_manager 3.8.x expects filename
    final entity = await PhotoManager.editor.saveImage(
      bytes,
      filename: filename,
    );

    return entity?.id;
  }

  /// Delete from iOS Photos by localIdentifier.
  Future<bool> deleteFromGallery(String assetId) async {
    if (assetId.isEmpty) return false;
    if (!await ensurePermission()) return false;

    // photo_manager returns List<String> of deleted ids (not bool)
    final deletedIds = await PhotoManager.editor.deleteWithIds([assetId]);
    return deletedIds.contains(assetId);
  }

  Future<File?> getFileFromAssetId(String assetId) async {
    if (assetId.isEmpty) return null;
    if (!await ensurePermission()) return null;

    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;

    return await asset.file;
  }
}
