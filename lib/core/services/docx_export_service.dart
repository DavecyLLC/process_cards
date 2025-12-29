import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docx_creator/docx_creator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/projects/data/models/project.dart';
import '../../features/projects/data/models/step_item.dart';

class DocxExportService {
  Future<File> exportProjectToDocx({
    required Project project,
    required List<StepItem> steps,
  }) async {
    final sorted = List<StepItem>.from(steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    final now = DateTime.now();
    final exportDate = DateFormat('MMM d, yyyy  h:mm a').format(now);
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);

    final title = _safeText(project.title, 'Project');

    final builder = docx()
      ..h1(title)
      ..add(
        DocxParagraph(children: [
          DocxText(
            'Exported: $exportDate',
            fontStyle: DocxFontStyle.italic,
            color: DocxColor.gray,
          ),
        ]),
      )
      ..hr();

    for (final s in sorted) {
      final stepNo = (s.order + 1).toString().padLeft(2, '0');
      final stepTitle = _safeText(s.title, 'Untitled Step');
      final desc = _safeText(s.description, '(No description)');

      builder
        ..h3('Step $stepNo — $stepTitle')
        ..p(desc);

      final bytes = await _readImageBytesIfExists(s.imagePath);
      if (bytes != null) {
        final ext = _fileExtension(s.imagePath) ?? 'jpg';

        // Fit image to page while preserving aspect ratio
        final (w, h) = await _scaledImageSize(
          bytes,
          maxWidth: 520,  // tweak bigger/smaller
          maxHeight: 720, // tweak bigger/smaller
        );

        builder.add(
          DocxImage(
            bytes: bytes,
            extension: ext,
            width: w,   // ✅ double
            height: h,  // ✅ double
            align: DocxAlign.center,
          ),
        );

        builder.p('');
      }

      builder.hr();
    }

    final doc = builder.build();
    final outBytes = await DocxExporter().exportToBytes(doc);

    final filename = '${_safeFileName(title)}_$timestamp.docx';
    return _save(outBytes, filename);
  }

  Future<Uint8List?> _readImageBytesIfExists(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// Returns (width, height) as doubles for DocxImage
  Future<(double, double)> _scaledImageSize(
    Uint8List bytes, {
    required double maxWidth,
    required double maxHeight,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();

      if (w <= 0 || h <= 0) return (maxWidth, maxWidth * 0.75);

      final scaleW = maxWidth / w;
      final scaleH = maxHeight / h;
      final scale = scaleW < scaleH ? scaleW : scaleH;

      final outW = (w * scale).clamp(1.0, maxWidth);
      final outH = (h * scale).clamp(1.0, maxHeight);

      return (outW, outH);
    } catch (_) {
      // fallback
      return (maxWidth, maxWidth * 0.75);
    }
  }

  String? _fileExtension(String? path) {
    if (path == null) return null;
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'jpg';
    if (p.endsWith('.webp')) return 'webp';
    return null;
  }

  Future<File> _save(List<int> bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/exports');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final file = File('${outDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeText(String? v, String fallback) {
    final s = (v ?? '').trim();
    return s.isEmpty ? fallback : s;
  }

  String _safeFileName(String input) {
    final cleaned = input.trim().isEmpty ? 'Project' : input.trim();
    return cleaned
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
