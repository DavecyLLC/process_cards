import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/projects/data/models/project.dart';
import '../../features/projects/data/models/step_item.dart';

class PdfExportService {
  // “Full image” sizing (safe + readable)
  static const double _imageMaxHeight = 520;
  static const double _imageMinHeight = 180;
  static const double _imageCornerRadius = 8;

  Future<File> exportProjectToPdf({
    required Project project,
    required List<StepItem> steps,
  }) async {
    final sorted = steps.toList()..sort((a, b) => a.order.compareTo(b.order));

    // ✅ Unicode fonts (fixes • — and most characters)
    final fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final dateStr = DateFormat('MMM d, yyyy  h:mm a').format(DateTime.now());

    // Preload images safely
    final imageBytesByUid = <String, Uint8List>{};
    for (final s in sorted) {
      final bytes = await _readImageBytesIfExists(s.imagePath);
      if (bytes != null && bytes.isNotEmpty) {
        imageBytesByUid[s.uid] = bytes;
      }
    }

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) {
          final widgets = <pw.Widget>[];

          widgets.add(_header(projectTitle: project.title, dateStr: dateStr));
          widgets.add(pw.SizedBox(height: 16));

          for (var i = 0; i < sorted.length; i++) {
            final s = sorted[i];

            widgets.add(_stepBlock(s, imageBytesByUid[s.uid]));

            if (i != sorted.length - 1) {
              widgets.add(pw.SizedBox(height: 14));
              widgets.add(pw.Divider());
              widgets.add(pw.SizedBox(height: 10));
            }
          }

          return widgets;
        },
      ),
    );

    final bytes = await doc.save();
    return _saveExportFile(
      bytes: bytes,
      filename: '${_safeFileName(project.title)}_export.pdf',
    );
  }

  pw.Widget _header({required String projectTitle, required String dateStr}) {
    final title = projectTitle.trim().isEmpty ? 'Project' : projectTitle.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Exported: $dateStr', style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _stepBlock(StepItem s, Uint8List? imageBytes) {
    final stepNo = (s.order + 1).toString().padLeft(2, '0');
    final title = s.title.trim().isEmpty ? 'Untitled Step' : s.title.trim();
    final desc = s.description.trim().isEmpty ? '(No description)' : s.description.trim();
    final heading = 'Step $stepNo — $title';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          heading,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(desc, style: const pw.TextStyle(fontSize: 11)),
        if (imageBytes != null) ...[
          pw.SizedBox(height: 10),
          _fullImageFromBytes(imageBytes),
        ],
      ],
    );
  }

  /// Full image (no crop) + safe sizing (no Infinity / no null context)
  pw.Widget _fullImageFromBytes(Uint8List bytes) {
    try {
      final img = pw.MemoryImage(bytes);

      return pw.ClipRRect(
        horizontalRadius: _imageCornerRadius,
        verticalRadius: _imageCornerRadius,
        child: pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(
            minHeight: _imageMinHeight,
            maxHeight: _imageMaxHeight,
          ),
          alignment: pw.Alignment.center,
          child: pw.Image(
            img,
            fit: pw.BoxFit.contain, // ✅ full image
            alignment: pw.Alignment.center,
          ),
        ),
      );
    } catch (_) {
      // Never crash export due to one bad image
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '(Image could not be rendered)',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }
  }

  Future<Uint8List?> _readImageBytesIfExists(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<File> _saveExportFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/exports');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final outFile = File('${outDir.path}/$filename');
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  String _safeFileName(String input) {
    final cleaned = input.trim().isEmpty ? 'Project' : input.trim();
    final replaced = cleaned.replaceAll(RegExp(r'[^\w\s-]'), '');
    return replaced.replaceAll(RegExp(r'\s+'), '_');
  }
}

