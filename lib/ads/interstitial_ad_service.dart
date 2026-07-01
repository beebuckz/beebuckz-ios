import 'dart:math';

import 'package:applovin_max/applovin_max.dart';

import 'ad_state.dart';

/// Manages an AppLovin MAX interstitial ad unit: keeps one preloaded,
/// shows on demand, and auto-reloads after each show/failure.
class InterstitialAdService {
  InterstitialAdService({required this.adUnitId});

  final String adUnitId;
  int _retryAttempt = 0;

  void init() {
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) => _retryAttempt = 0,
      onAdLoadFailedCallback: (unitId, error) {
        _retryAttempt++;
        final seconds = pow(2, min(6, _retryAttempt)).toInt();
        Future.delayed(Duration(seconds: seconds),
            () => AppLovinMAX.loadInterstitial(adUnitId));
      },
      onAdDisplayedCallback: (ad) => AdState.fullscreenVisible = true,
      onAdDisplayFailedCallback: (ad, error) {
        AdState.fullscreenVisible = false;
        AppLovinMAX.loadInterstitial(adUnitId);
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        AdState.fullscreenVisible = false;
        AppLovinMAX.loadInterstitial(adUnitId);
      },
    ));
    AppLovinMAX.loadInterstitial(adUnitId);
  }

  /// Shows an interstitial if ready. Returns true if shown.
  Future<bool> show() async {
    final ready = await AppLovinMAX.isInterstitialReady(adUnitId) ?? false;
    if (ready) {
      AppLovinMAX.showInterstitial(adUnitId);
      return true;
    }
    AppLovinMAX.loadInterstitial(adUnitId);
    return false;
  }
}
