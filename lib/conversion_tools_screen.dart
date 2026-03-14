import 'dart:ui';
import 'package:flutter/material.dart';

class ConversionToolsScreen extends StatefulWidget {
  const ConversionToolsScreen({super.key});

  @override
  State<ConversionToolsScreen> createState() => _ConversionToolsScreenState();
}

class _ConversionToolsScreenState extends State<ConversionToolsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
    _animController.dispose();
    super.dispose();
  }

  static const _deepBg = Color(0xFF0B1120);
  static const _cardBg = Color(0xFF131B2E);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepBg,
      body: Stack(
        children: [
          // ── Mesh blobs ──
          Positioned(top: -120, right: -100, child: _meshBlob(_accentBlue, 400)),
          Positioned(bottom: 250, left: -120, child: _meshBlob(const Color(0xFF1E1B4B), 500)),
          Positioned(bottom: -80, right: -60, child: _meshBlob(_accentCyan, 280)),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: _deepBg.withOpacity(0.65)),
            ),
          ),
          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar()),
                  SliverToBoxAdapter(child: _buildHeroSection()),
                  // ── Conversion tool cards ──
                  SliverToBoxAdapter(
                    child: _buildExpandedToolCard(
                      icon: Icons.description_rounded,
                      iconBgColor: const Color(0xFF3B82F6).withOpacity(0.15),
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Word to PDF',
                      subtitle: 'Convert .docx to high-fidelity PDF documents.',
                      showTryNow: true,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildExpandedToolCard(
                      icon: Icons.article_rounded,
                      iconBgColor: const Color(0xFF7C3AED).withOpacity(0.15),
                      iconColor: const Color(0xFFA78BFA),
                      title: 'PDF to Word',
                      subtitle: 'Extract text and layout from PDF to editable Word.',
                      showTryNow: true,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCompactToolCard(
                      icon: Icons.slideshow_rounded,
                      iconBgColor: const Color(0xFF3B82F6).withOpacity(0.15),
                      iconColor: const Color(0xFF60A5FA),
                      title: 'PPT to PDF',
                      subtitle: 'Preserve slide layouts.',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCompactToolCard(
                      icon: Icons.slideshow_rounded,
                      iconBgColor: const Color(0xFF7C3AED).withOpacity(0.15),
                      iconColor: const Color(0xFFA78BFA),
                      title: 'PDF to PPT',
                      subtitle: 'Editable presentations.',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCompressCard(),
                  ),
                  // ── Recent Conversions ──
                  SliverToBoxAdapter(child: _buildRecentConversionsHeader()),
                  SliverToBoxAdapter(
                    child: _buildRecentItem(
                      title: 'Quarterly_Report_...',
                      time: '2h ago',
                      detail: 'Word to PDF • 2.4 MB',
                      dotColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildRecentItem(
                      title: 'Client_Presentatio...',
                      time: '5h ago',
                      detail: 'PDF to PPT • 15.8 MB',
                      dotColor: const Color(0xFFA78BFA),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildRecentItem(
                      title: 'NDA_Draft_v2...',
                      time: 'Yesterday',
                      detail: 'PDF to Word • 840 KB',
                      dotColor: const Color(0xFF34D399),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 4),
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
              const Text(
                'PDify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF06B6D4), _accentBlue]),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // HERO SECTION
  // ══════════════════════════════════════════════════════════════════
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCUMENT WORKFLOW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: const Color(0xFF60A5FA).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Powerful tools for\nevery file.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Convert, compress, and organize your documents with our high-performance glass-engine.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // EXPANDED TOOL CARD (Word to PDF, PDF to Word)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildExpandedToolCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool showTryNow,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (showTryNow) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Try Now',
                    style: TextStyle(
                      color: _accentBlue.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: _accentBlue.withOpacity(0.9), size: 16),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // COMPACT TOOL CARD (PPT to PDF, PDF to PPT)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCompactToolCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // COMPRESS PDF CARD
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCompressCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.compress_rounded,
                  color: Colors.white.withOpacity(0.7), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compress PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reduce size without quality loss.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3), size: 22),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // RECENT CONVERSIONS HEADER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildRecentConversionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          const Text(
            'Recent Conversions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Text(
            'View All',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // RECENT CONVERSION ITEM
  // ══════════════════════════════════════════════════════════════════
  Widget _buildRecentItem({
    required String title,
    required String time,
    required String detail,
    required Color dotColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            // Dot indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.description_rounded, color: dotColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download icon
            Icon(Icons.download_rounded,
                color: Colors.white.withOpacity(0.3), size: 20),
          ],
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
                _navItem(Icons.chat_bubble_rounded, 'Chat', false),
                _navItem(Icons.build_rounded, 'Tools', true),
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
        Icon(icon, color: color, size: 22,
          shadows: isActive
              ? [Shadow(color: _accentBlue.withOpacity(0.5), blurRadius: 12)]
              : null,
        ),
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
