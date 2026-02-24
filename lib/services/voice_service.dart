import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String _lastRecognizedWords = '';

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get lastRecognizedWords => _lastRecognizedWords;

  // Callback when final result is recognized
  void Function(String)? onResult;

  VoiceService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  // --- Speech-to-Text ---
  Future<bool> initSpeech() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('STT Error: ${error.errorMsg}');
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        debugPrint('STT Status: $status');
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          notifyListeners();
        }
      },
    );
    return _isInitialized;
  }

  Future<void> startListening() async {
    final available = await initSpeech();
    if (!available) return;

    // Stop TTS if it's speaking
    if (_isSpeaking) await stopSpeaking();

    _isListening = true;
    _lastRecognizedWords = '';
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        _lastRecognizedWords = result.recognizedWords;
        notifyListeners();
        if (result.finalResult && onResult != null) {
          onResult!(_lastRecognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  // --- Text-to-Speech ---
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Stop listening if active
    if (_isListening) await stopListening();

    // Clean markdown for natural speech
    final cleanText = _cleanForSpeech(text);

    _isSpeaking = true;
    notifyListeners();

    await _tts.speak(cleanText);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'`(.+?)`'), r'$1') // Inline code
        .replaceAll(RegExp(r'```[\s\S]*?```'), '') // Code blocks
        .replaceAll(RegExp(r'^#+\s', multiLine: true), '') // Headers
        .replaceAll(RegExp(r'^[-*]\s', multiLine: true), '') // List items
        .replaceAll(RegExp(r'\n{2,}'), '\n') // Double newlines
        .trim();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
