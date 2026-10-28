import 'dart:convert';
import 'dart:js_interop';

@JS('window.mechoPush.subscribe')
external JSPromise<JSString> _subscribe(JSString applicationServerKey);

@JS('window.mechoPush.playAlert')
external JSBoolean _playAlert();

@JS('window.mechoPush.getSetupStatus')
external JSString _getSetupStatus();

@JS('window.mechoPush.getSubscription')
external JSPromise<JSString> _getSubscription();

Future<Map<String, dynamic>> getWebPushSetupStatus() async {
  final json = _getSetupStatus().toDart;
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Could not read notification support status.');
  }
  return decoded;
}

Future<Map<String, dynamic>?> getExistingWebPushSubscription() async {
  final json = (await _getSubscription().toDart).toDart;
  final decoded = jsonDecode(json);
  if (decoded == null) return null;
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
        'Could not read this device’s push subscription.');
  }
  return decoded;
}

Future<Map<String, dynamic>> createWebPushSubscription(String publicKey) async {
  final json = (await _subscribe(publicKey.toJS).toDart).toDart;
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
        'The browser returned an invalid push subscription.');
  }
  return decoded;
}

Future<void> playWebPushAlert() async {
  _playAlert();
}
