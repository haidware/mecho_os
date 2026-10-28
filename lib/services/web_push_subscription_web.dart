import 'dart:convert';
import 'dart:js_interop';

@JS('window.mechoPush.subscribe')
external JSPromise<JSString> _subscribe(JSString applicationServerKey);

@JS('window.mechoPush.playAlert')
external JSBoolean _playAlert();

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
