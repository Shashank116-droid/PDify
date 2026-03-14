import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Singleton service to manage all AdMob ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Real Ad Unit IDs (Production)
  static const String _androidBannerId =
      'ca-app-pub-5456835571588899/6862548820';
  static const String _androidInterstitialId =
      'ca-app-pub-5456835571588899/2796881548';
  static const String _androidRewardedId =
      'ca-app-pub-5456835571588899/4236385488';

  // Test Ad Unit IDs (Development)
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return kReleaseMode ? _androidBannerId : _testBannerId;
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return kReleaseMode ? _androidInterstitialId : _testInterstitialId;
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return kReleaseMode ? _androidRewardedId : _testRewardedId;
    }
    return '';
  }

  // Ad instances
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInterstitialLoaded = false;
  bool _isRewardedLoaded = false;

  // Getters
  bool get isInterstitialLoaded => _isInterstitialLoaded;
  bool get isRewardedLoaded => _isRewardedLoaded;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Pre-load ads
    loadInterstitialAd();
    loadRewardedAd();
  }

  // ==================== BANNER AD ====================

  /// Creates a new BannerAd instance
  BannerAd createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  // Helper widget for Banner Ads
  static Widget buildBannerWidget({
    required BannerAd? ad,
    required bool isLoaded,
  }) {
    if (ad != null && isLoaded) {
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    return const SizedBox.shrink();
  }

  // ==================== INTERSTITIAL AD ====================

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdService: Interstitial loaded.");
          _interstitialAd = ad;
          _isInterstitialLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint("AdService: Interstitial showed.");
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("AdService: Interstitial dismissed.");
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd(); // Reload
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("AdService: Interstitial failed to show: $error");
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("AdService: Interstitial failed to load: $error");
          _isInterstitialLoaded = false;
          Future.delayed(const Duration(seconds: 30), loadInterstitialAd);
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null && _isInterstitialLoaded) {
      try {
        await _interstitialAd!.show();
      } catch (e) {
        debugPrint("AdService: Error showing interstitial: $e");
        _isInterstitialLoaded = false;
        loadInterstitialAd();
      }
    } else {
      loadInterstitialAd();
    }
  }

  // ==================== REWARDED AD ====================

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("AdService: Rewarded ad loaded.");
          _rewardedAd = ad;
          _isRewardedLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint("AdService: Rewarded ad showed.");
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("AdService: Rewarded ad dismissed.");
              ad.dispose();
              _isRewardedLoaded = false;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("AdService: Rewarded ad failed to show: $error");
              ad.dispose();
              _isRewardedLoaded = false;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("AdService: Rewarded ad failed to load: $error");
          _isRewardedLoaded = false;
          Future.delayed(const Duration(seconds: 30), loadRewardedAd);
        },
      ),
    );
  }

  Future<bool> showRewardedAd({required Function() onRewarded}) async {
    debugPrint("AdService: Attempting to show rewarded ad. Loaded: $_isRewardedLoaded");
    
    if (_rewardedAd != null && _isRewardedLoaded) {
      try {
        await _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            debugPrint("AdService: User earned reward.");
            onRewarded();
          },
        );
        return true;
      } catch (e) {
        debugPrint("AdService: Exception showing rewarded ad: $e");
        _isRewardedLoaded = false;
        loadRewardedAd();
        return false;
      }
    } else {
      debugPrint("AdService: Ad not loaded yet.");
      loadRewardedAd();
      return false;
    }
  }

  // ==================== CLEANUP ====================

  void dispose() {
    // _bannerAd?.dispose(); // This line was commented out or removed in the original context, but it's good practice to dispose of all ads.
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

/// A reusable widget that manages a Banner Ad lifecycle
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = AdService().createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
      },
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isLoaded) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
