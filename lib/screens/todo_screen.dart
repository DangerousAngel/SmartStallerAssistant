import 'package:flutter/material.dart';
import 'package:student_assistance_app/widgets/todo_list.dart';
import 'package:student_assistance_app/services/database_service.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TodoScreen extends StatelessWidget {
  final DatabaseService databaseService;

  const TodoScreen({super.key, required this.databaseService});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todoList),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: TodoList(databaseService: databaseService),
    );
  }
}
