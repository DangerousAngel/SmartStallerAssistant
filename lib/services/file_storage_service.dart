import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static Future<String> getLecturesDirectory() async {
    // Use getExternalStorageDirectory for Android/data/[package]/files
    final Directory? appDir = await getExternalStorageDirectory();
    
    // Fallback to internal storage if external is unavailable
    final Directory baseDir = appDir ?? await getApplicationDocumentsDirectory();
    
    final Directory lecturesDir = Directory('${baseDir.path}/Lectures');
    
    if (!await lecturesDir.exists()) {
      await lecturesDir.create(recursive: true);
    }
    
    return lecturesDir.path;
  }

  static Future<String> getPhotosDirectory() async {
    final String lecturesPath = await getLecturesDirectory();
    final Directory photosDir = Directory('$lecturesPath/photos');
    
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    
    return photosDir.path;
  }

  static Future<String> getRecordingsDirectory() async {
    final String lecturesPath = await getLecturesDirectory();
    final Directory recordingsDir = Directory('$lecturesPath/recordings');
    
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    
    return recordingsDir.path;
  }

  static Future<String> savePhoto(File imageFile, String fileName) async {
    final String photosDir = await getPhotosDirectory();
    final String newPath = '$photosDir/$fileName';
    
    await imageFile.copy(newPath);
    return newPath;
  }

  static Future<String> saveRecording(File audioFile, String fileName) async {
    final String recordingsDir = await getRecordingsDirectory();
    final String newPath = '$recordingsDir/$fileName';
    
    await audioFile.copy(newPath);
    return newPath;
  }

  static Future<bool> deleteFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
  
}