import 'dart:convert';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ads/rewarded_ad_service.dart';

// ---------------------------------------------------------------------------
// AppLovin MAX configuration — REPLACE these two placeholders with the real
// values from your AppLovin dashboard (https://dash.applovin.com):
//   1. SDK key:   Account → Keys → "SDK Key"
//   2. Ad unit:   MAX → Ad Units → create a "Rewarded" ad unit for iOS,
//                 then paste its Ad Unit ID here.
// ---------------------------------------------------------------------------
const String _appLovinSdkKey = 'YOUR_APPLOVIN_SDK_KEY';
const String _rewardedAdUnitId = 'YOUR_REWARDED_AD_UNIT_ID';

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

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  late final RewardedAdService _rewardedAds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _rewardedAds = RewardedAdService(
      adUnitId: _rewardedAdUnitId,
      onRewardEarned: _creditRewardToWeb,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFF8E7))
      // The website calls: FlutterAds.postMessage('showRewarded')
      // to play a rewarded ad. On success we call window.onBeeReward().
      ..addJavaScriptChannel('FlutterAds', onMessageReceived: _onWebAdMessage)
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
    await AppTrackingTransparency.requestTrackingAuthorization();

    final config = await AppLovinMAX.initialize(_appLovinSdkKey);
    if (config != null) {
      _rewardedAds.init();
    }
  }

  /// Handles messages posted from the web page via `FlutterAds.postMessage`.
  Future<void> _onWebAdMessage(JavaScriptMessage message) async {
    if (message.message == 'showRewarded') {
      final shown = await _rewardedAds.show();
      if (!shown) {
        // Tell the web app no ad was ready so it can show a "try again" state.
        _controller.runJavaScript(
            'window.onBeeAdUnavailable && window.onBeeAdUnavailable();');
      }
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
