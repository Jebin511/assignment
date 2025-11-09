import 'dart:async';
import 'dart:io'; 
import 'dart:math'; 
import 'dart:ui';

import 'package:assignment/screens/experience_selection/widgets/squiggly_progressbar.dart';
import 'package:audioplayers/audioplayers.dart'; // For audio playback
import 'package:camera/camera.dart'; // For video recording
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'; // For file path
import 'package:permission_handler/permission_handler.dart'; // For permissions
import 'package:record/record.dart'; // For audio recording
import 'package:video_player/video_player.dart'; // For video playback
class Onboarding_questions_screen extends StatefulWidget {
  final int step;
  const Onboarding_questions_screen({super.key, required this.step});

  @override
  State<Onboarding_questions_screen> createState() => _Onboarding_questions_screen();
}
class _Onboarding_questions_screen extends State<Onboarding_questions_screen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random(); // For simulated waveform
  late AudioRecorder _audioRecorder;
  String? _audioFilePath;
  // Audio Playback 
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  // Video Recording
  List<CameraDescription> _cameras = []; // List of all cameras
  CameraController? _cameraController;
  int _selectedCameraIndex = 0; // 0 for back, 1 for front
  String? _videoFilePath;
  bool _isRecordingVideo = false; // NEW: true when stopwatch is running

  // Video Playback Engine
  VideoPlayerController? _videoPlayerController;
  bool _isVideoPlaying = false;

  // Timer UI
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _durationTimer;
  String _recordingDuration = "00:00";
  String _finalRecordingDuration = "00:00";

  // Combined state check for proceeding
 bool get canProceed =>
      _controller.text.trim().isNotEmpty || hasRecording || hasVideo;

  // Audio Recording States
  bool isRecording = false;
  bool hasRecording = false;
  Timer? waveformTimer;
  List<double> waveformValues = List.filled(30, 0);

  // Video Recording States
  // This state now means "in video mode" (showing camera preview)
  bool isVideoMode = false;
  bool hasVideo = false;

  // Define the purple color from the design
  static const Color _purpleColor = Color(0xFF8B5CF6);
  // Static waveform for the preview card
  late final List<double> _previewWaveform;

  // --- HAPTIC FEEDBACK FUNCTIONS ---
  // (Using ServicesBinding.instance.platformDispatcher.vibrate is built-in)
  // (If you add the package, you can use HapticFeedback.mediumImpact() etc.)
  void _lightHaptic() {
    HapticFeedback.lightImpact();
  }
  void _mediumHaptic() {
    HapticFeedback.mediumImpact();
  }


  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _previewWaveform =
        List.generate(30, (index) => _random.nextDouble() * 10.0);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          isPlaying = false;
        });
      }
    });

    // Initialize cameras when screen loads
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      // Try to find the front camera and set it as default
      final frontCameraIndex = _cameras.indexWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front);
      if (frontCameraIndex != -1) {
        _selectedCameraIndex = frontCameraIndex;
      }
    } catch (e) {
      print("Error finding cameras: $e");
    }
  }

  @override
  void dispose() {
    waveformTimer?.cancel();
    _durationTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- State Management ---

  void onTextChanged(String text) {
    setState(() {});
  }

  // --- Timer Methods ---
  void _updateDuration(Timer timer) {
    final int seconds = _stopwatch.elapsed.inSeconds;
    final String minutesStr = (seconds ~/ 60).toString().padLeft(2, '0');
    final String secondsStr = (seconds % 60).toString().padLeft(2, '0');
    setState(() {
      _recordingDuration = "$minutesStr:$secondsStr";
    });
  }

  // --- Audio Methods (Unchanged) ---

  Future<void> startRecording() async {
    _mediumHaptic(); // Haptic feedback
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print("Microphone permission denied");
        return;
      }
      setState(() {
        isRecording = true;
        hasRecording = false;
        isVideoMode = false;
        hasVideo = false;
        _recordingDuration = "00:00";
      });
      _stopwatch.reset();
      _stopwatch.start();
      _durationTimer?.cancel();
      _durationTimer =
          Timer.periodic(const Duration(milliseconds: 500), _updateDuration);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/my_audio_answer.m4a';
      _audioFilePath = path;
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      waveformTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (!isRecording) {
          timer.cancel();
          return;
        }
        try {
          final amplitude = await _audioRecorder.getAmplitude();
          setState(() {
            final double db = amplitude.current;
            final double normalized = (db + 50).clamp(0, 50) / 5; // 0-10 scale
            waveformValues.removeAt(0);
            waveformValues.add(normalized);
          });
        } catch (e) {
          setState(() {
            waveformValues.removeAt(0);
            waveformValues.add(0.0);
          });
        }
      });
    } catch (e) {
      print("Error starting recording: $e");
      setState(() {
        isRecording = false;
        _stopwatch.stop();
        _durationTimer?.cancel();
      });
    }
  }
  
  Future<void> cancelAudioRecording() async {
  _mediumHaptic();
  try {
    // stop timers
    waveformTimer?.cancel();
    _stopwatch.stop();
    _durationTimer?.cancel();

    // stop recorder (no file path returned on cancel reliably, so check ours)
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    // delete any temp file we were writing to
    if (_audioFilePath != null) {
      final f = File(_audioFilePath!);
      if (await f.exists()) {
        await f.delete();
      }
    }

    setState(() {
      isRecording = false;
      hasRecording = false;
      _audioFilePath = null;
      waveformValues = List.filled(30, 0);
      _recordingDuration = "00:00";
    });
  } catch (e) {
    // fall back to clean state
    setState(() {
      isRecording = false;
      hasRecording = false;
      _audioFilePath = null;
      waveformValues = List.filled(30, 0);
      _recordingDuration = "00:00";
    });
  }
}

  Future<void> stopRecording() async {
    _mediumHaptic(); // Haptic feedback
    waveformTimer?.cancel();
    _stopwatch.stop();
    _durationTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      print("Audio saved to: $path");
      setState(() {
        isRecording = false;
        hasRecording = true;
        _finalRecordingDuration = _recordingDuration; // Save final time
        waveformValues = List.filled(30, 0); // Reset live waveform
      });
    } catch (e) {
      print("Error stopping recording: $e");
      setState(() {
        isRecording = false;
        waveformValues = List.filled(30, 0);
      });
    }
  }

  Future<void> deleteRecording() async {
    _mediumHaptic(); // Haptic feedback
    await _audioPlayer.stop(); // Stop playback if any
    if (_audioFilePath != null) {
      final file = File(_audioFilePath!);
      if (await file.exists()) {
        try {
          await file.delete();
          print("Deleted recording: $_audioFilePath");
        } catch (e) {
          print("Error deleting file: $e");
        }
      }
    }
    setState(() {
      hasRecording = false;
      _audioFilePath = null;
      isPlaying = false;
    });
  }

  Future<void> _onPlayPause() async {
    _lightHaptic(); // Haptic feedback
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        isPlaying = false;
      });
    } else {
      if (_audioFilePath != null) {
        await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
        setState(() {
          isPlaying = true;
        });
      }
    }
  }

  // --- Video Methods (REBUILT) ---

  Future<void> _initCameraController() async {
    if (_cameras.isEmpty) {
      await _initCameras(); // Ensure cameras are loaded
      if (_cameras.isEmpty) {
        print("No cameras found on device.");
        return;
      }
    }

    // Dispose old controller if exists
    await _cameraController?.dispose();

    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: true, // Record audio with video
    );

    try {
      await _cameraController!.initialize();
      // This setState is crucial to update the UI with the new preview
      if (mounted) setState(() {});
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  // This just enters "video mode"
  Future<void> enterVideoMode() async {
    _lightHaptic(); // Haptic feedback
    var cameraStatus = await Permission.camera.request();
    var micStatus = await Permission.microphone.request();

    if (cameraStatus != PermissionStatus.granted ||
        micStatus != PermissionStatus.granted) {
      print("Camera or Microphone permission denied");
      return;
    }

    setState(() {
      isVideoMode = true;
      hasVideo = false;
      isRecording = false;
      hasRecording = false;
      _recordingDuration = "00:00";
    });

    // Initialize the camera controller for the preview
    await _initCameraController();
  }

  Future<void> _switchCamera() async {
    _lightHaptic(); // Haptic feedback
    // Update index
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    // Re-initialize controller with new camera
    await _initCameraController();
  }
  

  Future<void> _beginActualRecording() async {
    _mediumHaptic(); // Haptic feedback
    if (!(_cameraController?.value.isInitialized ?? false)) {
      print("Camera controller not initialized");
      return;
    }

    // Start timer
    _stopwatch.reset();
    _stopwatch.start();
    _durationTimer?.cancel();
    _durationTimer =
        Timer.periodic(const Duration(milliseconds: 500), _updateDuration);

    // Start recording
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecordingVideo = true;
      });
    } catch (e) {
      print("Error starting video recording: $e");
    }
  }

  // --- THIS FUNCTION IS FIXED ---
  Future<void> stopVideoRecording() async {
    _mediumHaptic(); // Haptic feedback
    _stopwatch.stop();
    _durationTimer?.cancel();

    if (!(_cameraController?.value.isRecordingVideo ?? false)) {
      return;
    }

    // **FIX:** Set state immediately to hide the CameraPreview
    // This stops the UI from trying to access the disposed controller
    setState(() {
      _isRecordingVideo = false;
      isVideoMode = false; // Hide camera UI
      _finalRecordingDuration = _recordingDuration; // Save time
    });

    try {
      // 1. Stop recording and get file
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      _videoFilePath = videoFile.path;
      print("Video saved to: $_videoFilePath");

      // 2. Dispose camera controller (now safe to do)
      await _cameraController?.dispose();
      _cameraController = null;

      // 3. Set up video player
      _videoPlayerController = VideoPlayerController.file(File(_videoFilePath!));
      await _videoPlayerController!.initialize();

      // 4. Set final state to show the preview
      setState(() {
        hasVideo = true;
      });
    } catch (e) {
      print("Error stopping video recording: $e");
      // Reset all states on error
      setState(() {
        isVideoMode = false;
        _isRecordingVideo = false;
        hasVideo = false;
      });
      // Ensure controller is disposed even on error
      await _cameraController?.dispose();
      _cameraController = null;
    }
  }

  // --- THIS FUNCTION IS FIXED ---
  Future<void> cancelVideoRecording() async {
    _lightHaptic(); // Haptic feedback
    _stopwatch.stop();
    _durationTimer?.cancel();

    // **FIX:** Set state FIRST to hide the camera preview
    setState(() {
      isVideoMode = false;
      _isRecordingVideo = false;
    });
   

    // Now dispose the controller
    await _cameraController?.dispose();
    _cameraController = null;
  }

  Future<void> deleteVideo() async {
    _mediumHaptic(); // Haptic feedback
    await _videoPlayerController?.pause();
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;

    if (_videoFilePath != null) {
      final file = File(_videoFilePath!);
      if (await file.exists()) {
        try {
          await file.delete();
          print("Deleted video: $_videoFilePath");
        } catch (e) {
          print("Error deleting video file: $e");
        }
      }
    }
    setState(() {
      hasVideo = false;
      _videoFilePath = null;
      _isVideoPlaying = false;
    });
  }

  void _showVideoPreviewPopup() {
    _lightHaptic(); // Haptic feedback
    if (_videoPlayerController == null) return;

    // Start playing when dialog opens
    _videoPlayerController!.play();
    _videoPlayerController!.setLooping(true); // Loop the video
    _isVideoPlaying = true;

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to manage the play/pause state inside the dialog
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Listen to player state to update dialog
            _videoPlayerController!.addListener(() {
              final isCurrentlyPlaying =
                  _videoPlayerController!.value.isPlaying;
              if (_isVideoPlaying != isCurrentlyPlaying) {
                dialogSetState(() {
                  _isVideoPlaying = isCurrentlyPlaying;
                });
              }
            });

            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(16),
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoPlayerController!),
                    // Play/Pause Button Overlay
                    GestureDetector(
                      onTap: () async {
                        _lightHaptic(); // Haptic feedback
                        if (_videoPlayerController!.value.isPlaying) {
                          await _videoPlayerController!.pause();
                        } else {
                          await _videoPlayerController!.play();
                        }
                        dialogSetState(() {});
                      },
                      child: Container(
                        color: Colors.transparent, // Make overlay tap target
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity:
                                _videoPlayerController!.value.isPlaying ? 0.0 : 0.8,
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 80,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // When dialog is closed, stop and reset the video
      _videoPlayerController?.pause();
      _videoPlayerController?.seekTo(Duration.zero);
      _isVideoPlaying = false;
      setState(() {});
    });
  }

  // --- UI Builder Methods ---

 Widget _buildInputBlock() {
  final bool isSecondaryUiVisible =
      isRecording || isVideoMode || hasRecording || hasVideo;

  return Column(
    children: [
      // 1. TEXT FIELD
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: isSecondaryUiVisible ? 120 : 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _controller,
              maxLines: null,
              maxLength: 600,
              cursorColor: Colors.white,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: onTextChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "/ Start typing here",
                hintStyle: TextStyle(color: Colors.white38),
                counterText: "",
              ),
            ),
          ),
        ),
      ),

      // 2. AUDIO RECORDING UI
      if (isRecording) ...[
        const SizedBox(height: 24),
        const Text(
          "Recording Audio...",
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 12),

        Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              // Mic Icon
              Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: _purpleColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 24),
              ),

              const SizedBox(width: 12),

              // WAVEFORM stays expanded
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: waveformValues
                      .map((v) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.1),
                            child: Container(
                              width: 2.5,
                              height: (v * 5).clamp(2, 45),
                              decoration: BoxDecoration(
                                color: _purpleColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

              // TIMER + STOP stay compact ✅
              Flexible(
                flex: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _recordingDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: stopRecording,
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stop,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],

      // 3. VIDEO RECORDING UI
      if (isVideoMode) ...[
        const SizedBox(height: 16),
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isRecordingVideo ? Colors.redAccent : Colors.white24,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (_cameraController != null &&
                    _cameraController!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: 3 / 4,
                    child: CameraPreview(_cameraController!),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: cancelVideoRecording,
              child: const CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 24,
                child: Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 22),
            GestureDetector(
              onTap:
                  _isRecordingVideo ? stopVideoRecording : _beginActualRecording,
              child: CircleAvatar(
                backgroundColor: Colors.redAccent,
                radius: 34,
                child: Icon(
                  _isRecordingVideo ? Icons.stop : Icons.fiber_manual_record,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 22),
            GestureDetector(
              onTap: _isRecordingVideo ? null : _switchCamera,
              child: CircleAvatar(
                backgroundColor:
                    _isRecordingVideo ? Colors.white10 : Colors.white24,
                radius: 24,
                child: const Icon(Icons.flip_camera_ios,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
        if (_isRecordingVideo) ...[
          const SizedBox(height: 10),
          Text(
            "Recording... $_recordingDuration",
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ],
      ],

      if (hasRecording) ...[
        const SizedBox(height: 16),
        _buildAudioPreview(),
      ],

      if (hasVideo) ...[
        const SizedBox(height: 16),
        _buildVideoPreview(),
      ],
    ],
  );
}

  // --- PREVIEW WIDGETS ---

  Widget _buildAudioPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  children: [
                    const TextSpan(text: "Audio Recorded"),
                    TextSpan(
                      text: "  •  $_finalRecordingDuration",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: deleteRecording,
                child:
                    const Icon(Icons.delete_forever, color: Colors.red, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: _onPlayPause,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: const BoxDecoration(
                    color: _purpleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _previewWaveform // Use the static preview waveform
                      .map((v) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              width: 2.5,
                              height: (v * 5).clamp(2, 50), // Scale 0-10
                              decoration: BoxDecoration(
                                  color: _purpleColor,
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // VIDEO PREVIEW WIDGET 
  Widget _buildVideoPreview() {
    return GestureDetector(
      onTap: _showVideoPreviewPopup, // Open dialog on tap
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Thumbnail
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: (_videoPlayerController != null &&
                          _videoPlayerController!.value.isInitialized)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: VideoPlayer(_videoPlayerController!),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 24),
                              )
                            ],
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.videocam, color: Colors.white54),
                        ),
                ),
                const SizedBox(width: 16),
               
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    children: [
                      const TextSpan(text: "Video Recorded"),
                      TextSpan(
                        text: "\n$_finalRecordingDuration",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Delete Icon
            GestureDetector(
              onTap: deleteVideo,
              child: const Icon(Icons.delete_forever,
                  color: Colors.red, size: 28),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCameraFullScreen() {
  return Column(
    children: [
      // TOP CAMERA CONTROLS
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: cancelVideoRecording,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            const Spacer(),
            if (_isRecordingVideo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _recordingDuration,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            const Spacer(),
            IconButton(
              onPressed: _isRecordingVideo ? null : _switchCamera,
              icon: Icon(Icons.flip_camera_ios,
                  color: _isRecordingVideo ? Colors.white54 : Colors.white),
            ),
          ],
        ),
      ),

      // CAMERA PREVIEW
      Expanded(
        child: Container(
          color: Colors.black,
          width: double.infinity,
          child: (_cameraController != null &&
                  _cameraController!.value.isInitialized)
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),

      // RECORD BUTTON
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: GestureDetector(
            onTap: _isRecordingVideo ? stopVideoRecording : _beginActualRecording,
            child: Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecordingVideo ? Colors.redAccent : Colors.white,
              ),
              child: Icon(
                _isRecordingVideo ? Icons.stop : Icons.fiber_manual_record,
                color: _isRecordingVideo ? Colors.white : Colors.redAccent,
                size: 38,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

  // --- UPDATED BOTTOM BUTTONS ---
Widget _buildAudioButton() {
  // If a video is being recorded or already exists → disable audio
  final bool isDisabled = isVideoMode || hasVideo;

  // --- WHEN RECORDING AUDIO → SHOW CANCEL CIRCLE BUTTON ---
  if (isRecording) {
    return GestureDetector(
      onTap: cancelAudioRecording,
      child: Container(
        height: 58,
        width: 110,
        decoration: BoxDecoration(
          color: _purpleColor,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: _purpleColor.withOpacity(0.45),
              blurRadius: 18,
              spreadRadius: 3,
            )
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          "Cancel",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  //  DEFAULT MIC BUTTON 
  return GestureDetector(
    onTap: isDisabled ? null : startRecording,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.35 : 1,
      child: Container(
        height: 55,
        width: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
          color: Colors.transparent,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 22),
      ),
    ),
  );
}
  Widget _buildVideoButton() {
    // Disabled if audio is active or has been recorded
    final bool isDisabled = isRecording || hasRecording;

    return GestureDetector(
      // Now just enters video mode
      onTap: isDisabled ? null : enterVideoMode,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          height: 55,
          width: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(
            Icons.videocam,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      // Disable if currently in video mode
      onTap: (canProceed && !isVideoMode)
    ? () async {
        _lightHaptic();

        final box = Hive.box('host_data');

        // Save text 
        box.put('host_reason_text', _controller.text.trim());

        // Save audio if exists
        if (hasRecording && _audioFilePath != null) {
          box.put('host_reason_audio', _audioFilePath);
        } else {
          box.delete('host_reason_audio');
        }

        //  Save video if exists
        if (hasVideo && _videoFilePath != null) {
          box.put('host_reason_video', _videoFilePath);
        } else {
          box.delete('host_reason_video');
        }

        print("Saved:");
        print("Text: ${box.get('host_reason_text')}");
        print("Audio: ${box.get('host_reason_audio')}");
        print("Video: ${box.get('host_reason_video')}");

        //  Snackbar confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Saved successfully",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.black.withOpacity(0.65),
            behavior: SnackBarBehavior.floating,
            elevation: 0,
            margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
  
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: canProceed && !isVideoMode ? 1 : 0.35,
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white
                  .withOpacity(canProceed && !isVideoMode ? 0.9 : 0.4),
              width: 1.4,
            ),
            color: Colors.white
                .withOpacity(canProceed && !isVideoMode ? 0.15 : 0.06),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Next",
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(canProceed && !isVideoMode ? 1 : 0.6),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.white
                      .withOpacity(canProceed && !isVideoMode ? 1 : 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  // THIS IS THE CORRECTED BUILD METHOD 
  @override
Widget build(BuildContext context) {
  // When in video mode → show full-screen camera UI
  if (isVideoMode) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildCameraFullScreen(),
      ),
    );
  }

  // Your existing "normal" UI
  final bool showBottomBar = !isVideoMode;

  return Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    _lightHaptic();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
                SquigglyProgressBar(step: widget.step),
                IconButton(
                  onPressed: () {
                    _lightHaptic();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ],
            ),

            // MAIN CONTENT
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 100),
                    const Text("02", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text(
                      "Why do you want to host with us?",
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tell us about your intent and what motivates you to create experiences.",
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 22),

                    _buildInputBlock(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // BOTTOM ACTIONS
            if (showBottomBar)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Row(
                  children: [
                    if (!hasRecording && !hasVideo) _buildAudioButton(),
                    if (!hasRecording && !hasVideo) const SizedBox(width: 14),
                    if (!hasVideo && !hasRecording) _buildVideoButton(),
                    if (!hasRecording && !hasVideo) const SizedBox(width: 14),
                    Expanded(child: _buildNextButton()),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}