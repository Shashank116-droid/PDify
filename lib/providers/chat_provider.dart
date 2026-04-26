import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:pdify/services/gemini_ocr_service.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;

  ChatMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class ChatProvider extends ChangeNotifier {
  // Map of pdfId to a list of messages
  final Map<String, List<ChatMessage>> _messages = {};

  // Map of pdfId to loading state
  final Map<String, bool> _isLoading = {};

  String? _activePdfId;
  String? _activeFileName;

  String? get activePdfId => _activePdfId;
  String? get activeFileName => _activeFileName;

  void setActiveContext(String? pdfId, String? fileName) {
    _activePdfId = pdfId;
    _activeFileName = fileName;
    notifyListeners();
  }

  List<ChatMessage> getMessages(String pdfId) {
    return _messages[pdfId] ?? [];
  }

  bool isLoading(String pdfId) {
    return _isLoading[pdfId] ?? false;
  }

  Future<void> sendMessage(String id, String text, {String? customContext}) async {
    if (text.trim().isEmpty) return;

    // Initialize list if needed
    if (!_messages.containsKey(id)) {
      _messages[id] = [];
    }

    // Add user message
    _messages[id]!.add(ChatMessage(role: 'user', text: text.trim()));
    _isLoading[id] = true;
    notifyListeners();

    try {
      final history = _messages[id]!
          .take(_messages[id]!.length - 1)
          .map((m) => m.toJson())
          .toList();

      String reply;

      // If it's a local PDF or a Note (customContext provided), use local Gemini service
      if (id.startsWith('local_') || customContext != null) {
        final gemini = GeminiOcrService();
        // For local PDFs, we'd ideally fetch the text from local storage here.
        // For now, if customContext is provided (Notes), use it.
        reply = await gemini.chatWithContext(
          context: customContext ?? "No context provided.",
          message: text.trim(),
          history: history,
        );
      } else {
        // Use Cloud Function for legacy/cloud PDFs
        final result = await FirebaseFunctions.instance
            .httpsCallable('chatWithPdf')
            .call({'pdfId': id, 'message': text.trim(), 'history': history});
        reply = result.data['reply'] as String? ?? 'No response from AI.';
      }

      _messages[id]!.add(ChatMessage(role: 'model', text: reply));
    } catch (e) {
      _messages[id]!.add(
        ChatMessage(role: 'model', text: 'Error: ${e.toString()}'),
      );
    } finally {
      _isLoading[id] = false;
      notifyListeners();
    }
  }

  void clearChat(String pdfId) {
    _messages.remove(pdfId);
    notifyListeners();
  }
}
