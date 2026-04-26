import 'package:flutter/material.dart';
import 'package:pdify/screens/exam_notes_screen.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/services/ad_service.dart';
import 'package:pdify/services/export_service.dart';
import 'package:pdify/providers/bookmark_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdify/providers/summary_provider.dart';
import 'package:pdify/repositories/exam_notes_repository.dart';
import 'package:pdify/screens/ai_chat_screen.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/providers/navigation_provider.dart';

class ExamNoteTile extends StatefulWidget {
  final String noteId;
  final String topics;
  final String notesMarkdown;
  final List<Map<String, dynamic>> questions;
  final DateTime createdAt;
  final VoidCallback onDelete;

  const ExamNoteTile({
    super.key,
    required this.noteId,
    required this.topics,
    required this.notesMarkdown,
    required this.questions,
    required this.createdAt,
    required this.onDelete,
  });

  @override
  State<ExamNoteTile> createState() => _ExamNoteTileState();
}

class _ExamNoteTileState extends State<ExamNoteTile> {
  bool _isExpanded = false;

  static const _emerald = Color(0xFF10B981);
  static const _accentBlue = Color(0xFF3B82F6);

  void _showAdAndNavigate(BuildContext context) async {
    final summaryProvider = context.read<SummaryProvider>();
    final adService = AdService();
    final isUnlocked = summaryProvider.isUnlocked(widget.noteId);

    if (!isUnlocked) {
      // FIRST TIME: Show Rewarded Ad
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlocking notes with a rewarded ad...')),
      );

      final success = await adService.showRewardedAd(
        onRewarded: () async {
          await summaryProvider.unlock(widget.noteId);
          if (context.mounted) {
            _navigateToNotes(context);
          }
        },
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not ready. Please try again.')),
        );
      }
    } else {
      // SUBSEQUENT TIMES: Show Interstitial Ad
      await adService.showInterstitialAd();
      if (context.mounted) {
        _navigateToNotes(context);
      }
    }
  }

  void _navigateToNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamNotesScreen(
          topics: widget.topics,
          notesMarkdown: widget.notesMarkdown,
          questions: widget.questions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, h:mm a').format(widget.createdAt);
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final isBookmarked = bookmarkProvider.isBookmarked(widget.noteId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        child: ExpansionTileTheme(
          data: ExpansionTileThemeData(
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: theme.brightness == Brightness.dark
                ? Colors.white54
                : Colors.black54,
          ),
          child: ExpansionTile(
            onExpansionChanged: (expanded) =>
                setState(() => _isExpanded = expanded),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _emerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _emerald,
                size: 24,
              ),
            ),
            title: Text(
              widget.topics,
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                const Text(
                  'READY',
                  style: TextStyle(
                    color: _emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: isBookmarked ? _accentBlue : Colors.white24,
                    size: 20,
                  ),
                  onPressed: () =>
                      bookmarkProvider.toggleBookmark(widget.noteId),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, size: 20),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionIconBtn(
                      Icons.menu_book_rounded,
                      "Full Notes",
                      () => _showAdAndNavigate(context),
                      color: _accentBlue,
                    ),
                    _actionIconBtn(
                      Icons.ios_share_rounded,
                      "Export",
                      () => ExportService.exportExamNotesToPdf(
                        context: context,
                        topics: widget.topics,
                        notesMarkdown: widget.notesMarkdown,
                        questions: widget.questions,
                      ),
                    ),
                     _actionIconBtn(
                      Icons.chat_bubble_outline_rounded,
                      "Chat",
                      () {
                        final chatProvider = context.read<ChatProvider>();
                        chatProvider.setActiveContext(widget.noteId, widget.topics);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AiChatScreen(
                              pdfId: widget.noteId,
                              fileName: widget.topics,
                              customContext: widget.notesMarkdown,
                            ),
                          ),
                        );
                      },
                      color: const Color(0xFF00D9FF),
                    ),
                    _actionIconBtn(
                      Icons.drive_file_rename_outline_rounded,
                      "Rename",
                      () => _showRenameDialog(context),
                    ),
                    _actionIconBtn(
                      Icons.delete_outline_rounded,
                      "Delete",
                      widget.onDelete,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: widget.topics);
    final theme = Theme.of(context);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: const InputDecoration(hintText: 'Enter new topic name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == widget.topics) return;

    try {
      await ExamNotesRepository().renameExamNote(widget.noteId, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note renamed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    }
  }

  Widget _actionIconBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white54,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
