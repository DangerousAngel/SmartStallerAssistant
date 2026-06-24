import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:student_assistance_app/services/file_storage_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'student_assistant.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createChatTables(db);
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folderId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE media(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL, -- 'photo' or 'recording'
        filePath TEXT NOT NULL,
        subject TEXT, -- Associated subject from timetable
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT NOT NULL,
        time TEXT NOT NULL,
        subject TEXT NOT NULL,
        room TEXT,
        professor TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
    CREATE TABLE todos(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    priority INTEGER NOT NULL DEFAULT 1, -- 1: Low, 2: Medium, 3: High
    dueDate TEXT,
    createdAt TEXT NOT NULL
  )
''');
    await _createChatTables(db);
    await _insertDefaultSettings(db);
  }

  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE chat_sessions(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        role TEXT NOT NULL, -- 'user' or 'model'
        text TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final defaultSettings = [
      {'key': 'notifications', 'value': 'true'},
      {'key': 'darkMode', 'value': 'false'},
      {'key': 'language', 'value': 'en'}, // NEW: Default language
    ];
    for (var setting in defaultSettings) {
      await db.insert('settings', setting,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ... [THE REST OF THE FILE REMAINS EXACTLY THE SAME] ...

  // ============ FOLDER OPERATIONS ============
  Future<int> insertFolder(Map<String, dynamic> folder) async {
    final db = await database;
    return await db.insert('folders', folder);
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await database;
    return await db.query('folders', orderBy: 'name ASC');
  }

  Future<int> updateFolder(int id, Map<String, dynamic> folder) async {
    final db = await database;
    return await db.update('folders', folder, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFolder(int id) async {
    final db = await database;
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // ============ NOTE OPERATIONS ============
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }

  Future<List<Map<String, dynamic>>> getNotes(int folderId) async {
    final db = await database;
    return await db.query('notes',
        where: 'folderId = ?',
        whereArgs: [folderId],
        orderBy: 'createdAt DESC');
  }

  Future<int> updateNote(int id, Map<String, dynamic> note) async {
    final db = await database;
    return await db.update('notes', note, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ============ TIMETABLE OPERATIONS ============
  Future<int> insertTimetable(Map<String, dynamic> timetable) async {
    final db = await database;
    return await db.insert('timetable', {
      ...timetable,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getTimetable() async {
    final db = await database;
    return await db.query('timetable', orderBy: 'day, time');
  }

  Future<int> updateTimetable(
      int id, Map<String, dynamic> newTimetableData) async {
    final db = await database;
    int result = 0;
    await db.transaction((txn) async {
      final oldEntry =
          await txn.query('timetable', where: 'id = ?', whereArgs: [id]);
      if (oldEntry.isNotEmpty) {
        final oldSubject = oldEntry.first['subject'] as String?;
        final newSubject = newTimetableData['subject'] as String?;
        if (oldSubject != null &&
            newSubject != null &&
            oldSubject != newSubject) {
          await txn.update('media', {'subject': newSubject},
              where: 'subject = ?', whereArgs: [oldSubject]);
        }
      }
      result = await txn.update('timetable', newTimetableData,
          where: 'id = ?', whereArgs: [id]);
    });
    return result;
  }

  Future<int> deleteTimetable(int id) async {
    final db = await database;
    int result = 0;
    await db.transaction((txn) async {
      final entryToDelete =
          await txn.query('timetable', where: 'id = ?', whereArgs: [id]);
      if (entryToDelete.isEmpty) return;
      final subject = entryToDelete.first['subject'] as String?;
      if (subject != null) {
        final associatedMedia = await txn
            .query('media', where: 'subject = ?', whereArgs: [subject]);
        for (var media in associatedMedia) {
          if (media['filePath'] != null) {
            await FileStorageService.deleteFile(media['filePath'] as String);
          }
        }
        await txn.delete('media', where: 'subject = ?', whereArgs: [subject]);
      }
      result = await txn.delete('timetable', where: 'id = ?', whereArgs: [id]);
    });
    return result;
  }

  // ============ SETTINGS OPERATIONS ============
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  // ============ MEDIA OPERATIONS ============
  Future<int> insertMedia(Map<String, dynamic> media) async {
    final db = await database;
    return await db.insert('media', media);
  }

  Future<List<Map<String, dynamic>>> getMediaByType(String type) async {
    final db = await database;
    return await db.query('media',
        where: 'type = ?', whereArgs: [type], orderBy: 'createdAt DESC');
  }

  Future<int> deleteMedia(int id) async {
    final db = await database;
    final media =
        await db.query('media', where: 'id = ?', whereArgs: [id], limit: 1);
    if (media.isNotEmpty && media.first['filePath'] != null) {
      await FileStorageService.deleteFile(media.first['filePath'] as String);
    }
    return await db.delete('media', where: 'id = ?', whereArgs: [id]);
  }

  // ============ CHAT OPERATIONS ============
  Future<void> createChatSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert('chat_sessions', session,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getChatSessions() async {
    final db = await database;
    return await db.query('chat_sessions', orderBy: 'createdAt DESC');
  }

  Future<void> deleteChatSession(String id) async {
    final db = await database;
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertChatMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert('chat_messages', message);
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String sessionId) async {
    final db = await database;
    return await db.query('chat_messages',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'createdAt ASC');
  }

  // ============ TO-DO OPERATIONS ============
  Future<int> insertTodo(Map<String, dynamic> todo) async {
    final db = await database;
    return await db.insert('todos', {
      ...todo,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getTodos({String? filter}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (filter == 'pending') {
      whereClause = 'isCompleted = ?';
      whereArgs = [0];
    } else if (filter == 'completed') {
      whereClause = 'isCompleted = ?';
      whereArgs = [1];
    }

    return await db.query('todos',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'isCompleted ASC, priority DESC, dueDate ASC, createdAt DESC');
  }

  Future<int> updateTodo(int id, Map<String, dynamic> todo) async {
    final db = await database;
    return await db.update('todos', todo, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> toggleTodoCompletion(int id, bool isCompleted) async {
    final db = await database;
    return await db.update('todos', {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ============ GENERAL OPERATIONS ============
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('folders');
    await db.delete('notes');
    await db.delete('media');
    await db.delete('timetable');
    await db.delete('chat_sessions');
    await db.delete('chat_messages');
    await db.delete('todos');

    final lecturesDir =
        Directory(await FileStorageService.getLecturesDirectory());
    if (await lecturesDir.exists()) {
      await lecturesDir.delete(recursive: true);
    }
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> init() async {
    await database;
  }
}
