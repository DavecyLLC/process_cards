import 'package:isar/isar.dart';

part 'step_item.g.dart';

@collection
class StepItem {
  Id id = Isar.autoIncrement;

  @Index()
  late String projectUid;

  @Index(unique: true)
  late String uid;

  late int order;

  late String title;
  late String description;

  /// Permanent local path inside app Documents (copied from picker)
  String? imagePath;

  /// Optional: if you later save to Photos and want to delete it too
  String? galleryAssetId;

  late DateTime createdAt;
  late DateTime updatedAt;
}
