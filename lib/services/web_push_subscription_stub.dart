Future<Map<String, dynamic>> getWebPushSetupStatus() async => {
      'supported': false,
      'permission': 'unsupported',
      'message': 'Browser notifications are available in the web app.',
    };

Future<Map<String, dynamic>?> getExistingWebPushSubscription() async => null;

Future<String> requestWebPushPermission() async => 'unsupported';

Future<Map<String, dynamic>> createWebPushSubscription(String publicKey) {
  throw UnsupportedError('Push notifications are available in the web app.');
}

Future<void> playWebPushAlert() async {}
