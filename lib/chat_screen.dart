import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/services/voice_service.dart';
import 'package:pdify/services/export_service.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';

class ChatScreen extends StatefulWidget {
  final String pdfId;
  final String fileName;

  const ChatScreen({super.key, required this.pdfId, required this.fileName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    context.read<ChatProvider>().sendMessage(widget.pdfId, text);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MeshBackgroundScaffold(
      showAppBar: false,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Assistant",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.fileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(
                              0.7,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    onPressed: () {
                      final messages = context.read<ChatProvider>().getMessages(
                        widget.pdfId,
                      );
                      ExportService.exportChatToPdf(
                        context: context,
                        fileName: widget.fileName,
                        messages: messages,
                      );
                    },
                    tooltip: 'Export Chat',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error.withOpacity(0.8),
                    ),
                    onPressed: () {
                      context.read<ChatProvider>().clearChat(widget.pdfId);
                    },
                    tooltip: 'Clear Chat',
                  ),
                ],
              ),
            ),

            // Messages Area
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final messages = chatProvider.getMessages(widget.pdfId);
                  final isLoading = chatProvider.isLoading(widget.pdfId);

                  if (messages.isEmpty && !isLoading) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: theme.colorScheme.primary.withOpacity(
                                0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Ask Questions",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildSuggestionChip(
                                  "Summarize this document",
                                  theme,
                                ),
                                _buildSuggestionChip(
                                  "What are the key takeaways?",
                                  theme,
                                ),
                                _buildSuggestionChip(
                                  "Explain the main concept",
                                  theme,
                                ),
                                _buildSuggestionChip(
                                  "Are there any statistics?",
                                  theme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildLoadingBubble(theme);
                      }
                      return _buildMessageBubble(messages[index], theme);
                    },
                  );
                },
              ),
            ),

            // Input Area
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Consumer<VoiceService>(
                builder: (context, voiceService, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Listening indicator
                      if (voiceService.isListening)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  voiceService.lastRecognizedWords.isEmpty
                                      ? 'Listening...'
                                      : voiceService.lastRecognizedWords,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.error,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // Mic button
                          Material(
                            color: voiceService.isListening
                                ? theme.colorScheme.error
                                : (isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.05)),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () {
                                if (voiceService.isListening) {
                                  voiceService.stopListening();
                                } else {
                                  voiceService.onResult = (text) {
                                    _controller.text = text;
                                    _sendMessage();
                                  };
                                  voiceService.startListening();
                                }
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  voiceService.isListening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: voiceService.isListening
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                style: theme.textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  hintText: "Ask about this PDF...",
                                  hintStyle: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.5),
                                      ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Consumer<ChatProvider>(
                            builder: (context, chatProvider, child) {
                              final isLoading = chatProvider.isLoading(
                                widget.pdfId,
                              );
                              return Material(
                                color: isLoading
                                    ? theme.colorScheme.primary.withOpacity(
                                        0.5,
                                      )
                                    : theme.colorScheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: isLoading ? null : _sendMessage,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.role == 'user';
    final isDark = theme.brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(24).copyWith(
      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(24),
      bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(24),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary.withOpacity(0.8)
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.7)),
                borderRadius: borderRadius,
          boxShadow: !isUser
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: !isUser
              ? Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                )
              : null,
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.5,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyLarge?.color,
                        height: 1.5,
                      ),
                      strong: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      code: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor: isDark
                            ? Colors.black12
                            : Colors.grey.shade200,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : Colors.deepOrange,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      listBullet: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Listen button (TTS)
                        Consumer<VoiceService>(
                          builder: (context, voiceService, _) {
                            return IconButton(
                              icon: Icon(
                                voiceService.isSpeaking
                                    ? Icons.stop_circle_rounded
                                    : Icons.volume_up_rounded,
                                size: 16,
                              ),
                              onPressed: () {
                                if (voiceService.isSpeaking) {
                                  voiceService.stopSpeaking();
                                } else {
                                  voiceService.speak(message.text);
                                }
                              },
                              color: voiceService.isSpeaking
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white54 : Colors.black54),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: voiceService.isSpeaking
                                  ? 'Stop'
                                  : 'Listen',
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // Copy button
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: message.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Copied to clipboard',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: theme.colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          color: isDark ? Colors.white54 : Colors.black54,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(
            20,
          ).copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Thinking...",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(
                  0.7,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text, ThemeData theme) {
    return ActionChip(
      label: Text(text),
      labelStyle: const TextStyle(fontSize: 13),
      backgroundColor: theme.brightness == Brightness.dark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }
}
