import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/projects/data/models/project.dart';
import '../../features/projects/data/models/step_item.dart';

class IsarDb {
  static Isar? _isar;

  static Future<Isar> instance() async {
    if (_isar != null) return _isar!;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ProjectSchema, StepItemSchema],
      directory: dir.path,
      inspector: false,
    );
    return _isar!;
  }
}

