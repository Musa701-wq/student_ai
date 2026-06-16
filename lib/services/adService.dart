import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static BannerAd? bannerAd;
  static bool isPro = false;

  // ✅ Centralized ad unit IDs (Standard Test IDs for Debug Mode)
  static String get _interstitialAdId => kDebugMode 
    ? "ca-app-pub-3940256099942544/4411468910" 
    : "ca-app-pub-3774337907915828/2528660957";

  static String get _bannerAdId => kDebugMode 
    ? "ca-app-pub-3940256099942544/2934735716" 
    : "ca-app-pub-3774337907915828/1061049500";

  static String get _rewardedAdId => kDebugMode 
    ? "ca-app-pub-3940256099942544/1712485313" 
    : "ca-app-pub-3774337907915828/4113205367";

  static Future<void> init() async {
    print("loading ads");
    await MobileAds.instance.initialize();
    await _checkUserProStatus();
    _loadInterstitial();
    _loadBanner();
  }

  static Future<void> _checkUserProStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap =
      await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      if (snap.exists) {
        final data = snap.data();
        isPro = (data?["isPro"] ?? false) == true;
      } else {
        isPro = false;
      }
    } catch (e) {
      debugPrint("Error checking pro status: $e");
      isPro = false;
    }
  }

  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint("⚠️ Failed to load interstitial ad: $err");
          _interstitialAd = null;
        },
      ),
    );
  }

  static void _loadBanner() {
    print("loading banner ad");
    bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: _bannerAdId,
      listener: const BannerAdListener(),
      request: const AdRequest(),
    )..load();
  }

  // ✅ Simplified: Use single banner creation method
  static BannerAd? createBannerAd() {
    if (isPro) return null;

    try {
      return BannerAd(
        size: AdSize.banner,
        adUnitId: _bannerAdId,
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) => print('Banner ad loaded.'),
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            print('Banner ad failed to load: $error');
            ad.dispose();
          },
        ),
        request: const AdRequest(),
      )..load();
    } catch (e) {
      print("Error creating banner ad: $e");
      return null;
    }
  }

  static void disposeBannerAd() {
    bannerAd?.dispose();
    bannerAd = null;
  }

  static Future<void> showInterstitialAndNavigate(
    BuildContext context,
    Widget targetScreen,
  ) async {
    await _checkUserProStatus();
    if (isPro) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
      return;
    }

    final ad = _interstitialAd; // 🚀 Capture local reference
    if (ad != null) {
      _interstitialAd = null; // 🚀 Clear immediately to prevent race conditions
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitial();
          Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitial();
          Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
        },
      );
      ad.show();
    } else {
      debugPrint("ℹ️ Interstitial ad not ready. Navigating without showing ad.");
      Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
    }
  }

  static Future<void> showRewardedAd(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool rewardEarned = false;

    RewardedAd.load(
      adUnitId: _rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();

              if (rewardEarned) {
                try {
                  final userDoc =
                  FirebaseFirestore.instance.collection("users").doc(user.uid);

                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final snap = await tx.get(userDoc);
                    final currentCredits = (snap.data()?['credits'] ?? 0) as int;
                    tx.update(userDoc, {'credits': currentCredits + 5});
                  });
                  print('credits added');

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset(
                            'assets/success.json',
                            repeat: false,
                            onLoaded: (comp) {
                              Future.delayed(comp.duration, () {
                                Navigator.of(context).pop();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Credits Added 🎉",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                decoration: TextDecoration.none
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                } catch (e) {
                  debugPrint("Error updating credits: $e");
                }
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );

          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              rewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint("⚠️ Failed to load rewarded ad: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No rewarded ad available. Please try again later.")),
          );
        },
      ),
    );
  }
}