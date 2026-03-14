import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdify/login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          // Mesh gradient blobs
          Positioned(
            top: -120,
            right: -100,
            child: _meshBlob(const Color(0xFF3B82F6), 400),
          ),
          Positioned(
            bottom: 200,
            left: -120,
            child: _meshBlob(const Color(0xFF1E1B4B), 500),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _meshBlob(const Color(0xFF00D9FF), 300),
          ),
          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: const Color(0xFF0B1120).withOpacity(0.65),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // ── Header ──
                      _buildHeader(),
                      const SizedBox(height: 32),
                      // ── Tagline ──
                      _buildTagline(),
                      const SizedBox(height: 20),
                      // ── Hero Title ──
                      _buildHeroTitle(),
                      const SizedBox(height: 20),
                      // ── Description ──
                      _buildDescription(),
                      const SizedBox(height: 32),
                      // ── Buttons ──
                      _buildGetStartedButton(),
                      const SizedBox(height: 14),
                      _buildViewDemoButton(),
                      const SizedBox(height: 40),
                      // ── Preview Card ──
                      _buildPreviewCard(),
                      const SizedBox(height: 40),
                      // ── Feature Grid ──
                      _buildFeatureGrid(),
                      const SizedBox(height: 48),
                      // ── Footer ──
                      _buildFooter(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'PDify',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Tagline ─────────────────────────────────────────────────────
  Widget _buildTagline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
      ),
      child: const Text(
        'INTELLIGENCE REIMAGINED',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: Color(0xFF60A5FA),
        ),
      ),
    );
  }

  // ── Hero Title ──────────────────────────────────────────────────
  Widget _buildHeroTitle() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -1,
          color: Colors.white,
        ),
        children: [
          TextSpan(text: 'Unlock the\nPower of\n'),
          TextSpan(
            text: 'Your\n',
            style: TextStyle(
              color: Color(0xFF60A5FA),
            ),
          ),
          TextSpan(text: 'Documents'),
        ],
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────────
  Widget _buildDescription() {
    return Text(
      'Experience seamless AI-driven summaries that transform complex data into actionable insights. PDify bridges the gap between raw information and human intelligence.',
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: Colors.white.withOpacity(0.6),
      ),
    );
  }

  // ── Get Started Button ──────────────────────────────────────────
  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _navigateToAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Get Started',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── View Demo Button ────────────────────────────────────────────
  Widget _buildViewDemoButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _navigateToAuth,
        icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
        label: const Text(
          'View Demo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  // ── Preview Card ────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF131B2E),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.08),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with "Fast Analysis" badge
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Color(0xFF60A5FA), size: 14),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fast Analysis',
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '3.1s Average speed',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // LIVE SUMMARY label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE SUMMARY',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Summary text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: const Color(0xFF7C3AED).withOpacity(0.6),
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"This document outlines the strategic shift towards autonomous AI integration in Q4..."',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
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

  // ── Feature Grid ────────────────────────────────────────────────
  Widget _buildFeatureGrid() {
    final features = [
      _FeatureItem(
        icon: Icons.psychology_rounded,
        iconColor: const Color(0xFF60A5FA),
        title: 'AI Parsing',
        subtitle: 'Natural language\nunderstanding\nat scale.',
      ),
      _FeatureItem(
        icon: Icons.shield_rounded,
        iconColor: const Color(0xFF34D399),
        title: 'Secure Vault',
        subtitle: 'Military-grade\nencryption for\nall files.',
      ),
      _FeatureItem(
        icon: Icons.sync_rounded,
        iconColor: const Color(0xFFFBBF24),
        title: 'Real-time Sync',
        subtitle: 'Access your\ndata across\nall devices.',
      ),
      _FeatureItem(
        icon: Icons.grid_view_rounded,
        iconColor: const Color(0xFFA78BFA),
        title: 'Batch Process',
        subtitle: 'Summarize\n100+ PDFs in\nseconds.',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: features.map((f) => _buildFeatureTile(f)).toList(),
    );
  }

  Widget _buildFeatureTile(_FeatureItem feature) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: feature.iconColor.withOpacity(0.12),
            ),
            child: Icon(feature.icon, color: feature.iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              feature.subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Divider(color: Colors.white.withOpacity(0.08)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PDify',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '© 2024 Intelligent Systems Inc.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _footerLink('PRIVACY POLICY'),
            _footerLink('TERMS OF SERVICE'),
            _footerLink('SUPPORT'),
          ],
        ),
      ],
    );
  }

  Widget _footerLink(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.35),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Mesh blob helper ────────────────────────────────────────────
  Widget _meshBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.6),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}
