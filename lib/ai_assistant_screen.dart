import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdify/ad_service.dart';
import 'package:pdify/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/services/voice_service.dart';
import 'package:pdify/services/export_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? pdfId;
  final String? fileName;

  const AiAssistantScreen({super.key, this.pdfId, this.fileName});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _deepBg = Color(0xFF0B1120);
  static const _cardBg = Color(0xFF131B2E);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);
  static const _emerald = Color(0xFF10B981);

  final ScrollController _scrollController = ScrollController();

  void _sendMessage(String? pdfId) {
    if (pdfId == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    context.read<ChatProvider>().sendMessage(pdfId, text);
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
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final pdfId = widget.pdfId ?? chatProvider.activePdfId;
    final fileName = widget.fileName ?? chatProvider.activeFileName;

    return Scaffold(
      backgroundColor: _deepBg,
      body: Stack(
        children: [
          // ── Mesh blobs ──
          Positioned(top: -120, right: -100, child: _meshBlob(_accentBlue, 380)),
          Positioned(bottom: 250, left: -120, child: _meshBlob(const Color(0xFF1E1B4B), 450)),
          Positioned(bottom: -80, right: -60, child: _meshBlob(_accentCyan, 260)),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: _deepBg.withOpacity(0.7)),
            ),
          ),
          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: pdfId == null 
                  ? _buildNoContextView()
                  : Column(
                      children: [
                        _buildAppBar(pdfId, fileName),
                        _buildActiveContext(fileName ?? "Document"),
                        Expanded(child: _buildMessageList(pdfId)),
                        _buildInputArea(pdfId),
                        _buildDisclaimer(),
                      ],
                    ),
            ),
          ),

        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAppBar(String pdfId, String? fileName) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final navProvider = context.read<NavigationProvider>();
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                navProvider.setIndex(0); // Go back to Summarizer
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          // Logo
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Chat',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Export Chat
          GestureDetector(
            onTap: () {
              final messages = context.read<ChatProvider>().getMessages(pdfId);
              ExportService.exportChatToPdf(
                context: context,
                fileName: fileName ?? "Document",
                messages: messages,
              );
            },
            child: Row(
              children: [
                Icon(Icons.ios_share_rounded,
                    color: Colors.white.withOpacity(0.7), size: 18),
                const SizedBox(width: 5),
                Text(
                  'Export Chat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => context.read<ChatProvider>().clearChat(pdfId),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 22),
          ),
        ],
      ),
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
              "Select a document from the Dashboard or Tools to start an AI conversation with your files.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: "Browse Documents",
              onPressed: () {
                context.read<NavigationProvider>().setIndex(1); // Go to Documents tab
              },
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIVE CONTEXT BANNER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildActiveContext(String fileName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          // Main banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                // File icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Color(0xFF60A5FA), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE CONTEXT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.35), size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MESSAGE LIST
  // ══════════════════════════════════════════════════════════════════
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
          physics: const BouncingScrollPhysics(),
          itemCount: messages.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return _buildLoadingBubble();
            }
            final msg = messages[index];
            return msg.role == 'user' ? _buildUserBubble(msg) : _buildAiBubble(msg);
          },
        );
      },
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _emerald.withOpacity(0.1)),
            child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _emerald))),
          ),
        ],
      ),
    );
  }

  // ── AI message bubble ──
  Widget _buildAiBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _emerald.withOpacity(0.15),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: _emerald, size: 18),
          ),
          const SizedBox(width: 10),
          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: MarkdownBody(
                    data: msg.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 15, color: Colors.white, height: 1.55),
                      strong: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── User message bubble ──
  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentBlue.withOpacity(0.25),
                    _accentBlue.withOpacity(0.12),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border:
                    Border.all(color: _accentBlue.withOpacity(0.15)),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // User avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentBlue.withOpacity(0.2),
              border: Border.all(
                  color: _accentBlue.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(Icons.person_rounded,
                color: _accentBlue.withOpacity(0.7), size: 18),
          ),
        ],
      ),
    );
  }

  // ── Simple bold markdown parser ──
  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w400,
          color: Colors.white.withOpacity(i.isOdd ? 1.0 : 0.8),
        ),
      ));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 15, height: 1.55),
        children: spans,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // INPUT AREA
  // ══════════════════════════════════════════════════════════════════
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
            // Voice button
            Consumer<VoiceService>(
              builder: (context, voiceService, _) {
                return IconButton(
                  onPressed: () {
                    if (voiceService.isListening) {
                      voiceService.stopListening();
                    } else {
                      voiceService.onResult = (text) {
                        _controller.text = text;
                        _sendMessage(pdfId);
                      };
                      voiceService.startListening();
                    }
                  },
                  icon: Icon(voiceService.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: voiceService.isListening ? Colors.redAccent : Colors.white54, size: 22),
                );
              }
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask anything about the document...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(pdfId),
              ),
            ),
            // Send button
            GestureDetector(
              onTap: () => _sendMessage(pdfId),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      const LinearGradient(colors: [_accentBlue, _accentCyan]),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DISCLAIMER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Text(
        'PDify AI can make mistakes. Verify critical information.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 11,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _deepBg.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.dashboard_rounded, 'Dashboard', false),
                _navItem(Icons.description_rounded, 'Documents', false),
                _navItem(Icons.chat_bubble_rounded, 'Chat', true),
                _navItem(Icons.build_rounded, 'Tools', false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    final color = isActive ? _accentBlue : Colors.white.withOpacity(0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: color,
            size: 22,
            shadows: isActive
                ? [
                    Shadow(
                        color: _accentBlue.withOpacity(0.5),
                        blurRadius: 12)
                  ]
                : null),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MESH BLOB
  // ══════════════════════════════════════════════════════════════════
  Widget _meshBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

// ── Chat message model ──
class _ChatMsg {
  final bool isUser;
  final String text;
  final List<String>? suggestions;

  _ChatMsg({
    required this.isUser,
    required this.text,
    this.suggestions,
  });
}
