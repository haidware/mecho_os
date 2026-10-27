import 'dart:convert';

import 'package:http/http.dart' as http;

class SellerAdminApi {
  static const _baseUrl = String.fromEnvironment(
    'SELLER_API_URL',
    defaultValue: '',
  );
  final http.Client _client;

  SellerAdminApi({http.Client? client}) : _client = client ?? http.Client();

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<String> loginAdmin({
    required String username,
    required String password,
  }) async {
    final response = await _post('/admin/login', {
      'username': username,
      'password': password,
    });
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      throw const SellerAdminApiException(
          'Admin API returned an invalid token.');
    }
    return token;
  }

  Future<List<String>> generateSellerIds({
    required String adminToken,
    int count = 1,
  }) async {
    final response = await _post(
      '/admin/seller-ids',
      {'count': count},
      bearerToken: adminToken,
    );
    final ids = response['ids'];
    if (ids is! List || ids.any((id) => id is! String)) {
      throw const SellerAdminApiException(
        'Admin API returned an invalid seller ID response.',
      );
    }
    return ids.cast<String>();
  }

  Future<void> signupSeller({
    required String sellerId,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    await _post('/seller-signup', {
      'sellerId': sellerId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    if (!isConfigured) {
      throw const SellerAdminApiException(
        'Seller registration is not configured. Contact Mecho support.',
      );
    }
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const SellerAdminApiException(
        'Seller registration API URL is invalid.',
      );
    }

    final response = await _client
        .post(
          uri.resolve(path),
          headers: {
            'Content-Type': 'application/json',
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      throw SellerAdminApiException(
        'Seller registration service returned an invalid response '
        '(${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error'];
      throw SellerAdminApiException(
        message is String && message.isNotEmpty
            ? message
            : 'Request failed (${response.statusCode}).',
      );
    }
    return payload;
  }
}

class SellerAdminApiException implements Exception {
  final String message;

  const SellerAdminApiException(this.message);

  @override
  String toString() => message;
}
