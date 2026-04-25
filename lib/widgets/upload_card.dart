import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdify/widgets/primary_button.dart';

class UploadCard extends StatelessWidget {
  final bool isUploading;
  final bool isGenerating;
  final String statusMessage;
  final VoidCallback onUploadPressed;

  const UploadCard({
    super.key,
    required this.isUploading,
    required this.isGenerating,
    required this.statusMessage,
    required this.onUploadPressed,
  });

  static const _accentBlue = Color(0xFF3B82F6);
  static const _accentCyan = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accentBlue.withOpacity(0.12),
              _accentCyan.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: _accentBlue.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          (isUploading || isGenerating)
                              ? Icons.sync_rounded
                              : Icons.cloud_upload_rounded,
                          color: _accentBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (isUploading || isGenerating)
                                  ? statusMessage
                                  : "Upload Document",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (isUploading || isGenerating)
                                  ? "Please wait while we process your file"
                                  : "Analyze any PDF with AI",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isUploading || isGenerating) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: _accentBlue.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: "Select PDF Document",
                      onPressed: onUploadPressed,
                      icon: Icons.add_rounded,
                      height: 45,
                      width: double.infinity,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  const Text(
                    "TRIPLE AI INSIGHTS",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: _accentBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _insightFeature(Icons.auto_awesome_rounded, "Summary"),
                      _insightFeature(Icons.school_rounded, "Exam Prep"),
                      _insightFeature(Icons.list_alt_rounded, "Chapters"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _insightFeature(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
