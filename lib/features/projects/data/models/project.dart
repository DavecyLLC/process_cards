import 'package:isar/isar.dart';
part 'project.g.dart';

@collection
class Project {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uid;

  late String title;

  late DateTime createdAt;
  late DateTime updatedAt;
}

