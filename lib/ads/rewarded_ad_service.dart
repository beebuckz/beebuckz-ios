import 'dart:math';

import 'package:applovin_max/applovin_max.dart';

import 'ad_state.dart';

/// Manages a single AppLovin MAX rewarded ad unit: keeps one preloaded,
/// shows it on demand, auto-reloads, and fires [onRewardEarned] only after
/// the user has actually earned the reward AND closed the ad.
class RewardedAdService {
  RewardedAdService({required this.adUnitId, this.onRewardEarned});

  final String adUnitId;

  /// Called once, after the ad is dismissed, when a reward was granted.
  /// Wire this to credit the user (e.g. notify the web app / backend).
  void Function()? onRewardEarned;

  int _retryAttempt = 0;
  bool _rewardGranted = false;

  /// Registers listeners and preloads the first ad. Call after the SDK
  /// has finished initializing.
  void init() {
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) => _retryAttempt = 0,
      onAdLoadFailedCallback: (unitId, error) {
        // Exponential backoff, capped at ~64s.
        _retryAttempt++;
        final seconds = pow(2, min(6, _retryAttempt)).toInt();
        Future.delayed(Duration(seconds: seconds),
            () => AppLovinMAX.loadRewardedAd(adUnitId));
      },
      onAdDisplayedCallback: (ad) => AdState.fullscreenVisible = true,
      onAdDisplayFailedCallback: (ad, error) {
        AdState.fullscreenVisible = false;
        AppLovinMAX.loadRewardedAd(adUnitId);
      },
      onAdClickedCallback: (ad) {},
      onAdHiddenCallback: (ad) {
        AdState.fullscreenVisible = false;
        // Preload the next ad immediately.
        AppLovinMAX.loadRewardedAd(adUnitId);
        // Only credit once the ad is closed and a reward was earned.
        if (_rewardGranted) {
          _rewardGranted = false;
          onRewardEarned?.call();
        }
      },
      onAdReceivedRewardCallback: (ad, reward) => _rewardGranted = true,
    ));
    AppLovinMAX.loadRewardedAd(adUnitId);
  }

  /// Shows the rewarded ad if one is ready. Returns true if shown,
  /// false if no ad was ready (and kicks off a reload).
  Future<bool> show() async {
    final ready = await AppLovinMAX.isRewardedAdReady(adUnitId) ?? false;
    if (ready) {
      _rewardGranted = false;
      AppLovinMAX.showRewardedAd(adUnitId);
      return true;
    }
    AppLovinMAX.loadRewardedAd(adUnitId);
    return false;
  }
}
