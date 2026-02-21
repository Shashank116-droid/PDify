import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

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

  List<ChatMessage> getMessages(String pdfId) {
    return _messages[pdfId] ?? [];
  }

  bool isLoading(String pdfId) {
    return _isLoading[pdfId] ?? false;
  }

  Future<void> sendMessage(String pdfId, String text) async {
    if (text.trim().isEmpty) return;

    // Initialize list if needed
    if (!_messages.containsKey(pdfId)) {
      _messages[pdfId] = [];
    }

    // Add user message
    _messages[pdfId]!.add(ChatMessage(role: 'user', text: text.trim()));
    _isLoading[pdfId] = true;
    notifyListeners();

    try {
      // Get history (excluding the very message we just added)
      final history = _messages[pdfId]!
          .take(_messages[pdfId]!.length - 1)
          .map((m) => m.toJson())
          .toList();

      final result = await FirebaseFunctions.instance
          .httpsCallable('chatWithPdf')
          .call({'pdfId': pdfId, 'message': text.trim(), 'history': history});

      final reply = result.data['reply'] as String?;

      if (reply != null && reply.isNotEmpty) {
        _messages[pdfId]!.add(ChatMessage(role: 'model', text: reply));
      } else {
        _messages[pdfId]!.add(
          ChatMessage(
            role: 'model',
            text: 'Sorry, I received an empty response.',
          ),
        );
      }
    } catch (e) {
      _messages[pdfId]!.add(
        ChatMessage(role: 'model', text: 'Error: ${e.toString()}'),
      );
    } finally {
      _isLoading[pdfId] = false;
      notifyListeners();
    }
  }

  void clearChat(String pdfId) {
    _messages.remove(pdfId);
    notifyListeners();
  }
}
