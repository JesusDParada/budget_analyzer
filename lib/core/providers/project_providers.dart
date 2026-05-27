import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budget_analyzer/domain/models/project.dart';
import 'package:budget_analyzer/data/local_db/database_helper.dart';

class ActiveProjectNotifier extends Notifier<Project?> {
  @override
  Project? build() {
    return null;
  }

  void selectProject(Project? project) {
    state = project;
  }
}

final activeProjectProvider = NotifierProvider<ActiveProjectNotifier, Project?>(() {
  return ActiveProjectNotifier();
});

final projectListProvider = FutureProvider<List<Project>>((ref) async {
  return await DatabaseHelper.instance.getAllProjects();
});
