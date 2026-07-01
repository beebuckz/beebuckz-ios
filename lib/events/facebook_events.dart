import 'package:facebook_app_events/facebook_app_events.dart';

/// Thin wrapper around the Facebook App Events SDK. Lets the web app log the
/// standard events Meta uses to measure ad performance, optimise delivery and
/// build audiences — improving ROAS on your Meta campaigns.
class FacebookEvents {
  final FacebookAppEvents _fb = FacebookAppEvents();

  /// Enable/disable advertiser-ID collection. On iOS the SDK also derives
  /// tracking consent from App Tracking Transparency automatically.
  Future<void> setAdvertiserTracking(bool enabled) =>
      _fb.setAdvertiserIdCollectionEnabled(enabled);

  /// Routes a message from the web bridge to the right Facebook event.
  /// Expected shape: {"event":"purchase","valueToSum":9.99,"currency":"USD",
  ///                  "params":{"fb_content_id":"abc","fb_content_type":"x"}}
  Future<void> log(Map<String, dynamic> data) async {
    final event = (data['event'] ?? '') as String;
    final params = (data['params'] as Map?)?.cast<String, dynamic>();
    final valueToSum = (data['valueToSum'] as num?)?.toDouble();
    final currency = data['currency'] as String?;

    switch (event) {
      case 'view_content':
        await _fb.logViewContent(
            id: params?['fb_content_id'] as String?,
            type: params?['fb_content_type'] as String?,
            currency: currency,
            price: valueToSum);
        break;
      case 'search':
        await _fb.logEvent(name: 'fb_mobile_search', parameters: params);
        break;
      case 'complete_registration':
        await _fb.logCompletedRegistration(
            registrationMethod: params?['fb_registration_method'] as String?);
        break;
      case 'initiate_checkout':
        await _fb.logInitiatedCheckout(
            totalPrice: valueToSum, currency: currency);
        break;
      case 'purchase':
        await _fb.logPurchase(
            amount: valueToSum ?? 0, currency: currency ?? 'USD',
            parameters: params);
        break;
      case 'subscribe':
        await _fb.logEvent(
            name: 'Subscribe', valueToSum: valueToSum, parameters: params);
        break;
      case 'start_trial':
        await _fb.logEvent(
            name: 'StartTrial', valueToSum: valueToSum, parameters: params);
        break;
      default:
        // Fallback: log a custom event by whatever name the web passed.
        if (event.isNotEmpty) {
          await _fb.logEvent(
              name: event, valueToSum: valueToSum, parameters: params);
        }
    }
  }
}
