import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Registers this device for push notifications:
///  1. asks for notification permission (iOS + Android 13+),
///  2. sends the device push token to the BeeBuckz backend (FCM token on
///     Android, raw APNs token on iOS — matching how the backend sends),
///  3. hands the token to the web app inside the WebView, which re-posts it
///     with the member's Supabase session — binding the token to the account,
///  4. re-registers on token rotation and opens notification-tap URLs.
class PushService {
  PushService(this._controller);

  final WebViewController _controller;
  static const _registerEndpoint = 'https://beebuckz.com/push/register';
  String? _token;
  String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);
        // The backend pushes to iOS directly through APNs, so register the
        // raw APNs device token — an FCM token would only be deliverable
        // with the APNs key uploaded to the Firebase console.
        String? apnsToken;
        for (var i = 0;
            i < 10 && (apnsToken = await messaging.getAPNSToken()) == null;
            i++) {
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken != null) await _onNewToken(apnsToken);
      } else {
        final token = await messaging.getToken();
        if (token != null) await _onNewToken(token);
        messaging.onTokenRefresh.listen(_onNewToken);
      }

      // Notification taps: open the URL the push carries in the WebView.
      FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFromMessage(initial);
    } catch (_) {
      // Push is best-effort; never let it break the app.
    }
  }

  Future<void> _onNewToken(String token) async {
    _token = token;
    await _register(token);
    await injectIntoWeb();
  }

  /// Anonymous registration straight from the device (works pre-login).
  Future<void> _register(String token) async {
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(_registerEndpoint));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'token': token, 'platform': _platform}));
      await (await req.close()).drain<void>();
      client.close();
    } catch (_) {}
  }

  /// Expose the token to the web app; it re-posts it with the member's
  /// Supabase JWT so the backend can bind the token to the account. Called
  /// after every page load too, since navigation wipes injected JS state.
  Future<void> injectIntoWeb() async {
    final token = _token;
    if (token == null) return;
    final payload = jsonEncode({'token': token, 'platform': _platform});
    try {
      await _controller.runJavaScript('window.__beePush = $payload;'
          "window.dispatchEvent(new Event('bee-push-token'));");
    } catch (_) {}
  }

  void _openFromMessage(RemoteMessage message) {
    final url = message.data['url'];
    // Exact-origin check ('https://beebuckz.com.evil.com' must not pass).
    if (url is String &&
        (url == 'https://beebuckz.com' ||
            url.startsWith('https://beebuckz.com/'))) {
      _controller.loadRequest(Uri.parse(url));
    }
  }
}
