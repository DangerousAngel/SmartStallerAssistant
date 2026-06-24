import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart'; // Import for PlayerState

// Assume this is your AudioService class or similar provider.
// This is a placeholder since the full class isn't provided.
import 'package:just_audio/just_audio.dart';

class AudioServicec {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player; // expose the player

  // Track the current file
  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;

  Future<void> playRecording(String filePath) async {
    if (_currentFilePath != filePath) {
      _currentFilePath = filePath;
      await _player.setFilePath(filePath);
    } else {
      // If same file, check if completed and reset
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
    }
    await _player.play();
  }

  Future<void> pausePlayback() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // Streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
}

class BuildContent {
  // --- START OF CHANGE ---
  // Extracted the animated FAB logic and added heroTag parameter
  static Widget buildRecordFab({
    String? heroTag, // Added for unique FAB identification
    required BuildContext context,
    required bool isRecording,
    required bool isPaused,
    required VoidCallback onStart,
    required VoidCallback onPause,
    required VoidCallback onResume,
    required VoidCallback onStop,
    required void Function() onTakePhoto,
    required void Function() onStartRecord,
  }) {
    return _AnimatedRecordFab(
      heroTag: heroTag,
      isRecording: isRecording,
      isPaused: isPaused,
      onStart: onStart,
      onPause: onPause,
      onResume: onResume,
      onStop: onStop,
    );
  }
  // --- END OF CHANGE ---
}

// A dedicated stateful widget to manage the FAB animations
class _AnimatedRecordFab extends StatefulWidget {
  final String? heroTag; // Added heroTag
  final bool isRecording;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _AnimatedRecordFab({
    this.heroTag, // Added heroTag
    required this.isRecording,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<_AnimatedRecordFab> createState() => _AnimatedRecordFabState();
}

class _AnimatedRecordFabState extends State<_AnimatedRecordFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    if (widget.isRecording) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedRecordFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: FloatingActionButton(
            // --- START OF CHANGE ---
            heroTag: widget.heroTag != null ? '${widget.heroTag}_stop' : null,
            // --- END OF CHANGE ---
            mini: true,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: widget.onStop,
            child: const Icon(Icons.stop),
          ),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
            // --- START OF CHANGE ---
            heroTag: widget.heroTag,
            // --- END OF CHANGE ---
            onPressed: widget.isRecording
                ? (widget.isPaused ? widget.onResume : widget.onPause)
                : widget.onStart,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                widget.isRecording
                    ? (widget.isPaused ? Icons.play_arrow : Icons.pause)
                    : Icons.mic,
                key: ValueKey<int>(
                    widget.isRecording ? (widget.isPaused ? 2 : 1) : 0),
                color: Colors.black,
              ),
            ),
            backgroundColor: Color.fromRGBO(210, 181, 138, 1)),
      ],
    );
  }
}
