import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

class GalleryService {
  Future<bool> ensurePermissionForWriteAndDelete() async {
    final ps = await PhotoManager.requestPermissionExtend();
    // Need authorized or limited (limited may restrict delete if asset not in allowed set)
    return ps.isAuth || ps.isLimited;
  }

  /// Saves image bytes to Photos and returns the iOS localIdentifier (asset id).
  Future<String?> saveToGallery(File imageFile) async {
    final ok = await ensurePermissionForWriteAndDelete();
    if (!ok) return null;

    final bytes = await imageFile.readAsBytes();
    final asset = await PhotoManager.editor.saveImage(
      bytes,
      title: 'process_step_${DateTime.now().millisecondsSinceEpoch}',
    );
    return asset?.id; // id is the asset identifier
  }

  /// Deletes a previously saved Photos asset by id.
  Future<bool> deleteFromGallery(String? assetId) async {
    if (assetId == null || assetId.isEmpty) return false;

    final ok = await ensurePermissionForWriteAndDelete();
    if (!ok) return false;

    try {
      final result = await PhotoManager.editor.deleteWithIds([assetId]);
      return result.isNotEmpty && result.first == true;
    } catch (_) {
      return false;
    }
  }
}


