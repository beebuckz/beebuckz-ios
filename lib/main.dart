import 'dart:convert';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ads/app_open_ad_service.dart';
import 'ads/interstitial_ad_service.dart';
import 'ads/rewarded_ad_service.dart';
import 'events/facebook_events.dart';

// ---------------------------------------------------------------------------
// AppLovin MAX configuration — REPLACE these placeholders with the real values
// from your AppLovin dashboard (https://dash.applovin.com):
//   1. SDK key:   Account → Keys → "SDK Key"
//   2. Ad units:  MAX → Ad Units → create one each of Rewarded / Interstitial /
//                 App Open for iOS, then paste their Ad Unit IDs below.
// ---------------------------------------------------------------------------
const String _appLovinSdkKey = 'YOUR_APPLOVIN_SDK_KEY';
const String _rewardedAdUnitId = 'YOUR_REWARDED_AD_UNIT_ID';
const String _interstitialAdUnitId = 'YOUR_INTERSTITIAL_AD_UNIT_ID';
const String _appOpenAdUnitId = 'YOUR_APP_OPEN_AD_UNIT_ID';

const String _siteUrl = 'https://beebuckz.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BeeBuckzApp());
}

class BeeBuckzApp extends StatelessWidget {
  const BeeBuckzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bee Buckz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5C518)),
        useMaterial3: true,
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final RewardedAdService _rewardedAds;
  late final InterstitialAdService _interstitialAds;
  late final AppOpenAdService _appOpenAds;
  final FacebookEvents _fbEvents = FacebookEvents();
  bool _adsReady = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _rewardedAds = RewardedAdService(
      adUnitId: _rewardedAdUnitId,
      onRewardEarned: _creditRewardToWeb,
    );
    _interstitialAds = InterstitialAdService(adUnitId: _interstitialAdUnitId);
    _appOpenAds = AppOpenAdService(adUnitId: _appOpenAdUnitId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFF8E7))
      // The website calls: FlutterAds.postMessage('showRewarded')
      // to play a rewarded ad. On success we call window.onBeeReward().
      ..addJavaScriptChannel('FlutterAds', onMessageReceived: _onWebAdMessage)
      // The website calls: FlutterEvents.postMessage(JSON) to log Meta events.
      ..addJavaScriptChannel('FlutterEvents',
          onMessageReceived: _onWebEventMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(_siteUrl));

    _initAds();
  }

  Future<void> _initAds() async {
    // iOS requires the App Tracking Transparency prompt before ads can use
    // tracking data. Ask after a short delay so it doesn't clash with launch.
    await Future.delayed(const Duration(milliseconds: 800));
    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    // Tell Meta whether it may use advertiser tracking (drives campaign ROAS).
    await _fbEvents.setAdvertiserTracking(
        status == TrackingStatus.authorized);

    final config = await AppLovinMAX.initialize(_appLovinSdkKey);
    if (config != null) {
      _rewardedAds.init();
      _interstitialAds.init();
      _appOpenAds.init();
      _adsReady = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Show an app-open ad when the user returns to the foreground.
    if (state == AppLifecycleState.resumed && _adsReady) {
      _appOpenAds.showIfAvailable();
    }
  }

  /// Handles messages posted from the web page via `FlutterAds.postMessage`.
  /// Accepts either a plain string ('showRewarded' | 'showInterstitial') or a
  /// JSON object like {"action":"showRewarded","userId":"123"} — passing the
  /// userId lets AppLovin's server-side reward callback credit the right user.
  Future<void> _onWebAdMessage(JavaScriptMessage message) async {
    var action = message.message;
    String? userId;
    final raw = message.message.trim();
    if (raw.startsWith('{')) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        action = (map['action'] ?? '') as String;
        userId = map['userId'] as String?;
      } catch (_) {
        return;
      }
    }

    switch (action) {
      case 'showRewarded':
        final shown = await _rewardedAds.show(userId: userId);
        if (!shown) {
          // Tell the web app no ad was ready so it can show a "try again" state.
          _controller.runJavaScript(
              'window.onBeeAdUnavailable && window.onBeeAdUnavailable();');
        }
        break;
      case 'showInterstitial':
        await _interstitialAds.show();
        break;
    }
  }

  /// Handles Meta app-event messages posted from the web via
  /// `FlutterEvents.postMessage(JSON.stringify({event, valueToSum, ...}))`.
  Future<void> _onWebEventMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      await _fbEvents.log(data);
    } catch (_) {
      // Ignore malformed event payloads.
    }
  }

  /// Called after a rewarded ad is watched. Notifies the web app so it can
  /// credit the user's Buckz (ideally verified server-side via S2S callback).
  void _creditRewardToWeb() {
    final payload = jsonEncode({'source': 'applovin_rewarded'});
    _controller
        .runJavaScript('window.onBeeReward && window.onBeeReward($payload);');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8E7),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                Container(
                  color: const Color(0xFFFFF8E7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🐝', style: TextStyle(fontSize: 52)),
                        SizedBox(height: 24),
                        CircularProgressIndicator(
                          color: Color(0xFFF5C518),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
