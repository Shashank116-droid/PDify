import 'dart:ui';
import 'package:flutter/material.dart';

class MeshBackgroundScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final bool showAppBar;
  final Color? backgroundColor;

  const MeshBackgroundScaffold({
    super.key,
    required this.body,
    this.title,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.actions,
    this.showAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    const color1 = Color(0xFF7C3AED);
    const color2 = Color(0xFFFF6B6B);
    const color3 = Color(0xFF00D9FF);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: title != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title == 'Tools') ...[
                          const Icon(
                            Icons.transform_rounded,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          title!,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C3AED),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    )
                  : null,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: actions,
              iconTheme: IconThemeData(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF7C3AED),
              ),
            )
          : null,
      body: Stack(
        children: [
          // --- Gradient Mesh Background ---
          Positioned(top: -80, right: -60, child: _buildMeshBlob(color1, 280)),
          Positioned(
            bottom: 100,
            left: -60,
            child: _buildMeshBlob(color2, 300),
          ),
          Positioned(
            bottom: -50,
            right: -40,
            child: _buildMeshBlob(color3, 250),
          ),

          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                color: (theme.scaffoldBackgroundColor).withValues(alpha: 0.3),
              ),
            ),
          ),

          // --- Content ---
          SafeArea(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildMeshBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
