import 'web_push_subscription_stub.dart'
    if (dart.library.js_interop) 'web_push_subscription_web.dart' as platform;

Future<Map<String, dynamic>> getWebPushSetupStatus() {
  return platform.getWebPushSetupStatus();
}

Future<Map<String, dynamic>?> getExistingWebPushSubscription() {
  return platform.getExistingWebPushSubscription();
}

Future<Map<String, dynamic>> createWebPushSubscription(String publicKey) {
  return platform.createWebPushSubscription(publicKey);
}

Future<void> playWebPushAlert() {
  return platform.playWebPushAlert();
}
