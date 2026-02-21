import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pdify/widgets/glass_card.dart';
import 'package:pdify/widgets/primary_button.dart';
import 'package:pdify/widgets/mesh_background_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true; // Toggle between Login and Signup
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  // Design Tokens (Matches HomeScreen)
  static const color1 = Color(0xFF7C3AED); // Vivid Purple

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isLogin = _tabController.index == 0;
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Google Sign In failed: ${e.toString()}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email first.";
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent!")),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to send reset email: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MeshBackgroundScaffold(
      showAppBar: false,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // App Title
              Text(
                "Pdify",
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white, // White
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),

              const SizedBox(height: 40),

              // Glassmorphic Card
              GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tabs (Login / Signup)
                    Theme(
                      data: theme.copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: color1,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: color1,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        tabs: const [
                          Tab(text: "Log in"),
                          Tab(text: "Sign up"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Form Fields
                    TextField(
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: color1,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: color1, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: color1,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: color1, width: 2),
                        ),
                      ),
                    ),

                    // Forgot Password (only visible in Login mode)
                    if (_isLogin) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),
                    ],

                    if (_isLogin) ...[
                      const SizedBox(height: 24),

                      // Divider OR
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "or",
                              style: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Google Sign In
                      OutlinedButton(
                        onPressed: _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png",
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.g_mobiledata,
                                      size: 32,
                                      color: Colors.blue,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Continue with Google",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Main Action Button
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: color1),
                      )
                    else
                      PrimaryButton(
                        text: _isLogin ? "Log in" : "Sign up",
                        onPressed: _submit,
                        backgroundColor: color1,
                      ),

                    const SizedBox(height: 16),

                    // Switcher Footer (Redundant with tabs but good for UX)
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _tabController.animateTo(_isLogin ? 1 : 0);
                        },
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white70),
                            children: [
                              TextSpan(
                                text: _isLogin
                                    ? "Don't have an account? "
                                    : "Already have an account? ",
                              ),
                              TextSpan(
                                text: _isLogin ? "Sign up" : "Log in",
                                style: const TextStyle(
                                  color: color1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Footer Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Privacy Policy",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Terms of Service",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
