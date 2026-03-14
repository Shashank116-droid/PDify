import 'dart:ui';

import 'package:pdify/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pdify/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:pdify/ad_service.dart';
import 'package:pdify/firebase_options.dart';
import 'package:pdify/convert_screen.dart';
import 'package:pdify/home_screen.dart';
import 'package:pdify/login_screen.dart';
import 'package:pdify/profile_screen.dart';
import 'package:pdify/splash_screen.dart';
import 'package:pdify/providers/search_filter_provider.dart';
import 'package:pdify/providers/theme_provider.dart';
import 'package:pdify/providers/bookmark_provider.dart';
import 'package:pdify/providers/chat_provider.dart';
import 'package:pdify/services/voice_service.dart';
import 'package:pdify/providers/navigation_provider.dart';
import 'package:pdify/providers/folder_provider.dart';
import 'package:pdify/providers/summary_provider.dart';
import 'package:pdify/ai_assistant_screen.dart';
import 'package:pdify/widgets/app_drawer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AdService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchFilterProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider()..loadBookmarks(),
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => FolderProvider()..loadFolders()),
        ChangeNotifierProvider(create: (_) => SummaryProvider()..loadCache()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Pdify',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark, // Forced dark mode
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _minSplashDurationPassed = false;

  @override
  void initState() {
    super.initState();
    // Ensure splash shows for at least 2 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _minSplashDurationPassed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If still waiting for auth or haven't shown splash long enough, show splash
        if (snapshot.connectionState == ConnectionState.waiting || !_minSplashDurationPassed) {
          return const SplashScreen(isInitialBoot: true);
        }
        
        if (snapshot.hasData) {
          return const MainNavigation();
        }
        return const WelcomeScreen();
      },
    );
  }
}


class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  final List<Widget> _screens = const [
    HomeScreen(isDocumentsOnly: false), // AI Summarizer
    HomeScreen(isDocumentsOnly: true),  // Documents
    AiAssistantScreen(), 
    ConvertScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navProvider = context.watch<NavigationProvider>();

    return Scaffold(
      extendBody: true,
      drawer: const AppDrawer(), // Add the new drawer
      body: IndexedStack(index: navProvider.currentIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: BottomNavigationBar(
                  currentIndex: navProvider.currentIndex,
                  onTap: (index) => navProvider.setIndex(index),
                  selectedItemColor: const Color(0xFF3B82F6),
                  unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
                  backgroundColor: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : Colors.white.withOpacity(0.5),
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  showUnselectedLabels: true,
                  selectedIconTheme: const IconThemeData(
                    shadows: [Shadow(color: Color(0xFF3B82F6), blurRadius: 12)],
                  ),
                  selectedLabelStyle: const TextStyle(
                    shadows: [Shadow(color: Color(0xFF3B82F6), blurRadius: 12)],
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                  ),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.auto_awesome_mosaic_rounded),
                      label: 'AI Summarizer',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.description_rounded),
                      label: 'Documents',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.auto_awesome_rounded), // Or generic text icon
                      label: 'Chat',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.grid_view_rounded),
                      label: 'Tools',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

