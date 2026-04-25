import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PremiumHeader extends StatelessWidget {
  final String title;
  final bool showLogo;
  final bool showBack;
  final bool showProfile;
  final List<Widget>? actions;
  final VoidCallback? onProfileTap;
  final VoidCallback? onBackTap;

  const PremiumHeader({
    super.key,
    required this.title,
    this.showLogo = true,
    this.showBack = false,
    this.showProfile = true,
    this.actions,
    this.onProfileTap,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 4),
          ],
          if (showLogo && !showBack) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 28,
                  height: 28,
                  color: theme.primaryColor.withOpacity(0.2),
                  child: const Icon(Icons.blur_on_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          if (showProfile) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onProfileTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ),
          ],
        ],
      ),
    );
  }
}
