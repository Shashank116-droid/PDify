import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
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

  // ── Color palette ─────────────────────────────────────────────
  static const _deepBg = Color(0xFF0B1120);
  static const _cardBg = Color(0xFF131B2E);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);
  static const _emerald = Color(0xFF10B981);
  static const _amber = Color(0xFFFBBF24);
  static const _slate = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepBg,
      body: Stack(
        children: [
          // ── Mesh gradient blobs ──
          Positioned(top: -120, right: -100, child: _meshBlob(_accentBlue, 400)),
          Positioned(bottom: 250, left: -120, child: _meshBlob(const Color(0xFF1E1B4B), 500)),
          Positioned(bottom: -80, right: -60, child: _meshBlob(_accentCyan, 280)),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: _deepBg.withOpacity(0.65)),
            ),
          ),
          // ── Scrollable content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(child: _buildAppBar()),
                  // Search Bar
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  // Recent Documents Header
                  SliverToBoxAdapter(child: _buildSectionHeader('YOUR TIMELINE', 'Recent Documents', 'View All')),
                  // Document Cards
                  SliverToBoxAdapter(child: _buildDocumentCard(
                    icon: Icons.description_rounded,
                    iconBg: const Color(0xFF3B82F6).withOpacity(0.15),
                    iconColor: const Color(0xFF60A5FA),
                    title: 'Q4 Financial Report.pdf',
                    subtitle: 'Modified 2 hours ago',
                    badge: 'COMPLETED',
                    badgeColor: _emerald,
                    trailing: _buildCollaborators(),
                  )),
                  SliverToBoxAdapter(child: _buildDocumentCard(
                    icon: Icons.description_rounded,
                    iconBg: const Color(0xFF7C3AED).withOpacity(0.15),
                    iconColor: const Color(0xFFA78BFA),
                    title: 'Thesis Draft v2.pdf',
                    subtitle: 'Analyzing content...',
                    badge: 'PROCESSING',
                    badgeColor: _amber,
                    trailing: _buildProgressBar(),
                  )),
                  SliverToBoxAdapter(child: _buildDocumentCard(
                    icon: Icons.description_rounded,
                    iconBg: const Color(0xFF64748B).withOpacity(0.15),
                    iconColor: _slate,
                    title: 'Rental Agreement.pdf',
                    subtitle: 'Modified Aug 12, 2023',
                    badge: 'ARCHIVED',
                    badgeColor: _slate,
                    trailing: _buildPrivateAccess(),
                  )),
                  // Smart Folders Header
                  SliverToBoxAdapter(child: _buildSectionHeader('ORGANIZATION', 'Smart Folders', null)),
                  // Folder Cards
                  SliverToBoxAdapter(child: _buildFolderCard(
                    icon: Icons.folder_rounded,
                    iconColor: const Color(0xFF60A5FA),
                    gradientColors: [const Color(0xFF1E3A5F).withOpacity(0.6), _cardBg],
                    title: 'University',
                    subtitle: '42 files • 1.2 GB',
                    showMenu: true,
                  )),
                  SliverToBoxAdapter(child: _buildFolderCard(
                    icon: Icons.work_rounded,
                    iconColor: const Color(0xFFA78BFA),
                    gradientColors: [const Color(0xFF2D1B4E).withOpacity(0.6), _cardBg],
                    title: 'Work',
                    subtitle: '128 files',
                    showMenu: false,
                  )),
                  SliverToBoxAdapter(child: _buildFolderCard(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF34D399),
                    gradientColors: [const Color(0xFF0F3D2E).withOpacity(0.6), _cardBg],
                    title: 'Personal',
                    subtitle: '15 files',
                    showMenu: false,
                  )),
                  // Create New Folder
                  SliverToBoxAdapter(child: _buildCreateFolderButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Bottom Navigation ──
      bottomNavigationBar: _buildBottomNav(),
      // ── FAB ──
      floatingActionButton: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_accentBlue, _accentCyan]),
          boxShadow: [
            BoxShadow(
              color: _accentBlue.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
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
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
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
          // Profile avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
            const SizedBox(width: 10),
            Text(
              'Search your library...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String label, String title, String? action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: const Color(0xFF60A5FA).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (action != null) ...[
                const Spacer(),
                Text(
                  action,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DOCUMENT CARD
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDocumentCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Widget trailing,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const Spacer(),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            trailing,
          ],
        ),
      ),
    );
  }

  // ── Collaborators row ──
  Widget _buildCollaborators() {
    return Row(
      children: [
        // Small avatar stack
        SizedBox(
          width: 52,
          height: 20,
          child: Stack(
            children: [
              _miniAvatar(0, const Color(0xFF3B82F6)),
              _miniAvatar(14, const Color(0xFFEC4899)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '+2 collaborators',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _miniAvatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: _cardBg, width: 2),
        ),
      ),
    );
  }

  // ── Progress bar ──
  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: 0.6,
        minHeight: 5,
        backgroundColor: Colors.white.withOpacity(0.08),
        valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
      ),
    );
  }

  // ── Private access ──
  Widget _buildPrivateAccess() {
    return Row(
      children: [
        Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.3), size: 13),
        const SizedBox(width: 4),
        Text(
          'Private Access',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // FOLDER CARD
  // ══════════════════════════════════════════════════════════════════
  Widget _buildFolderCard({
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required bool showMenu,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (showMenu)
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.4), size: 20),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CREATE FOLDER BUTTON
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCreateFolderButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            style: BorderStyle.solid,
          ),
          color: Colors.white.withOpacity(0.03),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: _amber.withOpacity(0.7), size: 18),
            const SizedBox(width: 10),
            Text(
              'Create New Intelligent Folder',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                _navItem(Icons.dashboard_rounded, 'Dashboard', true),
                _navItem(Icons.description_rounded, 'Documents', false),
                _navItem(Icons.chat_bubble_rounded, 'Chat', false),
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
        Icon(icon, color: color, size: 22,
          shadows: isActive ? [Shadow(color: _accentBlue.withOpacity(0.5), blurRadius: 12)] : null,
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
