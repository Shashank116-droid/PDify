import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/services/voice_service.dart';
import 'package:pdify/services/export_service.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';
import 'package:pdify/widgets/premium_header.dart';
import 'package:pdify/providers/navigation_provider.dart';
import 'package:pdify/widgets/primary_button.dart';

class AiChatScreen extends StatefulWidget {
  final String? pdfId;
  final String? fileName;
  final String? customContext;

  const AiChatScreen({super.key, this.pdfId, this.fileName, this.customContext});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);
  static const _emerald = Color(0xFF10B981);
  static const _cardBg = Color(0xFF131B2E);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String? id) {
    if (id == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    context.read<ChatProvider>().sendMessage(id, text, customContext: widget.customContext);
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
    final chatProvider = context.watch<ChatProvider>();
    final pdfId = widget.pdfId ?? chatProvider.activePdfId;
    final fileName = widget.fileName ?? chatProvider.activeFileName;

    return MeshBackgroundScaffold(
      showAppBar: false,
      body: pdfId == null ? _buildNoContextView() : Column(
        children: [
          _buildAppBar(pdfId, fileName),
          _buildActiveContextBanner(fileName ?? "Document"),
          Expanded(child: _buildMessageList(pdfId)),
          _buildInputArea(pdfId),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildAppBar(String pdfId, String? fileName) {
    return PremiumHeader(
      title: 'Chat',
      onBackTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.read<NavigationProvider>().setIndex(0);
        }
      },
      showBack: true,
      showProfile: false,
      actions: [
        IconButton(
          onPressed: () {
            final messages = context.read<ChatProvider>().getMessages(pdfId);
            ExportService.exportChatToPdf(
              context: context,
              fileName: fileName ?? "Document",
              messages: messages,
            );
          },
          icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
          tooltip: 'Export Chat',
        ),
        IconButton(
          onPressed: () => context.read<ChatProvider>().clearChat(pdfId),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 22),
          tooltip: 'Clear Chat',
        ),
      ],
    );
  }

  Widget _buildNoContextView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: _accentBlue),
            ),
            const SizedBox(height: 32),
            const Text(
              "No Active Chat",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              "Select a document from the Dashboard or Documents to start an AI conversation.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: "Browse Documents",
              onPressed: () => context.read<NavigationProvider>().setIndex(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveContextBanner(String fileName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.description_rounded, color: _accentBlue.withOpacity(0.7), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(String pdfId) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messages = chatProvider.getMessages(pdfId);
        final isLoading = chatProvider.isLoading(pdfId);

        if (messages.isEmpty && !isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text("Ask anything about this document", style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: messages.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) return _buildLoadingBubble();
            final msg = messages[index];
            return _buildMessageBubble(msg);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(Icons.auto_awesome_rounded, _emerald),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? _accentBlue.withOpacity(0.2) : _cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 20 : 4),
                  topRight: Radius.circular(isUser ? 4 : 20),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
                border: Border.all(color: isUser ? _accentBlue.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
                      strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _msgAction(Icons.volume_up_rounded, () => context.read<VoiceService>().speak(message.text)),
                        const SizedBox(width: 16),
                        _msgAction(Icons.copy_rounded, () => Clipboard.setData(ClipboardData(text: message.text))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _buildAvatar(Icons.person_rounded, _accentBlue),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _msgAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: Colors.white38),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _buildAvatar(Icons.auto_awesome_rounded, _emerald),
          const SizedBox(width: 10),
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _emerald)),
        ],
      ),
    );
  }

  Widget _buildInputArea(String pdfId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Consumer<VoiceService>(builder: (context, vs, _) {
              return IconButton(
                icon: Icon(vs.isListening ? Icons.stop_rounded : Icons.mic_rounded, color: vs.isListening ? Colors.redAccent : Colors.white54, size: 22),
                onPressed: () {
                  if (vs.isListening) vs.stopListening();
                  else {
                    vs.onResult = (text) { _controller.text = text; _sendMessage(pdfId); };
                    vs.startListening();
                  }
                },
              );
            }),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(hintText: 'Ask anything...', hintStyle: TextStyle(color: Colors.white30, fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                onSubmitted: (_) => _sendMessage(pdfId),
              ),
            ),
            GestureDetector(
              onTap: () => _sendMessage(pdfId),
              child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_accentBlue, _accentCyan])), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('AI can make mistakes. Verify critical info.', style: TextStyle(color: Colors.white24, fontSize: 10)),
    );
  }
}
