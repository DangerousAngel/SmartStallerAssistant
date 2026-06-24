import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class AudioService {
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();

  get playerStateStream => _audioPlayer.playerStateStream;

  AudioPlayer get player => _audioPlayer;

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<bool> checkPermissions() async {
    final status = await Permission.microphone.request();
    if (kDebugMode) {
      print('[AudioService] Microphone permission status: ${status.name}');
    }
    return status.isGranted;
  }

  Future<String?> startRecording() async {
    if (!await hasRecordPermission()) {
      if (kDebugMode) {
        print(
            '[AudioService] Microphone permission not granted. Requesting...');
      }
      if (!await checkPermissions()) {
        if (kDebugMode) {
          print('[AudioService] Permission request was denied.');
        }
        return null;
      }
    }

    if (await _audioRecorder.isRecording()) {
      if (kDebugMode) {
        print('[AudioService] Already recording, stopping previous one first.');
      }
      await _audioRecorder.stop();
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${audioDir.path}/$fileName';

      if (kDebugMode) {
        print('[AudioService] Starting recording to path: $path');
      }

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      bool isRecording = await _audioRecorder.isRecording();
      if (kDebugMode) {
        print('[AudioService] Is recorder recording: $isRecording');
      }

      return isRecording ? path : null;
    } catch (e, s) {
      if (kDebugMode) {
        print('!!! [AudioService] ERROR starting recording: $e');
        print('!!! [AudioService] Stacktrace: $s');
      }
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (await _audioRecorder.isRecording() ||
          await _audioRecorder.isPaused()) {
        final path = await _audioRecorder.stop();
        if (kDebugMode) {
          print('[AudioService] Stopped recording. File at: $path');
        }
        return path;
      }
      if (kDebugMode) {
        print(
            '[AudioService] Stop recording called, but was not recording or paused.');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('!!! [AudioService] ERROR stopping recording: $e');
      }
      return null;
    }
  }

  // --- START OF CHANGE ---
  Future<void> pauseRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.pause();
        if (kDebugMode) {
          print('[AudioService] Recording paused.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('!!! [AudioService] ERROR pausing recording: $e');
      }
    }
  }

  Future<void> resumeRecording() async {
    try {
      if (await _audioRecorder.isPaused()) {
        await _audioRecorder.resume();
        if (kDebugMode) {
          print('[AudioService] Recording resumed.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('!!! [AudioService] ERROR resuming recording: $e');
      }
    }
  }
  // --- END OF CHANGE ---

  Future<void> playRecording(String filePath) async {
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.file(filePath)));
      await _audioPlayer.play();
    } catch (e) {
      if (kDebugMode) {
        print('!!! [AudioService] ERROR playing recording: $e');
      }
    }
  }

  Future<void> pausePlayback() async {
    await _audioPlayer.pause();
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  Future<void> dispose() async {
    await _audioRecorder.dispose();
    await _audioPlayer.dispose();
  }

  Future<bool> hasRecordPermission() async {
    return await _audioRecorder.hasPermission();
  }
}
