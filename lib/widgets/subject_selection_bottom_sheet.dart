import 'package:flutter/material.dart';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SubjectSelectionBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> timetable;
  final DatabaseService databaseService;
  final bool isPhoto;
  final Function(String) onSubjectSelected;

  const SubjectSelectionBottomSheet({
    super.key,
    required this.timetable,
    required this.databaseService,
    required this.isPhoto,
    required this.onSubjectSelected,
  });

  static void show({
    required BuildContext context,
    required List<Map<String, dynamic>> timetable,
    required DatabaseService databaseService,
    required bool isPhoto,
    required Function(String) onSubjectSelected,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SubjectSelectionBottomSheet(
          timetable: timetable,
          databaseService: databaseService,
          isPhoto: isPhoto,
          onSubjectSelected: onSubjectSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Ensure we only show unique subject names in the list
    final uniqueSubjects =
        timetable.map((s) => s['subject'] as String).toSet().toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPhoto
                  ? l10n.selectSubjectForPhoto
                  : l10n.selectSubjectForRecording,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            if (uniqueSubjects.isEmpty)
              const Text('No subjects found. Add some to your timetable first.')
            else
              ...uniqueSubjects.map((subjectName) {
                return ListTile(
                  leading: Icon((Icons.school)),
                  title: Text(subjectName),
                  onTap: () {
                    Navigator.pop(context);
                    // Simply call the callback with the selected subject.
                    // The parent widget is responsible for the action.
                    onSubjectSelected(subjectName);
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
