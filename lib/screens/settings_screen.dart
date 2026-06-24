import 'package:flutter/material.dart';
import 'dart:async';
import 'package:student_assistance_app/services/database_service.dart';
import 'package:student_assistance_app/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../widgets/todo_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:student_assistance_app/widgets/gradient_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final Function(bool) onThemeChanged;
  final Function(Locale) onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.databaseService,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = false, _darkMode = false;
  String _currentLanguageCode = 'en';
  int _notificationMinutesBefore = 15;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _scheduleAllLectureNotifications() async {
    // Get l10n while context is valid
    final l10n = mounted ? AppLocalizations.of(context) : null;

    try {
      await NotificationService.cancelAllNotifications();
      final timetable = await widget.databaseService.getTimetable();

      int scheduledCount = 0;
      for (var lecture in timetable) {
        await NotificationService.scheduleLectureNotification(lecture, l10n);
        scheduledCount++;
      }

      _showSnackBar(
        '$scheduledCount lecture alarms scheduled '
        '(reminder $_notificationMinutesBefore min before)',
      );
    } catch (e) {
      _showSnackBar('Failed to schedule notifications: $e');
      print('❌ Error in _scheduleAllLectureNotifications: $e');
    }
  }

  Future<void> _loadSettings() async {
    await NotificationService.initialize();
    _notifications =
        (await widget.databaseService.getSetting('notifications')) == 'true';
    _darkMode = (await widget.databaseService.getSetting('darkMode')) == 'true';
    _currentLanguageCode =
        (await widget.databaseService.getSetting('language')) ?? 'en';

    // Load notification minutes setting
    final minutesStr =
        await widget.databaseService.getSetting('notificationMinutesBefore');
    _notificationMinutesBefore =
        minutesStr != null ? int.parse(minutesStr) : 15;

    if (mounted) setState(() {});
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _launchURL() async {
    // This method remains unchanged
    final Uri url = Uri.parse('https://github/DangerousAngel');
    if (!await launchUrl(url)) {
      _showSnackBar('Could not launch $url');
    }
  }

  // FIXED: Pass the l10n instance directly to avoid null context issues
  void _showClearDataDialog(AppLocalizations l10n) => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.clearAllData),
          content: Text(l10n.confirmClearAllData),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                await widget.databaseService.clearAllData();
                await NotificationService.cancelAllNotifications();
                Navigator.pop(context);
                _showSnackBar(l10n.allDataCleared);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child:
                  Text(l10n.clear, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // For Android, use the known Downloads directory path
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _exportTimetableData() async {
    // This method is safe as it gets context before showing a snackbar
    final l10n = AppLocalizations.of(context)!;
    final timetableData = await widget.databaseService.getTimetable();

    if (timetableData.isEmpty) {
      _showSnackBar(l10n.noTimetableDataToExport);
      return;
    }

    List<String> headers = ['Day', 'Time', 'Subject', 'Room', 'Professor'];
    List<List<dynamic>> rows = [headers];

    for (var entry in timetableData) {
      rows.add([
        entry['day'],
        entry['time'],
        entry['subject'],
        entry['room'] ?? '',
        entry['professor'] ?? ''
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    try {
      // Get Downloads directory
      final downloadsDir = await _getDownloadsDirectory();

      // Create a filename with timestamp
      final fileName =
          'timetable_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
      final path = '${downloadsDir.path}/$fileName';
      final file = File(path);

      // Write the CSV file to Downloads
      await file.writeAsString(csv);

      // Share the file from Downloads directory
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Student Assistant - Timetable Export',
      );

      // Optional: Show success message
      _showSnackBar('Timetable exported to Downloads folder');
    } catch (e) {
      _showSnackBar('Error exporting data: $e');
    }
  }

  // FIXED: Pass the l10n instance directly to avoid null context issues
  void _showLanguageSelectionDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: _currentLanguageCode,
                onChanged: (value) {
                  if (value != null) {
                    _changeLanguage(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('العربية'),
                value: 'ar',
                groupValue: _currentLanguageCode,
                onChanged: (value) {
                  if (value != null) {
                    _changeLanguage(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildLinkButton(
      IconData icon, String label, String url, Color color) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnackBar('Could not launch $url');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _changeLanguage(String langCode) async {
    setState(() => _currentLanguageCode = langCode);
    await widget.databaseService.setSetting('language', langCode);
    widget.onLocaleChanged(Locale(langCode));

    // Wait for the UI to rebuild with the new locale
    await Future.delayed(const Duration(milliseconds: 500));

    // Reschedule notifications in the new language if enabled
    if (_notifications) {
      await _scheduleAllLectureNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: GradientAppBar(
        leading: const Icon(Icons.settings),
        title: Text(l10n.settings),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAppHeader(l10n),
            const SizedBox(height: 32),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.preferences,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.enableNotifications),
              subtitle: Text(l10n.getRemindersBeforeLectures),
              value: _notifications,
              onChanged: (value) async {
                setState(() => _notifications = value);
                widget.databaseService
                    .setSetting('notifications', value.toString());

                if (value) {
                  // Request permissions if not granted
                  await NotificationService.requestPermissions();
                  await _scheduleAllLectureNotifications();
                  // Show the nearest lecture immediately for confirmation
                  final timetable = await widget.databaseService.getTimetable();
                  if (timetable.isNotEmpty) {
                    await NotificationService.showNearestLectureNow(
                        timetable, l10n);
                  }
                } else {
                  NotificationService.cancelAllNotifications();
                }
              },
            ),
            SwitchListTile(
              title: Text(l10n.darkMode),
              subtitle: Text(l10n.switchToDarkTheme),
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
                widget.databaseService.setSetting('darkMode', value.toString());
                widget.onThemeChanged(value);
              },
            ),
            ListTile(
              title: Text(l10n.language),
              subtitle: Text(l10n.changeAppLanguage),
              trailing:
                  Text(_currentLanguageCode == 'en' ? 'English' : 'العربية'),
              onTap: () =>
                  _showLanguageSelectionDialog(l10n), // FIXED: Pass l10n
            ),
            const SizedBox(height: 24),
            if (_notifications) ...[
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.setNotificationTimer,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.notificationTime),
                subtitle: Text(l10n.minutesBeforeLecture),
                trailing: DropdownButton<int>(
                  value: _notificationMinutesBefore,
                  items: [0, 5, 10, 15, 30, 60].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value minutes'),
                    );
                  }).toList(),
                  onChanged: _notifications
                      ? (int? newValue) async {
                          if (newValue != null) {
                            setState(
                                () => _notificationMinutesBefore = newValue);
                            widget.databaseService.setSetting(
                                'notificationMinutesBefore',
                                newValue.toString());
                            NotificationService.setNotificationMinutesBefore(
                                newValue);

                            // Reschedule all notifications with the new time
                            await NotificationService.cancelAllNotifications();
                            _scheduleAllLectureNotifications();
                          }
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.dataManagement,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _exportTimetableData,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(l10n.exportTimetableData),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _showClearDataDialog(l10n), // FIXED: Pass l10n
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(l10n.clearAllData),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(AppLocalizations l10n) => Column(
        children: [
          InkWell(
            onTapDown: (_) {
              _longPressTimer = Timer(const Duration(seconds: 3), () {
                _launchURL();
              });
            },
            onTapUp: (_) {
              _longPressTimer?.cancel();
            },
            onTapCancel: () {
              _longPressTimer?.cancel();
            },
            customBorder: const CircleBorder(),
            child: ClipOval(
              child: Image.asset(
                'assets/ic_launcher_round.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 100,
                  height: 100,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.studentAssistant,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              l10n.appDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, color: Colors.grey, height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.version,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic)),
        ],
      );
}
