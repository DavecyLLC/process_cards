import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  Future<Directory> _rootDir() async {
    // ApplicationSupport is ideal for app-owned files and survives restarts.
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'step_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> saveStepImage({
    required File pickedImage,
    required String projectUid,
    required String stepUid,
  }) async {
    final root = await _rootDir();
    final projectDir = Directory(p.join(root.path, projectUid));
    if (!await projectDir.exists()) await projectDir.create(recursive: true);

    final ext = _safeExt(p.extension(pickedImage.path));
    final destPath = p.join(projectDir.path, 'step_$stepUid$ext');

    // ✅ Robust write: read bytes then write
    final bytes = await pickedImage.readAsBytes();
    final out = File(destPath);
    await out.writeAsBytes(bytes, flush: true);

    return out.path;
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteImageIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  bool looksTemporary(String path) {
    final pth = path.toLowerCase();
    // iOS temp locations commonly include /tmp or /temporary
    return pth.contains('/tmp/') || pth.contains('/temporary') || pth.contains('/cache');
  }

  String _safeExt(String ext) {
    final e = ext.trim().toLowerCase();
    if (e == '.jpg' || e == '.jpeg' || e == '.png' || e == '.heic') return e;
    return '.jpg';
  }
}
