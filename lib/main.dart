import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/lectures_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;
  bool _isDarkMode = false;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _databaseService.init();
    await NotificationService.initialize();
    await NotificationService.requestPermissions();

    // Listen for alarm ring
    Alarm.ringStream.stream.listen((alarmSettings) {
      _showAlarmDialog(alarmSettings);
    });

    final darkModeSetting = await _databaseService.getSetting('darkMode');
    _isDarkMode = darkModeSetting == 'true';

    final langCode = await _databaseService.getSetting('language') ?? 'en';
    _currentLocale = Locale(langCode);

    setState(() {
      _isLoading = false;
    });
  }

  void _showAlarmDialog(AlarmSettings alarmSettings) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to stop
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            alarmSettings.notificationTitle ?? l10n?.lectureReminder ?? 'Alarm',
            style: TextStyle(
                color: const Color.fromRGBO(210, 181, 138, 1),
                fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alarm,
                  size: 48, color: Color.fromRGBO(210, 181, 138, 1)),
              const SizedBox(height: 16),
              Text(
                alarmSettings.notificationBody ??
                    l10n?.ringRing ??
                    'Ring Ring!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(210, 181, 138, 1),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  await Alarm.stop(alarmSettings.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  l10n?.stopAlarm ?? 'Stop Alarm',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleThemeChanged(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  void _handleLocaleChanged(Locale newLocale) {
    setState(() {
      _currentLocale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> screens = [
      HomeScreen(databaseService: _databaseService),
      TimetableScreen(databaseService: _databaseService),
      LecturesScreen(databaseService: _databaseService),
      SettingsScreen(
        databaseService: _databaseService,
        onThemeChanged: _handleThemeChanged,
        onLocaleChanged: _handleLocaleChanged,
      ),
    ];

    final Color primaryColor = const Color(0xFF1F5F5B); // Deep Blue
    final Color accentColor = const Color.fromRGBO(210, 181, 138, 1); // Gold

    return MaterialApp(
      title: 'Student Assistant',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      locale: _currentLocale,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _isDarkMode
          ? ThemeData.dark(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                secondary: accentColor,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor:
                  Color.fromARGB(255, 28, 28, 28), // Darker Slate Blue
              cardColor: const Color(0xFF224A60), // Deep Blue
              appBarTheme: AppBarTheme(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: accentColor,
                unselectedItemColor: Colors.grey.shade400,
                backgroundColor: const Color(0xFF0A1929),
              ),
            )
          : ThemeData.light(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                secondary: accentColor,
                surface: Colors.white,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.black45,
              ),
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
            ),
      home: Builder(builder: (context) {
        // This Builder provides a new context that has the AppLocalizations.
        return Directionality(
          // This forces the app's layout to always be Left-to-Right,
          // even for Arabic, as requested.
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                    icon: const Icon(Icons.home),
                    label: AppLocalizations.of(context)!.home),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_today),
                  label: AppLocalizations.of(context)!.timetable,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.library_books),
                  label: AppLocalizations.of(context)!.lectures,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.settings,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
