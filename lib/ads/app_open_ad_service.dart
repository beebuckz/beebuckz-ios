import 'dart:math';

import 'package:applovin_max/applovin_max.dart';

import 'ad_state.dart';

/// Manages an AppLovin MAX app-open ad unit, shown when the user brings the
/// app back to the foreground. Skips showing if another full-screen ad is
/// already visible.
class AppOpenAdService {
  AppOpenAdService({required this.adUnitId});

  final String adUnitId;
  int _retryAttempt = 0;

  void init() {
    AppLovinMAX.setAppOpenAdListener(AppOpenAdListener(
      onAdLoadedCallback: (ad) => _retryAttempt = 0,
      onAdLoadFailedCallback: (unitId, error) {
        _retryAttempt++;
        final seconds = pow(2, min(6, _retryAttempt)).toInt();
        Future.delayed(Duration(seconds: seconds),
            () => AppLovinMAX.loadAppOpenAd(adUnitId));
      },
      onAdDisplayedCallback: (ad) => AdState.fullscreenVisible = true,
      onAdDisplayFailedCallback: (ad, error) {
        AdState.fullscreenVisible = false;
        AppLovinMAX.loadAppOpenAd(adUnitId);
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        AdState.fullscreenVisible = false;
        AppLovinMAX.loadAppOpenAd(adUnitId);
      },
    ));
    AppLovinMAX.loadAppOpenAd(adUnitId);
  }

  /// Shows the app-open ad if one is ready and no other full-screen ad is up.
  Future<void> showIfAvailable() async {
    if (AdState.fullscreenVisible) return;
    final ready = await AppLovinMAX.isAppOpenAdReady(adUnitId) ?? false;
    if (ready) {
      AppLovinMAX.showAppOpenAd(adUnitId);
    } else {
      AppLovinMAX.loadAppOpenAd(adUnitId);
    }
  }
}
